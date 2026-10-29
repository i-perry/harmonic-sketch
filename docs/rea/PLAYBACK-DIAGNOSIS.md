# Play responsiveness diagnosis — 2026-10-16

## Established evidence

The Play action on the disposable `dev.harmonicsketch.playbackqa` app timed out and later accessibility reads timed out. This establishes an observable responsiveness failure; it does not identify its source. The 30 Hz display throttle did not resolve that reproduction. Passing clock and scheduling unit tests do not test SwiftUI responsiveness.

A new read-only shell sample obtained with `sample 36804 2 1 -file /private/tmp/klimper-sol-sample.txt` resolved deeper stacks than the prior Activity Monitor excerpts. Process identity was confirmed by `ps` before sampling: `/Users/isaac/Projects/KlimperClone/dist/Harmonic Sketch.app/Contents/MacOS/HarmonicSketch`. Its bundle identifier is `dev.harmonicsketch.composer`, launch time 17:49:59, binary UUID `E4D2BA9E-01E2-3776-855D-56CB0628677C`. This is a separate already-running clone process, not the exited isolated QA process. No process was terminated.

All 957 main-thread samples are inside the AppKit event-loop call chain. They resolve into SwiftUI graph transaction flushing, AttributeGraph updates, NSHostingView layout and size measurement. Source frames include PianoRollView body/grid drawing and ComposerStore getters. The capture contains no PlaybackEngine.advancePlayback frame, no timer callback frame, and no blocking AVFoundation frame. This localizes the sampled saturation to UI work; it does not prove which published state or layout starts that work.

The process snapshot also found the other clone PID 12443 at approximately 99% CPU. Both existing processes were left untouched. The isolated disposable PID 61559 was absent; Luna independently confirmed it had disappeared from Activity Monitor.

## Ranked, falsifiable hypotheses

1. Playback position publication invalidates the complete composer often enough to starve input. Prediction: suppressing only the `audio.onBeat` assignment preserves engine operation and restores main-loop heartbeats and CUA responsiveness.
2. A state/layout feedback loop runs after Play. One concrete candidate is PianoRollView's unconditional `onContinuousHover` assignment to `@Published cursorBeat`, including repeated identical quantized values. Prediction: suppressing only hover writes or guarding equality removes the saturation while position publication remains enabled. The current stack sample does not directly contain the hover callback, so this remains a candidate.
3. Audio setup or scheduling blocks independently of SwiftUI. Prediction: a focused harness calling the real PlaybackEngine.play and pumping its run loop fails its timing assertion. A healthy harness falsifies audio-only explanations but cannot prove the full app is responsive.

## Required discriminating loop

Luna is implementing temporary diagnostic environment gates for beat and hover publication, an independent background heartbeat paired with a main-loop heartbeat, and an engine-only harness. The comparison must run the same disposable song through baseline, beat-suppressed, and hover-suppressed builds separately. A main-loop heartbeat stall with continued background heartbeats is the exact responsiveness signal, independent of accessibility timeouts. Neither candidate above is confirmed and no production fix is prescribed yet.

The existing `qa/session-snapshot-2026-10-16.hsketch` must remain unchanged. Its preservation hash from the QA run is `0a78ba8db1e1eeeb4ec45211b2e7fc3fba228ee739b0e5d1ce5438a3f5527bd1`.

## Engine harness result

Luna ran `HSK_DIAG_ENGINE_SMOKE=1 CLANG_MODULE_CACHE_PATH=/private/tmp/klimper-swift-clang-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/klimper-swift-module-cache swift test --filter PlaybackTimelineTests/testDiagnosticPlaybackEngineStartsAndTicksWhenRequested`. The test passed in 0.251 seconds (1 test, 0 failures; build 3.83 seconds). It calls the real PlaybackEngine.play, pumps RunLoop.main and asserts at least three onBeat callbacks. The engine and its timer progress when the run loop is serviced. This falsifies an unconditional audio-start deadlock in this environment; it does not verify the composer UI or audible output.

## Full-app heartbeat baseline

Luna's disposable diagnostic baseline PID 2148 used the default empty song (0 notes/chords, 120 BPM). Before Play its main-loop ping arrived approximately every 0.5 seconds. Play returned through CUA in approximately 0.06 seconds, and the log recorded both toggle_play_enter and toggle_play_return_playing. Beat callbacks arrived approximately every 65 milliseconds, while main-loop pings continued every 0.5 seconds. Activity Monitor showed approximately 96% CPU; a later accessibility snapshot timed out for 30 seconds even though main-loop pings continued.

This **falsifies an unconditional main-run-loop deadlock** for that run. Accessibility timeout and high CPU can coexist with a serviced run loop. The empty-song baseline is not the original one-note/one-chord reproduction and must not be substituted for it in final verification. Luna force-quit only the positively identified disposable diagnostic process and confirmed its PID absent. A no-beat publication comparison is pending.

## Discriminating A/B and implementation handoff

On the same default empty song, suppressing only the onBeat-to-playhead assignment changed the result materially: idle CPU approximately 1.8%, playback CPU approximately 0.1%, continuing 0.5-second main pings, prompt accessibility snapshot, and visible transport state changed to Pause. The baseline with publication enabled was approximately 96% CPU and timed out on accessibility. These are Activity Monitor snapshots, not a benchmark; the magnitude plus the one-variable change provides discriminating causal evidence that repeated broad ComposerStore playhead publication causes the observed CPU/accessibility starvation in this scene. It does not prove audible output or complete coverage of the original smoke document. The heartbeat evidence corrects the earlier interpretation of a complete deadlock.

The production handoff to Luna is to isolate playback position observation: own a stable PlaybackPosition ObservableObject separate from ComposerStore, publish beat there, and remove @Published from ComposerStore.playhead. Preserve a computed playhead forwarding accessor for commands and seek actions. Only small extracted playhead-line and numeric-readout views observe the position object. Parent composer, palette, track list and grid views receive a stable reference without subscribing to every beat. Keep playing state on ComposerStore because it changes at transport transitions.

A focused regression can assert that position changes do not emit ComposerStore.objectWillChange while still emitting position changes. The decisive acceptance loop remains the full GUI with the disposable one-note/one-chord smoke song: Play, advancing display, responsive Pause/Stop and tempo change, CPU observation and prompt accessibility. Remove temporary diagnostic gates and watchdogs after this check. The 30 Hz throttle is not the causal fix; preserving it as a display cap is an independent implementation choice.
