# L3 — the algorun-lang additions in the game

2026-11-18. Branch `claude/l3-lang-import-30795c`, based on `main` =
`4fbbfed`. Source: `stranger-the-unknown/algorun-lang` `main` = `299315c`
(read-only clone; nothing was pushed there; the `wip/*` branches were not
used). Plan and measurements: [`MILESTONE_L3_PLAN.md`](MILESTONE_L3_PLAN.md).

The language additions algorun-lang made after it copied the game's engine
are now playable: text, a deque, SORT, pairs, a real COPY, functions with up
to six values and two static checks. They run in the engine, draw and are
set in the editor, are explained in the block reference in English and
Turkish, have fixture forms, pass the content pipeline, and ship ten small
puzzles in a new world 15.

**Second part, after the merge (same day, on `main` = `d983b6c`): the number
model.** The owner chose option C of the plan, "safe whole numbers": numbers
are whole, DIVIDE truncates, and a result outside ±(2^53 − 1) is "This number
is too big." on the phone, in JavaScript and in Wasm alike. It is implemented
on this branch in two commits on top of `main`; see "Number model". Sections
written before the decision say so where they describe the earlier state.

## Taken and not taken

| Id | algorun-lang change | In the game |
|---|---|---|
| D1 | a single capital letter parses as a generic type, so IR JSON round-trips | taken |
| D2 | a result outside signed 64 bits is "This number is too big." | taken after the owner's decision, with the limit at ±(2^53 − 1) instead of ±(2^63 − 1) |
| D3 | DIVIDE truncates toward zero | taken after the owner's decision |
| D4 | no fractions | taken after the owner's decision |
| D5 | COPY is a deep copy, charged in memory cells | taken |
| D6 | text blocks | taken; the two text ↔ number blocks are narrower (below) |
| D7 | deque blocks | taken |
| D8 | SORT (stable bottom-up merge sort, one operation per comparison) | taken |
| D9 | pairs | taken, plus a fixture (input) form algorun-lang does not have |
| D10 | functions take up to six values (`fn.call4..6`) | taken |
| D11 | a FUNCTION that can end without RETURN is refused before it runs | taken |
| D12 | SORT's list type is checked before running | taken |
| A5 | text form of programs (`text_form.dart`, `algorun_text`) | not taken: the game has only blocks |
| B1 | C core | not taken: it belongs to the operating-system project |

How: ported per deviation into the game's own engine, keeping algorun-lang's
comments on each hunk; the engine is not replaced and does not depend on the
other repository (reasons in the plan, §2).

## New blocks

| Block (editor label) | Id | Type | Notes |
|---|---|---|---|
| TEXT | `lit.str` | → `str` | existed, could not be set; now chosen from chips |
| TEXT LENGTH | `str.len` | `str → num` | letters are Unicode code points |
| LETTER AT | `str.char_at` | `str, num → str` | positions from 0; outside is an error |
| JOIN | `str.concat` | `str, str → str` | longer than `maxArrayLen` letters is a memory limit |
| PART OF TEXT | `str.substring` | `str, num, num → str` | `[start, end)` |
| COMPARE TEXT | `str.compare` | `str, str → num` | −1 / 0 / 1 by code point |
| NUMBER AS TEXT | `str.from_num` | `num → str` | decimal digits, `-` for a negative number |
| TEXT AS NUMBER | `str.to_num` | `str → num?` | `-?[0-9]+` within ±(2^53 − 1), else NOTHING |
| NEW DEQUE | `new.deque` | → `deque<T>` | |
| PUSH FRONT / PUSH BACK | `deque.push_front` / `push_back` | statement | +1 memory cell |
| POP FRONT / POP BACK | `deque.pop_front` / `pop_back` | `deque<T> → T` | empty is an error |
| FRONT / BACK / SIZE / IS EMPTY | `deque.front` / `back` / `size` / `empty` | | |
| SORT | `arr.sort` | statement on `array<num>` or `array<str>` | in place, stable, 1 operation per comparison |
| COPY | `var.copy` | statement, two names | existed as an alias; now a deep copy |
| MAKE PAIR / FIRST / SECOND | `pair.make` / `first` / `second` | `T, U → pair<T,U>` | immutable, +1 memory cell |
| CALL with 4–6 values | `fn.call4` … `fn.call6` | | `FunctionSignature.maxParams` = 6 |

