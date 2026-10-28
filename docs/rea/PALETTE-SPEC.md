# Palette reconstruction specification

Target: `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`; Ghidra 12.1.4 profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b8bcc28`. Static shipped-artifact analysis only. No original-app activation or runtime behavior is claimed.

Focused evidence exports are kept locally as raw research artifacts: `research/rea-palette-enumeration-2026-10-28.json` (initial 369-record bundle), `research/rea-palette-owner-view-2026-10-28.json` (405-record owner-view bundle), `research/rea-palette-enumeration-2026-10-28-v3.json` (426-record bundle), `research/rea-palette-generator-2026-10-28.json` (431-record bundle), and `docs/rea/evidence-palette-downstream-20261028.json` (433-record bundle, 69,693,629 bytes). These are raw local research artifacts, not curated documentation.

## Recovered module boundaries and data flow

The recovered palette producer and owner-state layer are connected. The remaining break is between the owner-state collection and the generic collection consumer that calls `_item_creation`:

```text
ChordPaletteContent owner update (FUN_1000cb730)
    └─ scale record -> FUN_1000ce1fc
          ├─ base Entry rows: root order × four triad templates
          ├─ nested extensions: nine interval sets + three direct templates + [7]
          └─ relation-provider results -> owner-state tuple per base record
                └─ generic collection -> _item_creation(chords::Entry) [callsite unresolved]
                      └─ ChordPaletteItem -> preview/transfer actions
