import SwiftUI

struct TrackListView: View {
    @EnvironmentObject var store: ComposerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("TRACKS").font(.caption).foregroundStyle(.secondary); Spacer(); Button("+") { store.mutate { $0.tracks.append(Track(name: "Track \($0.tracks.count + 1)")) }; store.selectedTrack = store.song.tracks.count - 1 }.disabled(store.song.tracks.count >= 14).help("Up to 14 melody tracks plus the chord track") }
            ChordChannelView()
            ScrollView {
                ForEach(store.song.tracks) { track in TrackRowView(track: track) }
            }
            Button("Load SF2 / DLS…", action: store.loadSoundFont)
            Picker("MIDI out", selection: Binding(get: { store.audio.midi.destinationIndex ?? -1 }, set: { value in store.audio.midi.silence(); store.audio.midi.destinationIndex = value < 0 ? nil : value; store.objectWillChange.send() })) {
                Text("Disabled").tag(-1)
                ForEach(Array(store.audio.midi.destinations.enumerated()), id: \.offset) { index, name in Text(name).tag(index) }
            }
            Button("Refresh MIDI devices") { store.audio.midi.refresh(); store.objectWillChange.send() }
            Button("Remove Track") { guard store.song.tracks.count > 1, store.song.tracks.indices.contains(store.selectedTrack) else { return }; store.mutate { $0.tracks.remove(at: store.selectedTrack) }; store.selectedTrack = 0 }.disabled(store.song.tracks.count <= 1 || !store.song.tracks.indices.contains(store.selectedTrack))
        }.padding(12)
    }

}
private struct TrackRowView: View {
    @EnvironmentObject private var store: ComposerStore
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Track", text: Binding(get: { current?.name ?? track.name }, set: { name in update { $0.name = name } })).font(.headline)
            HStack {
                Button("M") { update { $0.mute.toggle() } }.tint(track.mute ? .orange : .gray)
                Button("S") { update { $0.solo.toggle() } }.tint(track.solo ? .yellow : .gray)
                Text("\(track.notes.count) notes").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            Slider(value: Binding(get: { current?.volume ?? track.volume }, set: { value in update { $0.volume = value } }), in: 0...1)
            HStack { Text("L").font(.caption2); Slider(value: Binding(get: { current?.pan ?? track.pan ?? 0 }, set: { value in update { $0.pan = value } }), in: -1...1); Text("R").font(.caption2) }.help("Stereo pan")
            Picker("Sound", selection: Binding(get: { current?.instrument ?? track.instrument }, set: { value in update { $0.instrument = value } })) {
                Text("Grand piano").tag(0); Text("Electric piano").tag(4); Text("Organ").tag(16); Text("Guitar").tag(24); Text("Bass").tag(32); Text("Strings").tag(48); Text("Synth lead").tag(80); Text("Pad").tag(88)
            }.labelsHidden()
        }
        .padding(10)
        .background(store.song.tracks.firstIndex(where: { $0.id == track.id }) == store.selectedTrack ? Color.mint.opacity(0.14) : Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { if let index = store.song.tracks.firstIndex(where: { $0.id == track.id }) { store.selectedTrack = index; store.selectedNotes = []; store.selectedChord = nil; store.selectedChords = []; store.selectedSections = [] } }
    }

    private var current: Track? { store.song.tracks.first { $0.id == track.id } }

    private func update(_ change: (inout Track) -> Void) {
        store.mutate { song in
            guard let index = song.tracks.firstIndex(where: { $0.id == track.id }) else { return }
            change(&song.tracks[index])
        }
    }
}

struct ChordChannelView: View {
    @EnvironmentObject var store: ComposerStore
    private func change(_ action: (inout ChannelSettings) -> Void) { store.mutate { song in var settings = song.chordChannel; action(&settings); song.chordSettings = settings } }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Chords").font(.headline); Spacer()
                Button("M") { change { $0.mute.toggle() } }.tint(store.song.chordChannel.mute ? .orange : .gray)
                Button("S") { change { $0.solo.toggle() } }.tint(store.song.chordChannel.solo ? .yellow : .gray)
            }
            Slider(value: Binding(get: { store.song.chordChannel.volume }, set: { value in change { $0.volume = value } }), in: 0...1).help("Chord volume")
            HStack { Text("L").font(.caption2); Slider(value: Binding(get: { store.song.chordChannel.pan }, set: { value in change { $0.pan = value } }), in: -1...1); Text("R").font(.caption2) }.help("Chord pan")
            Picker("Chord sound", selection: Binding(get: { store.song.chordChannel.instrument }, set: { value in change { $0.instrument = value } })) {
                Text("Grand piano").tag(0); Text("Electric piano").tag(4); Text("Organ").tag(16); Text("Guitar").tag(24); Text("Strings").tag(48); Text("Pad").tag(88)
            }.labelsHidden()
        }.padding(10).background(Color.teal.opacity(0.13)).cornerRadius(9)
    }
}
