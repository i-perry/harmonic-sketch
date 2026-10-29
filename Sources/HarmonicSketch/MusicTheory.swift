import Foundation

enum RelationMode: String, CaseIterable { case tonal = "Tonal harmony", flow = "Flow", contrast = "Contrast" }

/// Chord identity used by the recovered relation callbacks. `intervalOffsets`
/// excludes the root, and retains octave-bearing intervals such as 14.
struct HarmonyChord: Equatable {
    let root: Int
    let intervalOffsets: [Int]

    init(root: Int, intervalOffsets: [Int]) {
        self.root = MusicTheory.pc(root)
        self.intervalOffsets = Array(Set(intervalOffsets.filter { $0 != 0 })).sorted()
    }

    var pitchClasses: Set<Int> {
        Set([root] + intervalOffsets.map { MusicTheory.pc(root + $0) })
    }

    static func from(root: Int, quality: ChordQuality) -> HarmonyChord {
        HarmonyChord(root: root, intervalOffsets: quality.intervals)
    }
}

enum MusicTheory {
    static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static func pc(_ pitch: Int) -> Int { (pitch % 12 + 12) % 12 }
    static func name(_ pitch: Int) -> String { names[pc(pitch)] }
    static func inScale(root: Int, quality: ChordQuality, key: Int, mode: ScaleMode) -> Bool {
        let scale = Set(mode.intervals.map { pc($0 + key) })
        return quality.intervals.allSatisfy { scale.contains(pc(root + $0)) }
    }
    static func label(root: Int, quality: ChordQuality, key: Int, mode: ScaleMode, roman: Bool) -> String {
        guard roman else { return name(root) + quality.symbol }
        let degree = pc(root - key)
        let basic = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let isMinor = [.minor, .minorSixth, .minorSeventh, .minorNinth, .diminished, .diminishedSeventh, .halfDiminished].contains(quality)
        let suffix: String
        switch quality {
        case .minor: suffix = ""
        case .diminished: suffix = "°"
        case .minorSeventh: suffix = "7"
        case .minorSixth: suffix = "6"
        case .minorNinth: suffix = "9"
        default: suffix = quality.symbol
        }
        if let index = mode.intervals.firstIndex(of: degree) { return (isMinor ? basic[index].lowercased() : basic[index]) + suffix }
        let index = mode.intervals.enumerated().min(by: { abs($0.element - degree) < abs($1.element - degree) })?.offset ?? 0
        return (degree < mode.intervals[index] ? "♭" : "♯") + basic[index] + quality.symbol
    }

    /// Klimper Flow callback, preserving its first/second callback argument order.
    static func flowScore(first: HarmonyChord?, second: HarmonyChord) -> Float {
        guard let first else { return 0.8 }
        let overlap = sharedToneRatio(first, second)
        return clamp01(1.25 * overlap - 0.25)
    }

    /// Klimper Contrast callback, including its exact-chord score exception.
    static func contrastScore(first: HarmonyChord?, second: HarmonyChord) -> Float {
        guard let first else { return 0.8 }
        if first == second { return 1 }
        let overlap = sharedToneRatio(first, second)
        return clamp01(1.25 * (1 - overlap) - 0.25)
    }

    /// Klimper Match Notes callback. A missing selection returns 0.8; an
    /// engaged empty selection retains the source's unguarded 0/0 result.
    static func matchNotesScore(selection: [Int]?, second: HarmonyChord) -> Float {
        guard let selection else { return 0.8 }
        let selectedPitchClasses = Set(selection.map(pc))
        let sharedCount = selectedPitchClasses.intersection(second.pitchClasses).count
        return Float(sharedCount) / Float(selectedPitchClasses.count)
    }

    private static func sharedToneRatio(_ first: HarmonyChord, _ second: HarmonyChord) -> Float {
        let denominator = min(first.intervalOffsets.count + 1, second.intervalOffsets.count + 1)
        let sharedCount = first.pitchClasses.intersection(second.pitchClasses).count
        return Float(sharedCount) / Float(denominator)
    }

    private static func clamp01(_ value: Float) -> Float { max(0, min(1, value)) }

    // Transparent heuristics; these do not reproduce Klimper's proprietary ranking.
    static func relation(from chord: ChordClip?, root: Int, quality: ChordQuality, mode: RelationMode, key: Int = 0) -> Double {
        let candidate = HarmonyChord.from(root: root, quality: quality)
        let first = chord.map { HarmonyChord.from(root: $0.root, quality: $0.quality) }
        switch mode {
        case .flow:
            return Double(flowScore(first: first, second: candidate))
        case .contrast:
            return Double(contrastScore(first: first, second: candidate))
        case .tonal:
            guard let chord else { return 0.8 }
            let firstChord = first ?? HarmonyChord.from(root: chord.root, quality: chord.quality)
            return Double(tonalScore(first: firstChord, second: candidate, key: key))
        }
    }

    /// Recovered Tonal callback for engaged chords. Interval branch selection
    /// uses exact stored offsets; only derived pitch classes are normalized.
    static func tonalScore(first: HarmonyChord, second: HarmonyChord, key: Int) -> Float {
        let firstHasTwo = first.intervalOffsets.contains(2)
        let firstHasFive = first.intervalOffsets.contains(5)
        let secondHasTwo = second.intervalOffsets.contains(2)
        let secondHasFive = second.intervalOffsets.contains(5)

        guard firstHasTwo || firstHasFive || secondHasTwo || secondHasFive else {
            return tonalOrdinaryScore(first: first, second: second, key: key)
        }

        if let firstOffset = firstHasTwo ? 2 : (firstHasFive ? 5 : nil) {
            let x = pc(first.root + firstOffset)
            if let third = second.intervalOffsets.contains(3) ? 3 : (second.intervalOffsets.contains(4) ? 4 : nil) {
                let y = pc(second.root + third)
                if firstHasFive {
                    if y == pc(x - 1) || y == pc(x - 2) { return 1 }
                } else if y == pc(x + 1) || y == pc(x + 2) {
                    return 1
                }
            }
        }

        guard let secondOffset = secondHasTwo ? 2 : (secondHasFive ? 5 : nil) else { return 0 }
        let z = pc(second.root + secondOffset)
        return first.pitchClasses.contains(z) ? Float(bitPattern: 0x3f333333) : 0
    }

    /// Exact ordinary-branch predicates recovered from the Tonal callback.
    /// `first` and `second` preserve callback order; `key` is a pitch class.
    private static func tonalOrdinaryScore(first: HarmonyChord, second: HarmonyChord, key: Int) -> Float {
        let a = pc(first.root - key)
        let b = pc(second.root - key)
        let delta = pc(second.root - first.root)
        let acceptedRootPairs: Set<[Int]> = [[5, 11], [7, 0], [11, 0], [9, 5], [8, 2], [8, 5], [2, 11], [5, 7]]
        if first.root == second.root || first.root == pc(key) || delta == 5 || acceptedRootPairs.contains([a, b]) {
            return 1
        }
        return [1, 2, 6, 8, 9].contains(delta) ? Float(bitPattern: 0x3f333333) : 0
    }
}
