import Foundation

enum ScaleMode: String, Codable, CaseIterable {
    case major, dorian, phrygian, lydian, mixolydian, minor, locrian, harmonicMinor
    var intervals: [Int] {
        switch self {
        case .major: return [0,2,4,5,7,9,11]
        case .dorian: return [0,2,3,5,7,9,10]
        case .phrygian: return [0,1,3,5,7,8,10]
        case .lydian: return [0,2,4,6,7,9,11]
        case .mixolydian: return [0,2,4,5,7,9,10]
        case .minor: return [0,2,3,5,7,8,10]
        case .locrian: return [0,1,3,5,6,8,10]
        case .harmonicMinor: return [0,2,3,5,7,8,11]
        }
    }
    var label: String { rawValue == "harmonicMinor" ? "Harmonic minor" : rawValue.capitalized }
}
enum ChordQuality: String, Codable, CaseIterable {
    case major, minor, diminished, augmented, sus2, sus4, power, sixth, minorSixth, seventh, majorSeventh, minorSeventh, diminishedSeventh, halfDiminished, ninth, majorNinth, minorNinth, eleventh, sevenSus4
    var intervals: [Int] {
        switch self {
        case .major: return [0,4,7]
        case .minor: return [0,3,7]
        case .diminished: return [0,3,6]
        case .augmented: return [0,4,8]
        case .sus2: return [0,2,7]
        case .sus4: return [0,5,7]
        case .power: return [0,7]
        case .sixth: return [0,4,7,9]
        case .minorSixth: return [0,3,7,9]
        case .seventh: return [0,4,7,10]
        case .majorSeventh: return [0,4,7,11]
        case .minorSeventh: return [0,3,7,10]
        case .diminishedSeventh: return [0,3,6,9]
        case .halfDiminished: return [0,3,6,10]
        case .ninth: return [0,4,7,10,14]
        case .majorNinth: return [0,4,7,11,14]
        case .minorNinth: return [0,3,7,10,14]
        case .eleventh: return [0,4,7,10,14,17]
        case .sevenSus4: return [0,5,7,10]
        }
    }
    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "+"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .power: return "5"
        case .sixth: return "6"
        case .minorSixth: return "m6"
        case .seventh: return "7"
        case .majorSeventh: return "maj7"
        case .minorSeventh: return "m7"
        case .diminishedSeventh: return "dim7"
        case .halfDiminished: return "ø7"
        case .ninth: return "9"
        case .majorNinth: return "maj9"
        case .minorNinth: return "m9"
        case .eleventh: return "11"
        case .sevenSus4: return "7sus4"
        }
    }
}
struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var pitch: Int
    var start: Double
    var duration: Double
    var velocity: Int = 90
}
struct Track: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var notes: [Note] = []
    var volume: Double = 0.8
    var mute = false
    var solo = false
    var instrument = 0
    var pan: Double? = nil
}
struct ChordClip: Identifiable, Codable, Equatable {
    var id = UUID()
    var root: Int
    var quality: ChordQuality
    var start: Double
    var duration: Double = 4
    var inversion = 0
    var customPitches: [Int]? = nil
    var pitches: [Int] {
        if let customPitches { return customPitches }
        var result = quality.intervals.map { 48 + root + $0 }
        for _ in 0..<min(12, max(0, inversion)) { if let first = result.first { result.removeFirst(); result.append(min(127, first + 12)) } }
        return result
    }
}
struct Song: Codable, Equatable {
    var title = "Untitled sketch"
    var tempo: Double = 120
    var key = 0
    var mode: ScaleMode = .major
    var tracks: [Track] = [Track(name: "Melody"), Track(name: "Bass", instrument: 32)]
    var chords: [ChordClip] = []
    var sections: [SongSection] = []
    var chordSettings: ChannelSettings? = nil
    var loopStart: Double = 0
    var loopEnd: Double = 16
    var chordChannel: ChannelSettings { chordSettings ?? ChannelSettings() }
}
struct ChannelSettings: Codable, Equatable {
    var volume: Double = 0.8
    var mute = false
    var solo = false
    var instrument = 0
    var pan: Double = 0
}
struct SongSection: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var start: Double
    var duration: Double
}
