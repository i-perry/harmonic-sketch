import SwiftUI

struct PaletteView: View {
    @EnvironmentObject var store: ComposerStore
    @State private var matchNotes = false
    private var key: Int { store.followKey ? store.song.key : store.paletteKey }
    private var mode: ScaleMode { store.followKey ? store.song.mode : store.paletteMode }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("CHORD PALETTE").font(.caption).foregroundStyle(.secondary)
                Spacer(); Toggle("Roman", isOn: $store.roman).toggleStyle(.button)
            }
            HStack {
                Toggle("Home", isOn: $store.followKey).toggleStyle(.button)
                Button("‹") { store.paletteKey = MusicTheory.pc(key - 7); store.paletteMode = mode; store.followKey = false }
                Picker("Borrow", selection: $store.paletteKey) { ForEach(0..<12) { Text(MusicTheory.names[$0]).tag($0) } }.disabled(store.followKey)
                Button("›") { store.paletteKey = MusicTheory.pc(key + 7); store.paletteMode = mode; store.followKey = false }
                Picker("Mode", selection: $store.paletteMode) { ForEach(ScaleMode.allCases, id: \.self) { Text($0.label).tag($0) } }.disabled(store.followKey)
            }.labelsHidden()
            Picker("Relations", selection: $store.relation) { ForEach(RelationMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Toggle("Match selected melody notes", isOn: $matchNotes).font(.caption)
            ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7) { degree in
                        let root = MusicTheory.pc(key + mode.intervals[degree])
                        VStack(spacing: 8) {
                            ForEach(qualities(for: root).reversed(), id: \.self) { quality in
                                chordButton(root: root, quality: quality).id("\(degree)-\(quality.rawValue)")
                            }
                            Text(store.roman ? ["I", "II", "III", "IV", "V", "VI", "VII"][degree] : MusicTheory.name(root)).font(.headline).foregroundStyle(.secondary)
                        }
                    }
                }.padding(8)
            }.onAppear { proxy.scrollTo("0-major", anchor: .center) }
            }
            HStack { Text("Click to hear · double-click or drag to arrange").font(.caption2).foregroundStyle(.secondary); Spacer() }
            DisclosureGroup("Preview settings") {
                HStack { Stepper("Octave \(store.previewOctave)", value: $store.previewOctave, in: -2...2); Slider(value: $store.strum, in: 0...0.12) { Text("Strum") }; Text("Strum") }
                HStack { Text("Velocity"); Slider(value: Binding(get: { Double(store.previewVelocity) }, set: { store.previewVelocity = Int($0) }), in: 1...127) }
            }.font(.caption)
        }.padding(12)
    }
    private func qualities(for root: Int) -> [ChordQuality] {
        let shared: [ChordQuality] = [.power, .sus2, .sus4, .sevenSus4]
        if MusicTheory.inScale(root: root, quality: .major, key: key, mode: mode) { return shared + [.major, .augmented, .sixth, .seventh, .majorSeventh, .ninth, .majorNinth, .eleventh] }
        if MusicTheory.inScale(root: root, quality: .minor, key: key, mode: mode) { return shared + [.minor, .minorSixth, .minorSeventh, .minorNinth] }
        return shared + [.diminished, .diminishedSeventh, .halfDiminished]
    }
    private func chordButton(root: Int, quality: ChordQuality) -> some View {
        let inKey = MusicTheory.inScale(root: root, quality: quality, key: store.song.key, mode: store.song.mode)
        let majorFamily: Set<ChordQuality> = [.major, .sixth, .seventh, .majorSeventh, .ninth, .majorNinth, .eleventh]
        let minorFamily: Set<ChordQuality> = [.minor, .minorSixth, .minorSeventh, .minorNinth]
        let color: Color = majorFamily.contains(quality) ? .mint : minorFamily.contains(quality) ? .purple : .gray
        let relation = MusicTheory.relation(from: store.chord, root: root, quality: quality, mode: store.relation)
        let chosen = store.track.notes.filter { store.selectedNotes.contains($0.id) }
        let pitches = Set(quality.intervals.map { MusicTheory.pc(root + $0) })
        let matches = !matchNotes || chosen.allSatisfy { pitches.contains(MusicTheory.pc($0.pitch)) }
        return Text(MusicTheory.label(root: root, quality: quality, key: store.song.key, mode: store.song.mode, roman: store.roman))
            .font(.system(size: 10, weight: .semibold)).minimumScaleFactor(0.6).frame(width: 42, height: 42)
            .background(Circle().fill(inKey ? color.opacity(0.30) : Color.clear))
            .overlay(Circle().stroke(color.opacity(0.55 + relation * 0.45), lineWidth: relation > 0.65 ? 3 : 1))
            .foregroundStyle(color).opacity(matches ? 1 : 0.2)
            .onTapGesture(count: 2) { store.addChord(root: root, quality: quality) }
            .onTapGesture { store.preview(ChordClip(root: root, quality: quality, start: 0)) }
            .onDrag { NSItemProvider(object: "chord:\(root):\(quality.rawValue)" as NSString) }
            .contextMenu { Button("Add to progression") { store.addChord(root: root, quality: quality) } }
    }
}
struct VoicingView: View {
    @EnvironmentObject var store: ComposerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("VOICING").font(.caption).foregroundStyle(.secondary); Spacer(); Text("Select a chord in the timeline").font(.caption2).foregroundStyle(.secondary) }
            if let chord = store.chord {
                HStack {
                    Text(MusicTheory.name(chord.root) + chord.quality.symbol).font(.title2)
                    Button("Inversion −") { change(chord) { $0.inversion = max(0, $0.inversion - 1); $0.customPitches = nil } }
                    Button("Inversion +") { change(chord) { $0.inversion = min($0.quality.intervals.count, $0.inversion + 1); $0.customPitches = nil } }
                    Button("Hear") { store.preview(chord) }
                }
                HStack {
                    ForEach(Array(chord.pitches.enumerated()), id: \.offset) { index, pitch in
                        VStack { Text(MusicTheory.name(pitch) + "\(pitch / 12 - 1)").font(.caption); Stepper("", value: Binding(get: { pitch }, set: { value in change(chord) { var pitches = $0.pitches; pitches[index] = value; $0.customPitches = pitches } }), in: 0...127).labelsHidden() }
                    }
                    Button("+ tone") { change(chord) { $0.customPitches = $0.pitches + [($0.pitches.last ?? 60) + 3] } }
                }
            } else { Text("Arrange chords, then edit individual voices here.").foregroundStyle(.secondary).frame(height: 65) }
        }.padding(12)
    }
    private func change(_ chord: ChordClip, _ action: (inout ChordClip) -> Void) {
        store.mutate { song in if let index = song.chords.firstIndex(where: { $0.id == chord.id }) { action(&song.chords[index]) } }
    }
}
