# Tonal callback validation

Validated statically against retained Ghidra pseudocode **and ARM64 branches** for `FUN_100007248`, evidence `ev_bd1bbcc3048702a50e45f5a419956cd0a564e8a618f5e8bef526cac6782352b4`, in `research/rea-harmony-review-evidence.json`. Initializer `ev_ed50d4c10b4c435fb7742dcf151c36e3413253e355cc40e3698f17f7209b0bb0` establishes globals `1009ebffc=1`, `1009ec000=2`, `1009ec004=3`, `1009ec008=4`, `1009ec00c=5`. Target: thin arm64 `research/Klimper-arm64`, SHA-256 `3f26469013c1d3ac1cde475d851641da312c3100aa5ad452fdb6ebc737476d41`.

## Critical correction to HARMONY.md

The branch is **not crossed-only**. It is entered if **either chord contains either exact stored interval 2 or 5**. The tree is an ordinary lower-bound/exact-equality search, not a special relation between the two trees. Assembly `72c8` branches directly to `74bc` when A contains 2; `7308` does the same for A5. Only when A has neither does it inspect B2 (`7350`) and B5 (`738c`), again branching directly to `74bc`. Ordinary path starts at `7390` only after all four membership tests fail. Consequently existing “same interval stays ordinary” routing vectors are incorrect.

Membership checks use the stored ushort interval values, **not values reduced modulo 12**. Thus an interval 14 is not interval 2 for branch selection. Pitch classes computed from root plus selected interval are normalized modulo 12.

## Exact ordered algorithm

Let A be first engaged chord, B second chord, `pc(x)` normalize modulo 12, `IA`/`IB` be exact interval sets, and `P(A)={pc(A.root)} union {pc(A.root+i): i in IA}`.

1. If A is disengaged return Float bits `0x3f4ccccd` (approximately 0.8).
2. If neither IA nor IB contains 2 or 5, run the ordinary root/key algorithm already documented in HARMONY.md.
3. Otherwise run the following suspension path; key is unused here.
4. Select A's offset with **2 preferred over 5**. If neither exists, skip to step 7. Set `x=pc(A.root+selectedA)`.
5. Select B's third with **3 preferred over 4**. If neither exists, skip to step 7. Set `y=pc(B.root+selectedThird)`.
6. Check **A5 membership again**, independently of the offset chosen in step 4. If A contains 5, return 1 when `y==pc(x-1)` OR `y==pc(x-2)`. Otherwise (A contains 2 but not 5), return 1 when `y==pc(x+1)` OR `y==pc(x+2)`. If neither matches, continue.
7. Select B's suspension offset with **2 preferred over 5**. If neither exists, return 0. Set `z=pc(B.root+selectedB)`. Return Float bits `0x3f333333` (approximately 0.7) if `z in P(A)`, else return 0.

There are **no same-root, tonic-root, key-relative, or root-delta acceptance predicates** in this suspension path. Those belong exclusively to ordinary path. The final 0.7 condition is pitch-class membership, not root distance. Step 6 with A containing both 2 and 5 deliberately uses `x=A.root+2` and downward offsets because the later test prefers presence of 5; do not simplify these separate priorities into a single selected suspension kind.

Assembly anchors: A offset selection `74bc–7664`; B third selection `7678–76f4`; normalized B third `76f8–7744`; A5 recheck `7748–7784`; upward tests `77bc–77fc`; downward tests `7810–78a8`; B2/B5 fallback selection `78ac–7918`; B adjusted pitch `791c–7944`; construction of P(A) through `FUN_100006784` `7948–7978`; exact target membership and 0.7/0 returns `797c–79d8` and `7c90`. Branch at `79dc` returns the success float 1 already loaded at `77e0`/`7858`.

## Derived score vectors

These are mathematical consequences of the static algorithm, not runtime observations. Inputs are root plus exact interval set. All use key 0; any other key produces identical suspension scores.

| A | B | Score | Reason |
|---|---|---|---|
| 0 {2} | 0 {3} | 1 | x=2, y=3, upward 1 |
| 0 {2} | 0 {4} | 1 | upward 2 |
| 0 {5} | 0 {4} | 1 | x=5, y=4, downward 1 |
| 0 {5} | 0 {3} | 1 | downward 2 |
| 0 {2,5} | 9 {4} | 1 | x=2 despite A5; y=1 downward 1 |
| 0 {2,5} | 0 {3} | 0 | x=2, downward targets 1/0; B has no fallback suspension |
| 0 {2} | 11 {3,4} | 0 | B3 wins: y=2; B4 would wrongly accept y=3 |
| 0 {2} | 0 {5} | 0 | same roots do not auto-accept; fallback 5 absent from P(A) |
| 0 {5} | 0 {2} | 0 | crossed reverse does not auto-accept |
| 0 {2} | 0 {2} | 0.7 | fallback z=2 in P(A) |
| 0 {4,7} | 2 {2} | 0.7 | A has neither; fallback z=4 in P(A) |
| 0 {4,7} | 2 {5} | 0.7 | fallback z=7 in P(A) |
| 0 {7} | 2 {2,5} | 0 | fallback B2 wins z=4; B5 would wrongly accept z=7 |
| 11 {2} | 11 {3} | 1 | x=1 and y=2 normalize across octave |
| 0 {14} | 0 {3} | 1 | ordinary branch (same root), raw14 does not trigger suspension |

## Scope and remaining uncertainty

This resolves the full suspension scorer for ordinary valid chord storage, and corrects routing. The Swift implementation now follows this predicate chain and has derived-vector tests for all 15 rows above. Caller-to-UI roles and second optional engagement guarantees remain unresolved; this is callback-order reconstruction only. No original app was executed, activated, or license check bypassed. No claim of full application parity follows.
