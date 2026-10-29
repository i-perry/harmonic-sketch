# Instrument persistence and sound-source findings

This note traces what the shipped Klimper 2.4 ARM64 binary establishes about
instrument selection and audio routing. Static evidence now joins each parsed
Track or ChordTrack `instrument` string through the scheduler event queue to
the exact Soundfonts source-map key. The selector's command choice, key/path
grammar, and runtime behavior remain outside that closed static data path.

## Target and evidence

- Target: `research/Klimper-arm64`, SHA-256
  `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`.
- Analysis: REA 6.5.0 / Ghidra 12.1.4, ARM64, static shipped-artifact
  evidence. No activation or target runtime was used.
- The complete raw session export is held locally at
  `research/rea-instruments-resolution-2026-10-28.json`; it is excluded from
  the curated documentation commit along with other raw research artifacts.

## Proven pieces of the path

### Project descriptor and selector command

The project serializer `FUN_10000b590` writes an `instrument` property for
each Track and for ChordTrack by copying a string-shaped field from the model.
The project reader `FUN_1000135c8` decodes the property as a string-shaped value.
The serializer evidence is `ev_a58a7692fefa72c536843abab6d436e4b9b089c9cbdbe54923f6123e256bb084`;
reader evidence and its bounded pseudocode view are
`ev_c484b602aa9c689232d4a425f24d6c88d8741c6181502d5222e83daafe8f6991` and
`ev_59912403cd72e51b56ac3bbabc9f238374881e2b80b8fa185d909f3d71fd23a6`.
This proves persistence representation only; the string's schema and
interpretation are not present in that serializer/reader trace.

The binary contains RTTI for `polydigm::music::ui::InstrumentSelector`,
`show_instrument_selection`, and the command wrapper
`set_instrument_suggesting_trackname` (string inventory Evidence
`ev_c5e57fe94274aa0813eb46ae7580c2357292bafa02622f2b4e74e422ff691a6c`,
`ev_ad37926580b3c3dc174fe1d01c0d881269bf431d98b9f8a97ee1c43b4c0eb29b`,
and `ev_60b9a88a3ecd3a79564879acf9200660e05bd58067c4c4b38a42e5573f7aef29`).
The command-wrapper vtable data places `FUN_1000b2404`, `FUN_1000b24c0`, and
`FUN_1000b252c` in the same typed wrapper table (`ev_510db4bbac3f2e74d7cd28cb1aa1969ab25f247f7e6488e480e3c537ce032a14`).
The wrapper's vtable implementation `FUN_1000b2404` copies a string from the
command object into a model string field; its companion paths
`FUN_1000b24c0` and `FUN_1000b252c` copy the same string field in the other
direction / alternate command state. Evidence:
`ev_9507b4ef4eff10b1f51a3f45194cdff4f328ea76a6a5018d565cb67a0bd3dcb5`,
`ev_66b6fe6373e6454e8e1f6d98479eaba396766d0d0c1254a30c8dceff2d54c5f5`, and
`ev_2e7c9846a99391dbdfbc8d6252c13e4f63e20bad873306faccf3c63b3c98d310`.
The wrapper's type identity supports naming this operation as an instrument
setter, but static call resolution does not prove that the shown selector
constructs this exact command for every target type (Track versus ChordTrack).

### SoundFont source and preset lookup

The binary includes a `polydigm::music::Soundfonts` component, a constructor
typed as `Soundfonts(Project&)`, `noteOn(std::string, int, float, double)`,
`noteOff(std::string, int, double)`, and `_update_loaded_instruments`. The
corresponding string inventory is `ev_a4205054e8b02ae18c5b23c938a614b16b246f503a404143a837c69c1127e8cb`.
Its associated map type is
`std::map<std::string, std::unique_ptr<SoundfontAudioSource>>`, which shows
that Soundfonts manages named source objects. These type strings are identity
evidence; by themselves they do not prove which project field supplies the
map key or which method the player invokes.

