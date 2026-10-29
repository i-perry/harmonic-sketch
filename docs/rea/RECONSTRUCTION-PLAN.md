# Klimper reconstruction plan

This plan reconstructs the behavior of the installed Klimper 2.4 artifact from the curated REA evidence before implementation resumes. It describes the original app's observed data flow and subsystem boundaries first, then lists the specifications required before an independent implementation can make parity claims. It is not a claim of source equivalence or complete parity. Each milestone begins with an evidence-backed subsystem specification and ends with an explicit list of behavior still unknown. Do not use prototype behavior as evidence about Klimper.

## Evidence baseline and rules

The target is the installed Klimper 2.4 ARM64 slice identified in [PROJECT-MODEL.md](PROJECT-MODEL.md). Use curated notes and retained evidence IDs as the working record; do not cite raw exports alone. Static decompilation, derived vectors, passive UI observations, and controlled runtime observations must be labeled as such. A feature name or persisted field does not establish interaction behavior.

Corrections to earlier ledgers:

- The stored time scale is 10,368 ticks per whole note and 2,592 ticks per quarter-note beat, derived from the serializers and BPM-based scheduler conversion. The recursive query routines `FUN_10002ad90` and `FUN_10002b004` establish nested note origins and sequential chord placement. These are project-model query routines, not Tonal callback evidence. Preserve the recovered coordinate rules in the import projection; see [PROJECT-MODEL.md](PROJECT-MODEL.md) and [SECTION-TRANSFORMS.md](SECTION-TRANSFORMS.md).
- Tonal suspension routing and scoring are recovered, including the ordinary-versus-suspension branch predicates. See [TONAL-VALIDATION.md](TONAL-VALIDATION.md) and its cited evidence. Do not retain the older crossed-only interpretation.
- The palette item producer and preview/transfer actions are traced. Its controls expose project-scale follow, a borrow key, parallel mode, and left/right adjacent-scale steps; this identifies candidate inputs, not the range transformation or generated entries. PreviewSettings Octave and Strumming callbacks are proven to share the exact state pointer read by the palette producer; the separate embedded player is a different instance. The closure consumer is identified, but its upstream `chords::Entry` collection producer is not. Candidate enumeration, quality filtering/order, and score-to-color mapping remain unresolved. Root-threshold and producer-gain defaults/mutation remain unknown. See [PALETTE-SPEC.md](PALETTE-SPEC.md) and [VOICING-VALIDATION.md](VOICING-VALIDATION.md).
- Scale records store semitone steps, not absolute pitch-class offsets: the observed C Major default is root 0 plus `[2,2,1,2,2,2,1]`, expanded cumulatively to `[0,2,4,5,7,9,11]`. The two copied default Scale fields are not assigned semantic roles, and the ModeSelector baseline-to-Project scale identity remains unknown. Keep stored step vectors distinct from expanded pitch classes. See [PALETTE-SPEC.md](PALETTE-SPEC.md).
- [MIDI-EXPORT.md](MIDI-EXPORT.md) now specifies the bounded selected-note clip-drag writer: format 1, one track, 960 PPQ, timing conversion `nativeTicks * 960 / 2592`, event construction/order, and its direct multi-note selection origin. It does not establish all selection paths or full-composition export.

If a newly curated record supersedes one of these statements, update this plan and the relevant ledger together. Keep unresolved points labeled unknown until evidence changes.

## Observed original subsystem architecture

The recovered architecture is a set of bounded paths through native data and UI components, not a complete end-to-end call graph. The primary model is a recursive project tree: root project state owns scale, timing, tracks, sections, chord-track data, loop bounds, and optional UI state. Sections select either nested sections or clip payloads. Per-track note collections and sequential chord records are queried through recursive section-range routines. JSON serialization and those queries establish time conversion and coordinate origins, while the musical meaning of several fields remains open. See [PROJECT-MODEL.md](PROJECT-MODEL.md) and [SECTION-TRANSFORMS.md](SECTION-TRANSFORMS.md).

