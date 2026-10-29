# Focused voicing validation, 2026-10-27

Target: `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`; Ghidra 12.1.4 profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. Static observations only. The underlying REA session exports remain in the local research workspace and are not included in this source snapshot. Original activation remains blocked; no bypass or execution was attempted.

## Validated palette provenance

The type-name bytes at `0x1003bfcdb` explicitly identify `ChordPaletteContent::_item_creation(chords::Entry)` returning `ChordPaletteItem*` (`ev_f4520b0ee657b26f141425cb02f15367f0a18d13ea304e356fa2532b5c9fa6fe`). Its creator `FUN_1000d7528` allocates a 0x270-byte item, copies the entry root/interval set to offsets 0xf0/0xf8, installs vtable `0x1009c20d8`, and writes the shared state pointer to item offset 0x268 (`ev_bc11b34b51319b395e04e50e0caa143d52eb80c27e4150c9f00ee3db63cbecce`). Vtable bytes place `FUN_1000d95ec` at +0x28 and `FUN_1000d97a8` at +0x30 (`ev_f5e34ebd5097703207cce6e9473d4a6c2844a480de8a2edf2412fcd73d78f645`). Thus these producer callers belong to palette items, not an anonymous persistence path.

`FUN_1000d95ec` compares the item's chord with the optional at item+0x138. A different/disengaged chord is copied into that optional and passed to `FUN_1000309b0` with state=item+0x268. An equal chord clears the optional and disables the state+0x40 activity flag, then calls the reset helper (`ev_4aecb40d8326d863717f7bfba2d85414d1221fa80e3b61e06f245bc50f85f5bc`). This is a toggle-trigger action; naming it audition is an inference supported by note production/activity toggling, not an observed mouse gesture.

`FUN_1000d97a8` generates notes at velocity scalar 1, copies/sorts them, embeds them in a chord record, serializes the record and passes a string-like payload to `FUN_10033705c` on a dynamically located ancestor (`ev_8a43a89c384acbd5fb8341674d0ebef0cca0fdf5935ecf425f706053575199d8`). It is a palette transfer path; the exact UI gesture remains unverified.

## Corrected callback provenance

Do not treat `FUN_100030c88`'s object+0x108 as an optional chord. Its assembly loads a returned float from stack offset 4 into s0 (`ev_351a45a575f7b9646b42656d5cbffa20508c397dcfadc646112e1a55969c4e0f`). `FUN_1000309b0` passes the stack function object at vtable `0x1009c1368`; that table's +0x30 slot points to `FUN_100033010` (`ev_c52c8523b7947e9f55b788f879d08d2b6f708aad282034f9a70db7bcacc834b2`). Type-name bytes beginning `0x1003be720` name `Project::get<float>` and `effective_velocity`, with callback signature `void(Song const&,float&)` (`ev_ecdc0e4b1b1aaacf51b1a5eb37d3cbb606296eea83ef44fa3e17c156b2d5944c`). The invoker reads a Song-like collection and writes a float result (`ev_47c492f6e09d63e632decf05d81855beb23c0154036d5f8f4638559ebe54f8ef`). The palette trigger therefore uses effective song velocity as the producer scalar. The earlier optional-chord interpretation conflated a neighboring `ChordPalette::trigger_chord(optional<Chord>)` RTTI string with this generic Project reader. That neighboring name is real (`ev_962ab5f27322960ee948eb55329455782fb8f95495bc8dc1c1a611f34716c16b`) but does not type object+0x108.

## Validated constructor algorithm

Pseudocode `ev_e8aa3785202f6fe1c0c58dcef50f78d7800c880e035c7b6b43e18770ceac1928`, instructions `ev_58415af958697e4600e55e8216b5576f05a64ba16ddd68d1f8171536ed0e3ae6`:

1. Emit root, then root+each ordered ushort interval, as 24-byte note records. Initial position=0, length=10368, velocity=float32(state+0x28)*scalar.
2. For note index i, compute offset=truncateTowardZero((double(state.int64(+0x20))/10368.0)*i*10368.0). Position=offset; length=max(162,10368-offset). Preserve the floating operations if exact edge parity matters.
3. Compute normalized pitch class from the FIRST record's pitch, i.e. root. State+0x300 stores a pointer; load the signed int threshold through that pointer. If root pitch class<threshold, add 12 to EVERY note. Instructions `0x1000310dc` and `0x10003111c`–`0x100031128` establish first-note load, pointer dereference and signed comparison. This corrects HARMONY.md's earlier final-pitch/unsigned-threshold wording.
4. Add 12*state.int32(+0x18) to every pitch.

This preserves root position. It does not invert individual voices or perform voice-leading optimization. A separate constructor initializes one embedded `ChordPreviewPlayer` instance with register 4, but the saved trace does not establish that this is the same instance passed to the palette producer or expose setters for its settings. It therefore does not by itself establish the palette's default MIDI pitches.

