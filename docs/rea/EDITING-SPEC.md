# Selected-note transpose command

This is a bounded static specification of the original Klimper 2.4 ARM64 selected-note transpose and time-move commands. It recovers the two-command undo transaction used by those handlers, but not the editor's full command set or the UI path that supplies all move deltas. No clone code or target app was run for this analysis.

## Evidence baseline

The target is the installed thin ARM64 executable with SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`, analyzed with Ghidra 12.1.4 through REA profile digest `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b8bcc28`. The command body is `FUN_10007ef3c` (Evidence `ev_84f87739f93aecee4fb907c924c5962438d61b326ca78c85d78efbaa7dda1b45`). The complete bounded raw session export is kept locally at `research/rea-note-transpose-command-2026-10-28.json` and excluded from the curated documentation commit.

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

## Command-stack connection and inverse

The before/after objects are command wrappers, not merely opaque state copies. `FUN_100068924` installs the secondary vtable at `0x1009cb648`; RTTI links that table to `Command<Song>::Wrapper<remove_notes>` through the name at `0x1003ccb22` (xref Evidence `ev_d06c586bd7316d56568666c1d53db65fb743b6d5c12b2217c23d889bcd84d2b4`). Its command slots are `+0x10 = FUN_100068a64`, `+0x18 = FUN_100068b3c`, and `+0x20 = FUN_100068bdc`. `FUN_100070404` installs the secondary vtable at `0x1009cb768`; RTTI links that table to `Command<Song>::Wrapper<insert_notes>` through the name at `0x1003ccc6b` (xref Evidence `ev_8fdeed07fbb456b970d158d5a7e3a5bf5aec68d8c4e446b331698d6528160936`). Its corresponding slots are `+0x10 = FUN_1000706ac`, `+0x18 = FUN_10007074c`, and `+0x20 = FUN_100070824`. Constructor and vtable observations: `ev_98d20e22ad1348a01e6c6786e8015eca6d65e543f01c79f664fbda4e1e9ede15`, `ev_09cf0d5e3af9f787ec4cc9f105b1486c52032d75b791c77e1343bfc55df83c60`, vtable bytes `ev_83b6af22292c12b9edb54bb978e778faa60bb2902d1a7fd25777f7ad558ee1382` and `ev_9d905d03a04fd79d4d11d41c8988ae53fa9ad757cbe3e4740de7bc496c41ef57`.

This slot assignment uses the concrete `command_stack<Song>` callbacks already recovered for section commands: execute calls command `+0x10`, undo calls `+0x18`, and redo calls `+0x20` (execute closure Evidence `ev_cb9a146a90dd1d5228f2385f03fe47cbc3ab091519647f6050349a1a1f473e5d`; undo closure `ev_e142e08be488ccab748943c49e07c8fbe4a7b33f083c709f316ec1683414f380`; section redo-slot confirmation `ev_29ee66368beee5423a1e1d690692da7db8f5acde583db18ea4b4d435eb8ed545`). The transpose handler sends the `remove_notes` command with event flag `0`, then the `insert_notes` command with flag `1`, through the same `FUN_100047d48` Song-event route used to submit command wrappers. The stack execute closure creates a new history group when the stack is empty or the incoming flag is `0`; with an existing group, flag `1` appends to it. Undo walks that group's command list in reverse and calls each `+0x18`; redo replays the group in forward order via `+0x20`. This ties the two snapshot objects to one grouped transaction and resolves the inverse:

1. Execute: remove the old selected notes, then insert the transformed notes.
2. Undo: undo `insert_notes` first (remove the transformed notes), then undo `remove_notes` (restore the original notes).
3. Redo: repeat removal of the original notes, then insertion of the transformed notes.

The stack grouping/order is evidenced by `FUN_100047eec` and `FUN_10005280c`; the wrapper method bodies are `ev_16caf1efb1510a6415e075df04e45b68f69e4c6601b478254ed34571b1716b63`, `ev_75010475abbc39e7ac29e403bf6c84c395fc8dbeeca56e8c938ba6d920ba0992`, `ev_0ac48b3a426ffa5f00110a1f445b07cf8ca50fc5acc16f4a40977ec9b28cf34f`, `ev_e3580a307d022b7ca394b8517204b6d64337bf660db15b964317681993c43c4d`, `ev_d7db76401b376f27ba7efb8ac2dc96cc455230ba5ef96125b3cb0d69aa2f7bb2`, and `ev_ca1ee8c24f846307d68c5a001cac04004d99288d9fb7357c6a7746a92b49acfc`. The remove/insert helpers are `ev_36b60d3cc8fe0051da254f8f1dab0e2db97e343acda5904e52ddb06586ea119d`, `ev_d83bec8c3621da1e0e1de9eb789843b3debf5857ac12b69308fad3734500051`, and `ev_5c6aeece2de6a145a219bb08c810828cca7571fdd1db9e4ed26a7757861ce13a`.

The selection view is updated after the command pair is dispatched using `FUN_100067718` (Evidence `ev_b63ef0a9549c1e4a19b5b0345c4a91daa757ecb9df76d43a740a6f3a4bd9055a`). Whether selection and viewport state are part of the undo transaction is not established; the recovered command payloads operate on Song note records.

## Selected-note time move

`FUN_10007f538(this, delta)` uses the same selected-note map at `this + 0xd8`, emits a `remove_notes` command for the original map with flag `0`, adds `delta` to each selected note's start, emits an `insert_notes` command for the rebuilt map with flag `1`, then updates the selection view. Its current function dossier is `ev_4573deb54881d08f24ceb232d1dd191af31493e4557642da5f9122e4fe768f35`; an earlier complete dossier is `ev_e4c7ec819c1947039c21ce5bdb1d35a5c538c06f4a09427e88e1144cc6b986a0`. The delta-add/guard instruction sequence is `ev_48ca331c7c40f9c560107fa7c7013f3f0def171d4897aa5a8c1792ab7b893d0d`. A static callsite in the editor handler supplies `delta = +0x510` (1296 ticks) at `0x10007acd0` before calling the move handler at `0x10007acd4`; separate menu strings say “Moves left by an eigth note” and “Moves right by an eigth note” (Evidence `ev_01983e2b1779561100198979e5393274f8cf3e68c4954f50dce39790234773fa` and `ev_4002593255e4562b618ad51e4a570b1860d1c8c54b0726e7b08839dda28935b4`). At 2592 ticks per quarter note, 1296 ticks is one eighth note. The positive callsite is consistent with the rightward menu item, but a direct label-to-callsite reference and the leftward callsite were not recovered; the pixel-drag path's deltas also remain unknown.

The core transform is per note: calculate signed `proposedStart = start + delta`; if the signed result is negative, keep the original start, otherwise write the proposed start. AArch64 instructions `adds x10, x9, x21` followed by `csel x9, x9, x10, lt` confirm the rejection of negative results. Duration, pitch, and velocity are unchanged. There is no snap/quantize, upper clip-bound, or collision check in this handler. The menu supplies an exact 1296-tick eighth-note step; the pixel-drag path's delta quantization and any higher-level clip-bound policy remain unknown. The handler rebuilds the ordered map, so notes that hit the lower-bound guard are retained individually while other selected notes can still move.

Derived vectors (not runtime observations):

| Input selected note `(start, duration, pitch, velocity)` | Delta | Output |
|---|---:|---|
| `(100, 500, 60, 0.5)` | `-120` | `(100, 500, 60, 0.5)` |
| `(240, 250, 64, 0.4)` | `-120` | `(120, 250, 64, 0.4)` |
| `(0, 100, 60, 0.5)` | `+36` | `(36, 100, 60, 0.5)` |

Thus a mixed selection at starts `100` and `240` with `delta=-120` yields starts `100` and `120`: movement is not rejected as a whole, and the first note is not clamped to zero.

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

- Whether selection and viewport state are also restored on undo/redo.
- Whether repeated transposition is coalesced or creates one command per invocation.
- Other editing commands: resize, delete, duplicate, snap, and clipboard behavior.
- The drag/keyboard caller path that computes every move delta; only the integer delta handler and one 1296-tick callsite are established here.
- A separate RTTI type `music::change_item_length` and `LengthEditing::drag_to(MusicalTime)` lambda exist, but the evidence gathered so far does not tie that command to selected-note right-edge resizing. Its note-vs-section target, length rounding, minimum/maximum policy, and clip-bound behavior remain unresolved.
- UI selection gestures, keyboard shortcuts, and any behavior for an empty or stale selection beyond the handler's early return.
- Runtime verification against the original app; activation is blocked, so these conclusions are static analysis only.