The palette path has a recovered scale-membership candidate producer and partially unresolved view plumbing. `ChordPaletteContent` updates its source record and calls a producer that emits ordered base templates plus nested extension/direct-template entries; the owner then scores those records. Scale vectors are successive semitone steps; the observed default is C Major, root 0 with steps `[2,2,1,2,2,2,1]`. The generic SwiftUI `ForEach` flattening into `_item_creation`, visible order, gesture dispatch, and score-to-color mapping remain unresolved. The item has distinct preview-trigger and transfer actions. Preview calls the chord-note producer with shared state and effective song velocity; transfer calls the producer with scalar 1.0, serializes a chord record, and forwards a payload. Constructor stores prove PreviewSettings Octave/Strumming controls point at the same register/spacing state consumed by palette items. Project-scale follow, borrow-key, parallel-mode, and adjacent-scale controls are identified, but how those choices compose into the producer's input scale remains unknown. See [PALETTE-SPEC.md](PALETTE-SPEC.md), [VOICING-VALIDATION.md](VOICING-VALIDATION.md), and [HARMONY.md](HARMONY.md).

Playback has two bounded flows. The project scheduler advances an integer-tick cursor, queries event windows, dispatches event callbacks, and handles loop boundaries; separately, the chord-preview timer consumes generated pitch events with spacing and effective-velocity data. The clip-drag MIDI writer is a third path: it extracts selected notes, normalizes the observed multi-note branch to its earliest onset, and writes a one-track SMF. `instrument_of` resolves a captured Track ID to the Track's string field, and the scheduler consumer passes each event's string to ProjectPlayer's note-on callback. The producer that places that string into the scheduler event vector remains unknown, so unchanged flow from the persisted descriptor to the callback key is not yet proven. The app-side configured `.sf2` path into the SoundFont loader and the separate source/preset and bank/program resolver are recovered, but descriptor-to-source mapping and Track-to-channel routing remain open. See [PLAYBACK.md](PLAYBACK.md), [MIDI-EXPORT.md](MIDI-EXPORT.md), and [INSTRUMENTS-SPEC.md](INSTRUMENTS-SPEC.md).

Editing remains incomplete, but selected-note transpose and time-move handlers have grouped remove/insert undo-redo transactions, a generic length-edit command with its exact inverse and 649-tick minimum is recovered, and the selected-note delete command copies note tuples into `remove_notes` with a matching undo reinsertion path. Tag-3 note copy/paste is an in-process payload whose paste normalizes the earliest copied start to the paste-time. The length command's item-kind mapping and upstream drag conversion remain unknown; Delete menu identifier to handler mapping and other content-kind branches remain unproven. Recursive section paths, an insertion-boundary adjustment, and a few construction/length-update routines are also bounded; wrap, duplicate, coordinate propagation, selection transitions, and many command-stack semantics remain open. Treat each operation as unresolved until its command contract is tied to a handler and state update. See [EDITING-SPEC.md](EDITING-SPEC.md) and [SECTION-TRANSFORMS.md](SECTION-TRANSFORMS.md).

## Subsystem specifications and implementation gates

### 1. Project tree, time, pitch, and coordinates

**Evidence established:** the `.klp` project root and recursive section/clip shapes; a shared 10,368 internal-tick scale per whole note (2,592 per quarter-note beat); sequential chord placement; nested note origins; section path traversal; and a monotonic parent-length expansion path. The nested note and chord offsets are observed in recursive section queries `FUN_10002ad90` and `FUN_10002b004`; these identify the query flow and are unrelated to Tonal Harmony. Project-model and section evidence is summarized in [PROJECT-MODEL.md](PROJECT-MODEL.md) and [SECTION-TRANSFORMS.md](SECTION-TRANSFORMS.md).

**Specification still required:** reconcile the canonical recursive tree, coordinate conversion at each nesting level, section duration rules, scale override inheritance, and import/export projection in one model contract. Keep note pitch numbering, scale `steps` semantics, instrument descriptor meaning, and untraced coordinate rounding rules explicitly unknown.

**Gate:** no further importer/model redesign until the tree and coordinate spec reconciles the recovered nesting behavior with current `Song`, `KlimperSection`, and importer projections. Preserve raw source data whenever the independent timeline model cannot represent it.

### 2. Harmony, candidate palette, and voicing

**Evidence established:** Flow, Contrast, Match Notes, and both Tonal callback branches have recovered arithmetic and derived-vector evidence. Suspension routing uses exact stored interval 2 or 5 in either chord. The palette owner-to-producer path emits ordered base entries and nested extension/direct-template entries filtered by scale pitch classes; item preview/transfer paths and the root-first note-vector constructor are traced. Palette controls expose project-scale follow, borrow key, parallel mode, adjacent-scale step actions, and proven Octave/Strumming state bindings. See [HARMONY.md](HARMONY.md), [TONAL-VALIDATION.md](TONAL-VALIDATION.md), [PALETTE-SPEC.md](PALETTE-SPEC.md), and [VOICING-VALIDATION.md](VOICING-VALIDATION.md).

