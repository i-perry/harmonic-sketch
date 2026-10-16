import Foundation

enum RelationMode: String, CaseIterable { case tonal = "Tonal harmony", flow = "Flow", contrast = "Contrast" }
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
    // Transparent heuristics; these do not reproduce Klimper's proprietary ranking.
    static func relation(from chord: ChordClip?, root: Int, quality: ChordQuality, mode: RelationMode) -> Double {
        guard let chord else { return 0 }
        let old = Set(chord.pitches.map(pc)); let new = Set(quality.intervals.map { pc(root + $0) })
        let common = Double(old.intersection(new).count) / Double(max(old.count, new.count))
        switch mode {
        case .tonal: return [5,7].contains(pc(root - chord.root)) ? 1 : common
        case .flow: return common
        case .contrast: return 1 - common
        }
    }
}
