# Klimper static analysis findings

This document records evidence used by the standalone `.klp` importer. It describes the installed binary's serialized musical project format and selected user-facing musical behavior. It does not analyze or alter activation, licensing, or authentication code.

## Analyzed artifact and method

- Application: `/Applications/Klimper.app`, bundle identifier `com.polydigm.klimper.standalone`, version 2.4.
- Main executable: `/Applications/Klimper.app/Contents/MacOS/Klimper`; SHA-256 `00cd1d8731d358090828545826e35c57759b36e53722f50ec615613f55d4d689`.
- Extracted ARM64 slice: `research/Klimper-arm64`; SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`.
- Tool: Ghidra 12.1.4, headless ARM64 analysis of the extracted slice, image base `0x100000000`. Function addresses below are image-relative absolute addresses emitted by Ghidra.
- Ghidra project, extracted binary, scripts, and raw decompilation reports are under ignored `research/`; they are intentionally not part of source control. This document is the curated evidence artifact.

## Confirmed `.klp` structure

Ghidra decompilation of `FUN_10000b590` (project serializer, `0x10000b590`) and `FUN_1000135c8` (project reader, `0x1000135c8`) shows a JSON object with required top-level fields `name`, `scale`, `bpm`, `tracks`, `sections`, `chord_track`, `_start`, `_end`, and `looping`; `ui_state` is optional. The reader uses a JSON library and emits JSON parse diagnostics. The serializer writes the same root fields.

The serializer writes track entries with `id`, `name`, `volume`, `pan`, `mute`, `solo`, and `instrument`. The decompilation constructs `instrument` from a string value; it is not a confirmed General MIDI program number. `FUN_10000f4f4` (`0x10000f4f4`) serializes a scale as `root` (integer), `name` (string), `steps` (integer array), and `type`. Track pan and scale steps are present in the source format, while the current app model has no pan property and stores a finite set of named scale modes. The exact `steps` interpretation is unresolved; the importer only compares it with the selected built-in mode as a warning check.

`FUN_10000f788` (`0x10000f788`) serializes section objects with `id`, `name`, `color` (`r`, `g`, `b`, `a`), `length`, optional `scale`, and `children`. The children variant is either `{"sections": [...]}` or `{"clips": {"chords": [...], "clipByTrack": [...]}}`. Recursive section serialization calls the same function for nested sections.

`FUN_1000108a4` (`0x1000108a4`) serializes each chord clip as `{"chord":{"root":int,"intervals":[int...]},"length":number,"voicing":[int...]}`. The chord's duration is present, but no per-chord position is serialized in this function. The importer therefore places chord clips sequentially from the containing section's start, advancing by each `length`; this placement is an inference from the sequence representation. Voicing entries are mapped as absolute MIDI pitches because the receiving model and audio/MIDI pipeline consume MIDI pitches, but this remains an inference from the serialization and app context rather than a confirmed semantic range.

Within the `clipByTrack` map, the serializer traverses keyed entries and writes each as a two-item JSON array containing track ID and an array of serialized note objects. This representation is confirmed by `FUN_10000f788` calling `FUN_100010d38` (`0x100010d38`) for the notes and wrapping the key/value pair. The importer accepts exactly `[trackId, notes]` pairs.

`FUN_100010e28` (`0x100010e28`) serializes note fields `position`, `length`, `pitch`, and `velocity`. It divides internal integer time values by `10368.0` for JSON; the inverse reader multiplies beat values by 10368. Therefore all JSON time values are quarter-note beats, with 10,368 internal ticks per beat. Notes carry an integer pitch and floating-point velocity. The implementation maps pitch directly to MIDI note number and maps velocity 0…1 to the app's integer 1…127 range; those pitch/velocity interpretations are based on field use and the receiving app's MIDI model, not verified against a real activated project.

The top-level `_start` and `_end` loop positions are serialized by `FUN_10000b590` after division by 10368. `looping` is persisted as a boolean. The present model retains the bounds but does not store the playback toggle.

## Functional evidence from symbols and strings

The binary's symbols and UI strings identify operations for chord matching (`Find Matching Chords`), relation modes (`Tonal Harmony`, `Match Notes`), scale/key borrowing, section-relative scale selection, chord voicing editing, melody/bassline creation, piano-roll note editing and velocity, triplet grid snapping, MIDI clip drag export, and chord symbolization with Roman or pitch-name labels. Ghidra function names also include `chord_relations`, `chord_paths_valid`, `query_chord_at`, `chord_notes_of_entry`, `notes_in_region`, `all_notes_in_section`, `scale_at_path`, and `section_length`.

These names and strings establish feature presence, not exact user-visible algorithm behavior. In particular, no relation-scoring or matching algorithm is claimed here as recovered. The native app's relation and harmony implementation still requires comparison against controlled examples or deeper targeted analysis.

## Importer mapping and fidelity limits

The isolated importer in `Sources/HarmonicSketch/KlimperImporter.swift` maps project title, tempo, key, recognized scale name, track volume/mute/solo/program, section layout, chord root/voicing/duration, note pitch/timing/velocity, and loop bounds. Nested sections are flattened to a timeline while retaining their names and intervals. Each field is parsed with explicit shape/range checks; unrecognized `children` shapes throw instead of silently discarding content. `loadWithWarnings` reports unsupported details.

The current model cannot preserve track pan, source instrument string descriptors, section colors, per-section scale overrides, chord-track routing metadata, or saved UI state. The importer sets its current numeric instrument selector to default because the source field is an instrument descriptor string. Flattening also loses parent/child section grouping. Unknown track IDs in `clipByTrack` produce a warning and their notes are skipped. Unrecognized named scales fall back to Major with a warning. Unsupported chord interval sets keep the serialized voicing in `customPitches`, while the displayed chord quality falls back to Major.

No original `.klp` fixture was available for a round-trip or runtime compatibility check. The importer is evidence-based and schema-checked, but it is not claimed to be lossless or validated against Klimper at runtime. Harmony matching behavior, the exact semantic range of source pitch/velocity values, and section-relative versus song-relative clip positions remain open validation questions.
