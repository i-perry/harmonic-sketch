# Harmonic Sketch

A native standalone macOS composer, implemented independently from the documented Klimper 2.4 workflows. SwiftUI/AppKit, AVAudioEngine and General MIDI synthesis; no external dependencies or copied assets.

## Run

Requires macOS 13+ and Xcode command-line tools.

```sh
bash scripts/build-app.sh
open "dist/Harmonic Sketch Oct 27 2026.app"
```

Run tests with writable compiler caches in restricted environments:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/klimper-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/klimper-swift-cache \
swift test --disable-sandbox
```

The app build script sets equivalent cache overrides automatically.

The script always builds the QA app at `dist/Harmonic Sketch Oct 27 2026.app` with bundle identifier `dev.harmonicsketch.composer.oct272026`. Close that app before rebuilding it. Keep this as the single app identity used for QA; archived bundle copies are for storage and must not be launched. Restore an archived build to the canonical QA path before testing it. The build is ad hoc signed, so a stable path and bundle identifier do not guarantee that macOS will preserve an “Always Allow” approval across rebuilds. Do not change OS approval settings or databases as part of this workflow.

## Compose

Click a palette circle to audition; double-click to append, or drag it onto the arrangement. Scroll the palette to explore extensions. The seven columns represent scale degrees; filled circles are within the home key. Disable Home to borrow from other keys/modes. Relation outlines use callback arithmetic recovered from static analysis, with palette argument and visual mappings still reconstructed.

Select a timeline chord to edit inversions or individual pitches. Drag chords to move; drag their right edge to resize; Option-drag to duplicate. Create section ranges and set a loop from their context menus. Click the timeline to position playback.

The Chords channel and each melody track have independent instrument, volume, pan, mute and solo controls. Muted solo channels do not suppress other channels. Projects saved before these controls were added reopen with the default centered piano chord sound and centered melody tracks.

Select or add a melody track, then click the piano roll to insert notes. Double-click removes notes. Shift-click or drag an empty region selects multiple notes. Drag notes to move, Option-drag to duplicate, and drag either edge to alter length. Velocity mode changes vertical drag to velocity. Other tracks appear as ghost notes. Mint/purple bands show chord roots/tones, blue rows show remaining scale tones. Right-click notes to derive a custom chord.

Space plays/pauses; period stops/rewinds. Command-Z/Shift-Command-Z undo/redo; Command-X/C/V and Command-A edit notes. Up/down transpose notes; Shift adds octave transposition. Save uses an independently versioned `.hsketch` JSON document. Import Klimper Project performs a best-effort `.klp` conversion and explains fields that cannot be preserved. MIDI export saves the full composition; Drag MIDI exports selected notes, sections, chords, or the current track. Select a CoreMIDI output device in the track sidebar to route playback externally. SF2/DLS soundbanks can replace the system General MIDI sounds.

## Scope and verification

See [PARITY.md](PARITY.md). The installed reference stops at license activation; interactive behavior could not be compared beyond that screen. The current result is a working independent implementation of documented workflows, not a verified exact reproduction. No activation mechanism was bypassed and the original app was not changed.

No remote repository is configured, so a GitHub PR cannot be opened until a remote is supplied.

The curated [static analysis findings](docs/GHIDRA-FINDINGS.md) record the independently observed data schema and remaining hypotheses. Proprietary binary/disassembly work files are excluded from Git.
