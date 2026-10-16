import XCTest
@testable import HarmonicSketch

final class MusicTheoryTests: XCTestCase {
    func testRomanNotationUsesMinorAndDiminishedDegrees() {
        XCTAssertEqual(MusicTheory.label(root: 9, quality: .minor, key: 0, mode: .major, roman: true), "vi")
        XCTAssertEqual(MusicTheory.label(root: 11, quality: .diminished, key: 0, mode: .major, roman: true), "vii°")
        XCTAssertEqual(MusicTheory.label(root: 7, quality: .seventh, key: 0, mode: .major, roman: true), "V7")
    }
    func testBorrowedChordMembership() {
        XCTAssertTrue(MusicTheory.inScale(root: 5, quality: .major, key: 0, mode: .major))
        XCTAssertFalse(MusicTheory.inScale(root: 5, quality: .minor, key: 0, mode: .major))
        XCTAssertTrue(MusicTheory.inScale(root: 7, quality: .major, key: 0, mode: .harmonicMinor))
    }
    func testInversionRotatesVoicesAndIsBoundedForMalformedInput() {
        var chord = ChordClip(root: 0, quality: .major, start: 0, inversion: 1)
        XCTAssertEqual(chord.pitches, [52, 55, 60])
        chord.inversion = Int.max
        XCTAssertEqual(chord.pitches.count, 3)
        XCTAssertTrue(chord.pitches.allSatisfy { (0...127).contains($0) })
    }
}
