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
    /// Preserved Klimper section hierarchy. `sections` remains the legacy, flat timeline projection.
    var nativeSections: [KlimperSection]? = nil
    /// Whether edits to the flat projection have been synchronized with the retained native tree.
    /// Nil means unknown fidelity for older `.hsketch` files that predate tracking.
    var nativeSectionFidelity: NativeSectionFidelity? = nil
    var sections: [SongSection] = []
    var chordSettings: ChannelSettings? = nil
    var loopStart: Double = 0
    var loopEnd: Double = 16
    var chordChannel: ChannelSettings { chordSettings ?? ChannelSettings() }

    mutating func recordSectionProjectionEdit(comparedTo previous: Song, nativeFieldsSynchronized: Bool) {
        guard nativeSections != nil else { return }
        if nativeFieldsSynchronized {
            if previous.nativeSectionFidelity == .preserved {
                nativeSectionFidelity = .preserved
            }
        } else if previous.nativeSections == nativeSections,
                  previous.sections != sections || previous.chords != chords || previous.sectionTrackNotes != sectionTrackNotes {
            nativeSectionFidelity = .projectionOutOfSync
        }
    }

    private var sectionTrackNotes: [UUID: [Note]] {
        Dictionary(uniqueKeysWithValues: tracks.filter { !$0.notes.isEmpty }.map { ($0.id, $0.notes) })
    }
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
    /// Stable source identity for imported sections; new/legacy rows have no native path.
    var nativePath: KlimperSectionPath? = nil
}

enum NativeSectionFidelity: String, Codable {
    case preserved
    case projectionOutOfSync
}

/// JSON value retained from a Klimper section or clip payload, including fields this app does not edit.
enum NativeJSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Decimal)
    case string(String)
    case array([NativeJSONValue])
    case object([String: NativeJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Decimal.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([NativeJSONValue].self) { self = .array(value); return }
        self = .object(try container.decode([String: NativeJSONValue].self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    var objectValue: [String: NativeJSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

enum KlimperSectionChildren: Codable, Equatable {
    /// Ordered section children. Extra keys on the `children` object are preserved alongside them.
    case sections([KlimperSection], metadata: [String: NativeJSONValue])
    /// Complete `children` object for a clip payload; clip timing remains in native coordinates.
    case clips(NativeJSONValue)
    /// Complete unrecognized `children` value, retained without interpretation.
    case opaque(NativeJSONValue)
    /// The source section omitted its `children` key.
    case absent
}

struct KlimperSection: Codable, Equatable {
    /// Section fields other than `children`, preserved without interpreting unknown keys.
    var fields: [String: NativeJSONValue]
    var children: KlimperSectionChildren

    var name: String? { fields["name"]?.stringValue }
    var rawLength: NativeJSONValue? { fields["length"] }
}

struct KlimperSectionPath: Codable, Equatable, Hashable {
    /// Sibling-list indexes at each nesting level, matching native path semantics.
    var indices: [Int]

    func resolve(in roots: [KlimperSection]) throws -> KlimperSection {
        guard !indices.isEmpty else { throw SectionPathError.empty }
        var siblings = roots
        var selected: KlimperSection?
        for (depth, index) in indices.enumerated() {
            guard siblings.indices.contains(index) else {
                throw SectionPathError.indexOutOfBounds(depth: depth, index: index)
            }
            let section = siblings[index]
            selected = section
            if depth < indices.count - 1 {
                guard case let .sections(nested, _) = section.children else {
                    throw SectionPathError.notASection(depth: depth, index: index)
                }
                siblings = nested
            }
        }
        guard let selected else { throw SectionPathError.empty }
        return selected
    }

    /// Updates only the section's display name, preserving all native timing and child data.
    @discardableResult
    func setName(_ name: String, in roots: inout [KlimperSection]) -> Bool {
        guard !indices.isEmpty else { return false }
        return Self.setName(name, indices: ArraySlice(indices), in: &roots)
    }

    private static func setName(_ name: String, indices: ArraySlice<Int>, in siblings: inout [KlimperSection]) -> Bool {
        guard let index = indices.first, siblings.indices.contains(index) else { return false }
        guard indices.count > 1 else {
            siblings[index].fields["name"] = .string(name)
            return true
        }
        guard case let .sections(existingChildren, metadata) = siblings[index].children else { return false }
        var children = existingChildren
        guard setName(name, indices: indices.dropFirst(), in: &children) else { return false }
        siblings[index].children = .sections(children, metadata: metadata)
        return true
    }

    enum SectionPathError: Error, Equatable {
        case empty
        case indexOutOfBounds(depth: Int, index: Int)
        case notASection(depth: Int, index: Int)
    }
}
