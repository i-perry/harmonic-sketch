# MidiClipComponent clip-drag MIDI writer

Status: one static clip-drag writer is recovered far enough to specify its note-event and SMF serialization path. A separate File-menu/project-export boundary audit found an “Export Klimper Project” artifact string but did not join it to a UI action or MIDI writer. This is not a specification of every MIDI export feature, MIDI input, or project-wide export. No original-app activation or execution was performed.

## Target and evidence

Target is the shipped arm64 Mach-O `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`, analyzed with REA 6.5.0 / Ghidra 12.1.4 profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. The complete retained REA session export is [`rea-midi-clip-writer-2026-10-28.json`](../../research/rea-midi-clip-writer-2026-10-28.json) (69 records, 0 REA unknowns). Decompiled C is Ghidra pseudocode, not original source.

The class RTTI name bytes identify `polydigm::music::ui::MidiClipComponent` (`ev_268ad50d1633c4207bc9ededcea277f34b91369f802eaf77fa1df57d11bd0d6d`). The vtable at `0x1009cea88` has the RTTI pointer at `+0x08` and `FUN_100088cfc` at `+0x38` (`ev_c88025e836852daedfc617b6f8681a5ea6e1199787f065dbda41e6805670ebce`; type-name xref `ev_5d79788d58465af1ebf291dca7aac03babb804fe560dba05ca63abcbc0bd8394`). A function-type string names the lambda `_start_dragging_midi_clip` (`ev_268ad50d1633c4207bc9ededcea277f34b91369f802eaf77fa1df57d11bd0d6d`), and the binary contains the affordance “Drag to export midi clip” (`ev_bb1e1fc4bd38d5ecfdab75af7d2e9efc8bb076a5814442c52ccb43b7e1654753`). Together with the file writer and drag-data handoff in `FUN_100088cfc` (`ev_bfac8bcc381e3309ff65815a970a9ab33d093d58ddef0185a975cdb1cb8d33e0`), this strongly associates the method with clip dragging. The exact UI gesture dispatch into that virtual slot is not resolved.

## Source records and origin

`FUN_100088cfc` calls `FUN_10008a23c(this)` to obtain note records, and returns without reaching the writer when the helper returns an empty vector. The component member at `this + 0x100` is passed to selection extraction (`ev_bfac8bcc381e3309ff65815a970a9ab33d093d58ddef0185a975cdb1cb8d33e0`; helper `ev_acf893ab6705a2013f4020085b19b7063d82d4fb957301cd4c9d428ab7b0290d`). In the direct multi-note-selection branch, `FUN_100061e18` recognizes selection variant 1 and materializes its ordered selection tree (`ev_26855d0db291046f0f2b889e04ed978dff2416fe4cc2d7bb17413680a9649dff`). `FUN_10008a23c` finds the minimum selected note start and subtracts it from each selected start before producing the returned records. Thus that branch exports relative to the earliest selected onset, not the song origin. Other selection variants use separate range/query paths (`FUN_10003e7d0`, `FUN_10003e9b4`, `FUN_100061f50`); the trace does not prove that every such path applies the identical origin rule. Confidence: observed for the multi-note branch; unresolved across all selection modes.

The writer consumes a 24-byte record as:

| Offset | Field | Use in writer |
|---|---|---|
| `+0x00` | signed 64-bit start in native ticks | absolute event start before selection-relative normalization |
| `+0x08` | signed 64-bit duration in native ticks | added to start for note-off |
| `+0x10` | 32-bit pitch value | narrowed to one MIDI data byte |
| `+0x14` | float32 velocity | multiplied by 127 and narrowed/clamped to one MIDI data byte |

The record layout and its use are observed in `FUN_100088cfc`; interpretation of pitch as a MIDI note number is strongly supported by emitted `0x90`/`0x80` channel messages, but a broader pitch-range contract is not established. There is no pitch-range clamp visible in this writer; only the low byte is emitted.

## Event construction and ordering

Before note events, the method asks `FUN_10008b3e4` for a note-count description and inserts a time-zero event. Its observed message bytes begin `F0 F7 FF 03`, followed by a variable-length encoded description length and the returned text (for example, `2 notes`). This event is routed through the writer's SysEx (`F0`) serialization branch. Its exact consumer-facing meaning is unresolved; treat it as opaque clip metadata, not as a standard tempo or track-name event.