The SoundFont loader `FUN_1000f6bf4` maintains loaded SoundFont IDs and a linked
list of loaded sources. It removes a source by ID or loads the supplied
filename through a loader callback, assigns an increasing ID, and then
re-evaluates program selection on configured channels. Evidence:
`ev_6db9bae686330e7776b82f347bf075feb10d88890e3030cb93d5e5622def8cca`.
The parser `FUN_1000f7a00` validates RIFF/SoundFont chunks and constructs
sample and preset records. It copies two 16-bit values from each preset record
into distinct fields, and uses the preset's name (or a formatted
`Bank%d,Preset%d` fallback label); field interpretation should not be inferred
from the fallback label alone. Evidence:
`ev_299da7d3cb5543917804ff0abd58e8d0d22f871c017e777568bb91737e7b55d1`.

The embedded synth's `FUN_100103394` handles channel program selection. It
rejects a negative channel, a channel outside the configured MIDI-channel
count, or a program greater than 127. It stores the requested program in
per-channel state, iterates available sound-source records, and invokes each
source's virtual preset lookup with bank/program candidates. Let `B` be the
channel's stored bank, `P` the requested program, and `D` the per-source bank
offset read from the source-ID mapping. The observed candidate sequence is:

| Channel bank | Ordered per-source bank/program candidates |
|---|---|
| `B != 128` | `(B - D, P)` for all sources; `(0 - D, P)` for all sources; then `(0 - D, 0)` for all sources when `P != 0` |
| `B == 128` | `(128 - D, P)` for all sources; then `(128 - D, 0)` for all sources |

The resolver takes the first successful source lookup and logs requested and
substituted bank/program values when it substitutes. `FUN_1000f6bf4` prepends
newly loaded SoundFonts to the source list, and the resolver traverses that
list from its head, so newer loaded sources are tried before older ones for a
given candidate. These are observed code-path behaviors; source-level names
for the channel and offset fields remain unresolved. Evidence:
`ev_fc6a496fa6cf9c9726c2525f554e26bfc6dd8dff6031e59723e2c1911c5aab47` and
`ev_6db9bae686330e7776b82f347bf075feb10d88890e3030cb93d5e5622def8cca`.

The SoundFont synth constructor `FUN_1000f45fc` initializes FluidSynth-style
settings, including `synth.drums-channel.active=yes`, `synth.midi-channels=16`,
and audio/effect channel defaults. Its initializer evidence is
`ev_ba8d4a2c71c7ad613d752ff7124f35164c9d44b1282c3649351cd55d604d4b1b`; the
string inventory for the settings is `ev_70fbfa1391fd39b11d412b3e6fae8ec14c9b78724c0a657b49e4cc0619590378` and
`ev_f65b7bad7fd185348149c8c543754c539b1b7a0126094afc5d57f90982648c16`.
The `yes` / `16` values are constructor defaults in this path, not proof that
the application exposes or preserves those settings.

### Application-level SoundFont loading

Beyond the generic source loader, `FUN_1000e709c` is a Klimper-level path that
constructs a synth, derives a file path from a project-associated object and
an input collection, and calls `FUN_1000f6bf4` with that path. It also builds
the named `last_used_soundfont.sf2` path and branches on values obtained from
the associated settings/map state. Its direct caller includes
`FUN_1000e6fdc`; `FUN_1000e6d84` serializes access to the same object state
before calling it. Function evidence:
`ev_a931bcaf57a41990e5bc95db8bfcbc892f2ca315699aac13ab288bd70aa402c2` and
`ev_cb358f7352bd1939c8154cec98c2ba9e4a09c9d0867ccbcbbcbb19bd593789ae`.
This establishes an app-side configured-file-to-loader path separate from the
embedded engine's bank/program resolver. The decompilation does not recover a
source-level name for the collection or its keys, nor does it show that these
file names originate in a Track's serialized `instrument` property.

