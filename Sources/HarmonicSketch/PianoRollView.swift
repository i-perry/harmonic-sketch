import SwiftUI
import AppKit

struct PianoRollView: View {
    @EnvironmentObject var store: ComposerStore
    @State private var rowHeight: Double = 17
    @State private var dragOrigin: CGPoint?
    private let upper = 127
    private let lower = 0
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("PIANO ROLL · \(store.track.name)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Velocity", isOn: $store.velocityEditing).toggleStyle(.button)
                Button("−") { store.zoom = max(15, store.zoom / 1.2) }
                Button("+") { store.zoom = min(120, store.zoom * 1.2) }
                Button("↕") { rowHeight = rowHeight == 17 ? 24 : 17 }
            }.padding(8)
            ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach((lower...upper).reversed(), id: \.self) { pitch in
                            Text(MusicTheory.name(pitch) + (pitch % 12 == 0 ? "\(pitch / 12 - 1)" : ""))
                                .font(.system(size: 9)).frame(width: 38, height: rowHeight)
                                .background([1,3,6,8,10].contains(pitch % 12) ? Color.black : Color.white.opacity(0.12)).id(pitch)
                        }
                    }
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in drawGrid(context: context, size: size) }
                            .frame(width: store.length * store.zoom, height: Double(upper - lower + 1) * rowHeight)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in if case .active(let location) = phase { store.cursorBeat = store.quantize(location.x / store.zoom) } }
                            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                                if abs(value.translation.width) < 4 && abs(value.translation.height) < 4 {
                                    store.addNote(pitch: upper - Int(value.location.y / rowHeight), start: value.location.x / store.zoom)
                                } else {
                                    let left = min(value.startLocation.x, value.location.x) / store.zoom
                                    let right = max(value.startLocation.x, value.location.x) / store.zoom
                                    let low = upper - Int(max(value.startLocation.y, value.location.y) / rowHeight)
                                    let high = upper - Int(min(value.startLocation.y, value.location.y) / rowHeight)
                                    store.selectedNotes = Set(store.track.notes.filter { $0.start >= left && $0.start <= right && $0.pitch >= low && $0.pitch <= high }.map(\.id))
                                }
                            })
                        ForEach(store.song.tracks.filter { $0.id != store.track.id }.flatMap(\.notes)) { note in
                            Rectangle().fill(Color.white.opacity(0.11)).frame(width: note.duration * store.zoom, height: rowHeight - 3).offset(x: note.start * store.zoom, y: Double(upper - note.pitch) * rowHeight + 1).allowsHitTesting(false)
                        }
                        ForEach(store.track.notes) { note in noteView(note) }
                        PlayheadMarker(position: store.position, zoom: store.zoom, height: Double(upper - lower + 1) * rowHeight)
                            .allowsHitTesting(false)
                        Rectangle().fill(Color.orange.opacity(0.3)).frame(width: 1, height: Double(upper - lower + 1) * rowHeight).offset(x: store.cursorBeat * store.zoom).allowsHitTesting(false)
                    }
                }
            }.onAppear { proxy.scrollTo(72, anchor: .top) }
            }
            Text("Click: add · double-click: delete · Shift: select · drag: move · Option-drag: copy · edges: length").font(.caption2).foregroundStyle(.secondary).padding(4)
        }
    }
    private func noteView(_ note: Note) -> some View {
        HStack(spacing: 0) {
            Color.white.opacity(0.3).frame(width: 5).gesture(DragGesture().onEnded { value in edit(note) { n in let end = n.start + n.duration; n.start = min(end - 0.125, store.quantize(note.start + value.translation.width / store.zoom)); n.duration = end - n.start } })
            Spacer(minLength: 0)
            if store.velocityEditing { Text("\(note.velocity)").font(.system(size: 8)) }
            Spacer(minLength: 0)
            Color.white.opacity(0.3).frame(width: 5).gesture(DragGesture().onEnded { value in edit(note) { $0.duration = max(0.125, store.quantize(note.duration + value.translation.width / store.zoom)) } })
        }.frame(width: max(12, note.duration * store.zoom - 1), height: rowHeight - 2)
            .background(store.selectedNotes.contains(note.id) ? Color.orange : Color.mint.opacity(0.35 + Double(note.velocity) / 200))
            .cornerRadius(3).offset(x: note.start * store.zoom, y: Double(upper - note.pitch) * rowHeight + 1)
            .onTapGesture(count: 2) { store.mutate { $0.tracks[store.selectedTrack].notes.removeAll { $0.id == note.id } } }
            .onTapGesture { if NSEvent.modifierFlags.contains(.shift) { if !store.selectedNotes.insert(note.id).inserted { store.selectedNotes.remove(note.id) } } else { store.selectedNotes = [note.id] }; store.selectedChord = nil; store.selectedChords = []; store.selectedSections = [] }
            .gesture(DragGesture(minimumDistance: 4).onEnded { value in move(note, value: value) })
            .contextMenu {
                Button("Add chord from selected notes") { store.chordFromNotes(rootNote: note, replacing: false) }
                Button("Set chord from selected notes") { store.chordFromNotes(rootNote: note, replacing: true) }
                Button("Delete") { store.mutate { $0.tracks[store.selectedTrack].notes.removeAll { $0.id == note.id } } }
            }
    }
    private func edit(_ note: Note, action: (inout Note) -> Void) { store.mutate { song in if let index = song.tracks[store.selectedTrack].notes.firstIndex(where: { $0.id == note.id }) { action(&song.tracks[store.selectedTrack].notes[index]) } } }
    private func move(_ note: Note, value: DragGesture.Value) {
        let selected = store.selectedNotes.contains(note.id) ? store.selectedNotes : [note.id]
        let duplicate = NSEvent.modifierFlags.contains(.option)
        let chosen = store.track.notes.filter { selected.contains($0.id) }
        let earliest = chosen.map(\.start).min() ?? 0
        let shift = max(-earliest, store.quantize(note.start + value.translation.width / store.zoom) - note.start)
        let pitchShift = -Int((value.translation.height / rowHeight).rounded())
        let minPitch = chosen.map(\.pitch).min() ?? 0
        let maxPitch = chosen.map(\.pitch).max() ?? 127
        let safePitchShift = min(127 - maxPitch, max(-minPitch, pitchShift))
        store.mutate { song in
            let originals = song.tracks[store.selectedTrack].notes
            for original in originals where selected.contains(original.id) {
                var result = original
                if store.velocityEditing { result.velocity = min(127, max(1, original.velocity - Int(value.translation.height))) }
                else { result.start = original.start + shift; result.pitch = original.pitch + safePitchShift }
                if duplicate { result.id = UUID(); song.tracks[store.selectedTrack].notes.append(result) }
                else if let index = song.tracks[store.selectedTrack].notes.firstIndex(where: { $0.id == original.id }) { song.tracks[store.selectedTrack].notes[index] = result }
            }
        }
        if let result = store.track.notes.first(where: { $0.id == note.id }) { store.audition(result.pitch, velocity: result.velocity) }
    }
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        for pitch in lower...upper {
            let y = Double(upper - pitch) * rowHeight
            let inKey = store.song.mode.intervals.contains(MusicTheory.pc(pitch - store.song.key))
            context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight - 1)), with: .color(inKey ? .blue.opacity(0.10) : .black.opacity(0.12)))
            for chord in store.song.chords {
                let root = MusicTheory.pc(pitch) == chord.root
                let included = chord.pitches.contains { MusicTheory.pc($0) == MusicTheory.pc(pitch) }
                if included { context.fill(Path(CGRect(x: chord.start * store.zoom, y: y, width: chord.duration * store.zoom, height: rowHeight - 1)), with: .color(root ? .mint.opacity(0.22) : .purple.opacity(0.16))) }
            }
        }
        for beat in 0...Int(store.length * 2) {
            let x = Double(beat) / 2 * store.zoom
            context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.white.opacity(beat % 8 == 0 ? 0.22 : 0.06)))
        }
    }
}
