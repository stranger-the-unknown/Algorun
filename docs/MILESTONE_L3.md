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
puzzles in a new world 15. **The number model (D2–D4) is not taken: it is an
owner decision that is still open** — see "Number model".

## Taken and not taken

| Id | algorun-lang change | In the game |
|---|---|---|
| D1 | a single capital letter parses as a generic type, so IR JSON round-trips | taken |
| D2 | a result outside signed 64 bits is "This number is too big." | **not taken — owner decision** |
| D3 | DIVIDE truncates toward zero | **not taken — owner decision** |
| D4 | no fractions | **not taken — owner decision** |
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
| NUMBER AS TEXT | `str.from_num` | `num → str` | whole numbers within ±(2^53 − 1) |
| TEXT AS NUMBER | `str.to_num` | `str → num?` | `-?[0-9]+` within ±(2^53 − 1), else NOTHING |
| NEW DEQUE | `new.deque` | → `deque<T>` | |
| PUSH FRONT / PUSH BACK | `deque.push_front` / `push_back` | statement | +1 memory cell |
| POP FRONT / POP BACK | `deque.pop_front` / `pop_back` | `deque<T> → T` | empty is an error |
| FRONT / BACK / SIZE / IS EMPTY | `deque.front` / `back` / `size` / `empty` | | |
| SORT | `arr.sort` | statement on `array<num>` or `array<str>` | in place, stable, 1 operation per comparison |
| COPY | `var.copy` | statement, two names | existed as an alias; now a deep copy |
| MAKE PAIR / FIRST / SECOND | `pair.make` / `first` / `second` | `T, U → pair<T,U>` | immutable, +1 memory cell |
| CALL with 4–6 values | `fn.call4` … `fn.call6` | | `FunctionSignature.maxParams` = 6 |

## Number model — waiting for the owner

algorun-lang's numbers are signed 64-bit integers and its spec says Flutter
web is not supported. The game's web version must keep working and agree
with the phone, so D2–D4 were measured, not ported. The four options, the
measurements and the recommendation ("safe whole numbers": D3 and D4 as
written, D2 with the limit at ±(2^53 − 1), identical on the phone,
JavaScript and Wasm) are in the plan, §5.

On this branch **arithmetic is exactly what it was on `main`**: Dart `num`,
fractions, `7 DIVIDE 2` = 3.5, no overflow error. Nothing here makes the
phone and the web differ, and nothing breaks the web build.

Two new blocks cannot avoid the question and take the one rule that is the
same on every platform under every option:

- NUMBER AS TEXT writes whole numbers within ±9 007 199 254 740 991. A
  fraction is the error "NUMBER AS TEXT needs a whole number."; a larger
  number is "This number is too big.". A whole fraction (`7.0`, which the
  phone and a browser print differently) and negative zero print as digits.
- TEXT AS NUMBER reads digit by digit (not `int.parse`, which rounds in a
  browser) and gives NOTHING past the same limit.

algorun-lang allows both up to 64 bits. If the owner picks option C these
two are already right; under option B or D their limit moves to 2^63.

## The 149 puzzles did not change

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

Result at `299315c`:

```
edge   agree 134, differ 23
lower  agree 22, differ 0
refs   agree 1455, differ 0
text   agree 17, differ 1
conformance: 281 files, 1628 cases agree, 24 differ (24 known), 4 text-form files not run, 0 problem(s)
```

Every case compares the whole expectation (status, output, ops, peakAlloc,
peakDepth, message, blockId; lowering cases compare the errors) and every
stored program must survive `Program.fromJson` → `toJson`. The 24
differences are listed one by one, with the deviation that causes each, in
`tool/conformance_known.txt`: 11 × D2, 7 × D3, 4 × D4 and the two text ↔
number cases past 2^53. The tool fails when a listed case starts to agree or
an unlisted one differs. The four files not run are parse-error cases of the
text form.

## Phone and web

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

1. Numbers: the game still has Dart `num` — fractions, `7 DIVIDE 2` = 3.5,
   silent wrap on the phone and rounding in a browser past 2^53 (D2–D4).
2. NUMBER AS TEXT / TEXT AS NUMBER stop at 2^53 − 1 in the game, 2^63 − 1 in
   algorun-lang; NUMBER AS TEXT of a fraction is an error in the game (there
   are no fractions in algorun-lang).
3. A position that is a fraction (LETTER AT, PART OF TEXT) is "A position has
   to be a whole number." in the game; it cannot occur in algorun-lang.
4. Pairs can be puzzle input in the game only; `blocks.texts` exists in the
   game only (algorun-lang has no editor or puzzle schema).
5. No text form (A5) and no C core in the game.

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