For each record `(start, duration, pitch, velocity)`, the writer inserts:

```text
note-on:  time = start * 960 / 2592, status = 0x90, pitch = low8(pitch), velocity = clamp(round(velocity * 127), 0, 127)
note-off: time = (start + duration) * 960 / 2592, status = 0x80, pitch = low8(pitch), velocity = 0
```

Evidence: writer `ev_bfac8bcc381e3309ff65815a970a9ab33d093d58ddef0185a975cdb1cb8d33e0`; ordered insertion helper `FUN_100105ba8`, dossier `ev_58c2232055afe7a11a816ad97d8fce76666eddbce2580b95d0d94d8cc3fb0092`. The helper scans backward while the new time is strictly less than an existing time, then inserts after equal-time entries. This yields ascending absolute time and preserves insertion order for ties. The event time is retained as double during insertion; serialization rounds each absolute event time to an integer tick with the `6755399441055744.0` bias conversion, then computes delta ticks from the previously rounded absolute tick. On ordinary round-to-nearest-even FP mode this conversion rounds to nearest tick; the target's FP environment was not observed independently.

The velocity conversion uses the same bias constant after multiplying the float by 127. Values above 126 are set to 127; a sign mask makes negative rounded values 0. The common nearest-integer interpretation assumes the normal FP rounding mode. No other event types are synthesized by this code path. The serializer suppresses repeated channel status bytes (running status), emits SysEx lengths as VLQs, and appends `00 FF 2F 00` if the event stream does not already contain an end-of-track event. Evidence for these branches is in `ev_bfac8bcc381e3309ff65815a970a9ab33d093d58ddef0185a975cdb1cb8d33e0`.

## SMF header, tempo, and destination

The emitted header is `MThd`, length 6, format 1, one track, and division `0x03C0` (960 ticks per quarter note). The track is emitted as `MTrk` with a computed payload length. The method creates a path ending in the fixed basename `clip.mid`, opens/truncates its stream, serializes the file, then passes the resulting file/string context to `FUN_10033a0cc` as drag data. The exact temporary-directory/path construction and external drop-target behavior are not established.

No tempo meta-event is inserted by the recovered method. The time conversion is therefore tempo-independent and the file contains no observed tempo value; how a consuming DAW chooses playback tempo is outside this evidence. In particular, the UI's tempo or a project's BPM must not be added to an implementation of this path without separate evidence. The quarter-note interpretation of 2592 native units follows the playback conversion `10368 / 4` documented in [`PLAYBACK.md`](PLAYBACK.md); 960 PPQ is directly observed in this writer.

## File-menu and full-project export boundary (2026-10-29)

The Ghidra-defined string inventory contains “Export Klimper Project” at
`0x100392130`, alongside “Open Klimper Project”, “Save Klimper Project”, and
“Save Klimper Project as...”. This is artifact-string evidence only: a direct
Ghidra xref query for the export string returned no references, and no menu
construction/action edge is established. The query scope covers Ghidra-defined
references and strings; packed or otherwise undefined data and indirect UI
dispatch may be absent. Do not infer either an active File-menu action or the
absence of one from these strings/xrefs alone. Evidence: string inventory
`ev_0f9ad71db5c20919beecea5ece83334dd413c751c1b3bdb85d706493674f8ed6`, export
search `ev_4e0401d6740ba51225a8fe617d430d9cc85900be6c59f56e1dcc1e61d906385f`,
and xrefs `ev_42657c48ab9e830de26d7efd0adc2442adafd89be6af3ccd34fc93d03a004b65`.

The separately recovered `.klp` save adapter `FUN_10000b21c` calls
`FUN_10000b590` to build the project JSON object and hands the result to its
save callback; it is a project-document writer, not an SMF writer. The
recognized JSON writer shape and its limits are specified in
[`DOCUMENT-SPEC.md`](DOCUMENT-SPEC.md). This does not establish that the
“Export Klimper Project” string selects that adapter; the menu string-to-action
join remains unknown. Evidence: save adapter
`ev_c452220fbfa7e3a305da8f6a61a6682f5d71fbba7bd94a30dccc4d3c715ab59f` and
JSON writer `ev_7607806451f319706b04142bcb3dabf7bcb5110d567833674b0997579d97184`.

