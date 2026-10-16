import Foundation
import XCTest
@testable import HarmonicSketch

final class PersistenceTests: XCTestCase {
    func testProjectRoundTripsAllSongData() throws {
        let song = Song(title: "Evening", tempo: 98.5, key: 9, mode: .dorian,
                        tracks: [Track(name: "Lead", notes: [Note(pitch: 67, start: 1.25, duration: 0.75, velocity: 103)], volume: 0.62, mute: false, solo: true, instrument: 81)],
                        chords: [ChordClip(root: 9, quality: .minorSeventh, start: 4, duration: 2, inversion: 1)],
                        sections: [SongSection(name: "Verse", start: 0, duration: 8)],
                        loopStart: 2, loopEnd: 10)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ProjectPersistence.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        try ProjectPersistence.save(song, to: url)
        XCTAssertEqual(try ProjectPersistence.load(from: url), song)
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

    private struct Envelope: Encodable {
        let format: String
        let version: Int
        let song: Song
    }
}
