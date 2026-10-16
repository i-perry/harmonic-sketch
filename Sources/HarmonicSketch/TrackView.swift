import SwiftUI

struct TrackListView: View {
    @EnvironmentObject var store: ComposerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("TRACKS").font(.caption).foregroundStyle(.secondary); Spacer(); Button("+") { store.mutate { $0.tracks.append(Track(name: "Track \($0.tracks.count + 1)")) }; store.selectedTrack = store.song.tracks.count - 1 }.disabled(store.song.tracks.count >= 14).help("Up to 14 melody tracks plus the chord track") }
            ScrollView {
                ForEach(Array(store.song.tracks.enumerated()), id: \.element.id) { index, track in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Track", text: Binding(get: { store.song.tracks[index].name }, set: { name in store.mutate { $0.tracks[index].name = name } })).font(.headline)
                        HStack {
                            Button("M") { store.mutate { $0.tracks[index].mute.toggle() } }.tint(track.mute ? .orange : .gray)
                            Button("S") { store.mutate { $0.tracks[index].solo.toggle() } }.tint(track.solo ? .yellow : .gray)
                            Text("\(track.notes.count) notes").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        Slider(value: Binding(get: { store.song.tracks[index].volume }, set: { value in store.mutate { $0.tracks[index].volume = value } }), in: 0...1)
                        Picker("Sound", selection: Binding(get: { store.song.tracks[index].instrument }, set: { value in store.mutate { $0.tracks[index].instrument = value } })) {
                            Text("Grand piano").tag(0); Text("Electric piano").tag(4); Text("Organ").tag(16); Text("Guitar").tag(24); Text("Bass").tag(32); Text("Strings").tag(48); Text("Synth lead").tag(80); Text("Pad").tag(88)
                        }.labelsHidden()
                    }.padding(10).background(store.selectedTrack == index ? Color.mint.opacity(0.14) : Color.white.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 9))
                    .onTapGesture { store.selectedTrack = index; store.selectedNotes = []; store.selectedChord = nil }
                }
            }
            Button("Load SF2 / DLS…", action: store.loadSoundFont)
            Picker("MIDI out", selection: Binding(get: { store.audio.midi.destinationIndex ?? -1 }, set: { value in store.audio.midi.silence(); store.audio.midi.destinationIndex = value < 0 ? nil : value; store.objectWillChange.send() })) {
                Text("Disabled").tag(-1)
                ForEach(Array(store.audio.midi.destinations.enumerated()), id: \.offset) { index, name in Text(name).tag(index) }
            }
            Button("Refresh MIDI devices") { store.audio.midi.refresh(); store.objectWillChange.send() }
            Button("Remove Track") { guard store.song.tracks.count > 1 else { return }; store.mutate { $0.tracks.remove(at: store.selectedTrack) }; store.selectedTrack = 0 }.disabled(store.song.tracks.count <= 1)
        }.padding(12)
    }
}
