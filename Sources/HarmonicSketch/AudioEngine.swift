import AVFoundation
import Foundation

struct PlaybackClock {
    private(set) var beat: Double
    private var lastTime: TimeInterval
    private var fractionalMilliseconds = 0.0

    init(beat: Double, time: TimeInterval) {
        self.beat = beat
        lastTime = time
    }

    mutating func advance(to time: TimeInterval, tempo: Double) -> Double {
        let elapsedMilliseconds = max(0, time - lastTime) * 1_000
        lastTime = time
        guard tempo.isFinite, tempo > 0 else { return beat }
        let ticksPerMillisecond = (tempo / 60_000) * 0.25 * 10_368
        let rawTicks = (ticksPerMillisecond * elapsedMilliseconds).rounded(.towardZero)
        let rawTickMilliseconds = ((rawTicks / 10_368) * 4 * 60_000) / tempo
        let carriedMilliseconds = fractionalMilliseconds + (elapsedMilliseconds - rawTickMilliseconds)
        let carriedTicks = (ticksPerMillisecond * carriedMilliseconds).rounded(.towardZero)
        let carriedTickMilliseconds = ((carriedTicks / 10_368) * 4 * 60_000) / tempo
        fractionalMilliseconds = carriedMilliseconds - carriedTickMilliseconds
        beat += (rawTicks + carriedTicks) / 2_592
        return beat
    }
}

enum PlaybackTimeline {
    static func contentEnd(of song: Song) -> Double {
        let noteEnd = song.tracks.flatMap(\.notes).map { $0.start + $0.duration }.max() ?? 0
        let chordEnd = song.chords.map { $0.start + $0.duration }.max() ?? 0
        return max(song.loopEnd, max(noteEnd, chordEnd))
    }

    static func contains(_ note: Note, at beat: Double) -> Bool {
        note.start <= beat && note.start + note.duration > beat
    }
}

struct PlaybackDisplayThrottle {
    let minimumInterval: TimeInterval
    private(set) var lastPublishedAt: TimeInterval?

    init(minimumInterval: TimeInterval = 1.0 / 30.0) {
        self.minimumInterval = max(0, minimumInterval)
    }

    mutating func shouldPublish(at time: TimeInterval, force: Bool = false) -> Bool {
        guard time.isFinite else { return false }
        if force {
            lastPublishedAt = time
            return true
        }
        guard let lastPublishedAt else {
            self.lastPublishedAt = time
            return true
        }
        guard time - lastPublishedAt >= minimumInterval else { return false }
        self.lastPublishedAt = time
        return true
    }

    mutating func reset() {
        lastPublishedAt = nil
    }
}

@MainActor final class PlaybackEngine {
    private static let chordSamplerIndex = 0
    private static let firstTrackSamplerIndex = 1
    private static let previewSamplerIndex = 16
    private let engine = AVAudioEngine()
    private var samplers: [AVAudioUnitSampler] = []
    private var loadedPrograms: [Int: Int] = [:]
    private var timer: Timer?
    private var playbackClock: PlaybackClock?
    private var displayThrottle = PlaybackDisplayThrottle()
    private var previousBeat = 0.0
    private var isFirstPlaybackTick = true
    private var loopCycle: Int?
    private var wasLooping = false
    private var startedNoteIDs = Set<UUID>()
    private var startedChordIDs = Set<UUID>()
    private var trackLayout: [UUID] = []
    private var active: [ActiveVoice] = []
    private var midiPrograms: [Int: Int] = [:]
    private var midiVolumes: [Int: Double] = [:]
    private var midiPans: [Int: Double] = [:]
    private var previewWorkItems: [DispatchWorkItem] = []
    private var activePreviewMIDIPitches = Set<Int>()
    private(set) var soundFont: URL?
    let midi = MIDIOutput()
    var onBeat: ((Double) -> Void)?
    var onError: ((String) -> Void)?
    var onStopped: (() -> Void)?

    private struct ActiveVoice {
        let samplerIndex: Int
        let pitch: Int
        let endBeat: Double
        let trackID: UUID?
        let noteID: UUID?
        let chordID: UUID?
        let midiChannel: Int?
    }

    init() {
        for _ in 0..<17 {
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
            samplers.append(sampler)
        }
        midi.onDestinationChanged = { [weak self] in
            self?.midiPrograms.removeAll()
            self?.midiVolumes.removeAll()
            self?.midiPans.removeAll()
        }
        midi.onError = { [weak self] message in self?.onError?(message) }
    }

