import XCTest
import Combine
@testable import HarmonicSketch

final class PlaybackTimelineTests: XCTestCase {
    @MainActor
    func testPlaybackPositionChangesDoNotPublishTheComposerStore() {
        let store = ComposerStore()
        var storeChanges = 0
        let observation = store.objectWillChange.sink { storeChanges += 1 }

        store.position.beat = 2.5

        XCTAssertEqual(store.playhead, 2.5)
        XCTAssertEqual(storeChanges, 0)
        withExtendedLifetime(observation) { }
    }

    @MainActor
    func testDiagnosticPlaybackEngineStartsAndTicksWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["HSK_DIAG_ENGINE_SMOKE"] == "1" else {
            throw XCTSkip("Set HSK_DIAG_ENGINE_SMOKE=1 to run the AVAudioEngine runtime diagnostic.")
        }

        let engine = PlaybackEngine()
        var beatUpdates = 0
        engine.onBeat = { _ in beatUpdates += 1 }
        let song = Song()
        try engine.play(songProvider: { song }, from: 0, looping: { true })

        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline && beatUpdates < 3 {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        engine.stop()
        XCTAssertGreaterThanOrEqual(beatUpdates, 3, "Playback timer should publish beats while the main run loop is serviced.")
    }

    func testClockUsesCurrentTempoForEachElapsedInterval() {
        var clock = PlaybackClock(beat: 3, time: 10)

        XCTAssertEqual(clock.advance(to: 12, tempo: 120), 7)
        XCTAssertEqual(clock.advance(to: 13, tempo: 60), 8)
    }

    func testClockCarriesFractionalMillisecondsAcrossIntegerTickCallbacks() {
        var clock = PlaybackClock(beat: 0, time: 0)
        let expectedTicks = [5.0, 10.0, 15.0, 20.0, 25.0, 31.0]

        for (index, ticks) in expectedTicks.enumerated() {
            let beat = clock.advance(to: Double(index + 1) / 1_000, tempo: 120)
            XCTAssertEqual(beat * 2_592, ticks, accuracy: 1e-9)
        }
    }

    func testClockProducesSameTicksForOneChunkOrSeveralCallbacks() {
        var chunked = PlaybackClock(beat: 0, time: 0)
        for millisecond in 1...6 {
            _ = chunked.advance(to: Double(millisecond) / 1_000, tempo: 120)
        }

        var singleChunk = PlaybackClock(beat: 0, time: 0)
        let finalBeat = singleChunk.advance(to: 0.006, tempo: 120)

        XCTAssertEqual(chunked.beat, finalBeat, accuracy: 1e-12)
        XCTAssertEqual(finalBeat * 2_592, 31, accuracy: 1e-9)
    }

    func testClockCarriesTimeUsingTheCurrentTempoAfterTempoChanges() {
        var clock = PlaybackClock(beat: 0, time: 0)

        XCTAssertEqual(clock.advance(to: 0.001, tempo: 120) * 2_592, 5, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 0.002, tempo: 60) * 2_592, 7, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 0.003, tempo: 60) * 2_592, 10, accuracy: 1e-9)
    }

    func testClockDoesNotAccumulateZeroOrBackwardTimeIntervals() {
        var clock = PlaybackClock(beat: 0, time: 0)

        XCTAssertEqual(clock.advance(to: 0.001, tempo: 120) * 2_592, 5, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 0.001, tempo: 120) * 2_592, 5, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 0, tempo: 120) * 2_592, 5, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 0.001, tempo: 120) * 2_592, 10, accuracy: 1e-9)
    }

    func testPlaybackDisplayThrottleCapsPublishedBeatsAndAllowsForcedFinalPosition() {
        var throttle = PlaybackDisplayThrottle(minimumInterval: 1.0 / 30.0)

        XCTAssertTrue(throttle.shouldPublish(at: 1.00))
        XCTAssertFalse(throttle.shouldPublish(at: 1.01))
        XCTAssertFalse(throttle.shouldPublish(at: 1.02))
        XCTAssertTrue(throttle.shouldPublish(at: 1.04))
        XCTAssertTrue(throttle.shouldPublish(at: 1.041, force: true))
        XCTAssertFalse(throttle.shouldPublish(at: 1.05))
        XCTAssertTrue(throttle.shouldPublish(at: 1.08))
    }

    func testPlaybackDisplayThrottleRejectsNonFiniteTimeAndResets() {
        var throttle = PlaybackDisplayThrottle(minimumInterval: 0.03)

        XCTAssertFalse(throttle.shouldPublish(at: .infinity))
        XCTAssertFalse(throttle.shouldPublish(at: .nan))
        XCTAssertTrue(throttle.shouldPublish(at: 5))
        XCTAssertTrue(throttle.shouldPublish(at: 4, force: true))
        throttle.reset()
        XCTAssertTrue(throttle.shouldPublish(at: 4))
    }

    func testNonLoopingContentEndIncludesNotesAndChordsPastLoopEnd() {
        let song = Song(
            tracks: [Track(name: "Lead", notes: [Note(pitch: 64, start: 20, duration: 2)])],
            chords: [ChordClip(root: 0, quality: .major, start: 25, duration: 3)],
            loopEnd: 16
        )

        XCTAssertEqual(PlaybackTimeline.contentEnd(of: song), 28)
    }

    func testSeekRecognizesSustainingNotes() {
        let sustained = Note(pitch: 60, start: 2, duration: 4)
        let finished = Note(pitch: 62, start: 2, duration: 2)

        XCTAssertTrue(PlaybackTimeline.contains(sustained, at: 4))
        XCTAssertFalse(PlaybackTimeline.contains(finished, at: 4))
    }
}
