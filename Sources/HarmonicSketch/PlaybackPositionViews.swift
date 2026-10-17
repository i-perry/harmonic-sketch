import SwiftUI

struct PlayheadMarker: View {
    @ObservedObject var position: PlaybackPosition
    let zoom: Double
    let height: Double

    var body: some View {
        Rectangle()
            .fill(.mint)
            .frame(width: 2, height: height)
            .offset(x: position.beat * zoom)
    }
}

struct PlaybackPositionReadout: View {
    @ObservedObject var position: PlaybackPosition

    var body: some View {
        Text(String(format: "%03.1f", position.beat))
            .monospacedDigit()
            .foregroundStyle(.mint)
    }
}