The `ProjectPlayer::noteOn` closure type and `Soundfonts::noteOn` both have
the signature shape `(std::string, int, float, double)`. The former type
identity is referenced by the helper at `FUN_1000e649c`
(`ev_6b4ac5379e3355733dc7416d915cd2dff0e75d5c564f20634d8429a9d72dd99d`);
the latter is present in the Soundfonts type inventory cited above. Matching
signatures alone did not establish that the callback forwards to Soundfonts.
The constructor's callable copy and swap prove the join
(`ev_5431079b618c040a155572d76e0d7ed15fcc3d48a8059d4e84a1add7029818eb`,
`ev_22ed24e51e31ba065485b4c1326daadc90b0d0bc489a004fab8fb0d035273faf`). Its
callback vtable identifies the invoked Soundfonts lambda
(`ev_71d4390f1ad2ab6ab54417f711d3d1ded54a73dfb0fea02f48994ec4b4e826fc`).
The details are in
[instrument callback join validation](INSTRUMENT-JOIN-VALIDATION.md).
The parallel `music::instrument_of(Song const&, std::string&)` and
`music::instruments_in_use(Song const&, std::set<std::string>&)` closure type
strings (`ev_ce43d4f4b52c49a260fac1707f23a5832f82cb213ba735f78326e59f60e6c231`,
`ev_441a6bbfb1352c10acb241abbc24d24cc77d7c455f3bf066cc3679d3ccca0503`)
identify a song-wide lookup and collection operation. The actual
`instrument_of` invoker is `FUN_1000dbe90`, identified through its callable
table entry at `0x1009c16b8`; `FUN_1000dbecc` is only the RTTI manager/type
check, not the invoker (`ev_86f973677099eefb775be9bb8ad84d9753042aa95ee515ff57bba96168bac918`,
`ev_1150c820a4ca9743a601645c04720ba26641b153f059849b2aaba15de474877f`).
When the closure's captured flag at `+0x10` is nonzero, the invoker reads its
captured identifier at `+0x8`, scans the Song Track array at `Song+0x28..
Song+0x30` in `0x48`-byte records, compares each record's `+0x40` identifier,
and assigns the selected record's string at `+0x10` to the output. The helper
`FUN_100033174` throws `track not found` when the identifier is absent
(`ev_815924b92ce053f6096f9f38314977fffa110ad0c3b292433c9d31521eac338a`).
When the flag is zero, it copies the string from the Song argument at `+0x10`
directly. The parser and aggregate constructor establish that this Song
prefix is the `chord_track` value: the parser reads its nested
`chord_track.instrument` property, and `FUN_1000160d0` copies the 0x28-byte
prefix unchanged before placing the 0x48-byte Track array at `Song+0x28`.
Thus the closure's nonzero branch is Track lookup by captured ID, and its
zero branch is ChordTrack instrument fallback. Its capture creation site
remains unknown. The scheduler writer does not invoke this closure; it copies
the stored fields directly. The unique 40-record REA export is
[`rea-instrument-track-lookup-luna-2026-10-28.json`](../../research/rea-instrument-track-lookup-luna-2026-10-28.json). The 80-record closure follow-up is
[`rea-instrument-producer-join-luna-2026-10-29.json`](../../research/rea-instrument-producer-join-luna-2026-10-29.json). A further 107-record queue-frontier export is
[`rea-instrument-queue-frontier-luna-2026-10-29b.json`](../../research/rea-instrument-queue-frontier-luna-2026-10-29b.json).

The fresh parser, layout, and writer evidence is preserved in
[`rea-instrument-song-track-layout-luna-2026-10-29e.json`](../../research/rea-instrument-song-track-layout-luna-2026-10-29e.json)
and the focused writer export
[`rea-instrument-queue-writer-luna-2026-10-29c.json`](../../research/rea-instrument-queue-writer-luna-2026-10-29c.json).
Reader Evidence is `ev_504dabced6cd1265ee1c0bd3f89546320c336cda6bc363f11af316e55b8144d0`;
the aggregate layout constructor is
`ev_a945429b891a7895511890ca5caa777e395338124c315c9715d1ccbefe4d5346`;
the nested queue writer is
`ev_b06e3257d6ce2b529a7d4b0ba76a9e3fcb2a60611dd85d81ec4c31fe7075988d`.

### Parsed project fields through the scheduler

`FUN_1000135c8` parses the `chord_track` object and its `volume`, `pan`,
`mute`, `solo`, and `instrument` properties. It separately parses `tracks`
as 0x48-byte rows containing `id`, `name`, `volume`, `pan`, `mute`, `solo`,
and `instrument`. `FUN_1000160d0` copies the 0x28-byte chord-track prefix
unchanged into the aggregate, then copies the Track-row vector beginning at
`Song+0x28`. The resulting Track layout is volume at `+0`, mute/solo bytes
at `+8/+9`, instrument string at `+0x10`, name at `+0x28`, and identifier at
`+0x40`.

