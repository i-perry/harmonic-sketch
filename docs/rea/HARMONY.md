# Harmony recovery from Klimper 2.4

Status: Flow, Contrast, Match Notes, and both ordinary and suspension Tonal callback branches are implemented from recovered callback arithmetic. Palette usage is an explicit reconstruction mapping; invocation roles, visual mapping, voicing, and complete palette generation remain partial or unknown. No runtime parity claim follows from this document.

## Identity and authority

REA Ghidra 12.1.4, thin arm64 Mach-O `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`. Analysis profile digest `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. Original harmony evidence: `research/rea-harmony-evidence.json` (21 records). Independent branch-review bundle: `research/rea-harmony-review-evidence.json` (45 records), including the fresh tonal callback dossier and initializer. Dispatch trace bundle: `research/rea-harmony-dispatch-review-evidence.json` (255 records), including focused vtable references and bounded indirect-call-site resolution attempts. Callback follow-up: `research/rea-harmony-callback-followup.json` (18 records), with repeated scorer body/reference analysis. All results below are static shipped-artifact observations or explicitly derived formulas, not execution observations. Decompiled C is recovered pseudocode, not original source.

## Callback identity: observed chain

The initializer `FUN_10037a208` explicitly writes each label and callback vtable into the same relation descriptor. This is stronger than proximity of UI strings. Evidence `ev_0576ffd6862d69404b7baf843c227d779d192cff6cc5bc132a144a74b3b0549c` contains those stores and initialization of numeric constants. The vtable bytes are in `ev_9b05d3a32b298646cc72f365f41c41da5301bc135af21e3bc783e2b7a48cb684` and `ev_b6f62ab274c95f6ca71822608e43f918bbbb482742a23b88804a6f575b9248c5`.

| Descriptor | Label / serialized key | Callable vtable | Call slot |
|---|---|---|---|
| `1009ecfd0` | No Matching / disabled | `1009cf968` | `100008154` |
| `1009ed020` | Tonal Harmony / tonal_harmony | `1009cf9f8` | `100007248` |
| `1009ed070` | Flow / flow | `1009cfa78` | `100007148` |
| `1009ed0c0` | Contrast / contrast | `1009cfaf8` | `100006d2c` |
| `1009ed110` | Match Notes / empty key in initializer | `1009cfb78` | `1000063d4` |

The typeinfo strings describe `float(optional<Chord>, optional<Chord>, PitchClass, optional<NoteSelection>)`. ARM64 Flow and Contrast instructions establish x1=first optional chord, x2=second chord; both inspect byte x1+0x20 for engagement. Do not translate the Contrast pseudocode signature literally: its recovered parameter types/storage are wrong. Instruction evidence: `ev_78da8335e2c37f4c1221be7fa0949de5de3c1538b1305cb59f7e210b840e2cc6`, `ev_d92ca1dee69daf28d7eda3edbf7570620639bde48f9e123088d354df9e09cab8`.

## Pitch-class representation and overlap

Observed `FUN_100006784` inserts chord root, then each `(root + interval) mod 12` into an ordered unique set. Negative sums are normalized before modulo. A chord stores root at +0, interval tree at +8/+0x10, interval count at +0x18. Evidence `ev_9e94b4b9214e99b34021525f47ba0644b2b9473a17b7223fa47360efdcc6441f`.

Observed `FUN_100006ea4` intersects those sets and returns intersection count divided by `min(intervalCountA+1, intervalCountB+1)`. The denominator uses stored interval counts plus one, not recomputed unique pitch-class cardinality. Evidence `ev_f196e8dc3d172c200b28b58ff1d401b4c492c5f63eb9d9043a08b54fa81dab0b`.

Derived notation: P(C) is this unique pitch-class set; O(A,B)=|P(A) intersect P(B)|/min(intervalCountA+1,intervalCountB+1); clamp01(x)=max(0,min(1,x)).

## Recovered scores

- No Matching always returns float bits 0x3f4ccccd (approximately 0.8). Evidence `ev_546da27fceaa53d494d9aa95cab63ea3eac06e865ceb89c15267f8f4082e9f0b`.
- Flow returns 0.8 when first optional is absent; otherwise clamp01(1.25*O(A,B)-0.25). Evidence `ev_b204d0135bc5bb9cb6455f37358b379c3fef8960ce9bc28863b513b1a450c29f`, corroborated by instructions above.
- Contrast returns 0.8 when first optional is absent. If roots and entire interval sets are equal it returns 1.0. Otherwise it returns clamp01(1.25*(1-O(A,B))-0.25). The equality exception is explicit and must be preserved even though it is surprising. Evidence `ev_b75df018932fb151747eb8bfc7d8990b00d5a2b373dfb13edde6308a03dacb8a`, corroborated by instructions above.
- Match Notes returns 0.8 when selection optional is absent. Otherwise it normalizes selected MIDI pitches modulo 12, deduplicates them, intersects with second chord's P(C), and divides intersection count by unique selected pitch-class count. Evidence `ev_a64256e14746bcb5cc7f764b6e7736802a32e41c1c175e9b27bab1413c7ffd34`. Empty engaged selection has no explicit denominator guard; runtime reachability/NaN treatment is unknown.

These callbacks ignore voicing/register for overlap. They are pitch-class comparisons. Assignment of first and second chord to user-facing previous/candidate roles still requires caller tracing.

## Tonal Harmony: bounded recovered predicates

Evidence `ev_a4a3c1370214534db6495492b4d47e0c2b5aa938aa434525079dd51191d4aa76`. It returns only 0, 0.7, 0.8, 1 in observed pseudocode. First absent optional returns 0.8. Root and interval membership drive results; key pitch class affects key-relative predicates. Initializer evidence above establishes numeric constants from runtime initialization, rather than reading zero-filled data before execution.

For the branch where neither input interval set contains 2 or 5 (e.g. ordinary major/minor triads), define a=(rootA-key) mod 12, b=(rootB-key) mod 12, d=(rootB-rootA) mod 12. Score 1 when any predicate holds:

- rootA=rootB;
- rootA=key;
- d=5;
- (a,b) in {(5,11),(7,0),(11,0),(9,5),(8,2),(8,5),(2,11),(5,7)}.

Otherwise score 0.7 when d is in {1,2,5,6,8,9}; otherwise 0. The d=5 case is already consumed by score 1 in this branch. These predicates are derived from the numeric globals and comparisons, not conventional harmony rules imposed by the analyst.

The branch split is entered if either chord contains exact stored interval 2 or 5. It is not crossed-only. Membership checks compare the stored ushort values directly; interval 14 does not count as interval 2. The initialized globals identify these values as 2 and 5 (initializer pseudocode `ev_ed50d4c10b4c435fb7742dcf151c36e3413253e355cc40e3698f17f7209b0bb0`; tonal callback pseudocode `ev_bd1bbcc3048702a50e45f5a419956cd0a564e8a618f5e8bef526cac6782352b4`).

For this path, let A be the first chord, B the second, and P(A) its unique pitch-class set. A’s first offset prefers 2 over 5; B’s third prefers 3 over 4. If both exist, form x=pc(A.root+offset) and y=pc(B.root+third). Then A5 membership is checked independently: if A contains 5, accept score 1 when y is x−1 or x−2; otherwise accept when y is x+1 or x+2. If that does not accept, B’s fallback offset prefers 2 over 5. Return the exact 0.7 float when pc(B.root+offset) belongs to P(A), otherwise 0. If B has neither fallback offset, return 0. Key is unused on this path. There are no root-equality, tonic, key-relative, or root-delta predicates here. The separate A-offset and A5 priorities matter when A contains both 2 and 5.

The tonal callback body treats its recovered `param_2` as the first optional chord, `param_3` as the second chord-like input, and `param_4` as the key pitch class; it returns 0.8 when the first optional is disengaged. The callback body does not establish which user-facing chord is first or second (for example, current versus candidate), and it does not show a guard for the second optional input. Preserve this argument-role uncertainty; do not assume caller order or nullability from the callback's typeinfo alone.

I traced the callback's vtable slot (`0x1009cf9f8`, slot `+0x30`) and its descriptor (`0x1009ed038`). Incoming references to the callback resolve only to static/data storage; descriptor references lead to UI/configuration functions and the static initializer (`ev_cf31…`, `ev_a838…`, `ev_f800…`). A focused search for the common ARM64 sequence `ldr x8,[x0]; ldr x8,[x8,#0x30]; blr x8` found 233 initialized-text sites (`ev_e267…`). REA call-target resolution of those sites did not resolve any to `FUN_100007248`. This is a bounded search over that exact register/encoding pattern; other virtual-call forms may exist. It did not identify the actual indirect scorer callsite or establish first/second chord roles or the second optional's engagement guarantee.

A repeated incoming-reference inspection confirms the unresolved boundary rather than filling it: Flow `0x100007148` has only its own control-flow references plus two DATA references to its vtable slots (`ev_a718e832054949158019a619aed9b70597ba1b178833382a6d4d14b2af9bd8f9`); Contrast `0x100006d2c` has internal branches plus DATA references to slot storage (`ev_f4224292fdde1cec6fcabe7e61b72a94542596fc4bfa79fac9cca5838a419ee3`); Match Notes `0x1000063d4` has the same shape (`ev_0880f8b69807c68933db5b2cc83f47234d8675cac36739e1692c73015b4bd559`). This is a static direct-reference result, not proof that indirect invocations do not exist. The callback bodies establish argument positions (Flow first optional at ABI param 2, second chord at param 3; Match Notes selection optional at param 5 and target chord at param 3), but no caller maps those positions to user-facing chord roles. Focused callback-body evidence: Flow `ev_b04675c12939e76ba161ebd24f41939c960c193a934b16c939887db8e8f2f2c1`, Contrast `ev_a8f873925ecf1828c5da4314f053f47603e91be3a162e846ab50afc1967e93d6`, Match Notes `ev_d4213a54f342c74bb495471ee749d9d33a9518d362f5dc602e429bdfa156f5ab`.

## Derived vectors (not runtime observations)

Assume ordinary triads represented with intervals {4,7} or {3,7}, C=0. These follow directly from recovered arithmetic and are suitable future oracle checks.

| Inputs | Expected |
|---|---|
| Flow C major vs C major | 1 |
| Contrast C major vs exact C major | 1 (equality exception) |
| Flow C major {0,4,7} vs G major {7,11,2} | approximately 1/6 |
| Contrast those same distinct triads | approximately 7/12 |
| Flow C major vs D-flat major {1,5,8} | 0 |
| Contrast C major vs D-flat major | 1 |
| Match Notes selected MIDI {60,64,76} vs C major | 1; duplicate E octave counts once |
| Match Notes selected MIDI {60,61,64} vs C major | approximately 2/3 |
| Tonal C major -> any ordinary major/minor triad, key C | 1 (first root is key) |
| Tonal D minor -> G major, key C | 1 (root delta 5) |
| Tonal G major -> C major, key C | 1 (relative roots 7,0) |
| Tonal D minor -> E minor, key C | 0.7 (root delta 2) |
| Tonal D minor -> F major, key C | 0 (root delta 3, no special predicate) |

Branch-routing checks can be derived separately from score outputs: `{2}` -> `{5}` and `{5}` -> `{2}` enter the suspension-specific branch; `{2}` -> `{7}`, `{5}` -> `{5}`, and `{2}` -> `{2}` take the ordinary branch. These are branch-selection vectors, not complete score oracles.

## Reconstruction status

The Swift model has callback-order helpers `MusicTheory.flowScore(first:second:)`, `contrastScore(first:second:)`, and `matchNotesScore(selection:second:)` using `HarmonyChord` (root pitch class plus stored interval offsets). They implement the recovered formulas, including disengaged defaults, interval-count denominator, exact interval-set exception for equal Contrast inputs, pitch-class deduplication for Match Notes, and the unguarded empty-selection NaN. `MusicTheory.relation` now routes palette Flow and Contrast through those scorers. Because both formulas are symmetric for engaged chord inputs, the unresolved first/second role does not change these outputs.

The palette supplies the prior selected chord as the first chord, the candidate as the second, and its displayed key pitch class to Tonal. That is an implementation mapping, not a recovered caller mapping: the indirect callback caller remains unidentified. The ordinary and suspension Tonal branches reproduce the predicates above and have derived-vector tests. Match Notes passes selected melody pitches to the recovered score; the score controls outline strength while the previous exact-match dimming behavior is retained. The source callback's UI use and score-to-visual mapping remain unverified, so these are parity-oriented choices rather than recovered palette behavior. With no selection, the palette treats selection as disengaged and uses the source's 0.8 score, but the original empty-selection reachability remains unknown.

## Unknowns and next evidence

Automatic voicings, interval palette enumeration, exact scoring-to-color transform, ordering/tie behavior, candidate filtering, first/second caller roles, second optional engagement guarantees, and selected empty-set reachability remain unresolved. The current caller search found references to the callback's vtable/static storage, but no direct code callsite; indirect dispatch coverage is therefore incomplete. This bounded pass does not establish absence of other callers or validate total app parity. Next pass should trace the relation descriptor through palette ranking and inspect voicing producers.

### Voicing serialization boundary (observed, not a producer)

The chord serializer `FUN_1000108a4` passes the chord's voicing range to `FUN_100010d38`; that helper allocates a 16-byte output entry for each 24-byte input note record and calls `FUN_100010e28` (`ev_28a789c59da99977d9baa06b2a8530d1be5c45d7a5c5018a9a7252d627f00f7b`, `ev_47875286901fd0dcca02b2307367f64fdb954e42f20d1d19e94949c90e9cbaa0`). The note serializer reads fields at offsets 0, 8, 16, and 20: position and length are signed integer time units divided by 10368.0, pitch is read as a signed 32-bit integer, and velocity is read as a 32-bit float. It emits `position`, `length`, `pitch`, and `velocity` (`ev_5ae6f6a575bd2aa6e6d31667e01c8a481f15e61287fb56a3d26062a464c709c0`).

This confirms how existing voicing notes are encoded and serialized; it does not show how their pitches are generated. In particular, it gives no default MIDI register, inversion policy, pitch ordering, quality enumeration, or palette-candidate filter. Keep the reconstruction's explicit voicing and quality choices labeled as assumptions until a producer or palette-construction path establishes those rules. Derived serializer test vectors: a record `(position: 10368, length: 5184, pitch: 60, velocity: 0.8)` becomes `(1 beat, 0.5 beat, MIDI 60, velocity 0.8)`; serialization preserves input record order because the helper advances one 24-byte record per output entry.

### Voicing/palette follow-up (static trace; producer still unknown)

The fresh focused REA pass used the same thin ARM64 target and Ghidra profile. The defined string `"voicing"` at `0x100391616` has one incoming reference, at `0x100010bbc`; that address is inside the already-known chord serializer `FUN_1000108a4` (`ev_ce5062ad8aec00b7fd2cb501cb7bd72a9e0eae3d107fd75d9ca6990c3bc1aa25`, `ev_6e8cba7a98e52e9e51ac7a3ad30b0f2fc97dc02d98120ae80da5e63da8b0ccc6`). The serializer's exact incoming references are `0x10000fc08`, `0x1000d9944`, and a data location `0x1009ffebc` (`ev_715a7988016d7d44b67bd5a42d0e46b12e6592d8c7a437bd0ade3326d1d22647`). This reinforces the persistence boundary: serialization consumes an existing voicing vector and does not establish who creates it.

The defined `"chord_palette"` key at `0x100391794` is referenced by `0x1000eb6b4` and `0x1000ee25c` (`ev_0103a56497da68996be2ceec0d02184936fe242c618d28217b633a58fba5fec0`); these are configuration paths, and their presence does not establish palette candidate enumeration. The nearby user-facing string `"Edit freely how the chords are being voiced"` at `0x100391c94` has no direct xrefs (`ev_14b13d4752ef76b5174e566a33e8098a7c42f8fbf2d67adbcfb7e527704d0065`). These references did not lead to a voicing producer or candidate-generation function. The current MIDI 48 placement and 19-quality set therefore remain reconstruction assumptions; this pass supplies no evidence to replace them with a source-faithful rule. No runtime behavior was observed, and Ghidra's defined-string xrefs are not complete coverage of indirect calls or generated values.