## Derived vectors, not runtime observations

For root=0, intervals={4,7}, register field=4, threshold=0, strum field=0, velocity field=0.8, scalar=1: pitches [48,52,55], all positions 0, lengths 10368, velocity float32(0.8).

Same input with threshold=1: pitches [60,64,67]. This distinguishes FIRST/root-pitch comparison from an incorrect final-G comparison.

Root=11, intervals={4,7}, register=4, threshold=1: [59,63,66]. No threshold octave is added.

Root=0, intervals={4,7}, register=4, threshold=0, strum=5184: positions [0,5184,10368], lengths [10368,5184,162]. With scalar=0.5 and velocity field=0.8, velocity is float32 multiplication approximately 0.4 for each note.

Unknowns: root-threshold mutation/defaults, producer gain setters, exact gesture-to-vtable slot dispatch, candidate quality enumeration/filter/order, sort tie behavior, and palette score-to-color mapping. The preview-settings-to-producer alias is resolved by the constructor argument/store trace below. Do not promote any remaining unknown to source parity.

## Clone integration boundary

`Sources/HarmonicSketch/NativeChordVoicing.swift` is an isolated transcription of the observed constructor with explicit inputs. The constructor trace now proves that the Octave and Strumming settings write the same shared state fields consumed by the palette producer. Root threshold and gain/default mapping remain unresolved. The earlier tests and app behavior are clone evidence, not a claim of native parity; no implementation or QA was done in this analysis pass.


## Settings and constructor binding trace, 2026-10-28

The complete 49-record REA session export remains in the local research workspace and is not included in this source snapshot.

The preview settings view builder `FUN_1000ed758` reads a `preview` settings object and exposes `octave` from a 32-bit value at object offset `+0x23d0`, `strumming` from a signed tick value at `+0x23d8` divided by 10368 for display, and `velocity` from a float at `+0x23e0` (`ev_b62d86919b48decb89d09d05552bc09d152f01d866f0aff0d5ccd059f5755f64`). The persistence loader `FUN_1000eac00` reads the same nested `preview` keys; it stores the strumming value as `long(floatValue * 10368.0)` and stores the velocity as a float (`ev_dea38e020dd8eee09fc93b109ae7037ea2bae3caf65bc2bf74627df926eae93f`). This establishes a 10368-based setting representation for strumming and its visible value conversion. This persisted settings object is a separate path; the direct binding of the `PreviewSettings` controls to the palette producer state is established below.

In constructor `FUN_100096e9c`, an object with the `ChordPreviewPlayer` vtable is placed at owner offset `+0x300`. That instance is initialized with register `4` at player `+0x18`, spacing `0` at `+0x20`, and float `1.0` at `+0x28`. Its pointer field at player `+0x300` is set to owner `+0x230`, which the constructor initializes from global `DAT_1009ec850` (`ev_304feb91e477e5c78208cdb1c1c7b2e1177236bd162af702b9ce6dd8d5f7d46b`). The chord producer dereferences this pointer for its signed root-pitch-class threshold. The global's source-level meaning and any live mutation path into this particular instance remain unproven.

The palette item creator `FUN_1000d7528` copies a shared player/context pointer from its `ChordPaletteContent` owner into item `+0x268` (`ev_3f3aef684cce709ca00aeb45f42278d7db9c7c4f74d81606db01e4013385fef9`); the item preview action passes that pointer to the preview producer (`ev_bc11b34b51319b395e04e50e0caa143d52eb80c27e4150c9f00ee3db63cbecce`).

The `PreviewSettings` type-name bytes identify a constructor taking `ChordPreviewPlayer&` and a settings-panel callback (`ev_03a38c796d8efc837ebbcfdae40a8437724ba0d41c5bdfbf9f1d6e18b9624b2d`). Its view function `FUN_1000c6538` builds Strumming choices for tick values `0`, `0xa2` (162), and `0x144` (324), then Octave choices for integers 12 through 0. The selection predicates read fields `+0x20` and `+0x18` through a pointer at the captured object's `+0xf0` (`ev_15e35178954820df74040d36c95db7d794a870f481ca679a50e05c043576b95b`). The corresponding selection callbacks write those same nested fields: `FUN_1000c7038` stores 0 (`ev_a0c95b0d083da5bb11a246fda7e306f2136dd1c272399482dcdfd20d1573e51a`), `FUN_1000c6f6c` stores 162 (`ev_0b7ad1c5ce832c86f82621a0442afd968551dcc3be78e5e045ba5828ef00ebc3`), `FUN_1000c6ea0` stores 324 (`ev_98f6f60649abaee94be8c605b179ed4c4aa860fcdc4aadc03175411b6028d692`), and `FUN_1000c6dd4` stores the selected register value (`ev_18e8ceb783fb8381c9c2558f33b35c8134c3837cb51e8721f86403b412195b68`). No gain setter appears in this settings panel.