## Number model — decided: safe whole numbers

**Decision (owner, 2026-11-18, relayed by the coordinating session):** option
C of [`MILESTONE_L3_PLAN.md`](MILESTONE_L3_PLAN.md) §5. Commits `268f781`
(engine) and the two after it, on top of `main` = `d983b6c`.

### The rules

1. **A number is a whole number from −9 007 199 254 740 991 to
   9 007 199 254 740 991** (±(2^53 − 1), `maxSafeNumber` in
   `packages/algorun_engine/lib/src/runtime/whole_number.dart`). Inside that
   range the phone's 64-bit integers, a browser's JavaScript numbers and Wasm
   integers are all exact, so every platform computes the same thing.
2. **No fractions** (algorun-lang D4). A fractional literal is
   `invalidProgram` "Only whole numbers can be used."; a fractional input is
   `invalidProgram` "This program only works with whole numbers." before
   anything runs; a whole `2.0` is the number 2.
3. **DIVIDE truncates toward zero** (D3): `7 DIVIDE 2` = 3, `-7 DIVIDE 2` =
   −3. FLOOR DIVIDE still rounds down (`-7 FLOOR DIVIDE 2` = −4) and
   REMAINDER is still never negative; the two divisions differ only below
   zero. Dividing by zero is the same error as before.
4. **A result outside the range is the run-time error "This number is too
   big."** (D2 with the limit at 2^53 − 1): PLUS, MINUS, TIMES, INCREMENT,
   DECREMENT, the FOR counter, and a literal or input that is already
   outside. Before, the phone wrapped silently at 2^63 and a browser rounded
   from 2^53.
