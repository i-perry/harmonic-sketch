import Foundation

enum MIDIExporter {
    private static let ticksPerQuarter = 480

    enum ExportError: Error, Equatable {
        case invalidTiming
        case eventTooFarInFuture
        case tooManyAudibleTracks
    }

    private struct Event {
        let tick: Int
        let priority: Int
        let bytes: [UInt8]
        let sequence: Int
    }

    static func data(for song: Song) throws -> Data {
        try ProjectPersistence.validate(song)
        let audibleTracks = MixingPolicy.audibleTracks(in: song)
        let hasChordTrack = MixingPolicy.includesChordTrack(in: song)
        let availableChannels = (0...15).filter { $0 != 9 && !(hasChordTrack && $0 == 0) }
        guard audibleTracks.count <= availableChannels.count else { throw ExportError.tooManyAudibleTracks }
        var chunks = [trackChunk(events: metadataEvents(for: song))]
        for (track, channel) in zip(audibleTracks, availableChannels) {
            chunks.append(trackChunk(events: try musicEvents(for: track, channel: channel)))
        }
        if hasChordTrack {
            chunks.append(trackChunk(events: try chordEvents(for: song.chords, settings: song.chordChannel, channel: 0)))
        }
        var result = Data("MThd".utf8)
        appendUInt32(6, to: &result)
        appendUInt16(1, to: &result)
        appendUInt16(UInt16(chunks.count), to: &result)
        appendUInt16(UInt16(ticksPerQuarter), to: &result)
        for chunk in chunks { result.append(chunk) }
        return result
    }

    static func write(_ song: Song, to url: URL) throws {
        try data(for: song).write(to: url, options: .atomic)
    }

    private static func metadataEvents(for song: Song) -> [Event] {
        let micros = UInt32((60_000_000 / song.tempo).rounded())
        let tempo = [UInt8(0xFF), 0x51, 0x03, UInt8((micros >> 16) & 0xFF), UInt8((micros >> 8) & 0xFF), UInt8(micros & 0xFF)]
        let signature = keySignature(for: song)
        return [
            Event(tick: 0, priority: 0, bytes: metaText(type: 0x03, text: song.title), sequence: 0),
            Event(tick: 0, priority: 1, bytes: tempo, sequence: 1),
            Event(tick: 0, priority: 2, bytes: [0xFF, 0x58, 0x04, 4, 2, 24, 8], sequence: 2),
            Event(tick: 0, priority: 3, bytes: [0xFF, 0x59, 0x02, UInt8(bitPattern: signature.sharps), signature.minor ? 1 : 0], sequence: 3)
        ]
    }

    private static func musicEvents(for track: Track, channel: Int) throws -> [Event] {
        var events = [
            Event(tick: 0, priority: 0, bytes: metaText(type: 0x03, text: track.name), sequence: 0),
            Event(tick: 0, priority: 1, bytes: [UInt8(0xC0 | channel), UInt8(track.instrument)], sequence: 1),
            Event(tick: 0, priority: 2, bytes: [UInt8(0xB0 | channel), 7, UInt8((track.volume * 127).rounded())], sequence: 2),
            Event(tick: 0, priority: 3, bytes: [UInt8(0xB0 | channel), 10, midiPan(track.pan ?? 0)], sequence: 3)
        ]
        var sequence = 4
        for note in track.notes {
            let (start, end) = try tickRange(start: note.start, duration: note.duration)
            guard end > start else { throw ExportError.invalidTiming }
            events.append(Event(tick: start, priority: 4, bytes: [UInt8(0x90 | channel), UInt8(note.pitch), UInt8(note.velocity)], sequence: sequence))
            sequence += 1
            events.append(Event(tick: end, priority: 3, bytes: [UInt8(0x80 | channel), UInt8(note.pitch), 0], sequence: sequence))
            sequence += 1
        }
        return events
    }

