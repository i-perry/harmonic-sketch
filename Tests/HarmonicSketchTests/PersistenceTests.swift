import Foundation
import XCTest
@testable import HarmonicSketch

final class PersistenceTests: XCTestCase {
    func testProjectRoundTripsAllSongData() throws {
        let song = Song(title: "Evening", tempo: 98.5, key: 9, mode: .dorian,
                        tracks: [Track(name: "Lead", notes: [Note(pitch: 67, start: 1.25, duration: 0.75, velocity: 103)], volume: 0.62, mute: false, solo: true, instrument: 81)],
                        chords: [ChordClip(root: 9, quality: .minorSeventh, start: 4, duration: 2, inversion: 1)],
                        sections: [SongSection(name: "Verse", start: 0, duration: 8)],
                        chordSettings: ChannelSettings(volume: 0.55, solo: true, instrument: 6, pan: -0.25),
                        loopStart: 2, loopEnd: 10)
        var songWithPan = song
        songWithPan.tracks[0].pan = 0.4
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ProjectPersistence.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        try ProjectPersistence.save(songWithPan, to: url)
        XCTAssertEqual(try ProjectPersistence.load(from: url), songWithPan)
    }

    func testLoadRejectsInvalidMusicalRanges() throws {
        var song = Song()
        song.tracks[0].notes = [Note(pitch: 128, start: 0, duration: 1)]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(Envelope(format: "HarmonicSketch", version: 1, song: song)).write(to: url)

        XCTAssertThrowsError(try ProjectPersistence.load(from: url))
    }

    func testLoadRejectsUnknownFileVersion() throws {
        let data = Data(#"{"format":"HarmonicSketch","version":99,"song":{}}"#.utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)

        XCTAssertThrowsError(try ProjectPersistence.load(from: url)) { error in
            XCTAssertEqual(error as? ProjectPersistence.PersistenceError, .unsupportedVersion(99))
        }
    }

    func testValidationRejectsOverflowingSectionEndAndUnsafeChordInversion() {
        var song = Song()
        song.sections = [SongSection(name: "Overflow", start: Double.greatestFiniteMagnitude, duration: Double.greatestFiniteMagnitude)]
        XCTAssertThrowsError(try ProjectPersistence.validate(song))

        song.sections = []
        song.chords = [ChordClip(root: 0, quality: .major, start: 0, inversion: Int.max)]
        XCTAssertThrowsError(try ProjectPersistence.validate(song))
    }

    func testValidationRejectsUnsupportedTrackCountAndRunawayTimeline() {
        var song = Song()
        song.tracks = (0...ProjectPersistence.maximumTracks).map { Track(name: "Track \($0)") }
        XCTAssertThrowsError(try ProjectPersistence.validate(song))

        song.tracks = [Track(name: "Lead", notes: [Note(pitch: 60, start: ProjectPersistence.maximumBeat, duration: 1)])]
        XCTAssertThrowsError(try ProjectPersistence.validate(song))
    }

    func testVersionOneProjectsWithoutNewMixFieldsStillLoad() throws {
        var song = Song()
        song.tracks[0].pan = -0.6
        song.chordSettings = ChannelSettings(volume: 0.4, mute: true, solo: true, instrument: 11, pan: 0.7)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try ProjectPersistence.save(song, to: url)

        var project = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var storedSong = try XCTUnwrap(project["song"] as? [String: Any])
        storedSong.removeValue(forKey: "chordSettings")
        storedSong.removeValue(forKey: "nativeSections")
        let storedTracks = try XCTUnwrap(storedSong["tracks"] as? [[String: Any]])
        storedSong["tracks"] = storedTracks.map { track -> [String: Any] in
            var oldTrack = track
            oldTrack.removeValue(forKey: "pan")
            return oldTrack
        }
        project["song"] = storedSong
        try JSONSerialization.data(withJSONObject: project).write(to: url)

        let loaded = try ProjectPersistence.load(from: url)
        XCTAssertNil(loaded.chordSettings)
        XCTAssertNil(loaded.nativeSections)
        XCTAssertEqual(loaded.chordChannel, ChannelSettings())
        XCTAssertNil(loaded.tracks[0].pan)
    }

    func testValidationRejectsOutOfRangeMixControls() {
        var song = Song()
        song.tracks[0].pan = 1.1
        XCTAssertThrowsError(try ProjectPersistence.validate(song))

        song.tracks[0].pan = 0
        song.chordSettings = ChannelSettings(volume: .infinity)
        XCTAssertThrowsError(try ProjectPersistence.validate(song))
    }

    private struct Envelope: Encodable {
        let format: String
        let version: Int
        let song: Song
    }
}
