import Foundation
import XCTest
@testable import HarmonicSketch

final class MIDIExporterTests: XCTestCase {
    func testExportsFormatOneWithTempoAndBeatAccurateNoteEvents() throws {
        let song = Song(title: "Test", tempo: 120, key: 2, mode: .dorian, tracks: [
            Track(name: "Lead", notes: [
                Note(pitch: 60, start: 2, duration: 0.5, velocity: 100),
                Note(pitch: 60, start: 2.5, duration: 0.5, velocity: 100)
            ], instrument: 4)
        ], chords: [ChordClip(root: 0, quality: .major, start: 0, duration: 1)])

        let file = try parseMIDI(MIDIExporter.data(for: song))
        XCTAssertEqual(file.format, 1)
        XCTAssertEqual(file.ticksPerQuarter, 480)
        XCTAssertEqual(file.tracks.count, 3)

        let metadata = file.tracks[0]
        XCTAssertTrue(metadata.contains { $0.metaType == 0x51 && $0.data == [0x07, 0xA1, 0x20] })
        XCTAssertTrue(metadata.contains { $0.metaType == 0x58 && $0.data == [4, 2, 24, 8] })
        XCTAssertTrue(metadata.contains { $0.metaType == 0x59 && $0.data == [0, 0] })

        let lead = try XCTUnwrap(file.tracks.first { $0.contains { $0.metaType == 0x03 && String(decoding: $0.data, as: UTF8.self) == "Lead" } })
        let chordTrack = try XCTUnwrap(file.tracks.first { $0.contains { $0.metaType == 0x03 && String(decoding: $0.data, as: UTF8.self) == "Chords" } })
        let noteEvents = lead.filter { $0.status & 0xF0 == 0x90 || $0.status & 0xF0 == 0x80 }
        XCTAssertEqual(noteEvents.map(\.tick), [960, 1200, 1200, 1440])
        XCTAssertEqual(noteEvents.map { $0.status & 0x0F }, [1, 1, 1, 1])
        XCTAssertEqual(noteEvents.map { $0.status & 0xF0 }, [0x90, 0x80, 0x90, 0x80])
        XCTAssertTrue(chordTrack.contains { $0.status & 0xF0 == 0x90 && $0.status & 0x0F == 0 })
    }

    func testMutedTracksAndNonSoloTracksAreExcludedWhenSoloExists() throws {
        let song = Song(tracks: [
            Track(name: "Solo", notes: [Note(pitch: 60, start: 0, duration: 1)], solo: true),
            Track(name: "Other", notes: [Note(pitch: 62, start: 0, duration: 1)]),
            Track(name: "Muted", notes: [Note(pitch: 64, start: 0, duration: 1)], mute: true)
        ])

        let file = try parseMIDI(MIDIExporter.data(for: song))
        let events = file.tracks.flatMap { $0 }
        XCTAssertTrue(events.contains { $0.status & 0xF0 == 0x90 && $0.data == [60, 90] })
        XCTAssertFalse(events.contains { $0.status & 0xF0 == 0x90 && $0.data.first == 62 })
        XCTAssertFalse(events.contains { $0.status & 0xF0 == 0x90 && $0.data.first == 64 })
        XCTAssertEqual(file.tracks.count, 2)
    }

    func testExportsChordAndTrackPanWithCenterAndEdgeControllers() throws {
        var left = Track(name: "Left", notes: [Note(pitch: 60, start: 0, duration: 1)])
        left.pan = -1
        var center = Track(name: "Center", notes: [Note(pitch: 62, start: 0, duration: 1)])
        center.pan = 0
        var right = Track(name: "Right", notes: [Note(pitch: 64, start: 0, duration: 1)])
        right.pan = 1
        let song = Song(tracks: [left, center, right], chords: [ChordClip(root: 0, quality: .major, start: 0)],
                        chordSettings: ChannelSettings(volume: 0.5, instrument: 12, pan: 0))
        let file = try parseMIDI(MIDIExporter.data(for: song))

        XCTAssertTrue(try XCTUnwrap(namedTrack("Left", in: file)).contains { $0.status == 0xB1 && $0.data == [10, 0] })
        XCTAssertTrue(try XCTUnwrap(namedTrack("Center", in: file)).contains { $0.status == 0xB2 && $0.data == [10, 64] })
        XCTAssertTrue(try XCTUnwrap(namedTrack("Right", in: file)).contains { $0.status == 0xB3 && $0.data == [10, 127] })
        let chordTrack = try XCTUnwrap(namedTrack("Chords", in: file))
        XCTAssertTrue(chordTrack.contains { $0.status == 0xB0 && $0.data == [10, 64] })
        XCTAssertTrue(chordTrack.contains { $0.status == 0xC0 && $0.data == [12] })
        XCTAssertTrue(chordTrack.contains { $0.status == 0xB0 && $0.data == [7, 64] })
    }

