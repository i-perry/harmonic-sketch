import Foundation
import XCTest
@testable import HarmonicSketch

final class KlimperImporterTests: XCTestCase {
    func testImportsBeatTimingsNotesVoicingAndNestedSections() throws {
        let json: [String: Any] = [
            "name": "Fixture", "scale": ["root": 2, "name": "minor", "steps": [0, 2, 3, 5, 7, 8, 10]],
            "bpm": 96, "_start": 0, "_end": 12, "looping": true,
            "tracks": [["id": "t1", "name": "Lead", "volume": 0.7, "pan": 0.25,
                         "mute": false, "solo": false, "instrument": "Piano"]],
            "chord_track": ["volume": 1.0, "pan": 0.0, "mute": false, "solo": false, "instrument": "Chord"],
            "sections": [
                ["id": "s1", "name": "Verse", "color": ["r": 1, "g": 0, "b": 0, "a": 1],
                 "length": 4, "children": ["clips": [
                     "chords": [["chord": ["root": 2, "intervals": [0, 3, 7]], "length": 4, "voicing": [50, 53, 57]]],
                     "clipByTrack": [["t1", [["position": 1.5, "length": 0.5, "pitch": 72, "velocity": 0.8]]]]
                 ]]],
                ["id": "s2", "name": "Chorus", "color": ["r": 1, "g": 1, "b": 1, "a": 1],
                 "length": 4, "children": ["clips": ["chords": [], "clipByTrack": []]]]
            ]
        ]
        let result = try importFixture(json)
        XCTAssertEqual(result.song.title, "Fixture")
        XCTAssertEqual(result.song.mode, .minor)
        XCTAssertEqual(result.song.sections.map(\.start), [0, 4])
        XCTAssertEqual(result.song.chords.first?.start, 0)
        XCTAssertEqual(result.song.chords.first?.pitches, [50, 53, 57])
        XCTAssertEqual(result.song.tracks.first?.notes.first?.start, 1.5)
        XCTAssertEqual(result.song.tracks.first?.notes.first?.velocity, 102)
        XCTAssertTrue(result.warnings.contains { $0.contains("pan") })
    }

    func testRejectsUnknownChildrenShapeInsteadOfDroppingContent() throws {
        var fixture = baseFixture()
        fixture["sections"] = [["name": "Broken", "length": 4, "color": [:], "children": ["opaque": []]]]
        let url = try writeFixture(fixture)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try KlimperImporter.load(from: url))
    }

    private func importFixture(_ json: [String: Any]) throws -> KlimperImportResult {
        let url = try writeFixture(json)
        defer { try? FileManager.default.removeItem(at: url) }
        return try KlimperImporter.loadWithWarnings(from: url)
    }

    private func writeFixture(_ json: [String: Any]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".klp")
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return url
    }

    private func baseFixture() -> [String: Any] {
        ["name": "Fixture", "scale": ["root": 0, "name": "major", "steps": [0, 2, 4, 5, 7, 9, 11]],
         "bpm": 120, "tracks": [], "sections": [], "chord_track": [:], "_start": 0, "_end": 4, "looping": true]
    }
}
