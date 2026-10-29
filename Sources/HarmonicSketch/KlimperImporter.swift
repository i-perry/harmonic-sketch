import Foundation
import CoreFoundation

struct KlimperImportResult {
    let song: Song
    let warnings: [String]
}

enum KlimperImporter {
    /// The player converts one whole-note unit (10368 ticks) to four quarter-note beats.
    private static let beatsPerSerializedTimeUnit = 4.0

    enum ImportError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            if case let .invalid(message) = self { return "Cannot import Klimper project: \(message)" }
            return nil
        }
    }

    /// Imports the JSON project data stored in a Klimper `.klp` file.
    static func load(from url: URL) throws -> Song {
        try loadWithWarnings(from: url).song
    }

    /// Imports supported musical content and reports fields that this model cannot retain.
    static func loadWithWarnings(from url: URL) throws -> KlimperImportResult {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? NSNumber, fileSize.intValue > 50_000_000 {
            throw ImportError.invalid("file exceeds the 50 MB safety limit")
        }
        let data = try Data(contentsOf: url)
        let raw: Any
        do { raw = try JSONSerialization.jsonObject(with: data) }
        catch { throw ImportError.invalid("file is not valid JSON (\(error.localizedDescription))") }
        guard let root = raw as? [String: Any] else { throw ImportError.invalid("root must be an object") }
        for key in ["name", "scale", "bpm", "tracks", "sections", "chord_track", "_start", "_end", "looping"] {
            guard root[key] != nil else { throw ImportError.invalid("missing required root field `\(key)`") }
        }

        var warnings: [String] = []
        let title = try string(root["name"], at: "name")
        let bpm = try number(root["bpm"], at: "bpm")
        guard (20...400).contains(bpm) else { throw ImportError.invalid("bpm is outside supported 20...400 range") }
        let scale = try object(root["scale"], at: "scale")
        let key = try integer(scale["root"], at: "scale.root")
        guard (0...11).contains(key) else { throw ImportError.invalid("scale.root must be a pitch class from 0 through 11") }
        let scaleName = try string(scale["name"], at: "scale.name").lowercased()
        let mode = modeFor(scaleName)
        if mode == nil { warnings.append("Scale `\(scaleName)` is not represented by the app's scale modes; imported as Major.") }
        if let stepsValue = scale["steps"] {
            let steps = try integerArray(stepsValue, at: "scale.steps")
            if let mode, steps != mode.intervals { warnings.append("Scale steps differ from the named built-in mode; the app keeps the name's mode only.") }
        }

        let chordTrack = try object(root["chord_track"], at: "chord_track")
        let chordSettings = try channelSettings(chordTrack, at: "chord_track", warnings: &warnings)
        let trackObjects = try array(root["tracks"], at: "tracks")
        guard trackObjects.count <= 256 else { throw ImportError.invalid("tracks exceeds the supported count of 256") }
        var tracks: [Track] = []
        var trackIndices: [String: Int] = [:]
        for (index, item) in trackObjects.enumerated() {
            let path = "tracks[\(index)]"
            let value = try object(item, at: path)
            let id = try string(value["id"], at: "\(path).id")
            guard trackIndices[id] == nil else { throw ImportError.invalid("duplicate track id `\(id)`") }
            let name = try string(value["name"], at: "\(path).name")
            let volume = try number(value["volume"], at: "\(path).volume")
            guard (0...1).contains(volume) else { throw ImportError.invalid("\(path).volume must be between 0 and 1") }
            let pan = try number(value["pan"], at: "\(path).pan")
            guard (-1...1).contains(pan) else { throw ImportError.invalid("\(path).pan must be between -1 and 1") }
            let mute = try bool(value["mute"], at: "\(path).mute")
            let solo = try bool(value["solo"], at: "\(path).solo")
            guard let instrument = value["instrument"] as? String else {
                throw ImportError.invalid("\(path).instrument must be a string descriptor")
            }
            tracks.append(Track(name: name, volume: volume, mute: mute, solo: solo, instrument: 0, pan: pan))
            if !instrument.isEmpty { warnings.append("Track `\(name)` instrument descriptor `\(instrument)` is not represented and was reset to the default sound.") }
            trackIndices[id] = tracks.count - 1
        }

        let sectionsJSON = try array(root["sections"], at: "sections")
        var sections: [SongSection] = []
        var chords: [ChordClip] = []
        guard sectionsJSON.count <= 10_000 else { throw ImportError.invalid("sections exceeds the supported count of 10,000") }
        var nativeSectionCount = 0
        let nativeSections = try sectionsJSON.enumerated().map { index, section in
            try nativeSection(section, path: "sections[\(index)]", depth: 0, count: &nativeSectionCount)
        }
        var rootCursor = 0.0
        var rootPlacementKnown = true
        for (index, section) in sectionsJSON.enumerated() {
            guard rootPlacementKnown else {
                warnings.append("sections[\(index)] is preserved in the native tree but omitted from the flat projection because an earlier sibling has no usable length for sequential placement.")
                continue
            }
            guard let sectionObject = section as? [String: Any],
                  let sectionLength = try? number(sectionObject["length"], at: "sections[\(index)].length"),
                  sectionLength >= 0 else {
                warnings.append("sections[\(index)] has no usable length; it and later siblings are preserved but omitted from the flat projection because their sequential positions cannot be derived.")
                rootPlacementKnown = false
                continue
            }
            guard sectionLength > 0 else {
                warnings.append("sections[\(index)] has a nonpositive length; its raw section tree is preserved, but it is omitted from the flat timeline projection.")
                continue
            }
            try flatten(section, path: "sections[\(index)]", nativePath: KlimperSectionPath(indices: [index]),
                        start: rootCursor, into: &sections,
                        chords: &chords, tracks: &tracks, trackIndices: trackIndices, warnings: &warnings, depth: 0)
            rootCursor += beats(fromSerializedTime: sectionLength)
        }

        let start = try number(root["_start"], at: "_start")
        let end = try number(root["_end"], at: "_end")
        guard start >= 0, end > start else { throw ImportError.invalid("loop bounds must be nonnegative beats with end after start") }
        _ = try bool(root["looping"], at: "looping") // Saved playback toggle has no persistent Song field.
        warnings.append("The saved playback looping toggle is not represented by Song.")
        warnings.append("Section colors and saved UI state are not represented.")
        let song = Song(title: title, tempo: bpm, key: key, mode: mode ?? .major,
                        tracks: tracks, chords: chords, nativeSections: nativeSections,
                        nativeSectionFidelity: .preserved, sections: sections,
                        chordSettings: chordSettings,
                        loopStart: beats(fromSerializedTime: start), loopEnd: beats(fromSerializedTime: end))
        try ProjectPersistence.validate(song)
        return KlimperImportResult(song: song, warnings: Array(Set(warnings)).sorted())
    }

    private static func flatten(_ raw: Any, path: String, nativePath: KlimperSectionPath, start: Double,
                                into sections: inout [SongSection],
                                chords: inout [ChordClip], tracks: inout [Track], trackIndices: [String: Int],
                                warnings: inout [String], depth: Int) throws {
        guard depth < 64 else { throw ImportError.invalid("section nesting exceeds the supported depth of 64") }
        let item = try object(raw, at: path)
        guard let nameValue = item["name"], let name = try? string(nameValue, at: "\(path).name"),
              let lengthValue = item["length"], let length = try? number(lengthValue, at: "\(path).length"),
              length > 0 else {
            warnings.append("\(path) has a missing, invalid, or nonpositive name/length; it is preserved in the native section tree but omitted from the flat timeline projection.")
            return
        }
        guard let color = item["color"], (try? object(color, at: "\(path).color")) != nil else {
            warnings.append("\(path) has no supported color object; it is preserved in the native section tree but omitted from the flat timeline projection.")
            return
        }
        if item["scale"] != nil { warnings.append("Section-level scale overrides are not represented.") }
        guard let children = item["children"], let childObject = try? object(children, at: "\(path).children") else {
            warnings.append("\(path) has an unsupported children value; it is preserved in the native section tree but omitted from the flat timeline projection.")
            return
        }
        if let nested = childObject["sections"] {
            guard let nestedSections = try? array(nested, at: "\(path).children.sections") else {
                warnings.append("\(path).children.sections has an unsupported value; it is preserved in the native section tree but omitted from the flat timeline projection.")
                return
            }
            guard nestedSections.allSatisfy({ $0 is [String: Any] }) else {
                warnings.append("\(path).children.sections contains a non-object item; the entire nested branch is preserved opaquely and omitted from the flat timeline projection.")
                return
            }
            var cursor = start
            var siblingPlacementKnown = true
            for (index, child) in nestedSections.enumerated() {
                let childPath = "\(path).children.sections[\(index)]"
                guard siblingPlacementKnown else {
                    warnings.append("\(childPath) is preserved in the native tree but omitted from the flat projection because an earlier sibling has no usable length for sequential placement.")
                    continue
                }
                guard let childObject = child as? [String: Any],
                      let childLength = try? number(childObject["length"], at: "\(childPath).length"),
                      childLength >= 0 else {
                    warnings.append("\(childPath) has no usable length; it and later siblings are preserved but omitted from the flat projection because their sequential positions cannot be derived.")
                    siblingPlacementKnown = false
                    continue
                }
                var childNativePath = nativePath
                childNativePath.indices.append(index)
                try flatten(child, path: childPath, nativePath: childNativePath,
                            start: cursor,
                            into: &sections, chords: &chords, tracks: &tracks,
                            trackIndices: trackIndices, warnings: &warnings, depth: depth + 1)
                cursor += beats(fromSerializedTime: childLength)
            }
        } else if let clipContainer = childObject["clips"] {
            guard let clips = try? object(clipContainer, at: "\(path).children.clips") else {
                warnings.append("\(path).children.clips has an unsupported value; it is preserved in the native section tree but omitted from the flat timeline projection.")
                return
            }
            guard let chordList = try? array(clips["chords"], at: "\(path).children.clips.chords"),
                  let trackClipEntries = try? array(clips["clipByTrack"], at: "\(path).children.clips.clipByTrack"),
                  chordList.count <= 100_000, trackClipEntries.count <= 256 else {
                warnings.append("\(path).children.clips is missing or has malformed chord/track arrays; it is preserved in the native tree but omitted from the flat timeline projection.")
                return
            }
            sections.append(SongSection(name: name, start: start,
                                        duration: beats(fromSerializedTime: length), nativePath: nativePath))
            var chordCursor = start
            var chordPlacementKnown = true
            for (index, rawChord) in chordList.enumerated() {
                let chordPath = "\(path).children.clips.chords[\(index)]"
                guard chordPlacementKnown else {
                    warnings.append("\(chordPath) and later chords are preserved but omitted because a preceding chord has no usable length for sequential placement.")
                    continue
                }
                guard let chordValue = try? object(rawChord, at: chordPath),
                      let serializedDuration = try? number(chordValue["length"], at: "\(chordPath).length"),
                      serializedDuration >= 0 else {
                    warnings.append("\(chordPath) has no usable length; it and later chords are preserved but omitted because their sequential positions cannot be derived.")
                    chordPlacementKnown = false
                    continue
                }
                guard serializedDuration > 0 else {
                    warnings.append("\(chordPath) has nonpositive length and is omitted from the flat timeline projection.")
                    continue
                }
                let duration = beats(fromSerializedTime: serializedDuration)
                guard let descriptor = try? object(chordValue["chord"], at: "\(chordPath).chord"),
                      let root = try? integer(descriptor["root"], at: "\(chordPath).chord.root"),
                      (0...11).contains(root),
                      let intervals = try? integerArray(descriptor["intervals"], at: "\(chordPath).chord.intervals"),
                      let voicing = try? voicingPitches(chordValue["voicing"], at: "\(chordPath).voicing"),
                      !voicing.isEmpty, voicing.allSatisfy({ (0...127).contains($0) }) else {
                    warnings.append("\(chordPath) has unsupported chord or voicing data; it is preserved natively and omitted from the flat timeline projection.")
                    chordCursor += duration
                    continue
                }
                let quality = ChordQuality.allCases.first { $0.intervals == intervals } ?? .major
                if quality.intervals != intervals { warnings.append("Chord intervals \(intervals) are retained as custom pitches; displayed quality defaults to Major.") }
                chords.append(ChordClip(root: root, quality: quality, start: chordCursor,
                                        duration: duration, customPitches: voicing))
                chordCursor += duration
            }
            for (entryIndex, rawEntry) in trackClipEntries.enumerated() {
                guard let tuple = try? array(rawEntry, at: "\(path).children.clips.clipByTrack[\(entryIndex)]"),
                      tuple.count == 2,
                      let trackId = try? string(tuple[0], at: "clipByTrack track id"),
                      let noteEntries = try? array(tuple[1], at: "clipByTrack notes") else {
                    warnings.append("clipByTrack[\(entryIndex)] is malformed; it is preserved in the native tree but omitted from the flat projection.")
                    continue
                }
                guard let trackIndex = trackIndices[trackId] else {
                    warnings.append("Notes for unknown track id `\(trackId)` were skipped.")
                    continue
                }
                guard tracks[trackIndex].notes.count + noteEntries.count <= 100_000 else {
                    throw ImportError.invalid("note count exceeds 100,000")
                }
                for (noteIndex, rawNote) in noteEntries.enumerated() {
                    let notePath = "clipByTrack[\(entryIndex)].notes[\(noteIndex)]"
                    guard let note = try? object(rawNote, at: notePath),
                          let serializedPosition = try? number(note["position"], at: "\(notePath).position"),
                          let serializedLength = try? number(note["length"], at: "\(notePath).length"),
                          let pitch = try? integer(note["pitch"], at: "\(notePath).pitch"),
                          let velocity = try? number(note["velocity"], at: "\(notePath).velocity"),
                          (0...127).contains(pitch), serializedLength > 0, serializedPosition >= 0,
                          (0...1).contains(velocity) else {
                        warnings.append("\(notePath) is malformed; it is preserved in the native tree but omitted from the flat projection.")
                        continue
                    }
                    tracks[trackIndex].notes.append(Note(pitch: pitch,
                                                         start: start + beats(fromSerializedTime: serializedPosition),
                                                         duration: beats(fromSerializedTime: serializedLength),
                                                         velocity: min(127, max(1, Int((velocity * 127).rounded())))))
                }
            }
        } else {
            warnings.append("\(path).children has an unsupported shape; it is preserved as opaque native section data and omitted from the flat timeline projection.")
        }
    }

    private static func beats(fromSerializedTime value: Double) -> Double {
        value * beatsPerSerializedTimeUnit
    }

    private static func nativeSection(_ raw: Any, path: String, depth: Int,
                                      count: inout Int) throws -> KlimperSection {
        guard depth < 64 else { throw ImportError.invalid("section nesting exceeds the supported depth of 64") }
        count += 1
        guard count <= 10_000 else { throw ImportError.invalid("sections exceeds the supported count of 10,000") }
        let item = try object(raw, at: path)
        var fields: [String: NativeJSONValue] = [:]
        for (key, value) in item where key != "children" {
            fields[key] = try nativeJSONValue(value, at: "\(path).\(key)")
        }
        guard let childValue = item["children"] else {
            return KlimperSection(fields: fields, children: .absent)
        }

        if let childObject = childValue as? [String: Any],
           let nestedValue = childObject["sections"],
           let nested = nestedValue as? [Any],
           nested.allSatisfy({ $0 is [String: Any] }) {
            var children: [KlimperSection] = []
            children.reserveCapacity(nested.count)
            for (index, child) in nested.enumerated() {
                children.append(try nativeSection(child, path: "\(path).children.sections[\(index)]",
                                                  depth: depth + 1, count: &count))
            }
            var metadata: [String: NativeJSONValue] = [:]
            for (key, value) in childObject where key != "sections" {
                metadata[key] = try nativeJSONValue(value, at: "\(path).children.\(key)")
            }
            return KlimperSection(fields: fields, children: .sections(children, metadata: metadata))
        }

        let preservedChildren = try nativeJSONValue(childValue, at: "\(path).children")
        if let childObject = childValue as? [String: Any], childObject["clips"] != nil {
            return KlimperSection(fields: fields, children: .clips(preservedChildren))
        }
        return KlimperSection(fields: fields, children: .opaque(preservedChildren))
    }

    private static func nativeJSONValue(_ raw: Any, at path: String) throws -> NativeJSONValue {
        if raw is NSNull { return .null }
        if let value = raw as? String { return .string(value) }
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            guard let decimal = Decimal(string: number.stringValue, locale: Locale(identifier: "en_US_POSIX")) else {
                throw ImportError.invalid("\(path) contains an unsupported JSON number")
            }
            return .number(decimal)
        }
        if let values = raw as? [Any] {
            return .array(try values.enumerated().map { index, value in
                try nativeJSONValue(value, at: "\(path)[\(index)]")
            })
        }
        if let object = raw as? [String: Any] {
            var values: [String: NativeJSONValue] = [:]
            for (key, value) in object {
                values[key] = try nativeJSONValue(value, at: "\(path).\(key)")
            }
            return .object(values)
        }
        throw ImportError.invalid("\(path) contains a value that is not representable as JSON")
    }

    private static func modeFor(_ name: String) -> ScaleMode? {
        switch name.replacingOccurrences(of: " ", with: "") {
        case "major", "ionian": return .major
        case "dorian": return .dorian
        case "phrygian": return .phrygian
        case "lydian": return .lydian
        case "mixolydian": return .mixolydian
        case "minor", "aeolian", "naturalminor": return .minor
        case "locrian": return .locrian
        case "harmonicminor": return .harmonicMinor
        default: return nil
        }
    }

    private static func channelSettings(_ value: [String: Any], at path: String,
                                        warnings: inout [String]) throws -> ChannelSettings {
        let volume = try number(value["volume"], at: "\(path).volume")
        let pan = try number(value["pan"], at: "\(path).pan")
        guard (0...1).contains(volume), (-1...1).contains(pan) else {
            throw ImportError.invalid("\(path) volume or pan is outside the supported range")
        }
        let mute = try bool(value["mute"], at: "\(path).mute")
        let solo = try bool(value["solo"], at: "\(path).solo")
        guard let instrument = value["instrument"] as? String else {
            throw ImportError.invalid("\(path).instrument must be a string descriptor")
        }
        if !instrument.isEmpty {
            warnings.append("Chord-track instrument descriptor `\(instrument)` is not represented and uses the default sound.")
        }
        return ChannelSettings(volume: volume, mute: mute, solo: solo, instrument: 0, pan: pan)
    }

    private static func object(_ value: Any?, at path: String) throws -> [String: Any] {
        guard let value, let object = value as? [String: Any] else { throw ImportError.invalid("\(path) must be an object") }
        return object
    }
    private static func array(_ value: Any?, at path: String) throws -> [Any] {
        guard let value, let array = value as? [Any] else { throw ImportError.invalid("\(path) must be an array") }
        return array
    }
    private static func string(_ value: Any?, at path: String) throws -> String {
        guard let value = value as? String else { throw ImportError.invalid("\(path) must be a string") }
        return value
    }
    private static func number(_ value: Any?, at path: String) throws -> Double {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw ImportError.invalid("\(path) must be a number")
        }
        let result = number.doubleValue
        guard result.isFinite else { throw ImportError.invalid("\(path) must be finite") }
        return result
    }
    private static func integer(_ value: Any?, at path: String) throws -> Int {
        let result = try number(value, at: path)
        guard result.rounded() == result, let exact = Int(exactly: result) else {
            throw ImportError.invalid("\(path) must be an integer")
        }
        return exact
    }
    private static func integerArray(_ value: Any?, at path: String) throws -> [Int] {
        try array(value, at: path).enumerated().map { try integer($0.element, at: "\(path)[\($0.offset)]") }
    }
    private static func voicingPitches(_ value: Any?, at path: String) throws -> [Int] {
        let entries = try array(value, at: path)
        guard let first = entries.first else { return [] }
        if first is NSNumber {
            return try integerArray(entries, at: path)
        }
        return try entries.enumerated().map { index, entry in
            let record = try object(entry, at: "\(path)[\(index)]")
            return try integer(record["pitch"], at: "\(path)[\(index)].pitch")
        }
    }
    private static func bool(_ value: Any?, at path: String) throws -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw ImportError.invalid("\(path) must be a boolean")
        }
        return number.boolValue
    }
}