    func prepare(_ song: Song) throws {
        if !engine.isRunning { try engine.start() }
        try ensureProgramLoaded(0, program: song.chordChannel.instrument)
        try ensureProgramLoaded(Self.previewSamplerIndex, program: song.chordChannel.instrument)
        samplers[Self.chordSamplerIndex].volume = Float(song.chordChannel.volume)
        samplers[Self.chordSamplerIndex].pan = Float(song.chordChannel.pan)
        samplers[Self.previewSamplerIndex].volume = Float(song.chordChannel.volume)
        samplers[Self.previewSamplerIndex].pan = Float(song.chordChannel.pan)
        configureChordMIDI(song.chordChannel)
        for (index, track) in song.tracks.prefix(15).enumerated() {
            try ensureProgramLoaded(index + Self.firstTrackSamplerIndex, program: track.instrument)
        }
    }

    func loadSoundFont(_ url: URL, song: Song) throws {
        soundFont = url
        loadedPrograms.removeAll()
        try prepare(song)
    }

    func preview(_ pitches: [Int], velocity: Int = 90, strum: Double = 0) {
        cancelPreview()
        guard !pitches.isEmpty else { return }
        let safeVelocity = UInt8(clamping: velocity)
        for (index, pitch) in pitches.enumerated() {
            let delay = max(0, Double(index) * strum)
            schedulePreview(after: delay) { engine in
                engine.samplers[Self.previewSamplerIndex].startNote(
                    UInt8(clamping: pitch), withVelocity: safeVelocity, onChannel: 0
                )
                if engine.timer == nil {
                    engine.activePreviewMIDIPitches.insert(pitch)
                    engine.midi.noteOn(pitch: pitch, velocity: Int(safeVelocity), channel: 0)
                }
            }
            schedulePreview(after: delay + 0.7) { engine in
                engine.samplers[Self.previewSamplerIndex].stopNote(UInt8(clamping: pitch), onChannel: 0)
                if engine.activePreviewMIDIPitches.remove(pitch) != nil {
                    engine.midi.noteOff(pitch: pitch, channel: 0)
                }
            }
        }
    }

    func play(songProvider: @escaping @MainActor () -> Song, from beat: Double,
              looping: @escaping @MainActor () -> Bool) throws {
        stop()
        let initialSong = songProvider()
        try prepare(initialSong)
        let startBeat = max(0, beat.isFinite ? beat : 0)
        let now = Date.timeIntervalSinceReferenceDate
        playbackClock = PlaybackClock(beat: startBeat, time: now)
        displayThrottle.reset()
        previousBeat = startBeat
        isFirstPlaybackTick = true
        loopCycle = nil
        wasLooping = looping()
        startedNoteIDs.removeAll()
        startedChordIDs.removeAll()
        trackLayout = initialSong.tracks.map(\.id)

        let playbackTimer = Timer(timeInterval: 0.01, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.advancePlayback(song: songProvider(), looping: looping(), now: Date.timeIntervalSinceReferenceDate)
            }
        }
        timer = playbackTimer
        RunLoop.main.add(playbackTimer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        playbackClock = nil
        wasLooping = false
        cancelPreview()
        silence()
        startedNoteIDs.removeAll()
        startedChordIDs.removeAll()
        loopCycle = nil
        trackLayout.removeAll()
    }

