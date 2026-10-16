import Foundation
import CoreFoundation

struct KlimperImportResult {
    let song: Song
    let warnings: [String]
}

enum KlimperImporter {
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

        _ = try object(root["chord_track"], at: "chord_track")
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
            let mute = try bool(value["mute"], at: "\(path).mute")
            let solo = try bool(value["solo"], at: "\(path).solo")
            guard let instrument = value["instrument"] as? String else {
                throw ImportError.invalid("\(path).instrument must be a string descriptor")
            }
            tracks.append(Track(name: name, volume: volume, mute: mute, solo: solo, instrument: 0))
            if !instrument.isEmpty { warnings.append("Track `\(name)` instrument descriptor `\(instrument)` is not represented and was reset to the default sound.") }
            trackIndices[id] = tracks.count - 1
            if let panValue = value["pan"] {
                let pan = try number(panValue, at: "\(path).pan")
                if pan != 0 { warnings.append("Track `\(name)` pan (\(pan)) is not represented and was reset to center.") }
            }
        }

        let sectionsJSON = try array(root["sections"], at: "sections")
        var sections: [SongSection] = []
        var chords: [ChordClip] = []
        guard sectionsJSON.count <= 10_000 else { throw ImportError.invalid("sections exceeds the supported count of 10,000") }
        var rootCursor = 0.0
        for (index, section) in sectionsJSON.enumerated() {
            let sectionLength = try number(try object(section, at: "sections[\(index)]")["length"], at: "sections[\(index)].length")
            try flatten(section, path: "sections[\(index)]", start: rootCursor, into: &sections,
                        chords: &chords, tracks: &tracks, trackIndices: trackIndices, warnings: &warnings, depth: 0)
            rootCursor += sectionLength
        }

        let start = try number(root["_start"], at: "_start")
        let end = try number(root["_end"], at: "_end")
        guard start >= 0, end > start else { throw ImportError.invalid("loop bounds must be nonnegative beats with end after start") }
        _ = try bool(root["looping"], at: "looping") // Saved playback toggle has no persistent Song field.
        warnings.append("Klimper track pan, project chord-track routing, section colors, and saved UI state are not represented.")
        warnings.append("Nested sections are flattened into timeline sections; parent/child grouping is not retained.")
        let song = Song(title: title, tempo: bpm, key: key, mode: mode ?? .major,
                        tracks: tracks, chords: chords, sections: sections, loopStart: start, loopEnd: end)
        try ProjectPersistence.validate(song)
        return KlimperImportResult(song: song, warnings: Array(Set(warnings)).sorted())
    }

    private static func flatten(_ raw: Any, path: String, start: Double, into sections: inout [SongSection],
                                chords: inout [ChordClip], tracks: inout [Track], trackIndices: [String: Int],
                                warnings: inout [String], depth: Int) throws {
        guard depth < 64 else { throw ImportError.invalid("section nesting exceeds the supported depth of 64") }
        let item = try object(raw, at: path)
        let name = try string(item["name"], at: "\(path).name")
        let length = try number(item["length"], at: "\(path).length")
        guard length > 0 else { throw ImportError.invalid("\(path).length must be positive beats") }
        guard let color = item["color"] else { throw ImportError.invalid("missing \(path).color") }
        _ = try object(color, at: "\(path).color")
        if item["scale"] != nil { warnings.append("Section-level scale overrides are not represented.") }
        guard let children = item["children"] else { throw ImportError.invalid("missing \(path).children") }
        let childObject = try object(children, at: "\(path).children")
        if let nested = childObject["sections"] {
            let nestedSections = try array(nested, at: "\(path).children.sections")
            var cursor = start
            for (index, child) in nestedSections.enumerated() {
                let childPath = "\(path).children.sections[\(index)]"
                try flatten(child, path: "\(path).children.sections[\(index)]", start: cursor,
                            into: &sections, chords: &chords, tracks: &tracks,
                            trackIndices: trackIndices, warnings: &warnings, depth: depth + 1)
                let childObject = try object(child, at: childPath)
                cursor += try number(childObject["length"], at: "\(childPath).length")
            }
        } else if let clipContainer = childObject["clips"] {
            let clips = try object(clipContainer, at: "\(path).children.clips")
            sections.append(SongSection(name: name, start: start, duration: length))
            guard let chordValues = clips["chords"], let trackValues = clips["clipByTrack"] else {
                throw ImportError.invalid("\(path).children.clips requires chords and clipByTrack")
            }
            var chordCursor = start
            let chordList = try array(chordValues, at: "\(path).children.clips.chords")
            guard chordList.count <= 100_000 else { throw ImportError.invalid("chord count exceeds 100,000") }
            for (index, rawChord) in chordList.enumerated() {
                let chordPath = "\(path).children.clips.chords[\(index)]"
                let chordValue = try object(rawChord, at: chordPath)
                let descriptor = try object(chordValue["chord"], at: "\(chordPath).chord")
                let root = try integer(descriptor["root"], at: "\(chordPath).chord.root")
                guard (0...11).contains(root) else { throw ImportError.invalid("\(chordPath).chord.root must be pitch class 0...11") }
                let intervals = try integerArray(descriptor["intervals"], at: "\(chordPath).chord.intervals")
                let duration = try number(chordValue["length"], at: "\(chordPath).length")
                guard duration > 0 else { throw ImportError.invalid("\(chordPath).length must be positive beats") }
                let voicing = try integerArray(chordValue["voicing"], at: "\(chordPath).voicing")
                guard !voicing.isEmpty, voicing.allSatisfy({ (0...127).contains($0) }) else {
                    throw ImportError.invalid("\(chordPath).voicing must contain MIDI pitches 0...127")
                }
                let quality = ChordQuality.allCases.first { $0.intervals == intervals } ?? .major
                if quality.intervals != intervals { warnings.append("Chord intervals \(intervals) are retained as custom pitches; displayed quality defaults to Major.") }
                chords.append(ChordClip(root: root, quality: quality, start: chordCursor,
                                        duration: duration, customPitches: voicing))
                chordCursor += duration
            }
            let trackClipEntries = try array(trackValues, at: "\(path).children.clips.clipByTrack")
            guard trackClipEntries.count <= 256 else { throw ImportError.invalid("clipByTrack exceeds 256 entries") }
            for (entryIndex, rawEntry) in trackClipEntries.enumerated() {
                let tuple = try array(rawEntry, at: "\(path).children.clips.clipByTrack[\(entryIndex)]")
                guard tuple.count == 2 else { throw ImportError.invalid("clipByTrack entries must be [trackId, notes] pairs") }
                let trackId = try string(tuple[0], at: "clipByTrack track id")
                guard let trackIndex = trackIndices[trackId] else {
                    warnings.append("Notes for unknown track id `\(trackId)` were skipped.")
                    continue
                }
                let noteEntries = try array(tuple[1], at: "clipByTrack notes")
                guard tracks[trackIndex].notes.count + noteEntries.count <= 100_000 else {
                    throw ImportError.invalid("note count exceeds 100,000")
                }
                for (noteIndex, rawNote) in noteEntries.enumerated() {
                    let notePath = "clipByTrack[\(entryIndex)].notes[\(noteIndex)]"
                    let note = try object(rawNote, at: notePath)
                    let position = try number(note["position"], at: "\(notePath).position")
                    let noteLength = try number(note["length"], at: "\(notePath).length")
                    let pitch = try integer(note["pitch"], at: "\(notePath).pitch")
                    let velocity = try number(note["velocity"], at: "\(notePath).velocity")
                    guard (0...127).contains(pitch), noteLength > 0, position >= 0, velocity.isFinite,
                          (0...1).contains(velocity) else { throw ImportError.invalid("\(notePath) has invalid pitch, timing, or velocity") }
                    tracks[trackIndex].notes.append(Note(pitch: pitch, start: start + position,
                                                         duration: noteLength, velocity: min(127, max(1, Int((velocity * 127).rounded())))))
                }
            }
        } else {
            throw ImportError.invalid("\(path).children must contain `sections` or `clips`")
        }
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
    private static func bool(_ value: Any?, at path: String) throws -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw ImportError.invalid("\(path) must be a boolean")
        }
        return number.boolValue
    }
}