### Direct alias proof for palette settings

The previous pass left the nested `+0xf0` pointer unresolved because it had not followed the two captured `this` pointers or the constructor's incoming ABI argument. The new static trace proves both paths store and later use the same pointer; this conclusion is based on actual stores and loads, not coincident field offsets:

1. In the outer constructor `FUN_10008e050`, `x11` is formed as `this + 0x410` at `0x10008ed1c`, and stored at stack slot `sp+0x108` at `0x10008ed7c`. At `0x10008f1c4` that slot is loaded into `x20`; `x4` is set to `x20` at `0x10008f1e0` and passed to `FUN_100096e9c` at `0x10008f1e4`. The same stack slot had earlier held a CoreText font value, but the store at `0x10008ed7c` overwrites it before this constructor call. Evidence: `ev_d7fe2d9b7c3519b984741be617d29af827a000b856ced0b7c0c493ac0083b462`.
2. `FUN_100096e9c` saves this incoming `x4` as `x28`. The `_item_creation` closure captures `this+0x620` (`0x1000974b8`–`0x10009757c`); the state field at `this+0x7a0` is set directly from `x28` at `0x100097568`. `FUN_1000d7528` reads captured-owner `+0x180` (equivalent to that `this+0x7a0` field) and copies it unchanged to `ChordPaletteItem+0x268`. Evidence: `ev_c03c7765098f5a226ffb95b7eb8e1dac84b22cfb7e7888f1b297a379c4938930`, `ev_538833cb679152a249adb473ffd8394ff7183ea042230e67927ef9ae3fb5dba3`.
3. The settings view closure captures a subobject at `this+0x19d8` (`0x10009891c` and `0x10009897c`). `FUN_100096e9c` stores the same saved `x28` value at `this+0x1ac8`, exactly the captured object's `+0xf0` pointer slot (`0x100098938` and the following store). `FUN_1000c6538` dereferences that `+0xf0` pointer and reads the player fields; its callbacks write through the same pointer to offsets `+0x18` and `+0x20`. Evidence: `ev_c03c7765098f5a226ffb95b7eb8e1dac84b22cfb7e7888f1b297a379c4938930`, `ev_39cf63bad2c2e0b5b39c4ac37339ebb1e1524b382ac1eb31da226531e542908b`, `ev_18e8ceb783fb8381c9c2558f33b35c8134c3837cb51e8721f86403b412195b68`, `ev_7e6af3e043e7c1937b79923c097ad624e0307a55dc3d6bd98279129c72424c16`, `ev_98f6f60649abaee94be8c605b179ed4c4aa860fcdc4aadc03175411b6028d692`, and `ev_4b0dc38ea090d3cc8dfd9e898e0c5199dc30b1d853bf21307a691449122b9729`.
4. `ChordPaletteItem` preview passes item `+0x268` unchanged to `FUN_1000309b0`; that function forwards it as `FUN_100030dc0`'s state argument. The producer reads state offsets `+0x18`, `+0x20`, `+0x28`, and `+0x300` directly. There is no base-adjusting thunk between the settings pointer and this producer state in these observed paths. Evidence: `ev_cd413e65a194119f64719aedcc168277bbc8b3f9de70c29fd7f1e861cfe0a6cb`, `ev_e40e0a86a2ebd6f655ee565f000b634ee3930558708de73b4c82871da48bc9a8`, and `ev_e8aa3785202f6fe1c0c58dcef50f78d7800c880e035c7b6b43e18770ceac1928`.

The x4 pointer is the same `this+0x410` address from the outer constructor, passed unchanged into both stores. Therefore the palette's Octave choices 0–12 drive the producer's signed register field at `+0x18`, and its Strumming choices 0/162/324 drive the producer's tick field at `+0x20`. The gain field at `+0x28` and signed root-PC threshold reached through `+0x300` remain distinct producer inputs with no setter/default established by this panel. The separate embedded player initialized to register 4 / spacing 0 / gain 1.0 in `FUN_100096e9c` must not be substituted for the shared x4 state without further constructor/use evidence.

The global `DAT_1009ec850` and the producer threshold are still not mapped to a UI control or a confirmed default. The settings-panel trace exposes no gain field. Register and strumming bindings are proven; gain and root-threshold controls/defaults remain unresolved.

The recovered palette vtable exposes distinct preview-trigger and transfer callbacks, but the exact UI gesture dispatch and whether insertion also auditions were not traced. The clone retains add-chord audition as a local interaction choice; it is not claimed as native parity. The recovered preview producer uses `effective_velocity` as its Song-derived scalar multiplied by the player float. `NativeEffectiveVelocity` encodes the observed low/high/aggregate flag gate with opaque field names; the clone does not map the native Song velocity record or its flag bytes to `Song`, so its integer slider is not evidence of effective-velocity parity. The transfer producer's scalar is 1.0; this does not establish default palette pitches or quality enumeration.