    private func advancePlayback(song: Song, looping: Bool, now: TimeInterval) {
        guard var clock = playbackClock else { return }
        if looping != wasLooping {
            clock = PlaybackClock(beat: previousBeat, time: now)
            playbackClock = clock
            loopCycle = nil
            wasLooping = looping
        }
        let absoluteBeat = clock.advance(to: now, tempo: song.tempo)
        playbackClock = clock
        let position: Double
        let currentCycle: Int?
        if looping, song.loopEnd > song.loopStart, absoluteBeat >= song.loopEnd {
            let span = song.loopEnd - song.loopStart
            let cycles = Int((absoluteBeat - song.loopStart) / span)
            currentCycle = max(1, cycles)
            position = song.loopStart + (absoluteBeat - song.loopStart).truncatingRemainder(dividingBy: span)
        } else {
            currentCycle = nil
            position = absoluteBeat
        }

        if currentCycle != loopCycle, let currentCycle {
            silence()
            startedNoteIDs.removeAll()
            startedChordIDs.removeAll()
            previousBeat = song.loopStart
            isFirstPlaybackTick = true
            loopCycle = currentCycle
        } else if !looping || song.loopEnd <= song.loopStart {
            loopCycle = nil
        }

        let audibleTracks = MixingPolicy.audibleTracks(in: song)
        let chordIsAudible = MixingPolicy.includesChordTrack(in: song)
        let layout = song.tracks.map(\.id)
        if layout != trackLayout {
            silence()
            startedNoteIDs.removeAll()
            trackLayout = layout
            isFirstPlaybackTick = true
        }
        stopVoicesThatAreNoLongerAudible(audibleTrackIDs: Set(audibleTracks.map(\.id)),
                                         chordIsAudible: chordIsAudible, song: song)
        stopExpiredVoices(at: position)

        do {
            if loadedPrograms[Self.chordSamplerIndex] != song.chordChannel.instrument {
                let chordVoices = active.filter { $0.chordID != nil }
                for voice in chordVoices { stop(voice); if let chordID = voice.chordID { startedChordIDs.remove(chordID) } }
                active.removeAll { $0.chordID != nil }
            }
            try ensureProgramLoaded(Self.chordSamplerIndex, program: song.chordChannel.instrument)
            samplers[Self.chordSamplerIndex].volume = Float(song.chordChannel.volume)
            samplers[Self.chordSamplerIndex].pan = Float(song.chordChannel.pan)
            configureChordMIDI(song.chordChannel)
            let channelByIndex = Dictionary(uniqueKeysWithValues: Self.melodicChannels.enumerated().map { ($0.offset, $0.element) })
            for (index, track) in song.tracks.prefix(15).enumerated() where audibleTracks.contains(where: { $0.id == track.id }) {
                try ensureProgramLoaded(index + Self.firstTrackSamplerIndex, program: track.instrument)
                samplers[index + Self.firstTrackSamplerIndex].volume = Float(track.volume)
                samplers[index + Self.firstTrackSamplerIndex].pan = Float(track.pan ?? 0)
                if let channel = channelByIndex[index] {
                    if midiPrograms[channel] != track.instrument {
                        let trackVoices = active.filter { $0.trackID == track.id }
                        for voice in trackVoices {
                            stop(voice)
                            if let noteID = voice.noteID { startedNoteIDs.remove(noteID) }
                        }
                        active.removeAll { $0.trackID == track.id }
                        midi.programChange(program: track.instrument, channel: channel)
                        midiPrograms[channel] = track.instrument
                    }
                    if midiVolumes[channel] != track.volume {
                        midi.setVolume(track.volume, channel: channel)
                        midiVolumes[channel] = track.volume
                    }
                    let pan = track.pan ?? 0
                    if midiPans[channel] != pan {
                        midi.setPan(pan, channel: channel)
                        midiPans[channel] = pan
                    }
                }
                for note in track.notes where !startedNoteIDs.contains(note.id) {
                    let crossed = note.start > previousBeat && note.start <= position && note.start + note.duration > position
                    let sustainingAtPosition = PlaybackTimeline.contains(note, at: position)
                    if crossed || sustainingAtPosition {
                        start(note.pitch, velocity: note.velocity, samplerIndex: index + Self.firstTrackSamplerIndex,
                              end: note.start + note.duration, trackID: track.id, noteID: note.id,
                              midiChannel: channelByIndex[index])
                        startedNoteIDs.insert(note.id)
                    }
                }
            }
            for chord in song.chords where chordIsAudible && !startedChordIDs.contains(chord.id) {
                let crossed = chord.start > previousBeat && chord.start <= position && chord.start + chord.duration > position
                let sustainingAtPosition = chord.start <= position && chord.start + chord.duration > position
                if crossed || sustainingAtPosition {
                    for pitch in chord.pitches {
                        start(pitch, velocity: 85, samplerIndex: Self.chordSamplerIndex,
                              end: chord.start + chord.duration, chordID: chord.id, midiChannel: 0)
                    }
                    startedChordIDs.insert(chord.id)
                }
            }
        } catch {
            stop()
            onError?(error.localizedDescription)
            onStopped?()
            return
        }

        previousBeat = position
        isFirstPlaybackTick = false
        if displayThrottle.shouldPublish(at: now) { onBeat?(position) }
        if !looping, position >= PlaybackTimeline.contentEnd(of: song) {
            let endBeat = PlaybackTimeline.contentEnd(of: song)
            stop()
            if displayThrottle.shouldPublish(at: now, force: true) { onBeat?(endBeat) }
            onStopped?()
        }
    }

