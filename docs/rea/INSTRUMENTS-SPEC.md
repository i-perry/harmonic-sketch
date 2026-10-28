# Instrument persistence and sound-source findings

This note traces what the shipped Klimper 2.4 ARM64 binary establishes about
instrument selection and audio routing. It separates the app's string-valued
project descriptor from the embedded SoundFont engine's bank/program lookup.
The static evidence does **not** yet join those two paths end to end, so this
is a bounded partial specification rather than a recovered mapping contract.

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

## Current evidence boundary

The traces establish these endpoints:

```text
Track / ChordTrack string field
  -> project JSON `instrument` string

InstrumentSelector and set_instrument_suggesting_trackname command
  -> command code copies a string into a model string field

Soundfonts noteOn(string, ...)
  -> map<string, unique_ptr<SoundfontAudioSource>>
  -> loaded SoundFont preset/source lookup
  -> channel + bank/program candidate selection and fallback
```

They do **not** prove the arrows between those endpoints: which exact string
the selector returns, whether it identifies a soundfont file, a named preset,
or a combined catalog item; whether Track and ChordTrack resolve identically;
how the project/player binds each Track to a channel; or whether the project
string is passed directly to `Soundfonts::noteOn`. The app's visible output
callback and the embedded engine's MIDI channel selection are also not yet
joined by a complete static call/data-flow trace. The engine's candidate
sequence is specified above, but there is no validated end-to-end vector from
a project descriptor to a selected preset or an allocated MIDI channel.

## Evidence needed to close the trace

1. Recover the selector callback's chosen value and its exact command creation
   call into `set_instrument_suggesting_trackname`, separately for Track and
   ChordTrack targets.
2. Trace the runtime `ProjectPlayer`/output callback from a specific Track
   record to `Soundfonts::noteOn`, retaining the actual string argument and
   channel argument through the indirect call boundary.
3. Connect the source string key to a loaded `.sf2` source and its enumerated
   preset records; then connect the selected source/preset to each Track's
   MIDI channel. The embedded resolver's fallback sequence is already
   specified above, but the project-level input values and channel ownership
   remain open.

Until those connections are proven, reconstruction should preserve the
serialized instrument string and model track/output bindings as unresolved.
Do not substitute a General MIDI program table based only on the embedded
SoundFont parser or `bank/program` logging strings.