5. **Fixture JSON** (`value_json.dart`, so puzzle files, `run_graph` and the
   content validator) refuses a fraction ("Numbers are whole: 2.5 has a
   fraction.") and a number outside the range ("Numbers go from … to …"),
   also for list-node and tree-node values and graph ids. `2.0` reads as 2.

### The two traps the prototype found, in the real interpreter

- **Size before wrap.** On the phone `a × b` can wrap around 64 bits and land
  back inside the range (`4294967296 × 4294967296` is 0 there). `_mul` judges
  the size on the double product first — it only rounds, and never down past
  2^53 — and multiplies as integers only when that passed.
- **Negative zero.** JavaScript has one (`0 × −3`, `−1 ÷ 5`, `−0`) and prints
  it; the phone does not. `_unsigned0` removes it after TIMES, DIVIDE,
  REMAINDER and NEGATE, and `wholeNumber` on the way in.

### What became simpler

- NUMBER AS TEXT is `n.toString()`: its "needs a whole number" and "too big"
  errors cannot happen any more and are gone, with their Turkish.
- List and text positions lose "A position has to be a whole number.": a
  position is a number, and a number is whole.
- TEXT AS NUMBER is unchanged: it already read digit by digit and stopped at
  the limit.

### What a player notices

- `7 DIVIDE 2` is 3, not 3.5. Only **The Smallest Cart** offers DIVIDE; there
  a DIVIDE midpoint used to fail and now solves the puzzle exactly like FLOOR
  DIVIDE, at the same cost (65 204 operations). A saved solution that used
  DIVIDE there now passes.
- A program whose numbers run away — a factorial past 18!, doubling in a long
  loop — stops with "This number is too big." instead of going on with a
  wrong number. No shipped puzzle reaches the limit: nothing in any fixture is
  past 2^53 and every reference stays far inside.
- The block reference says so: DIVIDE and FLOOR DIVIDE have new texts and
  there is a "Number" concept, in English and Turkish.

### Nothing shipped changed

| Check | Result |
|---|---|
| Content validator on the 204 campaign puzzles and 5 probes, compared with a clean copy of `main` (`git archive d983b6c`) | the whole output — every `INFO [L5 performance]` line, every verdict, 492 lines — is identical; `PIPELINE 204 of 204` |
| `tool/web_parity.sh`: 207 reference programs, 2138 cases; one digest of every output, operation count, memory peak and depth | 516329794 on `main` and on this branch, on the Dart VM, dart2js and dart2wasm alike |
| T1's `trace_parity_test.dart` (every corpus run untraced, traced, and against its golden file) | passes with the golden file untouched |
| algorun-lang `conformance/refs` (1455 reference cases from before any of this) | 1455 of 1455 identical |
| Puzzle files, reference files, rejects, fixtures, budgets, expected answers | none edited |

Why: no reference solution or reject uses DIVIDE (The Smallest Cart is the
only puzzle whose palette has it, and its reference uses FLOOR DIVIDE), no
fixture holds a fraction or a number past 2^53, and no reference computes
one. The Smallest Cart passes the validator as it is — reference, its one
reject ("raise the capacity one unit at a time", `operationLimit`) and
fixtures unchanged. Its offline notes still call the DIVIDE midpoint a trap
(`content/references/world_02/smallest_cart.json` `notes` and `spec.traps`
"midpoints must be whole numbers"; the puzzle's `edgeCases` "midpoints that
are not whole numbers"): that wording is now out of date and was left alone,
because nothing needed changing to pass. See the list for the coordinator.

### Tests changed, each for the stated reason

| Test | Before | Now |
|---|---|---|
| `floor_divide_test.dart` "DIVIDE is unchanged" | `7 / 2` = 3.5 | "DIVIDE truncates toward zero": 3, −3, −3, 3 |
| `floor_divide_test.dart` "non-exact division never leaves a fraction" | `7.5 FLOOR DIVIDE 2` = 3 | the fractional literal is refused; `10 FLOOR DIVIDE 4` = 2 |
| `floor_divide_test.dart` "the same midpoint with DIVIDE is not" | "A position has to be a whole number." | the DIVIDE midpoint reads `nums[1]` |
| `interpreter_test.dart` "whole division stays whole…" | 3.5 | 3 |
| `shipped_puzzles_test.dart` smallest_cart with DIVIDE | not correct | correct, same operations |
| `value_json_test.dart` round trip of `-2.5` | accepted | refused; new cases for `2.0`, `-0.0`, the limit, nodes and graph ids |
| `l3_test.dart` text positions and NUMBER AS TEXT with fractions | their own errors | the fraction never becomes a number |
| `trace_test.dart` 150-deep recursion | 150! (silently wrapped to 0) | the same recursion adding instead of multiplying |

New: `packages/algorun_engine/test/whole_number_test.dart` (18 tests: every
operator at the limit, the wrap cases, negative zero, fractions on the way
in, and a pinned digest over 106 edge values × 6 operators) — it uses no
`dart:io`, so it also runs with `dart test -p node` and `dart test -p node -c
dart2wasm`, and passes on all three. `test/number_model_test.dart` in the app
pins the reference texts and The Smallest Cart.

## The 149 puzzles did not change (first part, before the merge)

| Check | Result |
|---|---|
| algorun-lang `conformance/refs` — 152 reference programs lowered by the unmodified game engine, 1455 cases, each with status, output, ops, peakAlloc, peakDepth, message and blockId | 1455 of 1455 identical on this branch |
| Content validator, every `INFO [L5 performance]` line of the 152 old references (operations, memory cells, depth, blocks) before and after | identical; the recorded `metrics` drift check passes; every old reject still ends in its verdict |
| Old puzzle JSON, reference files, budgets, expected answers | not edited (`git diff 4fbbfed -- assets/puzzles/world_0* assets/puzzles/world_1[0-4] content/references/world_0* content/references/world_1[0-4]` is empty) |

No puzzle offers COPY and no reference has a FUNCTION that can end without
RETURN, so D5 and D11 reach none of them; everything else is new blocks.

**One behaviour change for players (D11).** A saved or new solution whose
FUNCTION can reach its end without RETURN — for example `IF c THEN RETURN a`
followed by `IF NOT c THEN RETURN b` — is now refused before it runs
("FUNCTION f can end without RETURN.", Invalid Program) instead of failing
only when the end was actually reached. An IF counts only with an ELSE whose
two branches both return; a loop never counts. This affects world 12 only.

## What is new in the game beyond algorun-lang

- **Pairs as input.** `{"type": "pair", "first": …, "second": …}` is read
  as well as written (`value_json.dart`), `fixtureTypeProblem` accepts a
  pair of fixture types, and `valuesEqual` compares pairs by value. A puzzle
  can take or return `pair<…>` and lists of them.
- **`blocks.texts`.** The editor has no keyboard. A puzzle may list up to 24
  text constants of up to 24 letters (`BlockPolicy.texts`,
  `BlockPolicy.textChoices` = the empty text first, then the list). Closed
  data; needs `lit.str` in `blocks.allow`; the empty text is always offered
  and may not be listed.
- **Editor** (`lib/editor`, the smallest change that draws and sets the new
  blocks): a TEXT shows its value in quotes (`""`, `"-"`) and is chosen from
  chips (`LiteralSheet.showText`, `quotedText`,
  `EditorController.textChoices`); with nothing but the empty text to choose
  no sheet opens. COPY shows its two names as chips: COPY *source* TO
  *target*. Captions `text`, `deque`, `pair` for empty slots
  (`BlockChrome.holeCaption`, `holeCaptionText`). Every other new block
  draws through the existing layouts.
- **Block reference**: 23 block entries and three concepts (Text, Deque,
  Pair), English and Turkish. Block names stay English in both languages,
  as before; each entry has its Turkish name and explanation.
- **Wording**: Turkish for ten new engine sentences and the missing-RETURN
  sentence; `pair<str,num>` reads "pair of text and number" / "metin ve sayı
  çifti".
- **Content pipeline**: `content/capabilities.json` — `strings`,
  `sorting_builtin`, `pairs_tuples`, `monotonic_deque` supported, new family
  `deque`; `bit_manipulation` and the starter-program modes stay blocked.
  Structures `text`, `deque`, `pair`. The editor replay (level 3) accepts a
  TEXT only with the empty text or one of the puzzle's texts, and COPY's
  `name` / `from`. `CONTENT_AUTHORING.md` has the rule for text.
- **`bin/run_graph.dart`** needed no change: it reads and writes values
  through `value_json.dart`, so pair input and deque / pair output work; a
  test pins it.

## Sample puzzles — world 15 "Text, Sorting & Pairs"

Opens after Arrays (`prerequisites: ["arrays"]`), teaches `text`, `sorting`,
`deque`, `pairs`. A separate world keeps the merge with the MS16 content
batch to one new entry at the end of `assets/worlds.json`; the coordinator
or the owner may move the puzzles into existing worlds later.

| Puzzle | Tier, mode | New blocks | Reject |
|---|---|---|---|
| Letter Tally | 1, build | TEXT LENGTH, LETTER AT, EQUAL on text | — |
| Seat Label | 1, edge | JOIN, NUMBER AS TEXT, TEXT with `blocks.texts` `"-"`, `"0"` | no 0 in front of a seat below 10 |
| Middle Child | 1, build | SORT (numbers) | the right one of the two in the middle |
| Top Scorer | 1, build | FIRST, SECOND, a list of pairs as input | on a tie the later player wins |
| Mirror Sign | 2, build | JOIN, LETTER AT, the empty TEXT | — |
| Smudged Tickets | 2, edge | TEXT AS NUMBER, IS NOT NOTHING on its result | — |
| Out of Place | 2, build | COPY, SORT (text) | — |
| Zigzag Queue | 2, build | NEW DEQUE, PUSH FRONT, PUSH BACK, POP FRONT, IS EMPTY | — |
| Pass List | 2, build | MAKE PAIR, a list of pairs as output | a score exactly on the mark is left out |
| Two Doors | 3, edge | PUSH BACK, POP FRONT, POP BACK, IS EMPTY | no empty check: "This deque is empty." |

Each has a reference built with the editor's commands, an oracle read off the
story and not the reference's algorithm
(`packages/algorun_content/lib/src/oracles/l3.dart`; text compared by code
point, never Dart's UTF-16 `compareTo`), expected answers produced by the
oracle and checked by hand against the stories, Turkish title, story and
three hints. `PIPELINE 159 of 159 campaign puzzle(s) accepted`, the same five
probe warnings as before.

Not given a puzzle: PART OF TEXT, COMPARE TEXT, FRONT / BACK / SIZE of a
deque, CALL with 4–6 values. They are tested in the engine and listed in the
block reference.

## Conformance with algorun-lang

The suite is not copied (that repository is private, this one is public). It
is run from a clone:

```bash
gh repo clone stranger-the-unknown/algorun-lang /tmp/algorun-lang
cd packages/algorun_engine
dart run tool/conformance.dart /tmp/algorun-lang/conformance --known tool/conformance_known.txt
```

Result at `299315c`, **after the number-model decision**:

```
edge   agree 140, differ 17
lower  agree 22, differ 0
refs   agree 1455, differ 0
text   agree 17, differ 1
conformance: 281 files, 1634 cases agree, 18 differ (18 known), 4 text-form files not run, 0 problem(s)
```

The 24 differences of the first part became 18, and they are no longer
three different things (overflow, DIVIDE, fractions) but one: **the game's
limit is 2^53 − 1 where algorun-lang's is 2^63 − 1.** Listed one by one in
`tool/conformance_known.txt`:

| Count | What |
|---|---|
| 13 | the case's *input* is past 2^53 − 1 (±2^63 edges); the game refuses it when the fixture is read, so the program never starts |
| 2 | the same "too big" error, reached sooner: a FOR counter after 4 operations instead of 8, and 20! (21! is past both limits) |
| 1 | TEXT AS NUMBER of `9223372036854775807` is NOTHING |
| 2 | a fractional input is refused one step earlier, when the fixture is read; handed the value directly the interpreter answers exactly as algorun-lang does (`whole_number_test.dart`) |

Every DIVIDE case, every fractional-literal case and the overflow cases that
start inside 2^53 now agree, operation counts and messages included.

Before the decision (first part) it was:

```
edge   agree 134, differ 23
lower  agree 22, differ 0
refs   agree 1455, differ 0
text   agree 17, differ 1
conformance: 281 files, 1628 cases agree, 24 differ (24 known), 4 text-form files not run, 0 problem(s)
```

Every case compares the whole expectation (status, output, ops, peakAlloc,
peakDepth, message, blockId; lowering cases compare the errors) and every
stored program must survive `Program.fromJson` → `toJson`. Those 24 were
11 × D2, 7 × D3, 4 × D4 and the two text ↔ number cases past 2^53. The tool
fails when a listed case starts to agree or an unlisted one differs (a case
id may contain spaces, so the reason starts after two spaces). The four files not run are parse-error cases of the
text form.

## Phone and web

**After the number-model decision** (the first-part passes follow below):

- **The same engine on three targets, and the same as before.**
  `tool/web_parity.sh`, now 207 programs and 2138 cases: digest 516329794 on
  the Dart VM, dart2js and dart2wasm — and the same digest from a clean copy
  of `main`, so no output, operation count, memory peak or depth of any
  reference moved. `whole_number_test.dart`, `l3_test.dart` and
  `algorun_lang_a3_test.dart` pass with `dart test`, `-p node` and `-p node
  -c dart2wasm` (50 tests each). The prototype
  (`tool/number_model_probe.dart`) still prints `results 1088014 tooBig
  265067 digest 345775110` on all three.
- **The web build, with DIVIDE.** `flutter build web --release`
  (`main.dart.js` 3.63 MB), served from `build/web`, headless Firefox 160
  (the JavaScript build):
  1. The Smallest Cart's reference with its FLOOR DIVIDE swapped for DIVIDE,
     put into the browser's `algorun_save` as a draft, opened with CONTINUE
     and RUN: **CORRECT, 65,204 steps of 130,000, 0 memory cells, depth 1, 55
     blocks, 8 of 8 hidden cases** — the phone runtime (Dart VM, `runPuzzle`)
     gives correct, 65204, 0, 1, 55 for the same program. Before the decision
     this program failed on both.
  2. `RETURN (-7 DIVIDE 2)` built by taps in the same puzzle (picker, number
     pad with ±): the results screen says **"you gave: -3"** for both visible
     cases, 4 steps. The engine test gives −3 on the VM, in JavaScript and in
     Wasm.
- **Emulator: NOT TESTED** for the number model (the coordinator did not ask
  for it). The phone side is the Dart VM in the measurements above: the same
  runtime the APK uses, as a JIT test run and as an AOT executable for the
  prototype.

**First part:**

- **The same engine on three targets.** `tool/web_parity.sh` runs every
  reference in `content/references` (162 programs, 1550 cases) on the Dart
  VM, dart2js and dart2wasm and compares one digest of every output,
  operation count, memory peak and depth: identical on all three (digest
  222574733 on 2026-11-18). The new engine tests (`test/l3_test.dart`,
  `test/algorun_lang_a3_test.dart`) also pass with `dart test -p node` and
  `dart test -p node -c dart2wasm`.
- **The web build, played.** `flutter build web --release` (what
  `tool/web.sh` runs; `main.dart.js` 3.07 MB, 895 kB gzipped), served from
  `build/web` and driven in a headless Firefox 160 with a throwaway profile
  (the JavaScript build, the path algorun-lang's numbers would break): home
  shows "0 of 159 puzzles solved", world 15 opens, **Seat Label was built by
  taps** — SET, JOIN, the TEXT chips `""` `"-"` `"0"`, the number pad, IF,
  NUMBER AS TEXT — and RUN gave CORRECT, 17 steps of 100 (the validator's
  count on the VM is also 17), 7 of 7 hidden cases, saved in local storage.
  The built-in browser pane of the session could not be used: with no window
  showing it the page gets no animation frames, so Flutter never draws.
- **The phone build, played.** Debug APK from this branch on the
  `algorun_phone` emulator (Android 15, 720 × 1600 px at density 320 = 360 ×
  800 dp), after M1, T1 and E1 had finished with it: the same puzzle, Seat
  Label, built by taps found through the accessibility tree (`uiautomator
  dump`, `adb shell input tap`) — the picker, the TEXT chips, the number pad
  — and RUN gave **the same result as the web: CORRECT, 17 steps of 100, 0
  memory cells, 17 of 28 blocks, 7 of 7 hidden cases.** The save on the
  emulator now has that one puzzle solved; `wm size` / `wm density` were
  reset and the emulator stopped.

## Tests

After the number-model decision, on top of `main` = `d983b6c`:

| Suite | `main` after the merge | This branch |
|---|---|---|
| `packages/algorun_engine` `dart analyze` | no issues | no issues |
| `packages/algorun_engine` `dart test` | 487 | **506** (+18 `whole_number_test.dart`, +1 in `floor_divide_test.dart`) |
| `packages/algorun_content` `dart analyze` | no issues | no issues |
| `packages/algorun_content` `dart test` | 114 | **114** |
| Content validator | 204 of 204, `OK 209`, 5 warnings | **204 of 204**, `OK 209`, the same 5 warnings; output identical line by line |
| `flutter analyze` | no issues | no issues |
| `flutter test` | 820 | **824** (+4 `number_model_test.dart`) |
| algorun-lang conformance | 1628 agree, 24 known differences | **1634 agree, 18 known differences**, 0 problems |
| `tool/web_parity.sh` | digest 516329794 | **digest 516329794**, identical on VM, dart2js, dart2wasm |

The 487 on `main` was run here before any edit; 114 and 820 are the
coordinator's numbers for `main` (the first local run of those two suites
overlapped with the engine edit and was thrown away); the validator's `main`
output comes from a clean `git archive d983b6c`.

First part, before the merge:

| Suite | Before (2026-10-30) | Now |
|---|---|---|
| `packages/algorun_engine` `dart analyze` | no issues | no issues |
| `packages/algorun_engine` `dart test` | 398 | **434** (+11 algorun-lang D1 / A3 tests, +24 `l3_test.dart`, +1 `run_graph`) |
| `packages/algorun_content` `dart analyze` | no issues | no issues |
| `packages/algorun_content` `dart test` | 86 | **91** (+5 `l3_replay_test.dart`) |
| Content validator | 149 of 149, `OK 154`, 5 warnings | **159 of 159**, `OK 164`, the same 5 warnings |
| `flutter analyze` | no issues | no issues |
| `flutter test` | 540 | **577** (+17 `l3_editor_test.dart`, +20: the ten new puzzles in the campaign loop, built by taps and run at 360 × 800) |
| algorun-lang conformance | — | 1628 agree, 24 known differences, 0 problems |
| `tool/web_parity.sh` | — | identical on VM, dart2js, dart2wasm |

Changed tests: `functions_test.dart` (the parameter limit is six; a missing
RETURN is a lowering error — both marked `algorun-lang D10 / D11`); the
campaign counts 149 → 159 and 154 → 164 in `campaign_test.dart`,
`campaign_regression_test.dart`, `localization_ui_test.dart`,
`responsive_test.dart`, `content_validator_test.dart`, `pipeline_test.dart`;
two pipeline tests that used `sorting_builtin` as their blocked family use
`bit_manipulation`.

One content run made while the web build was compiling ended with a failure
whose name was not captured; the two full runs after it passed (91). Treat it
as a timeout under load, not as proven.

## Shared files touched (for the merge)

| File | What | Likely to meet |
|---|---|---|
| `packages/algorun_engine/lib/src/execution/interpreter.dart` | new `case` arms at the top of the built-in `switch` in `_call`, helpers before "coercions", a `PairValue` arm in `_copy`. Nothing near `TraceSink` / `_emit` | T1 |
| `…/ast/lower.dart` | D11 check where a FUNCTION is lowered, `_copy`, D12 in `_callStmt`, three statement ids, `new.deque`, `alwaysReturns` at the end | — |
| `…/blocks/catalog.dart`, `chrome.dart`, `functions.dart` | new ids, definitions, labels, captions, `maxParams` | E1 (chrome) |
| `…/puzzles/parse.dart`, `puzzle.dart` | `blocks.texts` inside `_blocks`, `BlockPolicy.texts` | M1 |
| `…/runtime/runtime_value.dart`, `value_json.dart`, `runner/validators.dart`, `runner/benchmark.dart`, `types/parse_type.dart` | `PairValue` and its arms, pair fixtures, D1 | T1 if it prints values |
| `lib/editor/editor_controller.dart` | `textChoices`, a default for TEXT in `_withDefaults`, TEXT in `_labelOf` | E1 |
| `lib/editor/hole_picker.dart`, `reporter_tile.dart` | TEXT opens its chips; TEXT draws its value | E1 |
| `lib/editor/literal_sheet.dart` | `showText`, `quotedText`, a `text` flag on the name chips | E1 |
| `lib/editor/statement_tile.dart` | COPY's two chips in `_hatBody` | E1 |
| `lib/l10n/app_en.arb`, `app_tr.arb`, `gen/*`, `engine_text.dart`, `terms.dart` | new keys next to their relatives, not at the end of the files; regenerate with `flutter gen-l10n` after merging | everyone |
| `lib/guide/guide_data.dart` | entries appended to `blockGuide`, three concepts | — |
| `assets/worlds.json`, `pubspec.yaml`, `assets/l10n/content_tr.json`, `content/coverage.json`, `oracles/registry.dart` | world 15 and its ten puzzles | MS16 |
| count assertions in the tests listed above | 149 → 159 | MS16 (the merged number is 149 + MS16's + 10) |

`content/coverage.json` is generated: after the merge run the validator with
`--coverage` instead of resolving it by hand. Not touched:
`docs/PROJECT_STATE.md`, `README.md`.

## Differences that remain between the game and algorun-lang

1. **The limit of numbers**: ±(2^53 − 1) in the game, ±(2^63 − 1) in
   algorun-lang. A program that runs without "This number is too big." in
   the game gives the same answer in algorun-lang; a number between the two
   limits is an error in the game and fine there. This covers NUMBER AS TEXT
   and TEXT AS NUMBER too. (All 18 conformance differences.)
2. Fixture JSON: the game refuses a fraction or an out-of-range number when
   the fixture is read; algorun-lang reads it and the interpreter refuses it.
3. Pairs can be puzzle input in the game only; `blocks.texts` exists in the
   game only (algorun-lang has no editor or puzzle schema).
4. No text form (A5) and no C core in the game.

Gone since the decision: fractions, `7 DIVIDE 2` = 3.5, silent wrap on the
phone, rounding in a browser.

## Known limits

- FOR EACH takes a list only; a deque is emptied with POP FRONT (the same in
  algorun-lang's block typing).
- SORT and COMPARE TEXT order by code point: capital letters before small
  ones, `ç` after `z`. Fixtures that depend on order use a–z only.
- There is no way to type a text: every constant comes from `blocks.texts`
  or an input. A pair has two sides, no triples.
- SWAP (`var.swap`) still has no editor support (as before L3).
- The results screen shows a pair or a deque as fixture JSON, like every
  other structured value.
- World 15 is a staging place for the samples, not a designed world.

## NOT TESTED

- The Wasm web build in a browser (`flutter build web --wasm` was built and
  measured; the engine was run as Wasm under Node, not the app in a
  browser). Chrome and Safari: only headless Firefox was driven.
- CALL with four to six values in the editor UI (engine and lowering only).
- Loading a pre-L3 save with solved puzzles on a device with the new build
  (the emulator's save came from the M1 branch and showed 0 of 159 solved).
- Only Seat Label was played by hand on the web and on the emulator; the
  other nine world 15 puzzles are built from the picker and run in widget
  tests, and the engine is compared on the three targets by
  `tool/web_parity.sh`.
- Turkish on a device with the new blocks (covered by widget tests only).
- A physical phone; TalkBack with the new sheets.
- Number model: the emulator (see "Phone and web"); the app compiled to Wasm
  in a browser (the engine was run as Wasm under Node); Chrome and Safari; a
  save from before the decision that holds a completed run whose answer was a
  fraction (no shipped puzzle can produce one, so none should exist).
- The web version was not published (`tool/publish_web.sh` not run), no APK
  was released, nothing was pushed.

## For the coordinator — what to move into PROJECT_STATE.md

- Current-state line: L3 in; 159 campaign puzzles in 15 worlds (plus MS16's).
- "Important APIs": the new blocks table; `RuntimeValue` gains `PairValue`
  (the sealed list and "adding one means updating…" note); fixture format
  gains `{"type": "pair", …}`; schema rules gain `blocks.texts` and "`pair`
  has a fixture form" (remove it from the "not `void`, `heap`, `pair`" list
  and from "Other" under Known limitations); COPY is a deep copy; a missing
  RETURN is a lowering error; `maxParams` 6.
- "Editor": TEXT chips and COPY chips; the guide now covers COPY and TEXT
  (SWAP is still left out).
- "Still blocked, and not faked": remove strings, built-in sorting and
  pairs / tuples; keep building list or tree nodes, bit manipulation, edge
  weights.
- Roadmap row "later — pairs, text": done by L3; add the open number-model
  decision.
- "Exact commands": the conformance command above and `tool/web_parity.sh`.
- Test table: the counts above.

### After the number-model decision

`docs/PROJECT_STATE.md` and `README.md` were not touched. To move there:

- Current-state line / "Locked decisions": numbers are whole and stay inside
  ±(2^53 − 1); the phone, JavaScript and Wasm agree by construction; the
  owner decided it on 2026-11-18 (option C of `MILESTONE_L3_PLAN.md`).
- "Interpreter (MS5)": replace "DIVIDE keeps whole results whole (`8 / 2` →
  `2`, `7 / 2` → `3.5`)" with "DIVIDE truncates toward zero (`7 / 2` → `3`,
  `-7 / 2` → `-3`)"; replace "List positions must be whole numbers inside
  the list" with "inside the list"; add the "too big" rule and
  `runtime/whole_number.dart` (`maxSafeNumber`, `numberProblem`,
  `wholeNumber`).
- "Integer division (MS7)": "DIVIDE is unchanged" is no longer true; FLOOR
  DIVIDE and DIVIDE differ only below zero.
- "Content contract (MS7)", fixture format: numbers are whole and inside the
  range; `2.0` reads as 2.
- "The five puzzles (MS8)", The Smallest Cart: "a DIVIDE midpoint" is no
  longer turned away. Open content follow-up, not done here because the
  puzzle passes as it is: the reference file's `notes` and `spec.traps`
  ("midpoints must be whole numbers") and the puzzle's `edgeCases`
  ("midpoints that are not whole numbers") describe a trap that no longer
  exists; `arith.div` could leave its palette or stay as a harmless second
  way. Editing the puzzle JSON would need a `version` decision.
- "Languages (U1)": two engine sentences were removed ("A position has to be
  a whole number.", "NUMBER AS TEXT needs a whole number.") and two added
  ("Only whole numbers can be used.", "This program only works with whole
  numbers."), with their ARB keys; `lib/l10n/gen` was regenerated.
- "Known limitations": the game's numbers stop at 2^53 − 1, algorun-lang's
  at 2^63 − 1 (18 known conformance differences, all this one).
- Test table: engine 506, content 114, Flutter 824, validator 204 / 204.
- The web version and the APK are not rebuilt or published by this branch;
  the published web build still has the old numbers until
  `tool/publish_web.sh` is run after the merge.
