import SwiftUI
import UniformTypeIdentifiers

struct TimelineView: View {
    @EnvironmentObject var store: ComposerStore
    @State private var selectedSection: UUID?
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("ARRANGEMENT").font(.caption).foregroundStyle(.secondary)
                Button("Section from selection") {
                    let chord = store.chord
                    store.mutate { $0.sections.append(SongSection(name: "Section \($0.sections.count + 1)", start: chord?.start ?? store.playhead, duration: chord?.duration ?? 4)) }
                }
                Spacer()
                Text("Loop").font(.caption)
                TextField("Start", value: Binding(get: { store.song.loopStart }, set: { value in store.mutate { $0.loopStart = max(0, min(value, $0.loopEnd - 0.25)) } }), format: .number).frame(width: 40)
                TextField("End", value: Binding(get: { store.song.loopEnd }, set: { value in store.mutate { $0.loopEnd = max($0.loopStart + 0.25, value) } }), format: .number).frame(width: 40)
            }.padding(.horizontal, 10)
            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: store.length * store.zoom, height: 105)
                    ForEach(0..<Int(store.length) + 1, id: \.self) { beat in
                        Rectangle().fill(Color.white.opacity(beat % 4 == 0 ? 0.16 : 0.055)).frame(width: 1, height: 105).offset(x: Double(beat) * store.zoom)
                        if beat % 4 == 0 { Text("\(beat / 4 + 1)").font(.caption2).offset(x: Double(beat) * store.zoom + 3) }
                    }
                    Rectangle().fill(Color.mint.opacity(0.12)).frame(width: (store.song.loopEnd - store.song.loopStart) * store.zoom, height: 15).offset(x: store.song.loopStart * store.zoom, y: 17)
                    ForEach(store.song.sections) { section in sectionView(section) }
                    ForEach(store.song.chords) { chord in clipView(chord) }
                    Rectangle().fill(.mint).frame(width: 2, height: 105).offset(x: store.playhead * store.zoom)
                }
                .contentShape(Rectangle()).onTapGesture { location in store.playhead = store.quantize(location.x / store.zoom) }
                .onDrop(of: [.text], isTargeted: nil) { providers, location in
                    guard let provider = providers.first else { return false }
                    provider.loadObject(ofClass: NSString.self) { object, _ in
                        guard let text = object as? String else { return }
                        let parts = text.split(separator: ":").map(String.init)
                        guard parts.count == 3, parts[0] == "chord", let root = Int(parts[1]), (0...11).contains(root), let quality = ChordQuality(rawValue: parts[2]) else { return }
                        DispatchQueue.main.async { store.mutate { song in
                            let start = store.quantize(location.x / store.zoom)
                            song.chords.append(ChordClip(root: root, quality: quality, start: start))
                            if !song.sections.contains(where: { start >= $0.start && start < $0.start + $0.duration }) { song.sections.append(SongSection(name: "Section \(song.sections.count + 1)", start: start, duration: 4)) }
                        } }
                    }; return true
                }
            }
        }.padding(.vertical, 8)
    }
    private func clipView(_ chord: ChordClip) -> some View {
        HStack {
            Text(MusicTheory.label(root: chord.root, quality: chord.quality, key: store.song.key, mode: store.song.mode, roman: store.roman)).padding(.leading, 7)
            Spacer(minLength: 0)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 7).gesture(DragGesture().onEnded { value in update(chord) { $0.duration = max(0.125, store.quantize(chord.duration + value.translation.width / store.zoom)) } })
        }.font(.caption).frame(width: max(20, chord.duration * store.zoom - 2), height: 42)
            .background(store.selectedChords.contains(chord.id) || store.selectedChord == chord.id ? Color.mint.opacity(0.6) : Color.teal.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 5))
            .offset(x: chord.start * store.zoom, y: 58)
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.shift) { if !store.selectedChords.insert(chord.id).inserted { store.selectedChords.remove(chord.id) } }
                else { store.selectedChords = [chord.id]; store.selectedSections = [] }
                store.selectedChord = chord.id; store.selectedNotes = []; store.preview(chord)
            }
            .gesture(DragGesture(minimumDistance: 5).onEnded { value in
                store.moveChords(chord, delta: value.translation.width / store.zoom, duplicate: NSEvent.modifierFlags.contains(.option))
            })
            .contextMenu { Button("Delete") { store.mutate { $0.chords.removeAll { $0.id == chord.id } } }; Button("Duplicate") { var copy = chord; copy.id = UUID(); copy.start += copy.duration; store.mutate { $0.chords.append(copy) } } }
    }
    private func update(_ chord: ChordClip, _ action: (inout ChordClip) -> Void) { store.mutate { song in if let index = song.chords.firstIndex(where: { $0.id == chord.id }) { action(&song.chords[index]) } } }
    private func sectionView(_ section: SongSection) -> some View {
        HStack {
            Text(section.name).font(.caption2); Spacer(minLength: 0)
            Rectangle().fill(.white.opacity(0.4)).frame(width: 7).gesture(DragGesture().onEnded { value in
                store.transformSection(section, duration: max(0.25, store.quantize(section.duration + value.translation.width / store.zoom)))
            })
        }.padding(.leading, 4).frame(width: max(25, section.duration * store.zoom - 2), height: 21).background(Color.indigo.opacity(store.selectedSections.contains(section.id) ? 0.9 : 0.5)).cornerRadius(3).offset(x: section.start * store.zoom, y: 34)
            .onTapGesture { if NSEvent.modifierFlags.contains(.shift) { if !store.selectedSections.insert(section.id).inserted { store.selectedSections.remove(section.id) } } else { store.selectedSections = [section.id]; store.selectedChords = []; store.selectedChord = nil; store.selectedNotes = [] } }
            .gesture(DragGesture(minimumDistance: 5).onEnded { value in store.transformSection(section, start: section.start + value.translation.width / store.zoom, duplicate: NSEvent.modifierFlags.contains(.option)) })
            .contextMenu { Button("Set loop to section") { store.mutate { $0.loopStart = section.start; $0.loopEnd = section.start + section.duration } }; Button("Delete section") { store.mutate { $0.sections.removeAll { $0.id == section.id } } } }
    }
}
