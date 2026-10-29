# Scheduler producer validation

Static saved-evidence pass, 2026-10-29. Original thin Mach-O
`research/Klimper-arm64`, SHA-256
`3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`;
Ghidra 12.1.4, profile
`966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`.
No target execution or activation bypass.

## Corrected producer frontier

`FUN_10002a158` is not merely a consumer. It resets the 0x40-byte event
vector, dispatches a provider callback with that exact vector's address,
and only then reads the newly populated range. Existing evidence
`ev_228c2e14fb3d1d864574bcca34bf4c86ac204af8760d44f5a756b7074134d046`
in `research/rea-instrument-queue-frontier-luna-2026-10-29b.json`
contains both the decompilation and the assembly proving this boundary.

Use `Q = x20` in this function:

| Address | Observed instruction/effect |
| --- | --- |
| `0x10002a240` | `ldp x22,x23,[x21,#0xf8]!` with `x21=Q`; writes back `x21=Q+0xf8`. |
| `0x10002a248..264` | Walks backward in 0x40-byte steps and destroys heap string payloads where needed. |
| `0x10002a268` | Stores old begin `x22` to `Q+0x100`, clearing the vector. |
| `0x10002a26c` | Loads provider owner `x22=*(Q+0xf0)`. |
| `0x10002a274..280` | Constructs inner callable with table `0x1009bea18` at `fp-0xd0`, active pointer at `fp-0xb8`. |
| `0x10002a288..294` | Constructs outer callable table `0x1009be998` at `sp+0xd0`; captures inner wrapper address at outer `+8` and `Q+0xf8` at outer `+0x10`; sets active outer pointer to itself. |
| `0x10002a298..2a4` | Attempts shared lock at provider owner `+0x60`. |
| `0x10002a2b8..2c4` | Invokes outer table `+0x30` with argument `provider owner+0x108`. |
| `0x10002a334` | Reloads begin/end from `Q+0xf8` / `Q+0x100` after dispatch and callback cleanup. |
| `0x10002a38c` | Consumer advances by `0x40`; `0x10002a3bc..3e0` copies record string at `+0x20`. |

Thus the next focused question is the invoker stored at outer table
`0x1009be9c8` (`0x1009be998+0x30`), then inner invoker slot
`0x1009bea48` (`0x1009bea18+0x30`). The outer callable has the precise
vector destination, so following this provider dispatch is more specific
than searching every scheduler constructor for queue stores. These table
slot addresses are derived lookup locations, not recovered target values.

The inner callable's capture fields are not shown being initialized beyond
its operation-table/active-wrapper pointers. Do not assume it captures `Q`
or `instrument_of`. The outer capture at `+0x10` is the event-vector object
address, not the scheduler base. Confusing those aliases could hide stores
shown by a decompiler as destination `+8` rather than scheduler `+0x100`.

The later 0x30-byte append inside this same function is a different vector:
`Q+0x128` begin, `Q+0x130` end, `Q+0x138` capacity. Its string is at record
`+0`, and the append advances six qwords. It cannot establish the earlier
0x40-byte queue's producer or string origin.

## Remaining unknowns and execution limitation

At the time of this saved-evidence frontier, the outer/inner table targets,
event `+0x20` source, and zero-flag fallback identity were unresolved. The
fresh static resolution below supersedes those gaps; it does not resolve the
separate `instrument_of` closure's construction site or observe runtime
execution.

At the time of the original saved-evidence pass, the next read-only
`binary_session` request had been rejected before execution because automatic
approval review reported the selected model was at capacity. The later fresh
static resolution below supersedes that tooling status; it does not change the
activation restriction.

## Fresh static resolution — 2026-10-29

The normal read-only `binary_session({})` route succeeded on this pass. It
reported Ghidra 12.1.4 available on arm64, with its installation, Java 25,
headless launcher, and native decompiler checks passing. `open_binary` then
opened the exact thin Mach-O above with the matching SHA-256 and profile
`966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`.

The two table words now resolve from initialized Ghidra memory:

