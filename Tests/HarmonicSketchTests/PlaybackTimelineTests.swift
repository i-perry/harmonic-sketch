import XCTest
@testable import HarmonicSketch

final class PlaybackTimelineTests: XCTestCase {
    func testClockUsesCurrentTempoForEachElapsedInterval() {
        var clock = PlaybackClock(beat: 3, time: 10)

        XCTAssertEqual(clock.advance(to: 12, tempo: 120), 7)
        XCTAssertEqual(clock.advance(to: 13, tempo: 60), 8)
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
