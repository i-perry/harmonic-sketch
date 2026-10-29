# Instrument queue callback validation packet

## Question for the next static pass

Record the scheduler writer and its direct string source, connect parsed Track/ChordTrack values to the ProjectPlayer/Soundfonts callback, and distinguish that path from the separate `instrument_of` closure. The queue writer, data layout, mute/solo gate, and closure branch meanings are now resolved; the closure creation site remains open.

Target is the installed `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41` (Ghidra 12.1.4; REA profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`). Keep analysis static and source-immutable. Activation remains blocked; no bypass or runtime capture is part of this packet.

## Known objects and offsets

Use symbolic pointers until a static def-use chain identifies their owner. The existing evidence does not supply runtime pointer values.

| Symbol | Static meaning | Layout/evidence |
|---|---|---|
| `Q` | Scheduler context passed as `param_2` to `FUN_10002a158` | Event vector begin at `Q+0xf8` (`param_2[0x1f]`), end at `Q+0x100` (`param_2[0x20]`); records are 0x40 bytes. At function entry it clears this vector, passes its destination to a provider callback, then reads the populated records and copies string object at record `+0x20`. `FUN_10002a158`, `ev_228c2e14fb3d1d864574bcca34bf4c86ac204af8760d44f5a756b7074134d046`; detailed stores in [QUEUE-PRODUCER-VALIDATION.md](QUEUE-PRODUCER-VALIDATION.md). |
| `N` | Active ProjectPlayer note-on callback subobject | Consumer calls its active callback slot at subobject `+0x20` with copied string, pitch, velocity and timestamp. Constructor-to-Soundfonts assignment is specified in `INSTRUMENT-JOIN-VALIDATION.md`. |
| `T` | Timer/player context passed to `FUN_100029860` | `FUN_100029860` calls queue consumer `FUN_10002a158`; direct callers are `FUN_1000295e0(T)` and `FUN_10002980c(W)` where the latter passes `W-0x148`. Caller evidence `ev_1a6c8febd00e1a63546b24989426b587655169acdac80978ea1fc06e9f90a02d`. The precise relation between `T` and `Q` should be derived from the relevant owner constructor/layout rather than assumed from the common timer call. |
| `C` | `instrument_of` callable closure | Operation table at global `0x1009c1688`; confirmed invoker slot `0x1009c16b8 -> FUN_1000dbe90`. Closure layout: vtable at `+0`, captured identifier qword at `+8`, capture flag at `+0x10`. Invoker evidence `ev_86f973677099eefb775be9bb8ad84d9753042aa95ee515ff57bba96168bac918`; callable-table bytes `ev_2b40f61126d54583b0b5c956230bdf1be40d3a0dad4ae92fa0ad9faf5d8aef8f`. |
| `Song`, `Track` | Lookup inputs to `C` | With nonzero `C+0x10`, invoker searches Song's Track range `Song+0x28..+0x30`, stride 0x48, compares ID at Track `+0x40`, and copies the string at Track `+0x10`; missing ID throws. With zero flag it copies Song argument `+0x10`, which parser/aggregate evidence identifies as `chord_track.instrument`. Evidence `ev_815924b92ce053f6096f9f38314977fffa110ad0c3b292433c9d31521eac338a` plus fresh reader/layout export below. The closure's creator and flag initialization remain unknown. |

`FUN_10002a158` is both dispatcher and consumer: it clears queue `Q`, constructs an inner callable with table `0x1009bea18`, then an outer callable with table `0x1009be998`. The outer callable captures the inner wrapper address at `+8` and destination `Q+0xf8` at `+0x10`. It obtains provider object `P=*(Q+0xf0)`, takes a shared lock at `P+0x60`, and calls outer invoker slot `0x1009be9c8` with `P+0x108`; the nested callable invoker slot is `0x1009bea48`. The function then reloads `Q+0xf8..Q+0x100`, copies each record string from `+0x20`, and dispatches it. `QUEUE-PRODUCER-VALIDATION.md` cites the exact assembly addresses.

At the time of the initial saved-evidence review, none of the retained bundles
contained these table values or the event-string construction. The fresh
resolution below supersedes that earlier boundary. The separate timer refresh
`FUN_100029c04` only updates timing/provider state before the dispatcher
(`ev_3b122064a52746ac6829090709626e2a74f65cc2c9e55d7f211346eeb67ffee4`,
`ev_0a792faf5f8b6200ace93d40f28cd8bccbcbb40b516bfb653882c7d5cb135de2`).

## Exact validation sequence

1. Completed: slots `0x1009be9c8` and `0x1009bea48` resolve to `FUN_10002c73c` and `FUN_10002c810`, respectively.
2. Completed: `FUN_10002c810` iterates the parsed Song Track vector at `+0x28`, stride 0x48, and appends 0x40-byte records. Reader evidence shows the Song prefix is the parsed ChordTrack value, while each row is a Track. Do not confuse the separate 0x30-byte vector at `Q+0x128..+0x138` (string at record `+0`) with the 0x40-byte event queue.
3. Completed: the writer copies source `+0x10` directly into event `+0x20`; it does not call `C`. Parser evidence identifies the root prefix as ChordTrack and each 0x48-byte row as Track. The full reader/layout/writer evidence is in `rea-instrument-song-track-layout-luna-2026-10-29e.json`.
4. The `instrument_of` invoker's branch meaning is now established: nonzero flag selects the captured Track ID, zero flag copies the ChordTrack instrument at Song `+0x10`. The closure's construction site and flag initialization remain unresolved; that is separate from the scheduler's direct-copy path.
5. Completed statically: event `+0x20` is copied to the active ProjectPlayer callback at `N+0x20`, whose constructor-installed target is Soundfonts `noteOn`; the string is used as an exact source-map key. This does not observe a runtime event.

The static record addresses above are Ghidra virtual addresses, not live process pointers. No runtime pointer snapshot is currently retained. If a future controlled capture becomes authorized and available, record actual `Q`, `P`, queue begin/end, outer/inner closure pointers, captured destination, and `instrument_of` closure fields for one event. Do not infer those live values from decompiler stack temporaries.

## Retained evidence to reopen

- [`rea-instrument-track-lookup-luna-2026-10-28.json`](../../research/rea-instrument-track-lookup-luna-2026-10-28.json) — 40-record `instrument_of` lookup and Track layout.
- [`rea-instrument-producer-join-luna-2026-10-29.json`](../../research/rea-instrument-producer-join-luna-2026-10-29.json) — closure copies, operation table, ChordPreview consumer boundary.
- [`rea-instrument-queue-frontier-luna-2026-10-29b.json`](../../research/rea-instrument-queue-frontier-luna-2026-10-29b.json) — 107-record timer/queue frontier, including the confirmed consumer and refresh boundary.
- [`rea-instrument-song-track-layout-luna-2026-10-29e.json`](../../research/rea-instrument-song-track-layout-luna-2026-10-29e.json) — fresh parser, aggregate layout constructor, table values and queue writer.
- [`rea-instrument-queue-writer-luna-2026-10-29c.json`](../../research/rea-instrument-queue-writer-luna-2026-10-29c.json) — focused outer and nested invoker evidence.
- [`rea-instrument-scheduler-luna-2026-10-28.json`](../../research/rea-instrument-scheduler-luna-2026-10-28.json) — scheduler timing and queue-consumer context.
- [`rea-instrument-noteon-2026-10-28.json`](../../research/rea-instrument-noteon-2026-10-28.json), [`rea-instrument-join-sol-2026-10-28.json`](../../research/rea-instrument-join-sol-2026-10-28.json), and [`rea-instrument-joins-2026-10-28.json`](../../research/rea-instrument-joins-2026-10-28.json) — callback construction and Soundfonts endpoint joins.

All listed raw bundles are local research artifacts; preserve each unique export and keep them out of curated documentation commits. The static path from parsed Track/ChordTrack instrument to event `+0x20`, ProjectPlayer, and the Soundfonts source-map key is closed. Remaining unknowns are the instrument selector's command association, the source-map key/path grammar, and the separate `instrument_of` closure's construction site. The timer/Song object's ownership relationship is represented only through the provider argument/layout observed in this pass; no runtime pointer identity is claimed.

## Fresh static result — 2026-10-29

The original target opened successfully in Ghidra 12.1.4 after the normal
read-only session-status call reported the provider available. Its SHA-256
matches the target above. Fresh evidence is preserved in
[`rea-instrument-queue-writer-luna-2026-10-29c.json`](../../research/rea-instrument-queue-writer-luna-2026-10-29c.json).

The outer table slot `0x1009be9c8` resolves to `FUN_10002c73c`; the nested
slot `0x1009bea48` resolves to `FUN_10002c810`. The outer invoker dispatches
the inner callable with the captured destination. The nested writer iterates
0x48-byte Track-shaped records and copies each record's string object at
`+0x10` into each 0x40-byte event record at `+0x20`, then appends/copies those
records to the supplied vector. Its decompiler shows the field copy directly;
assembly at `0x10002ca48..0x10002ca58` loads and copies the string object.
This writer does not call `instrument_of` invoker `FUN_1000dbe90`; no closure
return participates in this scheduler path. Reader evidence shows that the
Track field comes directly from the serialized Track `instrument` property.

Evidence IDs: outer invoker `ev_d3c5f88f935788f22eb4a12b575959867509853129425d03384e76bf53f75325`;
nested writer `ev_b06e3257d6ce2b529a7d4b0ba76a9e3fcb2a60611dd85d81ec4c31fe7075988d`;
table reads `ev_97908ac655caf72a947928e9873e2de30724dbbd6d3101b8e447113722c969aa`
and `ev_59c24876b504fa711dca597cf95438b99ee99cdf18c49e761f1656f2e1cb0edb`.
The `instrument_of` capture-flag construction remains unresolved. Its
nonzero Track-ID and zero ChordTrack fallback meanings are established by the
reader/layout evidence below. No runtime capture or activation bypass was
performed.
