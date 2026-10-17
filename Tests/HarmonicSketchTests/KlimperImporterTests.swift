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
            "chord_track": ["volume": 0.65, "pan": -0.4, "mute": true, "solo": false, "instrument": "Chord"],
            "sections": [
                ["id": "s1", "name": "Verse", "color": ["r": 1, "g": 0, "b": 0, "a": 1],
                 "length": 4, "children": ["clips": [
                     "chords": [["chord": ["root": 2, "intervals": [0, 3, 7]], "length": 4,
                                 "voicing": [["position": 0, "length": 4, "pitch": 50, "velocity": 0.8],
                                             ["position": 0, "length": 4, "pitch": 53, "velocity": 0.8],
                                             ["position": 0, "length": 4, "pitch": 57, "velocity": 0.8]]]],
                     "clipByTrack": [["t1", [["position": 1.5, "length": 0.5, "pitch": 72, "velocity": 0.8]]]]
                 ]]],
                ["id": "s2", "name": "Chorus", "color": ["r": 1, "g": 1, "b": 1, "a": 1],
                 "length": 4, "children": ["clips": ["chords": [], "clipByTrack": []]]]
            ]
        ]
        let result = try importFixture(json)
        XCTAssertEqual(result.song.title, "Fixture")
        XCTAssertEqual(result.song.mode, .minor)
        XCTAssertEqual(result.song.sections.map(\.start), [0, 16])
        XCTAssertEqual(result.song.sections.map(\.duration), [16, 16])
        XCTAssertEqual(result.song.chords.first?.start, 0)
        XCTAssertEqual(result.song.chords.first?.duration, 16)
        XCTAssertEqual(result.song.chords.first?.pitches, [50, 53, 57])
        XCTAssertEqual(result.song.tracks.first?.notes.first?.start, 6)
        XCTAssertEqual(result.song.tracks.first?.notes.first?.duration, 2)
        XCTAssertEqual(result.song.loopEnd, 48)
        XCTAssertEqual(result.song.tracks.first?.notes.first?.velocity, 102)
        XCTAssertEqual(result.song.tracks.first?.pan, 0.25)
        XCTAssertEqual(result.song.chordChannel.volume, 0.65)
        XCTAssertEqual(result.song.chordChannel.pan, -0.4)
        XCTAssertTrue(result.song.chordChannel.mute)
        XCTAssertTrue(result.warnings.contains { $0.contains("instrument descriptor") })
        XCTAssertFalse(result.warnings.contains { $0.contains("pan") })
    }

    func testPreservesUnknownChildrenShapeWithoutProjectingItIntoTimeline() throws {
        var fixture = baseFixture()
        fixture["sections"] = [
            ["name": "Opaque", "length": 4, "color": [:], "children": ["opaque": ["version": 7]]],
            ["name": "Malformed nested", "length": 4, "color": [:], "children": ["sections": "preserve-me"]]
        ]
        let result = try importFixture(fixture)
        XCTAssertTrue(result.song.sections.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("unsupported shape") })
        guard let nativeSections = result.song.nativeSections,
              case let .opaque(children) = nativeSections[0].children else {
            return XCTFail("Expected opaque child data to remain in the native section tree")
        }
        XCTAssertEqual(children, .object(["opaque": .object(["version": .number(7)])]))
        guard let secondSection = result.song.nativeSections?[1],
              case let .opaque(malformedSections) = secondSection.children else {
            return XCTFail("Expected malformed nested section data to remain opaque")
        }
        XCTAssertEqual(malformedSections.objectValue?["sections"], .string("preserve-me"))
    }

    func testMalformedNestedLengthPreservesTreeAndStopsSequentialProjection() throws {
        var fixture = baseFixture()
        fixture["sections"] = [[
            "name": "Parent", "length": 8, "color": [:],
            "children": ["sections": [
                ["name": "First", "length": 2, "color": [:],
                 "children": ["clips": ["chords": [], "clipByTrack": []]]],
                ["name": "Missing length", "color": [:],
                 "children": ["clips": ["chords": [], "clipByTrack": []]]],
                ["name": "Later", "length": 2, "color": [:],
                 "children": ["clips": ["chords": [], "clipByTrack": []]]]
            ]]
        ]]

        let result = try importFixture(fixture)
        XCTAssertEqual(result.song.sections.map(\.name), ["First"])
        XCTAssertEqual(result.song.sections.first?.nativePath, KlimperSectionPath(indices: [0, 0]))
        XCTAssertTrue(result.warnings.contains { $0.contains("no usable length") && $0.contains("later siblings") })
        guard case let .sections(children, _) = try XCTUnwrap(result.song.nativeSections?.first?.children) else {
            return XCTFail("Expected the valid object children to remain a typed ordered tree")
        }
        XCTAssertEqual(children.map(\.name), ["First", "Missing length", "Later"])
    }

    func testMixedNestedArrayIsRetainedOpaqueInsteadOfFailingImport() throws {
        var fixture = baseFixture()
        fixture["sections"] = [[
            "name": "Malformed parent", "length": 4, "color": [:],
            "children": ["sections": [
                ["name": "Valid", "length": 2, "color": [:],
                 "children": ["clips": ["chords": [], "clipByTrack": []]]],
                "not a section object"
            ]]
        ]]

        let result = try importFixture(fixture)
        XCTAssertTrue(result.song.sections.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("non-object item") })
        guard case let .opaque(rawChildren) = try XCTUnwrap(result.song.nativeSections?.first?.children) else {
            return XCTFail("Expected the malformed child branch to remain opaque")
        }
        guard case let .array(rawChildrenArray) = rawChildren.objectValue?["sections"] else {
            return XCTFail("Expected the raw mixed child array to be preserved")
        }
        XCTAssertEqual(rawChildrenArray.count, 2)
    }

    func testIncompleteClipContainerIsPreservedAndOmittedSafely() throws {
        var fixture = baseFixture()
        fixture["sections"] = [[
            "name": "Incomplete clips", "length": 4, "color": [:],
            "children": ["clips": ["chords": []]]
        ]]

        let result = try importFixture(fixture)
        XCTAssertTrue(result.song.sections.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("malformed chord/track arrays") })
        guard case let .clips(rawClips) = try XCTUnwrap(result.song.nativeSections?.first?.children) else {
            return XCTFail("Expected malformed clip data to remain in the native tree")
        }
        XCTAssertEqual(rawClips.objectValue?["clips"]?.objectValue?["chords"], .array([]))
    }

    func testMalformedClipRecordsAreSkippedWithoutBreakingKnownSequentialPositions() throws {
        var fixture = baseFixture()
        fixture["tracks"] = [["id": "t1", "name": "Lead", "volume": 0.8, "pan": 0.0,
                               "mute": false, "solo": false, "instrument": ""]]
        fixture["sections"] = [[
            "name": "Clip section", "length": 8, "color": [:],
            "children": ["clips": [
                "chords": [
                    ["chord": ["root": 15, "intervals": [0, 4, 7]], "length": 2, "voicing": []],
                    ["chord": ["root": 0, "intervals": [0, 4, 7]], "length": 1,
                     "voicing": [["position": 0, "length": 1, "pitch": 60, "velocity": 0.8]]]
                ],
                "clipByTrack": [["t1", ["malformed note", ["position": 1, "length": 0.5,
                                                        "pitch": 60, "velocity": 0.8]]]]
            ]]
        ]]

        let result = try importFixture(fixture)
        XCTAssertEqual(result.song.chords.map(\.start), [8])
        XCTAssertEqual(result.song.tracks.first?.notes.map(\.start), [4])
        XCTAssertTrue(result.warnings.contains { $0.contains("unsupported chord or voicing") })
        XCTAssertTrue(result.warnings.contains { $0.contains("malformed; it is preserved") })
        XCTAssertEqual(result.song.sections.first?.nativePath, KlimperSectionPath(indices: [0]))
    }

    func testPreservesZeroLengthNativeSectionWithoutInventingTimelineDuration() throws {
        var fixture = baseFixture()
        fixture["sections"] = [["id": "zero", "name": "Zero", "length": 0, "color": [:],
                                  "children": ["clips": ["chords": [], "clipByTrack": []]]]]
        let result = try importFixture(fixture)
        XCTAssertTrue(result.song.sections.isEmpty)
        XCTAssertEqual(result.song.nativeSections?.first?.rawLength, .number(0))
        XCTAssertTrue(result.warnings.contains { $0.contains("nonpositive length") })
    }

    func testRetainsOrderedRecursiveTreeAcrossHSketchSaveAndResolvesIndexedPaths() throws {
        var fixture = baseFixture()
        fixture["sections"] = [[
            "id": "root", "name": "Root", "length": 8, "color": [:], "vendor": ["x": 3],
            "children": ["sections": [
                ["id": "first", "name": "First", "length": 3, "color": [:],
                 "children": ["clips": ["chords": [], "clipByTrack": [], "vendorClipData": [1, 2]]]],
                ["id": "second", "name": "Second", "length": 5, "color": [:],
                 "children": ["sections": [
                    ["id": "leaf", "name": "Leaf", "length": 2, "color": [:],
                     "children": ["clips": ["chords": [], "clipByTrack": []]]]
                 ]]]
            ]]
        ]]

        let imported = try importFixture(fixture)
        let roots = try XCTUnwrap(imported.song.nativeSections)
        XCTAssertEqual(roots.map(\.name), ["Root"])
        guard case let .sections(children, metadata) = roots[0].children else {
            return XCTFail("Expected ordered nested sections")
        }
        XCTAssertEqual(children.map(\.name), ["First", "Second"])
        XCTAssertEqual(metadata, [:])
        XCTAssertEqual(roots[0].fields["vendor"], .object(["x": .number(3)]))
        XCTAssertEqual(try KlimperSectionPath(indices: [0, 1, 0]).resolve(in: roots).name, "Leaf")
        XCTAssertEqual(imported.song.sections.map(\.nativePath), [
            KlimperSectionPath(indices: [0, 0]), KlimperSectionPath(indices: [0, 1, 0])
        ])
        XCTAssertEqual(imported.song.nativeSectionFidelity, .preserved)
        XCTAssertThrowsError(try KlimperSectionPath(indices: [0, 0, 0]).resolve(in: roots))
        XCTAssertThrowsError(try KlimperSectionPath(indices: [0, 2]).resolve(in: roots))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ProjectPersistence.fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }
        try ProjectPersistence.save(imported.song, to: url)
        let restored = try ProjectPersistence.load(from: url)
        XCTAssertEqual(restored.nativeSections, roots)
        XCTAssertEqual(restored.sections.map(\.nativePath), imported.song.sections.map(\.nativePath))
        XCTAssertEqual(restored.nativeSectionFidelity, .preserved)

        var project = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var storedSong = try XCTUnwrap(project["song"] as? [String: Any])
        storedSong.removeValue(forKey: "nativeSectionFidelity")
        project["song"] = storedSong
        try JSONSerialization.data(withJSONObject: project).write(to: url)
        let legacyTree = try ProjectPersistence.load(from: url)
        XCTAssertEqual(legacyTree.nativeSections, roots)
        XCTAssertNil(legacyTree.nativeSectionFidelity)
    }

    func testNativeNameEditByPathPreservesRawLengthAndChildren() throws {
        var fixture = baseFixture()
        fixture["sections"] = [[
            "name": "Source", "length": 4, "color": [:],
            "children": ["clips": ["chords": [], "clipByTrack": []]]
        ]]
        let imported = try importFixture(fixture)
        var nativeSections = try XCTUnwrap(imported.song.nativeSections)
        let path = try XCTUnwrap(imported.song.sections.first?.nativePath)
        let original = try path.resolve(in: nativeSections)
        XCTAssertTrue(path.setName("Renamed", in: &nativeSections))
        let renamed = try path.resolve(in: nativeSections)
        XCTAssertEqual(renamed.name, "Renamed")
        XCTAssertEqual(renamed.rawLength, original.rawLength)
        XCTAssertEqual(renamed.children, original.children)

        var projectionOnlyEdit = imported.song
        projectionOnlyEdit.sections[0].start += 1
        projectionOnlyEdit.recordSectionProjectionEdit(comparedTo: imported.song, nativeFieldsSynchronized: false)
        XCTAssertEqual(projectionOnlyEdit.nativeSectionFidelity, .projectionOutOfSync)

        var legacyNativeTree = imported.song
        legacyNativeTree.nativeSectionFidelity = nil
        var legacyEdit = legacyNativeTree
        legacyEdit.sections[0].name = "Changed"
        legacyEdit.recordSectionProjectionEdit(comparedTo: legacyNativeTree, nativeFieldsSynchronized: true)
        XCTAssertNil(legacyEdit.nativeSectionFidelity, "Missing historical fidelity must remain unknown.")
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
         "bpm": 120, "tracks": [], "sections": [],
         "chord_track": ["volume": 1.0, "pan": 0.0, "mute": false, "solo": false, "instrument": ""],
         "_start": 0, "_end": 4, "looping": true]
    }
}
