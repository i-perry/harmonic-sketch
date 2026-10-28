import Foundation

struct NativeChordNote: Equatable {
    let positionTicks: Int64
    let lengthTicks: Int64
    let pitch: Int32
    let velocity: Float
}

enum NativeEffectiveVelocity {
    static func value(rawVelocity: Float, selectedLowFlag: UInt8,
                      selectedHighFlag: UInt8, aggregateFlag: Bool) -> Float {
        guard selectedLowFlag == 0, !aggregateFlag || selectedHighFlag != 0 else { return 0 }
        return rawVelocity
    }
}

/// Reproduces the recovered note-vector arithmetic when every native input is known.
/// The app's palette settings are not mapped to these arguments, so callers must supply them.
enum NativeChordVoicing {
    static let ticksPerWholeNote: Double = 10_368
    static let baseLengthTicks: Int64 = 10_368
    static let minimumLengthTicks: Int64 = 162

    static func make(rootPitchClass: Int, orderedIntervals: [UInt16], register: Int32,
                     rootPitchClassThreshold: Int32, strummingTicks: Int64,
                     velocitySetting: Float, velocityScalar: Float) -> [NativeChordNote] {
        let root = Int32((rootPitchClass % 12 + 12) % 12)
        let rawPitches = [root] + orderedIntervals.map { root + Int32($0) }
        let addThresholdOctave = root < rootPitchClassThreshold
        let velocity = velocitySetting * velocityScalar

        return rawPitches.enumerated().map { index, rawPitch in
            let offset = Int64((Double(strummingTicks) / ticksPerWholeNote
                                * Double(index) * ticksPerWholeNote).rounded(.towardZero))
            let length = max(minimumLengthTicks, baseLengthTicks - offset)
            let thresholdShift: Int32 = addThresholdOctave ? 12 : 0
            let pitch = rawPitch + thresholdShift + 12 * register
            return NativeChordNote(positionTicks: offset, lengthTicks: length,
                                   pitch: pitch, velocity: velocity)
        }
    }
}