    private func configureChordMIDI(_ settings: ChannelSettings) {
        if midiPrograms[0] != settings.instrument {
            midi.programChange(program: settings.instrument, channel: 0)
            midiPrograms[0] = settings.instrument
        }
        if midiVolumes[0] != settings.volume {
            midi.setVolume(settings.volume, channel: 0)
            midiVolumes[0] = settings.volume
        }
        if midiPans[0] != settings.pan {
            midi.setPan(settings.pan, channel: 0)
            midiPans[0] = settings.pan
        }
    }

    private func stopVoicesThatAreNoLongerAudible(audibleTrackIDs: Set<UUID>, chordIsAudible: Bool, song: Song) {
        let availableNoteIDs = Set(song.tracks.flatMap(\.notes).map(\.id))
        for voice in active where voice.trackID.map({ !audibleTrackIDs.contains($0) }) == true
                || voice.noteID.map({ !availableNoteIDs.contains($0) }) == true {
            stop(voice)
        }
        active.removeAll { voice in
            voice.trackID.map({ !audibleTrackIDs.contains($0) }) == true
                || voice.noteID.map({ !availableNoteIDs.contains($0) }) == true
        }
        let audibleNoteIDs = Set(song.tracks.filter { audibleTrackIDs.contains($0.id) }.flatMap(\.notes).map(\.id))
        startedNoteIDs.formIntersection(audibleNoteIDs)
        let availableChordIDs = chordIsAudible ? Set(song.chords.map(\.id)) : []
        for voice in active where voice.chordID.map({ !availableChordIDs.contains($0) }) == true { stop(voice) }
        active.removeAll { $0.chordID.map { !availableChordIDs.contains($0) } == true }
        startedChordIDs.formIntersection(availableChordIDs)
    }

    private func stopExpiredVoices(at beat: Double) {
        for voice in active where voice.endBeat <= beat { stop(voice) }
        active.removeAll { $0.endBeat <= beat }
    }

    private func ensureProgramLoaded(_ samplerIndex: Int, program: Int) throws {
        let boundedProgram = min(127, max(0, program))
        guard loadedPrograms[samplerIndex] != boundedProgram else { return }
        samplers[samplerIndex].sendController(123, withValue: 0, onChannel: 0)
        let defaultURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        try samplers[samplerIndex].loadSoundBankInstrument(
            at: soundFont ?? defaultURL, program: UInt8(boundedProgram),
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0
        )
        loadedPrograms[samplerIndex] = boundedProgram
    }

    private func start(_ pitch: Int, velocity: Int, samplerIndex: Int, end: Double,
                       trackID: UUID? = nil, noteID: UUID? = nil, chordID: UUID? = nil,
                       midiChannel: Int? = nil) {
        samplers[samplerIndex].startNote(UInt8(clamping: pitch), withVelocity: UInt8(clamping: velocity), onChannel: 0)
        active.append(ActiveVoice(samplerIndex: samplerIndex, pitch: pitch, endBeat: end,
                                 trackID: trackID, noteID: noteID, chordID: chordID, midiChannel: midiChannel))
        if let midiChannel { midi.noteOn(pitch: pitch, velocity: velocity, channel: midiChannel) }
    }

    private func stop(_ voice: ActiveVoice) {
        samplers[voice.samplerIndex].stopNote(UInt8(clamping: voice.pitch), onChannel: 0)
        if let midiChannel = voice.midiChannel { midi.noteOff(pitch: voice.pitch, channel: midiChannel) }
    }

    private func silence() {
        for sampler in samplers { sampler.sendController(123, withValue: 0, onChannel: 0) }
        midi.silence()
        active.removeAll()
    }

    private static let melodicChannels = (0...15).filter { $0 != 0 && $0 != 9 }

    private func schedulePreview(after delay: Double, action: @escaping (PlaybackEngine) -> Void) {
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard !workItem.isCancelled, let self else { return }
                action(self)
            }
        }
        previewWorkItems.append(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPreview() {
        previewWorkItems.forEach { $0.cancel() }
        previewWorkItems.removeAll()
        samplers[Self.previewSamplerIndex].sendController(123, withValue: 0, onChannel: 0)
        for pitch in activePreviewMIDIPitches { midi.noteOff(pitch: pitch, channel: 0) }
        activePreviewMIDIPitches.removeAll()
    }
}