| Table slot | Little-endian pointer | Function |
| --- | --- | --- |
| `0x1009be9c8` | `3cc7020001000000` | `FUN_10002c73c` |
| `0x1009bea48` | `10c8020001000000` | `FUN_10002c810` |

The slot reads are Evidence `ev_97908ac655caf72a947928e9873e2de30724dbbd6d3101b8e447113722c969aa`
and `ev_59c24876b504fa711dca597cf95438b99ee99cdf18c49e761f1656f2e1cb0edb`.
The outer invoker dossier is `ev_d3c5f88f935788f22eb4a12b575959867509853129425d03384e76bf53f75325`;
the nested writer dossier is
`ev_b06e3257d6ce2b529a7d4b0ba76a9e3fcb2a60611dd85d81ec4c31fe7075988d`.
The unique raw export is
[`rea-instrument-queue-writer-luna-2026-10-29c.json`](../../research/rea-instrument-queue-writer-luna-2026-10-29c.json)
(four records; 2,325,752 bytes).

Observed in Ghidra pseudocode/assembly, `FUN_10002c73c` loads the callable at
outer closure `+8`, dereferences its `+0x18` subobject, and dispatches that
subobject's operation at vtable `+0x30`, passing through the original argument
and the outer closure's `+0x10` destination. The computed call at
`0x10002a2c4` from `FUN_10002a158` reaches this outer invoker. The nested
operation is `FUN_10002c810`.

`FUN_10002c810` walks 0x48-byte entries in its first data argument, whose
container begin/end are at `+0x28` and `+0x30`. For each entry it copies the
entry's string object at `Track+0x10` into a 0x40-byte queue record at
`record+0x20`; the decompiler's record writes use the eighth-qword stride
(`puVar1[4]` / `puVar8[4]`), and the assembly shows the source load at
`0x10002ca48` and string-object stores at `0x10002ca4c..0x10002ca58`. It then
appends/copies these 0x40-byte records through the destination vector supplied
as the nested invoker's third argument. This directly resolves the record
writer and the string origin as a field read from each iterated Track object.
It does not show a call to the previously identified `instrument_of` invoker;
the queue string is copied from the Track field itself. The layout matches the
Track string field observed in prior lookup evidence, but equality of any
particular closure's returned value is not established by this writer.

Reader evidence resolves the shared object layout. `FUN_1000135c8`
(`ev_504dabced6cd1265ee1c0bd3f89546320c336cda6bc363f11af316e55b8144d0`)
parses a `chord_track` object with volume, pan, mute, solo, and instrument,
then parses a `tracks` vector in 0x48-byte rows. Each Track row includes id,
name, volume, pan, mute, solo, and instrument. Aggregate copy
`FUN_1000160d0` (`ev_a945429b891a7895511890ca5caa777e395338124c315c9715d1ccbefe4d5346`)
copies the ChordTrack prefix through its +0x10 string, then places the Track
vector at +0x28. The writer's Song-prefix record is therefore the parsed
ChordTrack entry, and each later row supplies a Track entry. This establishes
one Song-shaped layout for the reader, writer, and `instrument_of` lookup.

The writer also resolves the note-selection gate. Reader key mapping
identifies byte +8 as mute and byte +9 as solo. The writer computes `anySolo`
across the ChordTrack prefix and all Track rows. Each record gets its row's
volume at event +0x38 only when unmuted and either no row is solo or that row
is solo; otherwise volume is zero. The consumer reads +0x38 and proceeds
only when it is at least 0.0001, so muted rows and non-solo rows under an
active solo selection do not dispatch notes. The writer still constructs
those records. This gate applies to both the ChordTrack seed and each Track
row.

The `instrument_of` closure's branch semantics are now clear from this
layout: a nonzero flag requests captured Track-ID lookup; zero selects the
ChordTrack string at Song +0x10. Its creation site and flag initialization
remain unknown, but it is not part of this scheduler writer. The static
event path is closed through ProjectPlayer's active note-on callback to
`Soundfonts::noteOn` and its exact map-key lookup. Static findings do not
establish runtime execution. No activation bypass or capture was attempted.
