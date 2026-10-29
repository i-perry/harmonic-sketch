import Foundation

enum MixingPolicy {
    static func audibleTracks(in song: Song) -> [Track] {
        let unmutedTracks = song.tracks.filter { !$0.mute }
        let chordIsUnmuted = !song.chords.isEmpty && !song.chordChannel.mute
        let hasAudibleSolo = unmutedTracks.contains(where: \.solo) || (chordIsUnmuted && song.chordChannel.solo)
        return unmutedTracks.filter { !hasAudibleSolo || $0.solo }
    }

    static func includesChordTrack(in song: Song) -> Bool {
        guard !song.chords.isEmpty, !song.chordChannel.mute else { return false }
        let unmutedTracks = song.tracks.filter { !$0.mute }
        let hasAudibleSolo = unmutedTracks.contains(where: \.solo) || song.chordChannel.solo
        return !hasAudibleSolo || song.chordChannel.solo
    }
}