```

The closure type name at `0x1003bfcdb` explicitly identifies `ChordPaletteContent::_item_creation(chords::Entry)` returning `ChordPaletteItem*` (`ev_f4520b0ee657b26f141425cb02f15367f0a18d13ea304e356fa2532b5c9fa6fe`). `FUN_1000d7528` is the item adapter: it copies the entry's root and ordered interval set into item offsets `+0xf0` and `+0xf8`, initializes a `0x270`-byte item, saves the shared state pointer at `+0x268`, and inserts the resulting UI node into its owner (`ev_538833cb679152a249adb473ffd8394ff7183ea042230e67927ef9ae3fb5dba3`). The insertion call `FUN_1002e33c0(owner,item,-1)` manipulates a generic tree/vector parent-child relationship; it does not enumerate chord qualities or sort candidates (`ev_99918dae4ca32ab6011a7e76c71626e23a2be8cd9a6c679a6b13023d7d9e5809`).

The item's vtable places the preview-trigger and transfer actions at slots `+0x28` and `+0x30` (`ev_f5e34ebd5097703207cce6e9473d4a6c2844a480de8a2edf2412fcd73d78f645`). The trigger toggles item activity and invokes `FUN_1000309b0`; that path obtains `effective_velocity` through the Project float getter and passes the result as the producer scalar (`ev_cd413e65a194119f64719aedcc168277bbc8b3f9de70c29fd7f1e861cfe0a6cb`, `ev_e40e0a86a2ebd6f655ee565f000b634ee3930558708de73b4c82871da48bc9a8`). The transfer action calls the same note generator with scalar `1.0`, then serializes and transfers the chord record (`ev_8a43a89c384acbd5fb8341674d0ebef0cca0fdf5935ecf425f706053575199d8`). Neither action establishes how the `chords::Entry` list is produced.

## Candidate-source investigation

`FUN_100096e9c` constructs the palette's control content, including the exact descriptions “Select a key to borrow chords from”, “Select a parallel mode to borrow chords from”, “If enabled, the chord palette follows the project's scale”, and the left/right circle-of-fifths steps for borrowing chords from adjacent scales (`ev_304feb91e477e5c78208cdb1c1c7b2e1177236bd162af702b9ce6dd8d5f7d46b`). These strings establish the names of candidate-source controls, not their initial values or the transformations they apply. The constructor body initializes and lays out these settings; the observed code does not construct a sequence of `chords::Entry` values.

The `_item_creation` closure's generated type test is `FUN_1000d8058`. Its incoming references are data references from `0x1009c2090` and `0x100a0109b`; no code callsite is identified (`ev_b504138a4468c0978c0057e179f2f1d8e939e701e68e9f5b2e118645d0d1bbb0`). The item adapter itself has no direct code caller in the analyzed references. Thus the vtable slot at `0x1009c2088` identifies the closure's callable implementation but does not reveal the generic `ForEach`/range producer that supplies its argument (`ev_9631139be776a71f4014a6ed7536cfa1fd4f5a07e7590df9e576f609bf5ae09b`).

A separate per-item update path is visible in `FUN_1000d8b48` (`ev_718b2c1dab9d9b4e6a9ffba9e5d7fcc5d9244950e0f057d95a7aca957eac35a2`). It compares an existing relation-score tree with a newly built tree, reconciles entries by integer key, and then invokes stored callbacks. Its helpers include `FUN_1000d80b8` (comparison), `FUN_1000d8250` (builds two keyed entries), and `FUN_1000d856c` (tree merge). This is evidence for item relation-state refresh and ordering within that state; it is not evidence for palette candidate enumeration or candidate display order. The actual relation scorer dispatch and score-to-color mapping remain unresolved, as detailed in [HARMONY.md](HARMONY.md).

### Base candidate generation recovered

The owner-view updater is `FUN_1000cb730`; it copies the active scale record (root plus ordered intervals) and calls `FUN_1000ce1fc`. The producer returns a vector of fixed-size `0x80`-byte records, one per accepted base entry (root plus interval template), not one per scale root. This joins the `ChordPaletteContent` update to candidate construction (`ev_2ea82f71e5b6ada994fa363e23ba1a772011a17bf66ec3be986e1f4db5ad78d5`, `ev_ef19c1af18bf3937ac156e96a4de2c34542aace55d60fc44d71314cb34bf2`).

`FUN_1000622d8` expands the scale record into pitch classes by emitting its root and then adding each stored interval in order modulo 12. `FUN_10006253c` builds the scale membership set. For each expanded pitch class in input order, `FUN_1000ce1fc` tests these four base templates in this order:

| Candidate interval vector | Conventional quality interpretation |
|---|---|
| `[4,7]` | major triad |
| `[3,7]` | minor triad |
| `[3,6]` | diminished triad |
| `[4,8]` | augmented triad |

`FUN_10037a208` initializes the vectors; the quality labels are conventional interpretations, not binary strings (`ev_78355479c6344a10a23f2ca728737bf780a0e756f39a4e2c3a34a7adc84e5ccf`). `FUN_100006784` constructs a sorted unique set from the candidate root plus each interval modulo 12. The producer compares that set with the scale membership set and rejects it when a candidate pitch class is absent; it accepts when all candidate pitch classes are members of the scale. The original interval template is preserved in the base entry, while its pitch-class set is only used for the membership test (`ev_9e94b4b9214e99b34021525f47ba0644b2b9473a17b7223fa47360efdcc6441f`, `ev_ef19c1af18bf3937ac156e96a4de2c34542aace55d60fc44d71314cb34bf2`).

Each accepted root/template pair appends one base-entry record. Thus the recovered order is root pitch-class order, then `[4,7]`, `[3,7]`, `[3,6]`, `[4,8]`, skipping rejected pairs. Each record contains the base entry and three nested vectors for related entries; it is not a per-root bucket. The scale expansion can retain repeated pitch classes from repeated input intervals while membership sets deduplicate keys. Whether repeated roots are suppressed later remains unknown.

The enrichment pass `FUN_1000d3b04` consumes those base-entry records and initializes nine extension vectors in this traversal order: `[9]`, `[10]`, `[11]`, `[14]`, `[14,9]`, `[10,14]`, `[11,14]`, `[10,14,17]`, `[11,14,17]`. It merges each extension vector with the base entry's interval keys through ordered unique sets, forms the rooted pitch-class set, and checks it against the scale membership set. Accepted derived entries are appended to the first nested vector at record offset `+0x38`; `FUN_1000d69c0` copies root, interval vector, and pitch-class set into each child entry. The union's emitted interval sequence is sorted/deduplicated, unlike the preserved base template order. Static initialization also contains `[10,14,17,21]` and `[11,14,17,21]`, but those vectors are not part of this nine-vector pass (`ev_784eda12be05f3db0bfebe8c4a0271b6f5b0a4f25e3d560cbdaa0798eb8a76a0`, `ev_cf46ef37798734cc4723a7af574f810b0d239793f013eac814b5848b419c8ad6`, `ev_78355479c6344a10a23f2ca728737bf780a0e756f39a4e2c3a34a7adc84e5ccf`).


The producer then tests direct templates `[5,7]`, `[2,7]`, and `[5,7,10]` in that order against the scale set and appends accepted entries to the second nested vector at `+0x50`. A final pass tests `[7]` and appends accepted entries to the third vector at `+0x68`. These are observed interval vectors; names such as suspended or power chord are interpretations. `FUN_1000cb730` visits the producer's base records in order, traverses data associated with the three child groups (`+0x38`, `+0x50`, `+0x68`), and invokes the supplied relation provider while building per-base relation state. It appends one vector-shaped result record (three pointer fields representing begin/end/capacity) for each base record. `FUN_1000cd82c` stores that result as owner state and triggers the state update. This proves that the three nested offsets are consumed in distinct passes while base-record order is retained in owner state. It does not prove that the UI renders three separate sections, or that this relation-state vector is itself the iterable supplied to `_item_creation` (`ev_2ea82f71e5b6ada994fa363e23ba1a772011a17bf66ec3be986e1f4db5ad78d5`, `ev_070312c7e512afc0efd86e55b45551dafe006a4741bdf59649f9c5e6559bdb4e`).

Duplicate behavior is only partially known. The per-scale pitch-class membership structure and each interval-union set are ordered unique sets. Thus repeated pitch classes do not make a candidate fail membership, and repeated interval keys in a base-plus-extension union occur once in the derived interval vector. The generator still iterates the expanded scale pitch-class sequence and appends a base record for each accepted root/template pair; no root-level set or final cross-template candidate set is present in that path. Repeated scale pitch classes can therefore yield repeated base rows. Each extension template is considered independently, and the direct-template groups are appended independently; there is no observed global de-duplication of equivalent derived entries across templates or groups. The relation provider separately uses keyed trees to reconcile relation results, which does not deduplicate the `chords::Entry` candidate stream (`ev_784eda12be05f3db0bfebe8c4a0271b6f5b0a4f25e3d560cbdaa0798eb8a76a0`, `ev_2ea82f71e5b6ada994fa363e23ba1a772011a17bf66ec3be986e1f4db5ad78d5`).

Derived base examples assume the input is the conventional root-plus-ordered-interval record for that scale; these are static consequences, not runtime captures. C major `[0,2,4,5,7,9,11]` yields C `[4,7]`, D `[3,7]`, E `[3,7]`, F `[4,7]`, G `[4,7]`, A `[3,7]`, B `[3,6]`. Natural C minor `[0,2,3,5,7,8,10]` yields C `[3,7]`, D `[3,6]`, E-flat `[4,7]`, F `[3,7]`, G `[3,7]`, A-flat `[4,7]`, B-flat `[4,7]`.

The settings identify project scale, chosen borrowing key, parallel mode, and adjacent fifth scales as candidate-source controls. The verified producer accepts a single already-formed scale record; `FUN_1000cd82c` copies the current scale object from its owner field at `+0x170` and passes that record into `FUN_1000cb730`, which in turn passes a copy to `FUN_1000ce1fc`. The UI choice construction in `FUN_1000c6538` establishes register and strumming controls, not the scale-choice mutation path. No proven store from the key, parallel-mode, or adjacent-fifths controls into the `+0x170` scale object has been identified, so the exact scale composition and precedence remain unresolved. No output can yet be attributed to a selected borrowed key. Do not treat the two-entry relation map in `FUN_1000d8250` as the palette catalog (`ev_070312c7e512afc0efd86e55b45551dafe006a4741bdf59649f9c5e6559bdb4e`, `ev_39cf63bad2c2e0b5b39c4ac37339ebb1e1524b382ac1eb31da226531e542908b`).

## State binding established by constructor stores

`FUN_100096e9c` receives its x4 argument from outer constructor `FUN_10008e050`. The caller forms `x19+0x410` at `0x10008ed1c` and stores it to `sp+0x108` at `0x10008ed7c`; before calling `FUN_100096e9c`, it reloads that slot into x20 and passes x20 as x4 (`0x10008f1c4`–`0x10008f1e4`). A prior CTFont value used the same stack slot, but the `0x10008ed7c` store overwrites it before this call (`ev_d7fe2d9b7c3519b984741be617d29af827a000b856ced0b7c0c493ac0083b462`).

Inside `FUN_100096e9c`, x4 is saved as x28. The `_item_creation` closure captures `this+0x620`, and the shared state field at `this+0x7a0` receives x28. The settings view closure captures `this+0x19d8`, and `this+0x1ac8` receives the same x28; this is the captured settings object's `+0xf0` pointer slot (`ev_c03c7765098f5a226ffb95b7eb8e1dac84b22cfb7e7888f1b297a379c4938930`). The item adapter reads the former slot and copies it unchanged into item `+0x268`; `FUN_1000c6538` and its choice callbacks dereference the latter and read/write the exact same state object (`ev_538833cb679152a249adb473ffd8394ff7183ea042230e67927ef9ae3fb5dba3`, `ev_39cf63bad2c2e0b5b39c4ac37339ebb1e1524b382ac1eb31da226531e542908b`, `ev_18e8ceb783fb8381c9c2558f33b35c8134c3837cb51e8721f86403b412195b68`, `ev_7e6af3e043e7c1937b79923c097ad624e0307a55dc3d6bd98279129c72424c16`, `ev_98f6f60649abaee94be8c605b179ed4c4aa860fcdc4aadc03175411b6028d692`, `ev_4b0dc38ea090d3cc8dfd9e898e0c5199dc30b1d853bf21307a691449122b9729`).

There is no pointer adjustment in the observed store/load path: one x4 pointer is copied into both fields, then passed unchanged as the chord generator's state pointer. The UI exposes register choices 0–12 writing state `+0x18` and strumming choices 0, 162, and 324 ticks writing state `+0x20`. The generator reads gain at `+0x28` and a signed root-PC threshold through the pointer at `+0x300`; this panel has no gain or threshold setter. The separate `ChordPreviewPlayer` embedded in `FUN_100096e9c` at its own `this+0x300` and initialized to register 4 / spacing 0 / gain 1.0 is a different object until evidence joins it to x4. See [VOICING-VALIDATION.md](VOICING-VALIDATION.md) for the full alias chain and producer arithmetic.

## Evidence vectors

These are derived from the recovered UI values and generator arithmetic, not runtime captures or candidate-list observations. Use root pitch class 0, intervals `[4,7]`, threshold 0, gain 1.0, and scalar 1.0:

| Register | Strumming ticks | Pitches | Positions | Lengths |
|---:|---:|---|---|---|
| 0 | 0 | `[0,4,7]` | `[0,0,0]` | `[10368,10368,10368]` |
| 4 | 162 | `[48,52,55]` | `[0,162,324]` | `[10368,10206,10044]` |
| 12 | 324 | `[144,148,151]` | `[0,324,648]` | `[10368,10044,9720]` |

The generator emits the root first and then each stored interval pitch; the spacing formula uses the selected tick amount times note index, and duration is reduced by the same offset with a 162-tick minimum. The threshold compares the first/root pitch class and, when it is below the signed threshold, adds 12 to every pitch (`ev_e8aa3785202f6fe1c0c58dcef50f78d7800c880e035c7b6b43e18770ceac1928`). These vectors demonstrate the now-proven control binding while leaving the threshold input explicit.

## Proven unknowns and next trace frontier

The base and additional direct templates, scale-membership filters, nested-record insertion order, and partial duplicate behavior are recovered. The owner updater preserves base-record order in its owner-state vector, but final UI flattening/order, score-based exclusion, palette score-to-color conversion, and gesture-to-item-action dispatch remain unknown. The creator's direct code callers remain absent; the dynamic generic `ForEach` invocation remains unidentified.

The next precise frontier is the generic collection consumer after `FUN_1000cb730`: identify how each base row and its three nested entry vectors are flattened for `_item_creation`, and recover relation-score-to-display ordering/color behavior. The scale record passed into `FUN_1000cb730` is known, but the stores that combine project scale, borrowing key, parallel mode, and adjacent-fifths controls into that record are not. Final UI order, borrow/parallel/adjacent-scale composition, score cutoff, and label mappings remain unknown.

Other explicit unknowns remain: root-threshold default/mutation, producer gain setter/default, and the source meaning/default of the persisted `preview` settings object. Static analysis does not prove absence of other indirect callers or establish runtime behavior. Original activation remains blocked; no bypass was attempted.