**Specification still required:** recover how palette controls compose into the input scale; trace generic collection flattening into visible item creation; determine whether scoring affects exclusion/order/color; and identify the gesture that dispatches preview or transfer. Root-threshold producer path is established; threshold defaults/mutation and user-facing meaning remain separate questions.

**Gate:** the palette and voicing subsystem may be implemented only from a written producer-to-view spec. The producer's template order and membership filter are recovered and reusable at their established inputs. Scale-choice composition, visible flattening/order, colors, defaults, and click/add audition behavior remain reconstruction choices until traced.

### 3. Editing commands, hierarchy transforms, and undo

**Evidence established:** selected-note semitone/octave transpose handler, per-note unsigned boundary rejection, selected-map rebuild, state copies and callbacks; serialized recursive variants, path traversal guard, section append constructor path, one insertion-boundary adjustment, and one nested-length max update. The transpose evidence does not resolve undo ownership. UI strings for other operations do not prove handlers. See [EDITING-SPEC.md](EDITING-SPEC.md) and [SECTION-TRANSFORMS.md](SECTION-TRANSFORMS.md).

**Specification still required:** recover undo/redo callback ownership for selected-note transpose; section move/resize/wrap/duplicate and descendant-coordinate behavior; chord and note insertion/deletion/drag/resize/duplicate semantics; selection rules; clipboard behavior; and command-stack transaction boundaries. State separately which facts come from code paths, strings, or manuals.

**Gate:** keep unspecified editor gestures as prototype behavior until each command has a bounded command contract. Compare selected-note transpose to [EDITING-SPEC.md](EDITING-SPEC.md), including per-note boundary rejection. Reuse a command only where the model and transformation match the spec; replace speculative descendant transforms when they conflict. Do not treat generic snapshot undo as recovered Klimper behavior.

### 4. Playback engine, chord preview, and instruments

**Evidence established:** scheduler tick arithmetic, event-window boundaries, end-before-start processing, loop-boundary cleanup, chord-preview event spacing and minimum duration, effective-velocity gating, an app-side path that constructs a configured `.sf2` path and calls the SoundFont loader, and the embedded bank/program resolution path. These findings and their limits are in [PLAYBACK.md](PLAYBACK.md) and [INSTRUMENTS-SPEC.md](INSTRUMENTS-SPEC.md). Palette Octave/Strumming settings share the producer state; the mapping from persisted instrument string to configured source, Track-to-channel allocation, producer gain/root-threshold settings, and downstream output callback audible note lifetime remain unknown.

**Specification still required:** trace project and track event production through output callbacks; determine loop-field initialization and toggle mapping; connect the selector's persisted string to a loaded SoundFont source and per-track MIDI channel; trace persisted preview settings separately from the proven Octave/Strumming state binding; and separate timer scheduling facts from audible behavior. Keep prior clone responsiveness diagnosis as evidence about the clone only, not the original.

**Gate:** scheduler arithmetic, event-window rules, and the embedded engine's scoped bank/program fallback path are recovered contracts. Instrument identity, channel allocation, audio output behavior, velocity controls, preview UI, and loop toggle need a full producer-to-output specification before parity claims.

### 5. MIDI, project files, and interchange

**Evidence established:** `.klp` serialization shapes and the scoped selected-note clip-drag MIDI writer's format 1, one-track, 960-PPQ output and observed timing conversion `nativeTicks * 960 / 2592`. The direct multi-note selection branch normalizes to the earliest selected onset. See [PROJECT-MODEL.md](PROJECT-MODEL.md) and [MIDI-EXPORT.md](MIDI-EXPORT.md).

**Specification still required:** resolve whether other selection types share the observed multi-note origin and filtering, the opaque count message's consumer meaning, and exact runtime file bytes. Trace full-composition save/export separately. Define `.klp` import fidelity and unsupported fields using the confirmed nested coordinate rules.

**Gate:** retain the independent `.hsketch` format as a product decision. Treat the importer as a projection with explicit loss reports. Do not infer full-song MIDI equivalence from the selected-clip writer.

### 6. UI state and interaction architecture