The only fully traced MIDI file writer in this audit is the `MidiClipComponent`
drag path described above. Its emitted events use channel 0 (`0x90` note-on
and `0x80` note-off), one SMF track, 960 PPQ, and no tempo event. Its records
come from the component's selected-note/range extraction, not a recovered
all-track project traversal. The direct multi-note selection branch is
earliest-onset-relative; the other selection branches do not yet have a
reconciled origin/filtering contract. The basename `clip.mid` and drag-data
handoff are observed, but the external consumer's behavior is not.

The defined-string search for “midi” returns the clip affordance and `clip.mid`
path, plus MIDI device/engine strings; it does not return a separate
“Export MIDI” label. This is a bounded string-inventory observation, not proof
that the artifact has no additional MIDI exporter or a menu item whose label
does not mention MIDI. No full-song/project MIDI writer, channel allocation
policy across tracks, tempo policy, or File-menu export handler has been
established in the examined evidence. A complete initialized-memory byte scan
also found no literal `MThd` or `MTrk` byte sequences; this cannot exclude a
writer that constructs the chunk identifiers from smaller values. The scan
skipped uninitialized regions, so it is only negative evidence for the searched
initialized image. Evidence: `ev_08155416098d2877fc738e81a9000971279e3e6fbfa7e32ee90af91ec3050750`
and `ev_f86daf14d5b6dd74ec3d51496259200bf5ca8aab882ef477ecaf169da4ef918e`.
Retained audit bundle:
[`rea-midi-full-export-boundary-2026-10-29-v2.json`](../../research/rea-midi-full-export-boundary-2026-10-29-v2.json)
(16 records; 0 REA unknowns). The clip-writer details remain in
[`rea-midi-clip-writer-2026-10-28.json`](../../research/rea-midi-clip-writer-2026-10-28.json).

## Derived test vectors (not runtime observations)

Given two selected records with starts in native units:

```text
(start=2592, duration=2592, pitch=60, velocity=0.5)
(start=5184, duration=1296, pitch=64, velocity=1.0)
```

After direct multi-note selection normalization by the minimum start, events are:

| Relative tick | Event | Delta | Expected bytes (before running-status suppression) |
|---:|---|---:|---|
| 0 | note 60 on, velocity 64 | 0 | `90 3C 40` |
| 960 | note 60 off | 960 | `80 3C 00` |
| 960 | note 64 on, velocity 127 | 0 | `90 40 7F` |
| 1440 | note 64 off | 480 | `80 40 00` |

Equal-time order is note 60 off before note 64 on because the note-60 event was inserted first and the insertion helper places later ties after existing ties. With the opaque two-note message at tick 0 and no supplied EOT event, the track event stream also contains that time-zero message and finishes with `00 FF 2F 00`. The header division is `03 C0`; no tempo event is expected. Exact file byte vectors should account for the serializer's VLQ delta encoding and running status.

Additional direct conversion checks: `2592` native units maps to `960` ticks; `1296` maps to `480`; velocity `0.5` maps to `64` under nearest rounding; velocity `1.0` maps to `127`; negative velocity maps to `0`; a velocity above 1 clamps to `127`. These are derived from the observed operations, not a runtime export comparison.

## Contract and unresolved boundaries

An implementation of this one path should take the selected note records emitted by the corresponding selection/query model, preserve their helper-provided ordering/origin, insert the opaque tick-zero description event, create one note-on and one note-off per record, stable-insert events by double absolute time, round absolute times before delta calculation, emit format-1 single-track SMF at 960 PPQ with running status and VLQ encoding, ensure EOT, and hand off a `clip.mid` file as drag data. It should not claim a project-wide MIDI export contract.

Still unknown: equivalence of origin and selection filtering across all selection variants; whether one-note selection follows the same path; whether the description/SysEx payload has a DAW-specific semantic; any tempo metadata in another exporter; all-track/project MIDI export; imported/exported MIDI relation to instruments or tracks; MIDI input; UI gesture and cancellation/error behavior; and runtime byte-for-byte output. Static evidence only. Original activation remains blocked and was not bypassed.