The scheduler's outer invoker `FUN_10002c73c` calls nested writer
`FUN_10002c810` with the captured event-vector destination. The writer
receives the Song-shaped value at provider `P+0x108`; it first builds a record
from the Song prefix, then one record per 0x48-byte Track row. It copies the
instrument string at source `+0x10` to event-record `+0x20` in both cases.
The first record therefore carries ChordTrack's stored instrument string;
the later records carry each Track's stored string. This scheduler path does
not call `FUN_1000dbe90` or use an `instrument_of` return value.

The writer ORs the solo byte across the Song/ChordTrack prefix and all Track
rows. For each record it writes that row's volume to event `+0x38` only when
the row is not muted and either no solo is selected or the row itself is
solo; otherwise it writes zero. The event consumer reads `+0x38` and skips
note dispatch below `0.0001`. Thus mute and solo selection gate note dispatch
through volume, while the writer still constructs the records.

`FUN_10002a158` copies event `+0x20` and passes it with pitch, velocity, and
scheduled time to ProjectPlayer's active callback field at subobject `+0x20`.
The constructor-installed callback is the Soundfonts callable described in
[instrument callback join validation](INSTRUMENT-JOIN-VALIDATION.md). It
passes the string to `Soundfonts::noteOn`, whose source map performs an exact
key lookup. This closes the static model-to-map-key path for Track and
ChordTrack instruments. Evidence for the dispatcher/consumer is
`ev_228c2e14fb3d1d864574bcca34bf4c86ac204af8760d44f5a756b7074134d046`;
the writer dossier is
`ev_b06e3257d6ce2b529a7d4b0ba76a9e3fcb2a60611dd85d81ec4c31fe7075988d`.
Raw records are in
[`rea-instrument-song-track-layout-luna-2026-10-29e.json`](../../research/rea-instrument-song-track-layout-luna-2026-10-29e.json)
and [`rea-instrument-queue-writer-luna-2026-10-29c.json`](../../research/rea-instrument-queue-writer-luna-2026-10-29c.json).

### Soundfonts note-on dispatch

The implementation associated with `Soundfonts::noteOn(std::string, int,
float, double)` dispatches the supplied values through the source map at
`this + 0x1d0`. `FUN_1000ea2d0` constructs the map callback and runs it under
the object's shared-mutex path; its callback body is `FUN_1000ea784`, whose
RTTI names it as a lambda inside `Soundfonts::noteOn`
(`0x1003bb027`; string-search evidence `ev_1b9358c1fc7e1be7226de4cf84168b8bd8ffa1aabd31b231b64aa020fdb34bf3`).
The function bodies are `ev_42eaac4c4a687461b9636a03c4fa818bcad822ad2784fc3ae1e8915f281256e9`
and `ev_7c602dfbb6076e17f94028ae34ba9ec8c03b74dceabe316cec909cc378e9fee9`.
The callback looks up its captured string as an exact map key; a missing key
reaches the `map::at: key not found` failure path. For a found source, it
builds a three-byte MIDI note-on event with status `0x90` (MIDI channel 0),
pitch `inputPitch & 0x7f`, and velocity derived from the float input times 127,
bounded to 0–127. It passes the supplied double alongside that packet to
`FUN_1000f677c`, which copies the event and invokes the source's synchronized
output handler. Evidence for packet construction and forwarding is the
callback body above and `FUN_1000f677c`
(`ev_e86d751e33be46344c2ff0ed1eb7c0933af4094e34635d69b18b3a08740f854e`).

This closes the key-to-loaded-source lookup inside `Soundfonts::noteOn` and
shows channel 0 in that event construction. The constructor installs the
Soundfonts callable into ProjectPlayer's note-on callback slot. The scheduler
trace above establishes that parsed Track and ChordTrack instrument strings
reach this callback and are used as the exact map key.

## Current evidence boundary

The traces establish these endpoints:

```text
Track / ChordTrack string field
  -> project JSON `instrument` string

InstrumentSelector and set_instrument_suggesting_trackname command
  -> command code copies a string into a model string field

ProjectPlayer note-on callback slot
  -> constructor-installed Soundfonts callable
  -> Soundfonts noteOn(string, ...)
  -> map<string, unique_ptr<SoundfontAudioSource>>
  -> app-configured `.sf2` path -> SoundFont loader
  -> exact source-key lookup -> MIDI note packet (channel 0)
  -> loaded SoundFont preset/source lookup and channel/bank/program fallback

Track `instrument`
  -> parsed Track row +0x10
  -> scheduler event +0x20
  -> ProjectPlayer callback -> Soundfonts exact source-key lookup

ChordTrack `instrument`
  -> parsed Song prefix +0x10
  -> scheduler's initial event +0x20
  -> ProjectPlayer callback -> Soundfonts exact source-key lookup
```