**Evidence established:** selected static UI strings, a passive initial settings snapshot, and specific UI construction paths cited in the ledgers. These establish labels/default observations only for the stated scope.

**Specification still required:** map view ownership, selection state, command routing, palette gestures, arrangement gestures, keyboard commands, and persistence of UI settings from UI wiring evidence or controlled reference observations. Activation blocks controlled app comparison for the currently available install; do not use the clone QA snapshot as a substitute.

**Gate:** build the independent UI around stable domain commands after their contracts exist. Keep visual layout and control behavior identified as reconstruction decisions wherever no original evidence is available.

## Existing source boundary map

This map identifies likely rewrite seams; it does not certify current code as reusable parity work. Reuse is conditional on the subsystem specification above.

| Current source | Boundary and disposition after specification |
|---|---|
| `Domain.swift` | Preserve only types that fit the specified recursive project model. `Song` and flat timeline types are product-model choices; replace or adapt where coordinate and nesting semantics require it. Keep the raw `.klp` tree as a preservation boundary. |
| `KlimperImporter.swift` | Rewrite its projection for confirmed nested note origins and sequential chord placement. Keep defensive JSON shape/range checks and explicit warnings if they remain correct. |
| `MusicTheory.swift` | Callback score functions are reusable for the exact recovered callback inputs, subject to current focused validation; replace palette caller assumptions, candidate filtering, ordering, and colors once traced. |
| `NativeChordVoicing.swift` | The explicit-input arithmetic is a useful isolated transcription. The settings/state alias for register and strumming is now resolved, but gain and root-threshold defaults remain open. Keep those inputs explicit and do not promote opaque names to user-facing semantics. |
| `ComposerStore.swift` | Rework into commands/state ownership after selection and undo contracts are specified. Compare transpose behavior against the selected-note per-record boundary guard in [EDITING-SPEC.md](EDITING-SPEC.md); callback/undo ownership remains unresolved. Current broad store, snapshot undo, clipboard, other section transforms, and UI state are prototype policy unless individually evidenced. The separated playhead observation is clone responsiveness architecture, not reference evidence. |
| `AudioEngine.swift`, `MIDIOutput.swift`, `MixingPolicy.swift` | Replace or retain only after scheduler/output, mute/solo, channel, instrument and timing specs are written. The current engine's successful clone smoke does not establish reference sound or output parity. |
| `MIDIExporter.swift` | Keep independent export as a product capability. Specify and implement the recovered selected-clip writer as a separate path; full-song export remains its own unknown contract. |
| `Persistence.swift` | Keep the independent, versioned `.hsketch` document format if desired; it is not `.klp` compatibility evidence. Validate its boundary separately from import projection. |
| `App.swift`, `PaletteView.swift`, `TimelineView.swift`, `PianoRollView.swift`, `TrackView.swift`, `PlaybackPositionViews.swift` | Rebuild UI ownership and event bindings around recovered command/state contracts. Layout, colors, gesture dispatch, and view decomposition are independent design until supported by UI wiring or controlled observation. |

## Ordered milestones

1. **Evidence ledger reconciliation:** correct stale unknowns and contradictions; add source identity, evidence type, coverage, and unknowns consistently. Merge the ongoing palette and MIDI notes into the linked ledgers.
2. **Domain and coordinate specification:** finish the recursive tree and time/pitch/scale boundary contract, including confirmed nested note origins, sequential chord positions, and whole-note/quarter-note conversion.
3. **Musical generation specification:** connect callback arithmetic, palette candidate producer, input-scale choice composition, shared register/spacing settings, voicing inputs, and view output; keep unresolved scale and view links out of parity claims.
4. **Editing specification:** extend the bounded transpose/time-move/length-edit findings to remaining edit commands, resolve item-kind mapping and uncovered callback-to-undo ownership, and mark reconstruction policy explicitly.
5. **Playback/output specification:** complete scheduler-to-output, loop controls, persisted settings, and instruments; retain the proven palette register/spacing alias and separate deterministic timing from sound behavior.
6. **Interchange specification:** define importer projections, warnings, the scoped selected-clip MIDI path, and full-composition export as distinct contracts.
7. **Implementation restart:** choose reusable modules from the boundary map only after their contracts pass evidence review; implement coherent subsystems, then verify against the written spec and available reference evidence.

No percentage-complete estimates are meaningful here. A milestone is ready when its specification states what evidence supports each behavior, what scope that evidence covers, and what remains unknown.
