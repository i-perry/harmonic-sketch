import Foundation

enum ProjectPersistence {
    static let fileExtension = "hsketch"
    static let maximumTracks = 14
    static let maximumBeat = 16_384.0

    private struct ProjectFile: Codable {
        let format: String
        let version: Int
        let song: Song
    }

    private struct ProjectHeader: Decodable {
        let format: String
        let version: Int
    }

    enum PersistenceError: Error, Equatable {
        case unsupportedFormat
        case unsupportedVersion(Int)
        case invalidSong(String)
    }

    static func save(_ song: Song, to url: URL) throws {
        try validate(song)
        let file = ProjectFile(format: "HarmonicSketch", version: 1, song: song)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> Song {
        let data = try Data(contentsOf: url)
        let header = try JSONDecoder().decode(ProjectHeader.self, from: data)
        guard header.format == "HarmonicSketch" else { throw PersistenceError.unsupportedFormat }
        guard header.version == 1 else { throw PersistenceError.unsupportedVersion(header.version) }
        let file = try JSONDecoder().decode(ProjectFile.self, from: data)
        try validate(file.song)
        return file.song
    }

    static func validate(_ song: Song) throws {
        guard song.tracks.count <= maximumTracks, song.chords.count <= 100_000, song.sections.count <= 10_000 else {
            throw PersistenceError.invalidSong("Project exceeds supported collection sizes.")
        }
        if let nativeSections = song.nativeSections {
            var sectionCount = 0
            try validateNativeSections(nativeSections, depth: 0, count: &sectionCount)
        }
        guard !song.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersistenceError.invalidSong("Title cannot be empty.")
        }
        guard song.tempo.isFinite, (20...400).contains(song.tempo) else {
            throw PersistenceError.invalidSong("Tempo must be between 20 and 400 BPM.")
        }
        guard (0...11).contains(song.key) else {
            throw PersistenceError.invalidSong("Key must be a pitch class from 0 through 11.")
        }
        let chordChannel = song.chordChannel
        guard chordChannel.volume.isFinite, (0...1).contains(chordChannel.volume),
              (0...127).contains(chordChannel.instrument), chordChannel.pan.isFinite,
              (-1...1).contains(chordChannel.pan) else {
            throw PersistenceError.invalidSong("Chord channel volume, instrument, or pan is outside its valid range.")
        }
        guard song.loopStart.isFinite, song.loopEnd.isFinite, song.loopStart >= 0,
              song.loopEnd > song.loopStart, song.loopEnd <= maximumBeat else {
            throw PersistenceError.invalidSong("Loop bounds must be finite, nonnegative beats with end after start.")
        }
        guard Set(song.tracks.map(\.id)).count == song.tracks.count,
              Set(song.chords.map(\.id)).count == song.chords.count,
              Set(song.sections.map(\.id)).count == song.sections.count else {
            throw PersistenceError.invalidSong("Project item identifiers must be unique within each collection.")
        }
        var noteCount = 0
        for track in song.tracks {
            let pan = track.pan ?? 0
            guard track.volume.isFinite, (0...1).contains(track.volume), (0...127).contains(track.instrument),
                  pan.isFinite, (-1...1).contains(pan) else {
                throw PersistenceError.invalidSong("Track volume, instrument, or pan is outside its valid range.")
            }
            guard Set(track.notes.map(\.id)).count == track.notes.count else {
                throw PersistenceError.invalidSong("Note identifiers must be unique within each track.")
            }
            noteCount += track.notes.count
            guard noteCount <= 100_000 else { throw PersistenceError.invalidSong("Project contains too many notes.") }
            for note in track.notes {
                guard (0...127).contains(note.pitch), (1...127).contains(note.velocity), note.start.isFinite,
                      note.duration.isFinite, note.start >= 0, note.duration > 0,
                      (note.start + note.duration).isFinite, note.start + note.duration <= maximumBeat else {
                    throw PersistenceError.invalidSong("Notes require MIDI pitch/velocity values and finite, nonnegative timing with positive duration.")
                }
            }
        }
        for chord in song.chords {
            guard chord.start.isFinite, chord.duration.isFinite, chord.start >= 0, chord.duration > 0,
                  (chord.start + chord.duration).isFinite,
                  chord.start + chord.duration <= maximumBeat,
                  (0...11).contains(chord.root), (0...chord.quality.intervals.count).contains(chord.inversion),
                  chord.customPitches?.isEmpty != true,
                  chord.pitches.allSatisfy({ (0...127).contains($0) }) else {
                throw PersistenceError.invalidSong("Chords require valid pitches and finite, nonnegative timing with positive duration.")
            }
        }
        for section in song.sections {
            guard section.start.isFinite, section.duration.isFinite, section.start >= 0, section.duration > 0,
                  (section.start + section.duration).isFinite, section.start + section.duration <= maximumBeat else {
                throw PersistenceError.invalidSong("Sections require finite, nonnegative timing with positive duration.")
            }
        }
    }

    private static func validateNativeSections(_ sections: [KlimperSection], depth: Int,
                                               count: inout Int) throws {
        guard depth < 64 else {
            throw PersistenceError.invalidSong("Native section nesting exceeds the supported depth of 64.")
        }
        count += sections.count
        guard count <= 10_000 else {
            throw PersistenceError.invalidSong("Project exceeds the supported count of 10,000 native sections.")
        }
        for section in sections {
            if case let .sections(children, _) = section.children, !children.isEmpty {
                try validateNativeSections(children, depth: depth + 1, count: &count)
            }
        }
    }
}
