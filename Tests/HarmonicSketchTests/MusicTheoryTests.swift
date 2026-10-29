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

    func testRecoveredFlowAndContrastVectors() {
        let cMajor = HarmonyChord.from(root: 0, quality: .major)
        let gMajor = HarmonyChord.from(root: 7, quality: .major)
        let dbMajor = HarmonyChord.from(root: 1, quality: .major)

        XCTAssertEqual(MusicTheory.flowScore(first: cMajor, second: cMajor), 1, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.contrastScore(first: cMajor, second: cMajor), 1, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.flowScore(first: cMajor, second: gMajor), Float(1.0 / 6.0), accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.contrastScore(first: cMajor, second: gMajor), Float(7.0 / 12.0), accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.flowScore(first: cMajor, second: dbMajor), 0, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.contrastScore(first: cMajor, second: dbMajor), 1, accuracy: 1e-6)
    }

    func testRecoveredRelationDefaultsAndMatchNotesDeduplication() {
        let cMajor = HarmonyChord.from(root: 0, quality: .major)

        XCTAssertEqual(MusicTheory.flowScore(first: nil, second: cMajor), 0.8, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.contrastScore(first: nil, second: cMajor), 0.8, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.matchNotesScore(selection: nil, second: cMajor), 0.8, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.matchNotesScore(selection: [60, 64, 76], second: cMajor), 1, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.matchNotesScore(selection: [60, 61, 64], second: cMajor), Float(2.0 / 3.0), accuracy: 1e-6)
        XCTAssertTrue(MusicTheory.matchNotesScore(selection: [], second: cMajor).isNaN)
    }

    func testPaletteFlowAndContrastUseRecoveredCallbackScores() {
        let source = ChordClip(root: 0, quality: .major, start: 0, customPitches: [36, 48, 52])

        XCTAssertEqual(MusicTheory.relation(from: source, root: 7, quality: .major, mode: .flow), Double(Float(1.0 / 6.0)), accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: source, root: 7, quality: .major, mode: .contrast), Double(Float(7.0 / 12.0)), accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: nil, root: 7, quality: .major, mode: .flow), 0.8, accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: nil, root: 7, quality: .major, mode: .contrast), 0.8, accuracy: 1e-7)
    }

    func testPaletteTonalOrdinaryBranchUsesRecoveredPredicates() {
        let dMinor = ChordClip(root: 2, quality: .minor, start: 0)

        XCTAssertEqual(MusicTheory.relation(from: dMinor, root: 4, quality: .minor, mode: .tonal, key: 0), 0.7, accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: dMinor, root: 5, quality: .major, mode: .tonal, key: 0), 0, accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: nil, root: 4, quality: .minor, mode: .tonal, key: 0), 0.8, accuracy: 1e-7)
        XCTAssertEqual(MusicTheory.relation(from: ChordClip(root: 7, quality: .major, start: 0), root: 0, quality: .major, mode: .tonal, key: 0), 1, accuracy: 1e-7)
    }

    func testRecoveredTonalSuspensionVectors() {
        let vectors: [(HarmonyChord, HarmonyChord, Float)] = [
            (HarmonyChord(root: 0, intervalOffsets: [2]), HarmonyChord(root: 0, intervalOffsets: [3]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [2]), HarmonyChord(root: 0, intervalOffsets: [4]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [5]), HarmonyChord(root: 0, intervalOffsets: [4]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [5]), HarmonyChord(root: 0, intervalOffsets: [3]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [2, 5]), HarmonyChord(root: 9, intervalOffsets: [4]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [2, 5]), HarmonyChord(root: 0, intervalOffsets: [3]), 0),
            (HarmonyChord(root: 0, intervalOffsets: [2]), HarmonyChord(root: 11, intervalOffsets: [3, 4]), 0),
            (HarmonyChord(root: 0, intervalOffsets: [2]), HarmonyChord(root: 0, intervalOffsets: [5]), 0),
            (HarmonyChord(root: 0, intervalOffsets: [5]), HarmonyChord(root: 0, intervalOffsets: [2]), 0),
            (HarmonyChord(root: 0, intervalOffsets: [2]), HarmonyChord(root: 0, intervalOffsets: [2]), Float(bitPattern: 0x3f333333)),
            (HarmonyChord(root: 0, intervalOffsets: [4, 7]), HarmonyChord(root: 2, intervalOffsets: [2]), Float(bitPattern: 0x3f333333)),
            (HarmonyChord(root: 0, intervalOffsets: [4, 7]), HarmonyChord(root: 2, intervalOffsets: [5]), Float(bitPattern: 0x3f333333)),
            (HarmonyChord(root: 0, intervalOffsets: [7]), HarmonyChord(root: 2, intervalOffsets: [2, 5]), 0),
            (HarmonyChord(root: 11, intervalOffsets: [2]), HarmonyChord(root: 11, intervalOffsets: [3]), 1),
            (HarmonyChord(root: 0, intervalOffsets: [14]), HarmonyChord(root: 0, intervalOffsets: [3]), 1),
        ]

        for (index, vector) in vectors.enumerated() {
            XCTAssertEqual(MusicTheory.tonalScore(first: vector.0, second: vector.1, key: 0), vector.2, accuracy: 1e-6, "vector \(index + 1)")
        }
        XCTAssertEqual(MusicTheory.tonalScore(first: vectors[0].0, second: vectors[0].1, key: 7), 1, accuracy: 1e-6)
    }

    func testTonalPreservesCallbackOrderAndExactIntervalMembership() {
        let sus2 = HarmonyChord(root: 0, intervalOffsets: [2])
        let sus4 = HarmonyChord(root: 0, intervalOffsets: [5])
        XCTAssertEqual(MusicTheory.tonalScore(first: sus2, second: sus4, key: 0), 0)
        XCTAssertEqual(MusicTheory.tonalScore(first: sus4, second: sus2, key: 0), 0)

        let third = HarmonyChord(root: 0, intervalOffsets: [3])
        XCTAssertEqual(MusicTheory.tonalScore(first: sus2, second: third, key: 0), 1)
        XCTAssertEqual(MusicTheory.tonalScore(first: third, second: sus2, key: 0), 0)

        let exactTwo = HarmonyChord(root: 0, intervalOffsets: [2])
        let octaveTwo = HarmonyChord(root: 0, intervalOffsets: [14])
        let sameRootThird = HarmonyChord(root: 0, intervalOffsets: [3])
        XCTAssertEqual(MusicTheory.tonalScore(first: exactTwo, second: sameRootThird, key: 0), 1)
        XCTAssertEqual(MusicTheory.tonalScore(first: octaveTwo, second: sameRootThird, key: 0), 1)
        XCTAssertEqual(MusicTheory.tonalScore(first: HarmonyChord(root: 1, intervalOffsets: [14]), second: HarmonyChord(root: 4, intervalOffsets: [3]), key: 0), 0)
    }

    func testRecoveredHarmonyUsesPitchClassOverlapAndExactIntervalEquality() {
        let cMajor = HarmonyChord.from(root: 0, quality: .major)
        let octaveAltered = HarmonyChord(root: 0, intervalOffsets: [4, 19])

        XCTAssertEqual(MusicTheory.contrastScore(first: cMajor, second: cMajor), 1, accuracy: 1e-6)
        XCTAssertEqual(MusicTheory.flowScore(first: cMajor, second: octaveAltered), 1, accuracy: 1e-6)
        XCTAssertNotEqual(cMajor, octaveAltered)
        XCTAssertEqual(MusicTheory.contrastScore(first: cMajor, second: octaveAltered), 0, accuracy: 1e-6)
    }

    func testRecoveredChordVectorComparesRootPitchClassToSignedThreshold() {
        let base = NativeChordVoicing.make(rootPitchClass: 0, orderedIntervals: [4, 7],
                                           register: 4, rootPitchClassThreshold: 0,
                                           strummingTicks: 0, velocitySetting: 0.8,
                                           velocityScalar: 1)
        let raised = NativeChordVoicing.make(rootPitchClass: 0, orderedIntervals: [4, 7],
                                             register: 4, rootPitchClassThreshold: 1,
                                             strummingTicks: 0, velocitySetting: 0.8,
                                             velocityScalar: 1)
        let boundary = NativeChordVoicing.make(rootPitchClass: 11, orderedIntervals: [4, 7],
                                               register: 4, rootPitchClassThreshold: 1,
                                               strummingTicks: 0, velocitySetting: 0.8,
                                               velocityScalar: 1)
        let negativeThreshold = NativeChordVoicing.make(rootPitchClass: 0, orderedIntervals: [4, 7],
                                                        register: 4, rootPitchClassThreshold: -1,
                                                        strummingTicks: 0, velocitySetting: 0.8,
                                                        velocityScalar: 1)

        XCTAssertEqual(base.map(\.pitch), [48, 52, 55])
        XCTAssertEqual(raised.map(\.pitch), [60, 64, 67])
        XCTAssertEqual(boundary.map(\.pitch), [59, 63, 66])
        XCTAssertEqual(negativeThreshold.map(\.pitch), [48, 52, 55])
        XCTAssertEqual(base.map(\.velocity), [0.8, 0.8, 0.8])
    }

    func testRecoveredChordVectorUsesTickSpacingDurationFloorAndVelocityProduct() {
        let notes = NativeChordVoicing.make(rootPitchClass: 0, orderedIntervals: [4, 7],
                                            register: 4, rootPitchClassThreshold: 0,
                                            strummingTicks: 5_184, velocitySetting: 0.8,
                                            velocityScalar: 0.5)

        XCTAssertEqual(notes.map(\.positionTicks), [0, 5_184, 10_368])
        XCTAssertEqual(notes.map(\.lengthTicks), [10_368, 5_184, 162])
        XCTAssertEqual(notes.map(\.velocity), [0.4, 0.4, 0.4])
    }

    func testRecoveredEffectiveVelocityGateLeavesNativeFlagMeaningsOpaque() {
        XCTAssertEqual(NativeEffectiveVelocity.value(rawVelocity: 0.8, selectedLowFlag: 0,
                                                     selectedHighFlag: 0, aggregateFlag: false), 0.8)
        XCTAssertEqual(NativeEffectiveVelocity.value(rawVelocity: 0.8, selectedLowFlag: 1,
                                                     selectedHighFlag: 1, aggregateFlag: false), 0)
        XCTAssertEqual(NativeEffectiveVelocity.value(rawVelocity: 0.8, selectedLowFlag: 0,
                                                     selectedHighFlag: 0, aggregateFlag: true), 0)
        XCTAssertEqual(NativeEffectiveVelocity.value(rawVelocity: 0.8, selectedLowFlag: 0,
                                                     selectedHighFlag: 1, aggregateFlag: true), 0.8)
    }
}
