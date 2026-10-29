import SwiftUI

@main struct HarmonicSketchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = ComposerStore()
    var body: some Scene {
        WindowGroup("Harmonic Sketch") { ComposerView().environmentObject(store).frame(minWidth: 1100, minHeight: 720).preferredColorScheme(.dark).background(WindowCloseGuard(store: store)).onAppear { delegate.store = store } }
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New Project", action: store.newProject).keyboardShortcut("n")
                    Button("Open…", action: store.open).keyboardShortcut("o")
                    Button("Import Klimper Project…", action: store.importKlimper)
                    Button("Save", action: store.save).keyboardShortcut("s")
                    Button("Save As…", action: store.saveAs).keyboardShortcut("s", modifiers: [.command, .shift])
                    Button("Export MIDI…", action: store.exportMIDI).keyboardShortcut("e")
                    Button("Load SoundFont…", action: store.loadSoundFont)
                }
                CommandGroup(replacing: .undoRedo) {
                    Button("Undo", action: store.undo).keyboardShortcut("z")
                    Button("Redo", action: store.redo).keyboardShortcut("z", modifiers: [.command, .shift])
                }
                CommandGroup(replacing: .pasteboard) {
                    Button("Cut", action: store.cut).keyboardShortcut("x")
                    Button("Copy", action: store.copy).keyboardShortcut("c")
                    Button("Paste", action: store.paste).keyboardShortcut("v")
                    Button("Select All Notes", action: store.selectAll).keyboardShortcut("a")
                    Button("Delete Selection", action: store.deleteSelection).keyboardShortcut(.delete, modifiers: [])
                }
                CommandMenu("Playback") {
                    Button("Play / Pause", action: store.togglePlay).keyboardShortcut(.space, modifiers: [])
                    Button("Stop", action: store.stop).keyboardShortcut(".", modifiers: [])
                    Button("Transpose Up") { store.transpose(1) }.keyboardShortcut(.upArrow, modifiers: [])
                    Button("Transpose Down") { store.transpose(-1) }.keyboardShortcut(.downArrow, modifiers: [])
                    Button("Octave Up") { store.transpose(12) }.keyboardShortcut(.upArrow, modifiers: [.shift])
                    Button("Octave Down") { store.transpose(-12) }.keyboardShortcut(.downArrow, modifiers: [.shift])
                }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: ComposerStore?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { store?.confirmDiscard() == false ? .terminateCancel : .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
struct WindowCloseGuard: NSViewRepresentable {
    let store: ComposerStore
    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.delegate = context.coordinator }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { }
    @MainActor final class Coordinator: NSObject, NSWindowDelegate {
        let store: ComposerStore
        init(store: ComposerStore) { self.store = store }
        func windowShouldClose(_ sender: NSWindow) -> Bool { store.confirmClose() }
    }
}
struct ComposerView: View {
    @EnvironmentObject var store: ComposerStore
    var body: some View {
        VStack(spacing: 0) {
            TransportView().padding(12).background(Color.black.opacity(0.25))
            Divider()
            HSplitView {
                TrackListView().frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
                VStack(spacing: 0) {
                    TimelineView().frame(height: 155)
                    Divider()
                    HSplitView {
                        PaletteView().frame(minWidth: 390, idealWidth: 470)
                        VStack(spacing: 0) { VoicingView(); Divider(); PianoRollView() }.frame(minWidth: 430)
                    }
                }
            }
            Divider()
            HStack { TextField("Project title", text: Binding(get: { store.song.title }, set: { value in store.mutate { $0.title = value.isEmpty ? "Untitled sketch" : value } })).textFieldStyle(.plain).frame(width: 200); if store.dirty { Text("•") }; Spacer(); Text("\(store.track.notes.count) notes · \(store.song.chords.count) chords"); Text(MusicTheory.name(store.song.key) + " " + store.song.mode.label).foregroundStyle(.secondary) }.font(.caption).padding(7)
        }
        .alert("Unable to complete operation", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct TransportView: View {
    @EnvironmentObject var store: ComposerStore
    var body: some View {
        HStack(spacing: 14) {
            Text("HARMONIC SKETCH").font(.system(.headline, design: .rounded)).tracking(2)
            Button(action: store.stop) { Image(systemName: "stop.fill") }
            Button(action: store.togglePlay) { Image(systemName: store.playing ? "pause.fill" : "play.fill") }.tint(.mint)
            Toggle("Loop", isOn: $store.looping).toggleStyle(.button)
            TextField("BPM", value: Binding(get: { store.song.tempo }, set: { value in store.mutate { $0.tempo = min(300, max(20, value)) } }), format: .number).frame(width: 48)
            Text("BPM").foregroundStyle(.secondary)
            Picker("Key", selection: Binding(get: { store.song.key }, set: { value in store.mutate { $0.key = value } })) { ForEach(0..<12) { Text(MusicTheory.names[$0]).tag($0) } }.frame(width: 90)
            Picker("Mode", selection: Binding(get: { store.song.mode }, set: { value in store.mutate { $0.mode = value } })) { ForEach(ScaleMode.allCases, id: \.self) { Text($0.label).tag($0) } }.frame(width: 170)
            Picker("Snap", selection: $store.snap) { Text("Off").tag(0.0); Text("1/4").tag(1.0); Text("1/8").tag(0.5); Text("1/16").tag(0.25); Text("1/32").tag(0.125); Text("Triplet").tag(1.0/3) }.frame(width: 110)
            Spacer()
            PlaybackPositionReadout(position: store.position)
            Button("MIDI…", action: store.exportMIDI)
            Text("Drag MIDI").padding(5).background(Color.mint.opacity(0.2)).cornerRadius(4).onDrag { store.midiDragProvider() }.help("Drag selected notes or chord; otherwise the selected track")
        }.controlSize(.small)
    }
}
