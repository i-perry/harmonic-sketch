# ModeSelector binding validation — 2026-10-29

Analysis only, original Klimper arm64 artifact `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`. Ghidra 12.1.4; profile `966e6016724421ad282356f583a9d5bf24577db4ac77a75c7099d236b88bcc28`. This pass reuses the complete 202-record export `research/rea-palette-mode-selector-binding-2026-10-29.json`; no original execution, activation bypass, clone change, QA, or publishing.

## Observed binding

The owner constructor dossier `ev_fd0a370d23c3ed759d1430b5c9e9324e2ebccafb995203201fa875698177584e` contains the decisive assembly stores omitted by the earlier prose audit. Let O be owner x19 and S=O+0x908 (formed at `0x100097818`).

| Selector field | Observed source | Exact store |
|---|---|---|
| S+0xf0 current observable | O+0x298 | `0x100097830` loads sp+0x30; `0x100097834` stores O+0x9f8 |
| S+0x110 baseline observable | O+0x230 | `0x100097850` loads sp+0x50; `0x100097854` stores O+0xa18 |
| S+0x130 follow flag | 1 | `0x10009786c` stores byte w8 to O+0xa38 |

The current pointer originates at `0x1000972d8` (O+0x298), saved at `0x100097310` to sp+0x30. The baseline originates at `0x100097228` (O+0x230), saved at `0x100097230` to sp+0x50. `mov w8,#1` at `0x100097840` establishes the initial flag; both intervening `ldaddal x8,x9,[x24]` instructions write the returned old counter to x9, preserving source x8=1. Thus the two Scales are distinct objects. The selector does not directly edit the Project Scale.

## Observer wiring

In that same dossier, `0x100098210` loads current O+0x9f8, `0x100098234` forms its +0x38 subscription source, and `0x100098240` calls `FUN_10000a514` with a closure capturing S and vtable `0x1009c35e0`. Its invoke slot +0x30 at `0x1009c3610` is `FUN_1000c9ba4`, established by byte record `ev_4a370e12cd039166953892ac2ee365b3c1ac198125117c2b792d114bec4e75ba`. That callback invokes selector refresh `FUN_1000c94b8` (`ev_293f0874aea0588c8dd64d8ef9d3ea1a414538652b5f850604d938d99ae4df5c`).

`0x10009839c` loads baseline O+0xa18, `0x1000983c0` forms its +0x38 subscription source, and `0x1000983cc` subscribes a closure capturing S with vtable `0x1009c36e0`. Its invoke slot +0x30 (`0x1009c3710`) is `FUN_1000c98d8`, established by `ev_583177b43703825c98aab64a640ec875485ab7e4dfaafc4aa0736686f3dc9c73`.

Baseline callback `FUN_1000c98d8` copies baseline into current when follow is nonzero; with follow zero it only refreshes (`ev_28a5a66bd0c795e4bed4f9bce183438e870901ca9233039c66e2e98888c75c35`). `FUN_1000c541c` updates O+0x230 from the caller-supplied source held at O+0x170 (`ev_c5b3319a79b634774e44bdd01f810e1b8b46fa80fd62c363a8bad788781107f3`). Initial sync occurs at `0x100098d70`, after subscription setup. Together these establish source → baseline230 → current298 while follow is enabled; the source object’s identity is unresolved.

## Left/right fifth mapping

The left description is stored at O+0xe28; the right description is stored at O+0x14c0 (owner pseudocode `ev_aeab2cd7c2f0735981cba6702c5a6d4331016b4d3927b9a8ac89fcc7162be0cf`; assembly stores `0x1000985ac` and `0x100098674`). Their adjacent action fields are O+0xe30 and O+0x14c8.

At `0x100098034`–`0x100098050`, the constructor installs the S-capturing closure with vtable `0x1009c2f18` into O+0xe30. Its +0x30 slot (`0x1009c2f48`) resolves to `FUN_1000cb224` by `ev_b2bf2fd6f0f77cda4f80fef6a9847bf6edec864286d32c7bddcedc6615c856ba`: **left subtracts 7 modulo 12**.

At `0x100098080`–`0x1000980a0`, it installs vtable `0x1009c2f98` into O+0x14c8. Its +0x30 slot (`0x1009c2fc8`) resolves to `FUN_1000caf34` by `ev_74032727897363a46fb43df5a6bb3b2cb22a04ebe5f152cdf34dfb9487feef39`: **right adds 7 modulo 12**. Callback arithmetic evidence respectively `ev_5bd0564e15235fb73e2fad64ca16c027a3f593004654dcef0aa9fbdb12588ea7` and `ev_39952d4cb880456498768307bbb10e43ee11fe8d276e6179e34956b437366ed0`.

## Derived validation vectors and corrections

- Initial follow=true. Both local defaults are C Major; initial source synchronization replaces baseline/current if the supplied Scale differs.
- If the supplied Scale is D Major while follow=true, baseline/current become D Major. Left yields current G Major (2−7 mod12=7), preserves steps, and disables follow; right from D yields A Major (2+7=9) and disables follow.
- If the supplied Scale changes to E Major while follow=false, baseline becomes E Major and current borrowing selection is preserved; display refreshes.
- Follow toggle always copies baseline into current before flipping flag (`ev_39cfb1e95ebaed1c956ffef1c60cc864ac9aee19ecd487c71b044dd65a36a186`). Disabling follow therefore initially leaves current equal to the supplied baseline; enabling follow resets a borrowed selection to current baseline.
- Corrections to PALETTE-SPEC: constructor alias, initial flag, and displayed fifth mapping are now statically resolved. The current value and source-fed baseline are distinct objects; the source referent’s identity is unresolved.

These are static control-flow/data-flow conclusions, not observed runtime outcomes. The join from current298 to every downstream palette refresh/generation path still requires its own evidence; do not replace the producer’s caller-supplied source pointer merely from this binding result. Display flattening/order, preview state defaults, and activation behavior remain outside this validation.
