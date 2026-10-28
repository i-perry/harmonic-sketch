import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class PlaybackPosition: ObservableObject {
    @Published var beat: Double = 0
}

@MainActor final class ComposerStore: ObservableObject {
    @Published var song = Song()
    @Published var selectedTrack = 0
    @Published var selectedChord: UUID?
    @Published var selectedChords: Set<UUID> = []
    @Published var selectedSections: Set<UUID> = []
    @Published var selectedNativeSectionPath: KlimperSectionPath?
    @Published var cursorBeat: Double = 0
    @Published var selectedNotes: Set<UUID> = []
    var playhead: Double {
        get { position.beat }
        set { position.beat = newValue }
    }
    @Published var playing = false
    @Published var looping = true
    @Published var snap: Double = 0.5
    @Published var roman = false
    @Published var paletteKey = 0
    @Published var paletteMode: ScaleMode = .major
    @Published var followKey = true
    @Published var relation: RelationMode = .tonal
    @Published var velocityEditing = false
    @Published var error: String?
    @Published var zoom: Double = 42
    @Published var previewOctave = 0
    @Published var strum: Double = 0
    @Published var previewVelocity = 90
    @Published private(set) var revision = 0
    @Published private(set) var documentURL: URL?
    let position = PlaybackPosition()
    lazy var audio: PlaybackEngine = {
        let engine = PlaybackEngine()
        engine.onBeat = { [weak self] beat in self?.position.beat = beat }
        engine.onError = { [weak self] message in self?.error = message; self?.playing = false }
        engine.onStopped = { [weak self] in self?.playing = false }
        engine.midi.onError = { [weak self] message in self?.error = message }
        if let midiError = engine.midi.lastError { error = midiError }
        return engine
    }()
    private var undoStack: [Song] = []
    private var redoStack: [Song] = []
    private var clipboard: [Note] = []
    private var chordClipboard: [ChordClip] = []
    private var sectionClipboard: [SongSection] = []
    private var sectionTrackClipboard: [Track] = []
    private var savedSong = Song()
    private var closeObserver: NSObjectProtocol?
    var track: Track { guard !song.tracks.isEmpty else { return Track(name: "No track") }; return song.tracks[min(max(0, selectedTrack), song.tracks.count - 1)] }
    var chord: ChordClip? { song.chords.first { $0.id == selectedChord } }
    var length: Double { max(32, song.loopEnd, (song.chords.map { $0.start + $0.duration }.max() ?? 0) + 4, (song.tracks.flatMap(\.notes).map { $0.start + $0.duration }.max() ?? 0) + 4) }
    init() {
        savedSong = song
    }
    var dirty: Bool { song != savedSong }
    func confirmDiscard() -> Bool {
        guard dirty else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to \(song.title)?"; alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard")
        let result = alert.runModal()
        if result == .alertFirstButtonReturn { save(); return !dirty }
        return result == .alertThirdButtonReturn
    }
    func confirmClose() -> Bool { guard confirmDiscard() else { return false }; audio.stop(); savedSong = song; return true }
    func mutate(synchronizesNativeSections: Bool = false, _ change: (inout Song) -> Void) {
        let previous = song
        undoStack.append(song); redoStack.removeAll(); change(&song)
        song.recordSectionProjectionEdit(comparedTo: previous, nativeFieldsSynchronized: synchronizesNativeSections)
        revision += 1
    }
    func quantize(_ beat: Double) -> Double { guard beat.isFinite else { return 0 }; return min(16380, max(0, snap == 0 ? beat : (beat / snap).rounded() * snap)) }
    func undo() { guard let old = undoStack.popLast() else { return }; redoStack.append(song); song = old; revision += 1 }
    func redo() { guard let next = redoStack.popLast() else { return }; undoStack.append(song); song = next; revision += 1 }
    func addChord(root: Int, quality: ChordQuality) {
        let start = song.chords.map { $0.start + $0.duration }.max() ?? 0
        let clip = ChordClip(root: root, quality: quality, start: start)
        mutate { song in song.chords.append(clip); song.sections.append(SongSection(name: "Section \(song.sections.count + 1)", start: clip.start, duration: clip.duration)) }; selectedChord = clip.id; selectedChords = [clip.id]; preview(clip)
    }
    func preview(_ clip: ChordClip) {
        do { try audio.prepare(song); audio.preview(clip.pitches.map { min(127, max(0, $0 + previewOctave * 12)) }, velocity: previewVelocity, strum: strum, tempo: song.tempo) }
        catch { self.error = error.localizedDescription }
    }
    func togglePlay() {
        if playing { audio.stop(); playing = false; return }
        do {
            try audio.play(songProvider: { [weak self] in self?.song ?? Song() }, from: playhead >= song.loopEnd && looping ? song.loopStart : playhead, looping: { [weak self] in self?.looping ?? false })
            playing = true
        }
        catch { self.error = error.localizedDescription }
    }
    func stop() { audio.stop(); playing = false; playhead = song.loopStart }
    func addNote(pitch: Int, start: Double) {
        let note = Note(pitch: min(127, max(0, pitch)), start: quantize(start), duration: max(0.25, snap))
        mutate { $0.tracks[selectedTrack].notes.append(note) }; selectedNotes = [note.id]
        do { try audio.prepare(song); audio.preview([pitch]) } catch { self.error = error.localizedDescription }
    }
    func deleteSelection() {
        mutate { song in
            if !selectedNotes.isEmpty { song.tracks[selectedTrack].notes.removeAll { selectedNotes.contains($0.id) } }
            else {
                let ranges = song.sections.filter { selectedSections.contains($0.id) }
                song.chords.removeAll { chord in selectedChords.contains(chord.id) || chord.id == selectedChord || ranges.contains(where: { range in chord.start >= range.start && chord.start < range.start + range.duration }) }
                for index in song.tracks.indices { song.tracks[index].notes.removeAll { note in ranges.contains { note.start >= $0.start && note.start < $0.start + $0.duration } } }
                song.sections.removeAll { selectedSections.contains($0.id) }
            }
        }; selectedNotes = []; selectedChord = nil; selectedChords = []; selectedSections = []
    }
    func copy() {
        clipboard = track.notes.filter { selectedNotes.contains($0.id) }
        sectionClipboard = song.sections.filter { selectedSections.contains($0.id) }
        sectionTrackClipboard = song.tracks.map { track in var result = track; result.notes = track.notes.filter { note in sectionClipboard.contains { note.start >= $0.start && note.start < $0.start + $0.duration } }; return result }
        chordClipboard = song.chords.filter { chord in selectedChords.contains(chord.id) || chord.id == selectedChord || sectionClipboard.contains { chord.start >= $0.start && chord.start < $0.start + $0.duration } }
    }
    func cut() { copy(); deleteSelection() }
    func paste() {
        if !chordClipboard.isEmpty || !sectionClipboard.isEmpty {
            let first = (chordClipboard.map(\.start) + sectionClipboard.map(\.start)).min() ?? 0
            let delta = quantize(cursorBeat) - first
            let chords = chordClipboard.map { value -> ChordClip in var result = value; result.id = UUID(); result.start += delta; return result }
            let sections = sectionClipboard.map { value -> SongSection in var result = value; result.id = UUID(); result.start += delta; return result }
            mutate { song in
                song.chords.append(contentsOf: chords); song.sections.append(contentsOf: sections)
                for fragment in sectionTrackClipboard {
                    guard let index = song.tracks.firstIndex(where: { $0.id == fragment.id }) else { continue }
                    song.tracks[index].notes.append(contentsOf: fragment.notes.map { note in var result = note; result.id = UUID(); result.start += delta; return result })
                }
            }; selectedChords = Set(chords.map(\.id)); selectedSections = Set(sections.map(\.id)); selectedChord = chords.first?.id
            return
        }
        guard let first = clipboard.map(\.start).min() else { return }
        let notes = clipboard.map { note -> Note in var result = note; result.id = UUID(); result.start = quantize(cursorBeat + note.start - first); return result }
        mutate { $0.tracks[selectedTrack].notes.append(contentsOf: notes) }; selectedNotes = Set(notes.map(\.id))
    }
    func transpose(_ semitones: Int) { mutate { song in for index in song.tracks[selectedTrack].notes.indices where selectedNotes.contains(song.tracks[selectedTrack].notes[index].id) { song.tracks[selectedTrack].notes[index].pitch = min(127, max(0, song.tracks[selectedTrack].notes[index].pitch + semitones)) } } }
    func selectAll() { selectedNotes = Set(track.notes.map(\.id)) }
    func audition(_ pitch: Int, velocity: Int) {
        do { try audio.prepare(song); audio.preview([pitch], velocity: velocity) } catch { self.error = error.localizedDescription }
    }
    func chordFromNotes(rootNote: Note, replacing: Bool) {
        let notes = track.notes.filter { selectedNotes.contains($0.id) || $0.id == rootNote.id }
        let start = notes.map(\.start).min() ?? rootNote.start
        let end = notes.map { $0.start + $0.duration }.max() ?? start + 1
        let clip = ChordClip(root: MusicTheory.pc(rootNote.pitch), quality: .major, start: start, duration: max(0.125, end - start), customPitches: notes.map(\.pitch).sorted())
        mutate { song in
            if replacing { song.chords.removeAll { $0.start < end && $0.start + $0.duration > start } }
            song.chords.append(clip)
        }; selectedChord = clip.id; selectedChords = [clip.id]; selectedNotes = []
    }
    func transformSection(_ section: SongSection, start: Double? = nil, duration: Double? = nil, duplicate: Bool = false) {
        let newStart = quantize(start ?? section.start)
        let newDuration = max(0.125, duration ?? section.duration)
        let ratio = newDuration / section.duration
        mutate { song in
            let contained = song.chords.filter { $0.start >= section.start && $0.start < section.start + section.duration }
            for chord in contained {
                var result = chord
                result.start = newStart + (chord.start - section.start) * ratio
                result.duration = max(0.125, chord.duration * ratio)
                if duplicate { result.id = UUID(); song.chords.append(result) }
                else if let index = song.chords.firstIndex(where: { $0.id == chord.id }) { song.chords[index] = result }
            }
            for index in song.tracks.indices {
                let notes = song.tracks[index].notes.filter { $0.start >= section.start && $0.start < section.start + section.duration }
                for note in notes {
                    var result = note; result.start = newStart + (note.start - section.start) * ratio; result.duration = max(0.125, note.duration * ratio)
                    if duplicate { result.id = UUID(); song.tracks[index].notes.append(result) }
                    else if let noteIndex = song.tracks[index].notes.firstIndex(where: { $0.id == note.id }) { song.tracks[index].notes[noteIndex] = result }
                }
            }
            var result = section; result.start = newStart; result.duration = newDuration
            if duplicate { result.id = UUID(); song.sections.append(result) }
            else if let index = song.sections.firstIndex(where: { $0.id == section.id }) { song.sections[index] = result }
        }
    }
    func renameSection(_ section: SongSection, name: String) {
        guard let index = song.sections.firstIndex(where: { $0.id == section.id }) else { return }
        if let path = section.nativePath {
            renameNativeSection(at: path, name: name)
        } else {
            mutate { $0.sections[index].name = name }
        }
    }
    func renameNativeSection(at path: KlimperSectionPath, name: String) {
        guard let nativeSections = song.nativeSections,
              (try? path.resolve(in: nativeSections)) != nil else { return }
        let canSynchronize = song.nativeSectionFidelity == .preserved
        mutate(synchronizesNativeSections: canSynchronize) { song in
            guard var sections = song.nativeSections, path.setName(name, in: &sections) else { return }
            song.nativeSections = sections
            if let index = song.sections.firstIndex(where: { $0.nativePath == path }) {
                song.sections[index].name = name
            }
        }
    }
    func selectNativeSection(at path: KlimperSectionPath) {
        selectedNativeSectionPath = path
        selectedChords = []
        selectedChord = nil
        selectedNotes = []
        guard let projection = song.sections.first(where: { $0.nativePath == path }) else {
            selectedSections = []
            return
        }
        selectedSections = [projection.id]
        cursorBeat = projection.start
    }
    func moveChords(_ chord: ChordClip, delta: Double, duplicate: Bool) {
        let ids = selectedChords.contains(chord.id) ? selectedChords : [chord.id]
        let chosen = song.chords.filter { ids.contains($0.id) }
        let earliest = chosen.map(\.start).min() ?? 0
        let shift = max(-earliest, quantize(chord.start + delta) - chord.start)
        mutate { song in
            for item in chosen {
                var copy = item; copy.start += shift
                if duplicate { copy.id = UUID(); song.chords.append(copy) }
                else if let index = song.chords.firstIndex(where: { $0.id == item.id }) { song.chords[index] = copy }
            }
        }
    }
    func newProject() { guard confirmDiscard() else { return }; stop(); mutate { $0 = Song() }; savedSong = song; documentURL = nil; selectedTrack = 0; selectedNotes = []; selectedChord = nil; selectedChords = []; selectedSections = []; selectedNativeSectionPath = nil }
    func open() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "hsketch") ?? .json, .json]
        if panel.runModal() == .OK, let url = panel.url {
            do { let loaded = try ProjectPersistence.load(from: url); stop(); mutate { $0 = loaded }; savedSong = song; documentURL = url; selectedTrack = 0; selectedNotes = []; selectedChord = nil; selectedChords = []; selectedSections = []; selectedNativeSectionPath = nil }
            catch { self.error = error.localizedDescription }
        }
    }
    func importKlimper() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "klp") ?? .json, .json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try KlimperImporter.loadWithWarnings(from: url)
                var importedSong = imported.song
                if importedSong.tracks.isEmpty { importedSong.tracks = [Track(name: "Melody")] }
                stop(); mutate { $0 = importedSong }
                documentURL = nil; selectedTrack = 0; selectedNotes = []; selectedChords = []; selectedSections = []; selectedChord = nil; selectedNativeSectionPath = nil
                if !imported.warnings.isEmpty { let alert = NSAlert(); alert.messageText = "Project imported with differences"; alert.informativeText = imported.warnings.joined(separator: "\n"); alert.runModal() }
            } catch { self.error = error.localizedDescription }
        }
    }
    func save() {
        if let documentURL { do { try ProjectPersistence.save(song, to: documentURL); savedSong = song } catch { self.error = error.localizedDescription }; return }
        saveAs()
    }
    func saveAs() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = song.title + ".hsketch"
        if panel.runModal() == .OK, let url = panel.url { do { try ProjectPersistence.save(song, to: url); documentURL = url; savedSong = song } catch { self.error = error.localizedDescription } }
    }
    func exportMIDI() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = song.title + ".mid"
        if panel.runModal() == .OK, let url = panel.url { do { try MIDIExporter.data(for: song).write(to: url, options: .atomic) } catch { self.error = error.localizedDescription } }
    }
    func midiDragProvider() -> NSItemProvider {
        do {
            var export = song
            if !selectedNotes.isEmpty { export.tracks = [track]; export.tracks[0].notes = track.notes.filter { selectedNotes.contains($0.id) }; export.chords = [] }
            else if !selectedSections.isEmpty {
                let ranges = song.sections.filter { selectedSections.contains($0.id) }
                export.chords = song.chords.filter { clip in ranges.contains { clip.start >= $0.start && clip.start < $0.start + $0.duration } }
                export.tracks = song.tracks.map { track in var result = track; result.notes = track.notes.filter { note in ranges.contains { note.start >= $0.start && note.start < $0.start + $0.duration } }; return result }
            }
            else if !selectedChords.isEmpty { export.chords = song.chords.filter { selectedChords.contains($0.id) }; export.tracks = [] }
            else if let chord { export.chords = [chord]; export.tracks = [] }
            else { export.tracks = [track]; export.chords = [] }
            let origin = (export.chords.map(\.start) + export.tracks.flatMap(\.notes).map(\.start)).min() ?? 0
            for index in export.chords.indices { export.chords[index].start -= origin }
            for index in export.tracks.indices { for noteIndex in export.tracks[index].notes.indices { export.tracks[index].notes[noteIndex].start -= origin } }
            export.sections = []; export.loopStart = 0; export.loopEnd = max(0.25, export.loopEnd - origin)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("HarmonicSketch-\(UUID().uuidString).mid")
            try MIDIExporter.data(for: export).write(to: url, options: .atomic)
            return NSItemProvider(contentsOf: url) ?? NSItemProvider()
        } catch { self.error = error.localizedDescription; return NSItemProvider() }
    }
    func loadSoundFont() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "sf2") ?? .data, UTType(filenameExtension: "dls") ?? .data]
        if panel.runModal() == .OK, let url = panel.url { do { try audio.loadSoundFont(url, song: song) } catch { self.error = error.localizedDescription } }
    }
}
