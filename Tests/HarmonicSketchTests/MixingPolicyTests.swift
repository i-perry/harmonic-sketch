import XCTest
@testable import HarmonicSketch

final class MixingPolicyTests: XCTestCase {
    func testMelodySoloSuppressesChordsAndOtherMelodyTracks() {
        let solo = Track(name: "Solo", solo: true)
        let other = Track(name: "Other")
        let song = Song(tracks: [solo, other], chords: [ChordClip(root: 0, quality: .major, start: 0)])

        XCTAssertEqual(MixingPolicy.audibleTracks(in: song).map(\.id), [solo.id])
        XCTAssertFalse(MixingPolicy.includesChordTrack(in: song))
    }

    func testChordSoloSuppressesMelodyAndKeepsChordTrack() {
        let track = Track(name: "Melody")
        let song = Song(tracks: [track], chords: [ChordClip(root: 0, quality: .major, start: 0)],
                        chordSettings: ChannelSettings(solo: true))

        XCTAssertTrue(MixingPolicy.audibleTracks(in: song).isEmpty)
        XCTAssertTrue(MixingPolicy.includesChordTrack(in: song))
    }

    func testMutedSoloDoesNotSuppressUnmutedMelody() {
        let melody = Track(name: "Melody")
        let mutedSolo = Track(name: "Muted solo", mute: true, solo: true)
        let song = Song(tracks: [melody, mutedSolo], chords: [ChordClip(root: 0, quality: .major, start: 0)],
                        chordSettings: ChannelSettings(mute: true, solo: true))

        XCTAssertEqual(MixingPolicy.audibleTracks(in: song).map(\.id), [melody.id])
        XCTAssertFalse(MixingPolicy.includesChordTrack(in: song))
    }

    func testChordAndMelodyCanBothPlayWhenBothAreSoloed() {
        let melody = Track(name: "Melody", solo: true)
        let song = Song(tracks: [melody], chords: [ChordClip(root: 0, quality: .major, start: 0)],
                        chordSettings: ChannelSettings(solo: true))

        XCTAssertEqual(MixingPolicy.audibleTracks(in: song).map(\.id), [melody.id])
        XCTAssertTrue(MixingPolicy.includesChordTrack(in: song))
    }
}
