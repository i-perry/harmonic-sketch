# Palette reconstruction specification

Target: `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`; Ghidra 12.1.4 profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b8bcc28`. Static shipped-artifact analysis only. No original-app activation or runtime behavior is claimed.

Focused evidence export: `research/rea-palette-enumeration-2026-10-28.json` (369 records, 58,032,566 bytes).

## Recovered module boundaries and data flow

The recovered palette has three observable layers, but its candidate-source edge is still indirect:

```text
ChordPaletteContent entry source (unresolved)
    └─ chords::Entry -> _item_creation closure -> ChordPaletteItem
          ├─ preview-trigger action -> shared player state -> chord-note generator
          └─ transfer action -> shared player state + scalar 1.0 -> serialized chord record
```

The closure type name at `0x1003bfcdb` explicitly identifies `ChordPaletteContent::_item_creation(chords::Entry)` returning `ChordPaletteItem*` (`ev_f4520b0ee657b26f141425cb02f15367f0a18d13ea304e356fa2532b5c9fa6fe`). `FUN_1000d7528` is the item adapter: it copies the entry's root and ordered interval set into item offsets `+0xf0` and `+0xf8`, initializes a `0x270`-byte item, saves the shared state pointer at `+0x268`, and inserts the resulting UI node into its owner (`ev_538833cb679152a249adb473ffd8394ff7183ea042230e67927ef9ae3fb5dba3`). The insertion call `FUN_1002e33c0(owner,item,-1)` manipulates a generic tree/vector parent-child relationship; it does not enumerate chord qualities or sort candidates (`ev_99918dae4ca32ab6011a7e76c71626e23a2be8cd9a6c679a6b13023d7d9e5809`).

The item's vtable places the preview-trigger and transfer actions at slots `+0x28` and `+0x30` (`ev_f5e34ebd5097703207cce6e9473d4a6c2844a480de8a2edf2412fcd73d78f645`). The trigger toggles item activity and invokes `FUN_1000309b0`; that path obtains `effective_velocity` through the Project float getter and passes the result as the producer scalar (`ev_cd413e65a194119f64719aedcc168277bbc8b3f9de70c29fd7f1e861cfe0a6cb`, `ev_e40e0a86a2ebd6f655ee565f000b634ee3930558708de73b4c82871da48bc9a8`). The transfer action calls the same note generator with scalar `1.0`, then serializes and transfers the chord record (`ev_8a43a89c384acbd5fb8341674d0ebef0cca0fdf5935ecf425f706053575199d8`). Neither action establishes how the `chords::Entry` list is produced.

## Candidate-source investigation

`FUN_100096e9c` constructs the palette's control content, including the exact descriptions “Select a key to borrow chords from”, “Select a parallel mode to borrow chords from”, “If enabled, the chord palette follows the project's scale”, and the left/right circle-of-fifths steps for borrowing chords from adjacent scales (`ev_304feb91e477e5c78208cdb1c1c7b2e1177236bd162af702b9ce6dd8d5f7d46b`). These strings establish the names of candidate-source controls, not their initial values or the transformations they apply. The constructor body initializes and lays out these settings; the observed code does not construct a sequence of `chords::Entry` values.

The `_item_creation` closure's generated type test is `FUN_1000d8058`. Its incoming references are data references from `0x1009c2090` and `0x100a0109b`; no code callsite is identified (`ev_b504138a4468c0978c0057e179f2f1d8e939e701e68e9f5b2e118645d0d1bbb0`). The item adapter itself has no direct code caller in the analyzed references. Thus the vtable slot at `0x1009c2088` identifies the closure's callable implementation but does not reveal the generic `ForEach`/range producer that supplies its argument (`ev_9631139be776a71f4014a6ed7536cfa1fd4f5a07e7590df9e576f609bf5ae09b`).

A separate per-item update path is visible in `FUN_1000d8b48` (`ev_718b2c1dab9d9b4e6a9ffba9e5d7fcc5d9244950e0f057d95a7aca957eac35a2`). It compares an existing relation-score tree with a newly built tree, reconciles entries by integer key, and then invokes stored callbacks. Its helpers include `FUN_1000d80b8` (comparison), `FUN_1000d8250` (builds two keyed entries), and `FUN_1000d856c` (tree merge). This is evidence for item relation-state refresh and ordering within that state; it is not evidence for palette candidate enumeration or candidate display order. The actual relation scorer dispatch and score-to-color mapping remain unresolved, as detailed in [HARMONY.md](HARMONY.md).

Current candidate-source boundary: the item consumes one `chords::Entry`, whose root and ordered intervals are preserved by the adapter. The settings identify project scale, chosen borrowing key, parallel mode, and adjacent fifth scales as candidate-source inputs. No static evidence found in this pass specifies the interval-quality catalog, candidate enumeration order, duplicate handling, candidate exclusion/filter predicates, or how those controls transform the candidate range. Do not treat the two-entry relation map in `FUN_1000d8250` as the palette catalog.

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

Candidate enumeration, candidate filtering, quality order, score-based exclusion, stable display order/tie behavior, palette score-to-color conversion, and the gesture-to-item-action dispatch are unknown. The creator's direct code callers are absent; Ghidra references identify its closure/vtable data but not the dynamic callsite. `ChordPaletteContent::_item_creation` therefore proves a consumer signature, not the upstream candidate list.

The next precise frontier is the candidate-range expression observed at the `ChordPaletteContent` view/body layer: resolve the generic closure invocation that consumes the captured `_item_creation` function and identify the collection expression yielding each `chords::Entry`. Trace its dependencies back to the project scale, chosen borrow key, parallel mode, and left/right adjacent-scale controls. If that generic callsite remains unavailable, the concrete next bounded probe is to identify the code/data object at the `_item_creation` closure's vtable (`0x1009c2088` and its adjacent slots), then follow the owning view's closure construction and range argument. Keep the unresolved outputs explicit: no interval catalog, entry generation loop, quality order, duplicate rule, scale/key filter, or candidate-level score cutoff has been recovered.

Other explicit unknowns remain: root-threshold default/mutation, producer gain setter/default, and the source meaning/default of the persisted `preview` settings object. Static analysis does not prove absence of other indirect callers or establish runtime behavior. Original activation remains blocked; no bypass was attempted.
