# Palette callback capture validation — 2026-10-29

The selector-to-generator join is statically resolved. `FUN_1000cd82c` captures the palette subview at owner `O+0x620`; its Scale pointer at subview `+0x170` is owner `O+0x790`, initialized to selector current `O+0x298`. It does not capture the constructor's `Observable<ChordSymbolisation>&` argument. The previous conclusion followed the register name x24 across assignments that replaced its value.

Analysis only: original `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`, Ghidra 12.1.4, profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. No runtime behavior, activation, clone implementation, or UI QA is claimed.

## Exact capture and pointer join

Constructor assembly is retained in `research/rea-palette-enumeration-2026-10-28-v3.json`, dossier `ev_ebbd583b6a48f8c853446dbf7258fc2d80d1f03b779a228cd9ecd9f850367453`. Let O be its x19 and V=O+0x620.

| Address | Instruction / consequence |
|---|---|
| `0x100096ec4` | `mov x24,x2`: entry x2 is initially held in x24, but does not survive to the callback capture. |
| `0x1000972d8` | `add x27,x19,#0x298`: current Scale observable address. |
| `0x1000974b8` | `add x22,x19,#0x620`: palette subview V. |
| `0x100097518` | `str x22,[sp,#0x38]`: replaces an earlier use of this stack slot with V. |
| `0x10009755c` | `str x27,[x19,#0x790]`: V+0x170 points to current O+0x298. |
| `0x1000976e0`, `0x1000976f8` | Both destructor-path branches reload `x24=[sp+0x38]`, therefore x24=V. |
| `0x100097764`, `0x100097778` | `stp x9,x24,...`: construct callback with vtable `0x1009c2768` and captured V at closure+8. |
| `0x100097758`, `0x10009777c` | Load O+0x790 (current), then its +0x58 notification collection. |
| `0x100097784` | Call `FUN_10009bbd0` to append the callback to that collection. |

`FUN_1000cd82c` loads x19 from closure+8 at `0x1000cd85c`, then x20 from x19+0x170 at `0x1000cd860`. Substitution gives `*(V+0x170)=*(O+0x790)=O+0x298`. It copies the Scale root/string/step vector from that current observable and calls `FUN_1000cb730` at `0x1000cd9b0`. The updater's call to candidate generator `FUN_1000ce1fc` is established in the existing PALETTE-SPEC producer evidence. Callback dossier: `ev_bbfd03792d047172096b3a2345456be4026688e8247bbe7d7beda864ab79a81c`.

The constructor also performs initial generation directly from O+0x298: root load `0x100097554`, string/vector copy beginning `0x100097588`, call `FUN_1000cb730` at `0x1000976d0`.

## Invoker identity and notification

New focused export: `research/rea-palette-capture-sol-validation-2026-10-29.json` (8 records, 3,063,159 bytes).

- Byte evidence `ev_035931b46aa461ad752e4a7ca8d8e0fe247cbdbb19b185b3c76fe53568bd0d49` reads the vtable: address point `0x1009c2768`; its invoke slot +0x30 (`0x1009c2798`) contains `0x1000cd82c`.
- `FUN_10009bbd0`, dossier `ev_bd3488a788d863376271ff9600ec775ce84b50d793f0e3787b4ad070f7cc26be`, copies the supplied std::function into its collection's vector (begin/end/capacity at +0x18/+0x20/+0x28). This constructor call registers the generator callback in current's notification collection.
- Left selector callback `FUN_1000cb224`, dossier `ev_85e912d0bf0d56e9026b142e42a8dc332330fc439cdc4f9374d1b688661cb387`, calls `FUN_1000c5a20` with `*(selector+0xf0)` (current) and its modified Scale. `FUN_1000c5a20`, dossier `ev_cb7687bfd207fe93367a32ed453e8a3c8444d33d5704697652d3c53f2494a858`, copies the supplied Scale then calls `FUN_1000c5b30`.
- `FUN_1000c5b30`, dossier `ev_6ed63984ba9bd2fb92b7f61633f86f38a170b6ba99ddcad3d44cc9784d08688b`, updates Scale and loads its notification collection at +0x58 (`0x1000c5b70`). Its vector loop loads each stored function object into x0 from entry+0x18 (`0x1000c5b90`) and invokes vtable+0x30 (`0x1000c5b9c`–`0x1000c5ba0`). Thus callback receives the function object in x0 and reads the captured V at x0+8; no hidden argument shift is needed.

Consequently an actual call to this current setter synchronously invokes the registered palette regeneration callback. The prior selector binding evidence establishes that current is O+0x298. This resolves the previously missing pointer/notification join, while preserving the already documented −7/+7 fifth transformations and follow behavior. It is a static call-chain conclusion, not an observed user gesture or runtime output.

## RTTI correction

Vtable header RTTI pointer is `0x1009c27b0`; its name pointer is `0x1003c0fbd`, established by bytes `ev_a7dad45bb62653bdf68a4b51b9edc6b4c1c45d2eec02f897ee161f600a6b56b1` and `ev_c137b152787c0ccb564a189b81e27a973350f37aff6d7059c26e595156aaabfe`. `c++filt -t` decodes the name as `std::__1::__function::__func<polydigm::music::ui::ChordPaletteContent::ChordPaletteContent(...)::lambda(), ..., void()>`. Its containing constructor signature lists Project, ChordSymbolisation observable, GlobalSelection, optional NoteSelection observable, ChordRelationsMode observable, mutable Scale observable, const Scale observable, and ChordPreviewPlayer references. These are the parameters of the containing constructor; the name does not identify the lambda's captured argument or capture fields. In particular the appearance of `Observable<ChordSymbolisation>` is not capture evidence.

## Corrections and remaining boundaries

Replace the PALETTE-SPEC assertion that the callback captures the ChordSymbolisation argument with V=O+0x620. Replace the claimed unknown current-to-generator join with current298 → notification collection+58 → callback cd82c → V+170 → current298 → cb730 → ce1fc. Project source at O+0x170 remains a different field: V+0x170 is O+0x790, never O+0x170. This capture correction does not independently prove the semantic identity of the selector's caller-supplied baseline source.

Display flattening/order, every possible refresh origin, scoring semantics, preview defaults, and runtime rendering remain outside this narrow validation. No new inference about those gaps follows from resolving the callback base.