    func testExportAppliesChordMuteAndSoloAcrossAllChannels() throws {
        let song = Song(tracks: [Track(name: "Lead", notes: [Note(pitch: 60, start: 0, duration: 1)])],
                        chords: [ChordClip(root: 0, quality: .major, start: 0)],
                        chordSettings: ChannelSettings(solo: true))
        let file = try parseMIDI(MIDIExporter.data(for: song))
        XCTAssertNotNil(namedTrack("Chords", in: file))
        XCTAssertNil(namedTrack("Lead", in: file))

        var mutedSolo = song
        mutedSolo.chordSettings = ChannelSettings(mute: true, solo: true)
        let mutedFile = try parseMIDI(MIDIExporter.data(for: mutedSolo))
        XCTAssertNotNil(namedTrack("Lead", in: mutedFile))
        XCTAssertNil(namedTrack("Chords", in: mutedFile))
    }

    private struct ParsedEvent {
        let tick: Int
        let status: UInt8
        let metaType: UInt8?
        let data: [UInt8]
    }

    private struct ParsedFile {
        let format: Int
        let ticksPerQuarter: Int
        let tracks: [[ParsedEvent]]
    }

    private func parseMIDI(_ data: Data) throws -> ParsedFile {
        let bytes = Array(data)
        XCTAssertGreaterThanOrEqual(bytes.count, 14)
        XCTAssertEqual(Array(bytes[0..<4]), Array("MThd".utf8))
        XCTAssertEqual(try readUInt32(bytes, at: 4), 6)
        let format = Int(bytes[8]) << 8 | Int(bytes[9])
        let trackCount = Int(bytes[10]) << 8 | Int(bytes[11])
        let ticksPerQuarter = Int(bytes[12]) << 8 | Int(bytes[13])
        var offset = 14
        var tracks = [[ParsedEvent]]()

        for _ in 0..<trackCount {
            XCTAssertLessThanOrEqual(offset + 8, bytes.count)
            XCTAssertEqual(Array(bytes[offset..<(offset + 4)]), Array("MTrk".utf8))
            let payloadLength = Int(try readUInt32(bytes, at: offset + 4))
            offset += 8
            let trackEnd = offset + payloadLength
            XCTAssertLessThanOrEqual(trackEnd, bytes.count)
            var tick = 0
            var events = [ParsedEvent]()
            while offset < trackEnd {
                tick += try readVariableLength(bytes, offset: &offset, limit: trackEnd)
                let status = bytes[offset]
                offset += 1
                if status == 0xFF {
                    let metaType = bytes[offset]
                    offset += 1
                    let length = try readVariableLength(bytes, offset: &offset, limit: trackEnd)
                    let end = offset + length
                    XCTAssertLessThanOrEqual(end, trackEnd)
                    events.append(ParsedEvent(tick: tick, status: status, metaType: metaType, data: Array(bytes[offset..<end])))
                    offset = end
                    if metaType == 0x2F { break }
                } else {
                    let command = status & 0xF0
                    let length = command == 0xC0 || command == 0xD0 ? 1 : 2
                    let end = offset + length
                    XCTAssertLessThanOrEqual(end, trackEnd)
                    events.append(ParsedEvent(tick: tick, status: status, metaType: nil, data: Array(bytes[offset..<end])))
                    offset = end
                }
            }
            offset = trackEnd
            tracks.append(events)
        }
        XCTAssertEqual(offset, bytes.count)
        return ParsedFile(format: format, ticksPerQuarter: ticksPerQuarter, tracks: tracks)
    }

    private func namedTrack(_ name: String, in file: ParsedFile) -> [ParsedEvent]? {
        file.tracks.first { track in
            track.contains { $0.metaType == 0x03 && String(decoding: $0.data, as: UTF8.self) == name }
        }
    }

    private func readUInt32(_ bytes: [UInt8], at offset: Int) throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw MIDIParseError.truncated }
        return UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }

    private func readVariableLength(_ bytes: [UInt8], offset: inout Int, limit: Int) throws -> Int {
        var value = 0
        for _ in 0..<4 {
            guard offset < limit else { throw MIDIParseError.truncated }
            let byte = bytes[offset]
            offset += 1
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        throw MIDIParseError.invalidVariableLength
    }

    private enum MIDIParseError: Error {
        case truncated
        case invalidVariableLength
    }
}
