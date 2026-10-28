# Selected-note transpose command

This is a bounded static specification of the original Klimper 2.4 ARM64 selected-note transpose command. It does not claim that the editor's complete command stack, undo behavior, or user interaction has been recovered. No clone code or target app was run for this analysis.

## Evidence baseline

The target is the installed thin ARM64 executable with SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`, analyzed with Ghidra 12.1.4 through REA profile digest `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. The command body is `FUN_10007ef3c` (Evidence `ev_84f87739f93aecee4fb907c924c5962438d61b326ca78c85d78efbaa7dda1b45`). The complete bounded session export is [`rea-note-transpose-command-2026-10-28.json`](../../research/rea-note-transpose-command-2026-10-28.json).

## Command association and input

`FUN_10007ef3c(this, delta)` returns immediately if `delta` is zero or the selected-note map at `this + 0xd8` is absent. RTTI names the menu callbacks `EditorMenu::transpose_note_selection(int)`; the RTTI/string evidence is `ev_16a1da6f2f482fab9f5be0342e7cbb2615ff012eb32a17f2381076acb99b8f4a` and the xref record is `ev_4f4d22ef1a8b26f314c2922dd46289fa20f352bd0c2201bf66178d2664b5bc00`. The menu labels are “Transposes up by a half step”, “Transposes down by a half step”, “Transposes up by an octave”, and “Transposes down by an octave” (strings Evidence `ev_94e43f229a6813df617e588eeaf3a7ef39b9765aa1b4c9c5817ae26d661b0136`).

The menu builder calls the handler with signed deltas `+1`, `-1`, `-12`, and `+12`; direct callsite xrefs are `0x10007aa14` and `0x10007ace4` (Evidence `ev_dc418c27d90ece8d8ddf58503df8353f9c57522d3e3d81bff3680535bcd0b78f`). The instruction record `ev_4d35b2eec6cdbe434e35395190da31566d8ca94233e5376667021806489e964c` shows the immediate arguments: `+1` at `0x10007aa10`, `-12` at `0x10007aa20`, `-1` at `0x10007abc8`, and `+12` at `0x10007ace0`. Together the labels and call arguments establish semitone and octave menu variants.

## Note data and transform

The selected notes are represented by an ordered map whose entries are 24 bytes: start/position at byte `+0` (64-bit), duration at `+8` (64-bit), pitch at `+16` (32-bit), and velocity at `+20` (32-bit float). Evidence for the selection lookup and record access is `ev_26855d0db291046f0f2b889e04ed978dff2416fe4cc2d7bb17413680a9649dff`; the insert/build path is `ev_5964ab66e6aa1e385622811e2a4791b75c5fec5b5ea37ad25f330b9569e08da4`.

For every selected note, the handler computes an unsigned 32-bit `candidate = pitch + delta`. If `candidate` is greater than `127`, it retains that note's original pitch; otherwise it writes `candidate`. This unsigned comparison also rejects underflow: a negative result wraps to a large unsigned value and is rejected by the same condition. Thus the behavior is **per-note reject at the MIDI pitch boundary**, not clamp and not wrap. A boundary-invalid note remains unchanged while other notes in the same selection may still transpose. The handler rebuilds the ordered map (`FUN_100036854`, Evidence `ev_ae0c5b1b267686eefbfea8aff863f41d70c8c8188ac61548635073e881c4ebe8`). Start, duration, and velocity are copied unchanged. The code also computes selected pitch extremes and updates a view-related state when required; this note does not specify that view adjustment because its user-visible interpretation is not established (`FUN_1000811a4`, Evidence `ev_30d151071dacfab325c8153d775fad0eb78bb71c9d3b916c489f9e63af3809ac`; `FUN_10008134c`, Evidence `ev_0a0ca26c0a10e1a6d610fee6cfba55b4570a365650ba20adc7a108b781a3e3ef`).

Implementation-ready contract for this handler's established scope:

```text
transpose(selectedNotes, delta):
    if delta == 0 or selectedNotes is absent: return without a note-map update
    for each (start, duration, pitch, velocity) in selectedNotes:
        candidate = unsigned32(pitch + delta)
        nextPitch = candidate <= 127 ? candidate : pitch
        emit (start, duration, nextPitch, velocity)
    rebuild the ordered selected-note map from emitted records
```

The menu currently supplies only `delta ∈ {-12, -1, +1, +12}`. Behavior for arbitrary integer deltas is visible in the handler's arithmetic but is not a menu-level feature claim.

## State copies and undo boundary

The handler copies a state object before and after the note-map transformation using `FUN_100068924` and `FUN_100070404`; both deep-copy tree storage through `FUN_100036bb8` (Evidence `ev_52214f41a5e5b2ad1c2f4d9ea5ab483cb5bdfad1b9c717b4c81a457dabbe7327`, `ev_7bb65b9d580601638f8c7ac3969a0ff560ffb620152abbc061311e3e52ccc132`, and helper `ev_ae0c5b1b267686eefbfea8aff863f41d70c8c8188ac61548635073e881c4ebe8`). `FUN_100047d48` dispatches closures through endpoints at offsets `+0x78` and `+0x98`, passing a fourth argument `0` before and `1` after the transformation (Evidence `ev_431f03f93cf493d7baeff7e4f80d9bcb5f4de71f458600558910c3213161a602`). The handler then updates the selection view from the rebuilt map using `FUN_100067718` (Evidence `ev_b63ef0a9549c1e4a19b5b0345c4a91daa757ecb9df76d43a740a6f3a4bd9055a`).

These are proven state-copy and callback facts. They do **not** by themselves establish which copy is stored as undo versus redo, how the command stack consumes the callbacks, or whether selection/view state is restored with the note data. RTTI contains generic `command_stack<Song>::execute/undo` and `Command<Song>::_UndoRedoable` names, but that naming is not proof that this handler's two state copies implement those stack semantics. Keep an implementation's undo transaction policy marked unresolved until the concrete callback/stack path is tied to this handler.

## Derived vectors

These are test vectors derived from the recovered arithmetic, not observations from running Klimper.

| Input selected note `(start, duration, pitch, velocity)` | Delta | Output |
|---|---:|---|
| `(2592, 1000, 60, 0.5)` | `+1` | `(2592, 1000, 61, 0.5)` |
| `(4000, 500, 64, 0.4)` | `+12` | `(4000, 500, 76, 0.4)` |
| `(0, 100, 126, 0.5)` | `+1` | `(0, 100, 127, 0.5)` |
| `(0, 100, 127, 0.5)` | `+1` | `(0, 100, 127, 0.5)` |
| `(0, 100, 0, 0.5)` | `-1` | `(0, 100, 0, 0.5)` |
| `(0, 100, 1, 0.5)` | `-1` | `(0, 100, 0, 0.5)` |

For a mixed selection containing pitches `60` and `127`, a `+1` command produces `61` and `127`, respectively. This follows from the handler's per-record guard and illustrates why selection-level rejection or clamping would be incompatible.

## Remaining gaps

- Concrete undo/redo callback ownership and restoration of selection, viewport, and note state.
- Whether repeated transposition is coalesced or creates one command per invocation.
- Other editing commands: move, resize, delete, duplicate, snap, and clipboard behavior.
- UI selection gestures, keyboard shortcuts, and any behavior for an empty or stale selection beyond the handler's early return.
- Runtime verification against the original app; activation is blocked, so these conclusions are static analysis only.