`FUN_10002a158` first clears the scheduler's `0x40`-byte event vector, then
dispatches an indirect provider callback with the vector destination, and only
after that call reads event records. It copies each record's string at `+0x20`
and passes it with pitch, velocity, and scheduled time to the active callback at
the ProjectPlayer subobject's `+0x20` field
(`ev_228c2e14fb3d1d864574bcca34bf4c86ac204af8760d44f5a756b7074134d046`).
The constructor evidence identifies that active field as ProjectPlayer's
replaceable note-on callback. The provider invokers and direct Track/ChordTrack
field copies are now resolved in [QUEUE-PRODUCER-VALIDATION.md](QUEUE-PRODUCER-VALIDATION.md).
The `instrument_of` closure is 0x18 bytes: its
callable table is followed by an identifier qword at `+0x8` and a flag at
`+0x10`; its clone and inline-copy helpers preserve both captured words
(`ev_afdac7cc58745e0abbc1b4f5795967761a31035d2f9dd8a4580344bceac12f6e`,
`ev_490cce365a3400b12502f5b3cd535159740bfe6eb7608252e5a41392006cab9e`,
`ev_2eea2600758741f3f5f9afef4ffe5ced82ea9b02b42f78b2b3e218a729953312`,
`ev_86518c89d75df9130482a0bc1c03a1ad670a5524497558aa42846c507b243514`).
The ChordPreview constructor `FUN_1000da3dc` copies/queries this callable during
its setup (`ev_14785251120af5e72ad6de1eb13d1785e9e15aa0705568405089801569066b80`);
that is evidence of one consumer, not evidence that it creates scheduler
events. The capture flag's creator remains unresolved; its nonzero Track and
zero ChordTrack branch meanings follow from the reader layout and lookup body
above. A separate timer-path trace confirms `FUN_100029860` calls
`FUN_100029c04` refreshes timing/provider state before the timer calls `FUN_10002a158` (`ev_3b122064a52746ac6829090709626e2a74f65cc2c9e55d7f211346eeb7ffee4`, `ev_0a792faf5f8b6200ace93d40f28cd8bccbcbb40b516bfb653882c7d5cb135de2`). Within `FUN_10002a158`, the outer provider callback captures the event-vector destination and receives provider object `+0x108`; its invoker slot `0x1009be9c8` resolves to `FUN_10002c73c`, which dispatches nested invoker `FUN_10002c810` from slot `0x1009bea48`. The nested writer copies the ChordTrack prefix and Track-row instrument strings into event `+0x20`; this completes the static model-to-Soundfonts path described above. The `instrument_of` closure creator remains outside this scheduler flow. Full boundary and validation details: [QUEUE-PRODUCER-VALIDATION.md](QUEUE-PRODUCER-VALIDATION.md).

The remaining gaps are which exact string the selector returns and which
command it creates for Track versus ChordTrack; whether that string identifies
a SoundFont file, named preset, or combined catalog item; and the configured
source collection's key/path grammar. The static model-to-map-key flow is
closed, but the app-side configured `.sf2` path has not been joined to the
map-key namespace or to a selected preset. The Soundfonts callback emits
status `0x90` (channel 0); that packet does not establish per-Track channel
assignment. The engine's bank/program candidate sequence is specified above,
but no project-level mapping from instrument key to selected bank/program has
been recovered.

## Evidence needed to close the trace

1. Recover the selector callback's chosen value and its exact command creation
   call into `set_instrument_suggesting_trackname`, separately for Track and
   ChordTrack targets.
2. Recover the app-side configured source collection's key/path grammar and
   connect it to the loaded `.sf2` source and enumerated preset records. The
   embedded resolver's fallback sequence and Soundfonts-side channel-0 packet
   are specified above; project-level routing remains open.

Reconstruction should preserve the serialized instrument string. Keep the
selector-to-command association and key-to-file/preset mapping unresolved.
Do not substitute a General MIDI program table based only on the embedded
SoundFont parser or `bank/program` logging strings.
