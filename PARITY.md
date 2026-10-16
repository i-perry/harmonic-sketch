# Functional coverage

Reference: installed Klimper 2.4, universal macOS executable. Official [chord manual](https://www.klimper-plugin.com/pages/chords-manual), [piano roll manual](https://www.klimper-plugin.com/pages/piano-roll-manual), [MIDI export manual](https://www.klimper-plugin.com/pages/exporting-midi), [release notes](https://www.klimper-plugin.com/pages/update). Read-only bundle metadata and UI strings corroborate the features. Live reference access is blocked by license activation.

| Feature | Implementation / limitation |
|---|---|
| Chord palette | Seven degree columns, 19 qualities, key/mode borrowing, filled/hollow membership, major/minor/other colors. Layout/order is approximate. |
| Scales | Seven diatonic modes plus harmonic minor. |
| Symbols | Pitch names and Roman degree notation. Enharmonic spelling simplified. |
| Relations | Tonal/Flow/Contrast use original fifth-motion/shared-tone heuristics. Exact reference ranking is unknown. |
| Note matching | Selected pitches filter chord candidates. No proprietary scoring reproduced. |
| Arrangement | Append/drop/move/duplicate/delete/resize chords; direct voicing and inversion edits. |
| Sections | Named flat ranges, content-aware move/resize/Option-duplicate, loop range context action. Recursive subsections are flattened; editing remains flat. |
| Piano roll | Create/delete/move/duplicate notes, both-end length edits, velocity, marquee/Shift selection, ghost notes and harmony guides. |
| Tracks | Up to 14 melody tracks plus chord track, add/remove/rename, mute/solo/volume, eight GM preset choices. Explicit channel capacity keeps live and exported MIDI consistent. |
| Editing | Snapshot undo/redo, internal note/chord/section clipboard, transpose, horizontal/vertical zoom, snap including triplets. Cross-app note clipboard is not implemented. |
| Playback | Tempo, play/pause/rewind, loop bounds, system sampler, SF2/DLS loading. Not a hard realtime DAW engine. |
| Files | Validated versioned independent JSON format; best-effort `.klp` importer based on static schema evidence, with explicit fidelity warnings. Not lossless `.klp` round-trip compatibility. Dirty document prompts and remembered Save URL. |
| MIDI | Standard MIDI File tempo/track/instrument/note export; selected-item/current-track drag file. |
| Live MIDI | CoreMIDI destination routing, program/volume updates, device refresh by unique identity; no MIDI recording/input. |
| DAW | Standalone target. No AU/VST3 companion plugins, host timeline sync, plugin hosting or project interchange. |
| Assets | Original interface styling, no copied branding, icons, samples or binary source. |

Projects are limited to 16,384 beats to reject impractical or malicious timing values. Automated checks cover project validation/round-trip, binary MIDI timing, music theory and importer cases. Build validates all Swift source. Manual smoke checks and remaining issues are recorded in the final delivery. Exact UI, playback sound, timing, proprietary rankings and file compatibility remain unverified against the activated reference.
