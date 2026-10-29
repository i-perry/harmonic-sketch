# Instrument callback join validation

Analysis only, 2026-10-28. Static observations concern original thin Mach-O `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`, Ghidra 12.1.4. No original activation bypass, implementation, or QA.

## Result

The application constructor installs the Soundfonts note-on callable into ProjectPlayer. This closes the callback-assignment gap, but does not recover the origin of the supplied string from a Track's persisted instrument descriptor.

## Actual dataflow

Use parent constructor object `P` to distinguish subobjects. Saved constructor evidence `ev_5431079b618c040a155572d76e0d7ed15fcc3d48a8059d4e84a1add7029818eb` (`FUN_100025e18`, in `research/rea-instrument-noteon-2026-10-28.json`) shows:

1. Soundfonts owner/capture is `P + 0x1218` (`P + 0x243 * 8`). Its note-on function wrapper starts at `P + 0x1250`, initialized with vtable `0x1009bdb10`, capture pointer at `P + 0x1258`, and active wrapper pointer at `P + 0x1268`.
2. ProjectPlayer starts at `P + 0x17c0` (`P + 0x2f8 * 8`). Its default note-on wrapper starts at `P + 0x17c8` with vtable `0x1009be458`, active wrapper pointer at `P + 0x17e0`.
3. Constructor instructions `0x100026cec` through `0x100026d2c` copy the active Soundfonts callable into temporary stack storage, choosing virtual heap clone `+0x10` or placement clone `+0x18`.
4. At `0x100026d3c`, it calls `FUN_100096bb4(&temporary, P + 0x17c8)`, then destroys the temporary.
5. `FUN_100096bb4` is the std::function swap operation: it exchanges active object pointers for heap cases, or uses clone/destruction slots to exchange inline objects. Consequently ProjectPlayer's default wrapper is replaced by the copied Soundfonts callable. Evidence `ev_22ed24e51e31ba065485b4c1326daadc90b0d0bc489a004fab8fb0d035273faf`.
6. Loader-adjusted bytes of vtable `0x1009bdb10` show `+0x10 = 0x1000ea280`, `+0x18 = 0x1000ea2b4`, `+0x30 = 0x1000ea2d0`. Evidence `ev_71d4390f1ad2ab6ab54417f711d3d1ded54a73dfb0fea02f48994ec4b4e826fc`.
7. Both clone implementations copy the original callable's captured pointer at `+8`, preserving its Soundfonts instance. Evidence `ev_8260096e88d4276ccff7fb30e1734511a26da37c7bb462c7b5505c78f1c9220c` and `ev_279bc40868cba8b8df348011c8de0b051dbc830f0ad6e549b61005dae578b196`.

Fresh four-record evidence is exported in ignored `research/rea-instrument-join-sol-2026-10-28.json`. The native analysis session was closed after export.

## RTTI caveat

`FUN_1000e649c` establishes target type identity only. The default ProjectPlayer note-on invocation `FUN_1000e6480` merely releases its by-value string and returns (saved evidence `ev_50ea595b5dc0ebf1f3cccb7c1acd28fc033e303309e3e65f26326b17b1c4ce6a`). Forwarding comes from the constructor replacement above, not from matching signatures or that empty default lambda.

## Soundfonts dispatch corrections and vectors

Saved `FUN_1000ea784` evidence `ev_bfbe0a34ec718afdbd549503245ff8b7fc447ce916c3b455d17f4e97214c4ac2` first searches for the captured exact string key, returning on an empty tree or failed search. Only after a successful search does it repeat a map-at lookup. Ordinary missing keys therefore return without a packet; the later `map::at: key not found` path is not the ordinary missing-key behavior.

For a found source it constructs status `0x90`, pitch `input & 0x7f`, velocity clamped to 0–127 after the observed floating-point rounding expression, timestamp copied from the double argument, and packet size 3. The integer is pitch here, not channel. No per-Track channel allocation is shown by this packet construction.

| Input condition | Static expected result |
| --- | --- |
| Empty map / absent exact key | No packet |
| Found key, pitch 60, velocity 1 | Bytes `90 3c 7f` |
| Found key, pitch 188, velocity 0 | Bytes `90 3c 00` |
| Found key, pitch 60, velocity 0.5 | Bytes `90 3c 40` under usual nearest rounding |
| Distinct found keys | Distinct map-selected source; packet status remains `90` |

These are derived vectors, not observed execution. NaN/extreme float behavior and nondefault floating-point rounding modes are not characterized.

## Remaining boundary

Recovered: actual Soundfonts callable construction, capture-preserving copy, installation into ProjectPlayer's note-on callback slot, callable target, exact-key-to-source lookup, and MIDI channel-0 packet construction.

Unresolved: which ProjectPlayer scheduling invocation supplies the string; the complete value flow from persisted Track.instrument through song lookup to that invocation; key creation and source-map insertion correspondence for each descriptor. Thus the constructor join must not be promoted into proof that the persisted instrument string is forwarded unchanged. No preset/bank/channel mapping is established upstream.
