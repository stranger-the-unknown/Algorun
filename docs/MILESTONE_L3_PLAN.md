# L3 plan — taking the algorun-lang language additions into the game

Written 2026-11-18, before the port. Branch `claude/l3-lang-import-30795c`,
based on `main` = `4fbbfed`. Source: `stranger-the-unknown/algorun-lang`
`main` = `299315c` (read-only clone; nothing is pushed there, and its
`wip/d12-host-calls` and `wip/d14-memory` branches are not used).

What was done is in [`MILESTONE_L3.md`](MILESTONE_L3.md). This file is the
plan and the measurements behind it.

## 1. The two repositories, compared

algorun-lang copied `packages/algorun_engine` at game commit `c654469`. The
game's engine has not changed since (`git diff c654469 4fbbfed --
packages/algorun_engine` is empty), so the whole difference is algorun-lang's
own work:

| Part of algorun-lang | Size | Taken? |
|---|---|---|
| Engine `lib/` changes in 10 files (D1–D12) | 772 diff lines | D1, D5–D12 now; D2–D4 wait for the owner (§4) |
| `lib/src/text/text_form.dart`, `bin/algorun_text.dart` (A5 text form) | new files | no — the game has only blocks |
| `c/` (B1 portable C core) | new | no — it is for the operating-system project |
| `test/algorun_lang_a3_test.dart`, `algorun_lang_d1_test.dart`, marked changes in `functions_test.dart` | tests | yes |
| Marked D3 / D4 changes in `floor_divide_test.dart`, `interpreter_test.dart`, `shipped_puzzles_test.dart` | tests | with D2–D4 only |
| `conformance/` (281 files) | data | not copied; run from a clone (§5) |
| `docs/spec.md` | spec | not copied; `MILESTONE_L3.md` lists the remaining differences |

Deviations by number (algorun-lang `ORIGIN.md`, `docs/spec.md` §12):

| Id | Change | Touches old programs? |
|---|---|---|
| D1 | a single capital letter parses as a generic type (IR JSON round-trip) | no |
| D2 | a result outside signed 64 bits is the error "This number is too big." | number model |
| D3 | DIVIDE truncates toward zero | number model |
| D4 | no fractions: a fractional literal or input is refused | number model |
| D5 | COPY is a deep copy, charged in memory cells | only programs with COPY — no puzzle allows it |
| D6 | text blocks `str.*` | new blocks |
| D7 | deque blocks `new.deque`, `deque.*` | new blocks |
| D8 | SORT `arr.sort` | new block |
| D9 | pairs: `PairValue`, `pair.make / first / second` | new blocks |
| D10 | functions take up to six values (`fn.call4..6`) | no (a limit is raised) |
| D11 | a FUNCTION that can end without RETURN is refused before it runs | a player program that relied on it is now refused earlier (it was a runtime error when the end was reached) |
| D12 | SORT's list type is checked before running | new block |

## 2. How the additions are taken

**The deviations are ported one by one into the game's engine; the game's
engine is not replaced by a dependency on algorun-lang.**

Because the base is identical, copying a changed file and applying its patch
give the same text today, so the choice is about what happens next:

- **Not a path / git dependency on algorun-lang.** That repository is private
  and the game is public; it carries D2–D4, which the web build cannot take
  as written (§4); it will keep moving for the operating-system project; and
  three sibling sessions are editing the game's engine right now (T1
  `interpreter.dart` tracing, M1 `parse.dart`, E1 around the editor). A
  wholesale swap would turn their merges into conflicts in every file.
- **Port per deviation**, in a few commits, keeping algorun-lang's comments
  (`algorun-lang D5` …) so each hunk can be traced back. The hunks are
  additive: new `case` arms, new catalog entries, new helpers. The only
  rewritten lines are `_copy` in `lower.dart` (D5) and four lines of
  `functions_test.dart`.

Shared files this touches, for the coordinator (full list in
`MILESTONE_L3.md`): `interpreter.dart` (new `case` arms at the top of the
built-in switch and helpers before "coercions"; nothing near `TraceSink` /
`_emit`), `lower.dart`, `catalog.dart`, `chrome.dart`, `parse.dart` (one new
optional field, §3), `value_json.dart`, `runtime_value.dart`.

## 3. What the game needs that algorun-lang does not have

algorun-lang has no editor and no puzzles, so three things are new here:

1. **Pairs as puzzle input.** algorun-lang writes a pair as
   `{"type":"pair","first":…,"second":…}` but cannot read one. The game reads
   the same spelling, so a puzzle can take `array<pair<str,num>>`.
2. **Entering text.** The editor has no keyboard, by design. A puzzle may
   list the text constants its TEXT block offers (`"texts": ["", " ", "a"]`,
   closed data like `variables.pool`); the player picks one from chips. The
   empty text is always offered.
3. **Editor, guide, wording.** Captions for the new holes, a TEXT literal
   that shows its value, block reference entries (English and Turkish),
   Turkish for the new engine sentences, the content validator's capability
   audit (`strings`, `sorting_builtin`, `pairs_tuples`, `monotonic_deque`),
   and one or two sample puzzles per family.

## 4. Do the 149 reference solutions change?

**No — measured, not assumed.** With D1 and D5–D12 ported and D2–D4 left out:

| Check | Result |
|---|---|
| algorun-lang `conformance/refs`: 152 reference programs, 1455 cases, expectations recorded from the unmodified game engine (status, output, ops, peakAlloc, peakDepth, message, blockId) | 1455 of 1455 identical |
| Content validator output (every `INFO [L5 performance]` line: operations, memory cells, depth, blocks for 222 solutions and rejects; the recorded `metrics` drift check; all rejects) before and after | byte-identical; `PIPELINE 149 of 149` |
| IR of every reference (`Program.toJson`) | unchanged (the conformance programs round-trip) |

Why nothing moves: no puzzle allows COPY (`var.copy` is in no `blocks.allow`,
so D5 cannot reach a reference or a saved solution), no reference has a
FUNCTION that can end without RETURN (D11), and D6–D10, D12 only add blocks.
No budget and no expected answer is edited.

If the owner later takes the number model (§5): no reference uses DIVIDE, no
fixture holds a fraction or a value beyond 2^53, and algorun-lang's own run of
all 152 references with D2–D4 gives identical operation counts, so the 149
would still not change. One *designed trap* would: see option C below.

## 5. The number model — an owner decision

algorun-lang's numbers (D2–D4) are signed 64-bit integers, and its spec §6.4
says Flutter web is not supported, because a browser's JavaScript numbers are
exact only up to 2^53. The game's web version must keep working and must
agree with the phone.

### What the game does today (measured)

The same Dart file, compiled three ways (`dart compile exe` = the phone's
runtime, `dart compile js`, `dart compile wasm`), run under Node 24:

| Expression | Phone (VM) | Web, JavaScript | Web, Wasm |
|---|---|---|---|
| 2^53 + 1 | 9007199254740993 | 9007199254740992 | 9007199254740993 |
| (2^63 − 1) + 1 | −9223372036854775808 (wraps) | 9223372036854776000 | wraps like the phone |
| 3037000500 × 3037000500 | −9223372036709301616 | 9223372037000250000 | like the phone |
| 7 / 2 × 2, printed | `7.0` | `7` | `7.0` |
| 0 × −3, printed | `0` | `-0.0` | `0` |
| `int.tryParse("9223372036854775808")` | null | 9223372036854776000 | null |
| algorun-lang's overflow test `((a^r)&(b^r)) < 0` on max + 1 | error (right) | no error (wrong) | error (right) |

So the phone and the web **already disagree** today for fractions that become
whole again, for negative zero and for anything past 2^53. No shipped puzzle
reaches these (no fractions, nothing past 2^53 in any fixture; only one
puzzle allows DIVIDE), which is why nobody has seen it.

### Options, each tried

**A. Leave the numbers alone; take only D5–D12.** Nothing changes for the
player. The game then differs from algorun-lang in 24 of 1652 conformance
cases (all D2 / D3 / D4), and the phone / web differences in the table stay.

**B. Build the web version as Wasm and take D2–D4 as written.**
`flutter build web --wasm` works on this app (2 min 37 s; `main.dart.wasm`
2.41 MB, 894 kB gzipped, next to `main.dart.js` 3.04 MB, 886 kB gzipped). Wasm
integers are real 64-bit integers: every row above matches the phone. But the
build always ships the JavaScript version too and picks at start-up: per the
Flutter documentation only Chromium browsers run the Wasm build by default;
Firefox and Safari (so every iPhone browser) fall back to JavaScript, as does
any browser without WasmGC. On that fallback algorun-lang's overflow test
fails silently and DIVIDE-free arithmetic past 2^53 rounds. So B gives two web
behaviours, chosen by the visitor's browser. Removing the fallback would lock
those browsers out.

**C. "Safe whole numbers": D3 and D4 as written, D2 with the limit at
±(2^53 − 1) instead of ±2^63.** Numbers are whole; DIVIDE truncates; a result
outside ±9 007 199 254 740 991 is "This number is too big." on every
platform. Inside that range a JavaScript number, a Wasm integer and the
phone's integer are all exact, so the three agree by construction. A
prototype (`packages/algorun_engine/tool/number_model_probe.dart`: `+ − × ÷
floor-÷ remainder`, text → number) ran 1 088 014 results
over values around every boundary: **the same digest on the phone runtime,
JavaScript and Wasm** (after two fixes the measurement itself found: negative
zero, and judging a product's size before the phone wraps it). Cost of the
check: 20 M × (multiply, remainder, add) in 0.76 s on the phone runtime,
0.88 s in JavaScript, 1.46 s in Wasm — the same order as unchecked arithmetic.
The game becomes a strict subset of algorun-lang: a program that runs
without "too big" in the game gives the same answer in algorun-lang; only
values between 2^53 and 2^63 are an error in one and fine in the other.
Conformance differences would drop from 24 to the cases that use values past
2^53 (expected, not yet run: C is not implemented on this branch).
What changes in the game: `7 DIVIDE 2` is 3, not 3.5; The Smallest Cart (the
only puzzle that allows DIVIDE) loses its "DIVIDE midpoint" trap, because a
truncated midpoint is right for positive numbers — no reference, reject or
fixture changes, one engine test does; a saved player solution that used a
fractional DIVIDE there would now pass.

**D. Exact 64-bit integers everywhere, emulated in the browser.** Identical
to algorun-lang on every platform. JavaScript has no 64-bit integer, so
`NumValue` would have to hold a `BigInt` (or a three-word emulation) on the
web. Measured with `BigInt`: 20 M × (multiply, remainder, add) takes about
39 s on the phone runtime and 89 s in JavaScript — 50 to 100 times slower
than C — and every place that reads a number (engine, validators, fixtures,
the results screen, saved solutions) changes type, across files three other
sessions are editing.

### Recommendation

**C.** It is the only option where the phone, a Chrome visitor and a Safari
or Firefox visitor provably compute the same thing, it removes the
differences that exist today, it costs nothing measurable, and it keeps the
game inside algorun-lang's language instead of beside it. The Wasm build can
still be turned on later for speed; it no longer decides correctness.

Until the owner decides, nothing that changes arithmetic is committed: the
branch keeps the game's numbers exactly as they are (option A). The two new
blocks that turn text into numbers and back cannot avoid the question, so
they already stay inside ±(2^53 − 1) — NUMBER AS TEXT of a larger or
fractional number is an error, TEXT AS NUMBER of a longer number is NOTHING —
which is the one rule that is the same on the phone and the web under every
option.

## 6. Order of work

1. Engine: D1, D5–D12, pair fixtures, `texts`; algorun-lang's tests plus game
   tests for what is new here.
2. Conformance runner against a clone, with the known-difference list.
3. Editor drawing, captions, TEXT chips; block reference; Turkish sentences.
4. Content validator: capability audit, replay of TEXT literals; `run_graph`.
5. Sample puzzles (text, deque, SORT, pairs, COPY) through the seven levels.
6. One web build and one emulator pass at the end (the machine is shared).
7. `MILESTONE_L3.md`.
