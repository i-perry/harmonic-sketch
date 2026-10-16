# Harmonic Sketch

A native standalone macOS composer, implemented independently from the documented Klimper 2.4 workflows. SwiftUI/AppKit, AVAudioEngine and General MIDI synthesis; no external dependencies or copied assets.

## Run

Requires macOS 13+ and Xcode command-line tools.

```sh
bash scripts/build-app.sh
open "dist/Harmonic Sketch.app"
```

Use `swift test --disable-sandbox` for tests. Package caches may need writable overrides in restricted environments; the build script sets these automatically.

## Compose

Click a palette circle to audition; double-click to append, or drag it onto the arrangement. Scroll the palette to explore extensions. The seven columns represent scale degrees; filled circles are within the home key. Disable Home to borrow from other keys/modes. Relation outlines use documented original heuristics, not the reference application's undisclosed algorithm.

Select a timeline chord to edit inversions or individual pitches. Drag chords to move; drag their right edge to resize; Option-drag to duplicate. Create section ranges and set a loop from their context menus. Click the timeline to position playback.

Select or add a melody track, then click the piano roll to insert notes. Double-click removes notes. Shift-click or drag an empty region selects multiple notes. Drag notes to move, Option-drag to duplicate, and drag either edge to alter length. Velocity mode changes vertical drag to velocity. Other tracks appear as ghost notes. Mint/purple bands show chord roots/tones, blue rows show remaining scale tones. Right-click notes to derive a custom chord.

Space plays/pauses; period stops/rewinds. Command-Z/Shift-Command-Z undo/redo; Command-X/C/V and Command-A edit notes. Up/down transpose notes; Shift adds octave transposition. Save uses an independently versioned `.hsketch` JSON document. Import Klimper Project performs a best-effort `.klp` conversion and explains fields that cannot be preserved. MIDI export saves the full composition; Drag MIDI exports selected notes, sections, chords, or the current track. Select a CoreMIDI output device in the track sidebar to route playback externally. SF2/DLS soundbanks can replace the system General MIDI sounds.

## Scope and verification

See [PARITY.md](PARITY.md). The installed reference stops at license activation; interactive behavior could not be compared beyond that screen. The current result is a working independent implementation of documented workflows, not a verified exact reproduction. No activation mechanism was bypassed and the original app was not changed.

No remote repository is configured, so a GitHub PR cannot be opened until a remote is supplied.

The curated [static analysis findings](docs/GHIDRA-FINDINGS.md) record the independently observed data schema and remaining hypotheses. Proprietary binary/disassembly work files are excluded from Git.