    private static func chordEvents(for chords: [ChordClip], settings: ChannelSettings, channel: Int) throws -> [Event] {
        var events = [
            Event(tick: 0, priority: 0, bytes: metaText(type: 0x03, text: "Chords"), sequence: 0),
            Event(tick: 0, priority: 1, bytes: [UInt8(0xC0 | channel), UInt8(settings.instrument)], sequence: 1),
            Event(tick: 0, priority: 2, bytes: [UInt8(0xB0 | channel), 7, UInt8((settings.volume * 127).rounded())], sequence: 2),
            Event(tick: 0, priority: 3, bytes: [UInt8(0xB0 | channel), 10, midiPan(settings.pan)], sequence: 3)
        ]
        var sequence = 4
        for chord in chords {
            let (start, end) = try tickRange(start: chord.start, duration: chord.duration)
            guard end > start else { throw ExportError.invalidTiming }
            for pitch in chord.pitches {
                events.append(Event(tick: start, priority: 4, bytes: [UInt8(0x90 | channel), UInt8(pitch), 84], sequence: sequence))
                sequence += 1
                events.append(Event(tick: end, priority: 3, bytes: [UInt8(0x80 | channel), UInt8(pitch), 0], sequence: sequence))
                sequence += 1
            }
        }
        return events
    }

    private static func midiPan(_ pan: Double) -> UInt8 {
        UInt8(((min(1, max(-1, pan)) + 1) * 63.5).rounded())
    }

    private static func tick(for beat: Double) throws -> Int {
        guard beat.isFinite, beat >= 0 else { throw ExportError.invalidTiming }
        let value = beat * Double(ticksPerQuarter)
        guard value <= 0x0FFF_FFFF else { throw ExportError.eventTooFarInFuture }
        return Int(value.rounded())
    }

    private static func tickRange(start: Double, duration: Double) throws -> (Int, Int) {
        let startTick = try tick(for: start)
        let endTick = try tick(for: start + duration)
        return (startTick, endTick)
    }

    private static func trackChunk(events: [Event]) -> Data {
        let sorted = events.sorted {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.sequence < $1.sequence
        }
        var payload = Data()
        var previousTick = 0
        for event in sorted {
            appendVariableLength(event.tick - previousTick, to: &payload)
            payload.append(contentsOf: event.bytes)
            previousTick = event.tick
        }
        appendVariableLength(0, to: &payload)
        payload.append(contentsOf: [0xFF, 0x2F, 0x00])
        var chunk = Data("MTrk".utf8)
        appendUInt32(UInt32(payload.count), to: &chunk)
        chunk.append(payload)
        return chunk
    }

    private static func metaText(type: UInt8, text: String) -> [UInt8] {
        let bytes = Array(text.utf8)
        return [0xFF, type] + variableLengthBytes(bytes.count) + bytes
    }

    private static func appendVariableLength(_ value: Int, to data: inout Data) {
        data.append(contentsOf: variableLengthBytes(value))
    }

    private static func variableLengthBytes(_ value: Int) -> [UInt8] {
        var buffer = [UInt8(value & 0x7F)]
        var remaining = value >> 7
        while remaining > 0 {
            buffer.insert(UInt8((remaining & 0x7F) | 0x80), at: 0)
            remaining >>= 7
        }
        return buffer
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value >> 8)); data.append(UInt8(value & 0xFF))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xFF)); data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF)); data.append(UInt8(value & 0xFF))
    }

    private static func keySignature(for song: Song) -> (sharps: Int8, minor: Bool) {
        let minor = song.mode == .minor || song.mode == .harmonicMinor
        let relativeMajorOffset: Int
        switch song.mode {
        case .major: relativeMajorOffset = 0
        case .dorian: relativeMajorOffset = 2
        case .phrygian: relativeMajorOffset = 4
        case .lydian: relativeMajorOffset = 5
        case .mixolydian: relativeMajorOffset = 7
        case .minor, .harmonicMinor: relativeMajorOffset = 9
        case .locrian: relativeMajorOffset = 11
        }
        let majorSharpCounts: [Int: Int8] = [0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: 7,
                                              5: -1, 10: -2, 3: -3, 8: -4]
        let majorTonic = (song.key - relativeMajorOffset + 12) % 12
        return (majorSharpCounts[majorTonic] ?? 0, minor)
    }
}
