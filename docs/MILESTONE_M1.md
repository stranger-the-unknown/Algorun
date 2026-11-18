# Milestone M1 — puzzles that open with a program

Three puzzle modes that existed only as names in `PuzzleMode` now play:

- **complete** — the puzzle opens with half a program; the player fills in
  what is missing.
- **repair** — the puzzle opens with a program that has one mistake; the
  player finds and fixes it.
- **predict** — the player is shown a program and inputs, and says what it
  returns without running it; the answers are compared with what the
  interpreter really returns.

Branch `claude/m1-puzzle-modes-014876`, on top of `main` = `4fbbfed`.
Nothing here touches the block catalog, the lowerer or the interpreter.

## Schema

One new, optional puzzle field (`packages/algorun_engine/lib/src/puzzles/parse.dart`,
model in `puzzle.dart`):

```json
"starter": {
  "graph": { <BlockGraph JSON — the format of content/references and of saves> },
  "locked": ["b1", "b6"]
}
```

- `Puzzle.starter` → `StarterProgram(graph, locked)`; `Puzzle.isPredict`.
- Locked decision 9 holds: the graph is data. It reaches the interpreter
  only through `engine.lower`, like a program the player built.
- Required for `complete`, `repair` and `predict` (`starterModes`); allowed
  for every other mode (a `build` puzzle may open with a scaffold).
- Checked while the puzzle is read, so a puzzle that could not open never
  loads: the graph decodes; `GraphStructure.validate` passes (empty slots
  are fine); it has at least one block; every block is in `blocks.allow`
  (FUNCTION blocks come from `functions`); it fits `blocks.maxBlocks`; its
  `variables` are inputs, pool variables or parameters with the puzzle's
  types; every `locked` id names one of its blocks.
- `predict` only: `locked` must be empty (the program is read only anyway)
  and `io.output` must be `num` or `bool` — the answer is entered on the
  number pad or as TRUE / FALSE.
- Unknown fields under `starter` are errors, as everywhere.

## New engine API

| | |
|---|---|
| `StarterProgram`, `Puzzle.starter`, `Puzzle.isPredict` | `puzzles/puzzle.dart` |
| `starterModes` | the three modes that need a starter (`puzzles/parse.dart`) |
| `SuiteResult gradePredictions(Program, Puzzle, Map<String, RuntimeValue> answers)` | `puzzles/predict.dart`: runs the program on every **visible** case and compares the player's answer with the run's output through the puzzle's validator. `CaseResult.actual` is the player's answer; `expected` is set only when it was right, so a wrong answer never carries the real one out of the engine. A missing answer or one of the wrong kind is wrong. Hidden cases take no part. |

`gradePredictions` uses `runProgram` and `compareOutputs` as they are.

## Content validator

`packages/algorun_content/lib/src/starter_check.dart` (`StarterChecker`,
called from `ContentValidator.validateContent` for every puzzle with a
starter). `CheckedReference.graph` now carries the reference as written.

| Rule | Level |
|---|---|
| Every starter is rebuilt through the editor's commands (`replayInEditor`), so it is buildable and every connection in it is typed | L3 replay |
| Every locked block is in the reference, with the same contents, plugged into the same block and port | L3 replay |
| A `complete` / `repair` / `predict` puzzle must declare reference metadata | L1 schema |
| **complete**: the starter does not pass (it does not lower, or the suite fails) | L4 execution |
| **complete**: the reference only adds — every starter block is in it with the same id and contents, and what the starter plugged in keeps its order; it adds at least one block | L3 replay |
| **repair**: the starter is a whole program (validates and lowers) | L3 replay |
| **repair**: the starter does not pass; an INFO line says how it ends and how many cases (and visible cases) it fails | L4 execution |
| **repair**: the starter differs from the reference in 1 to 4 blocks (`repairMaxChangedBlocks`, `changedBlocks()`: a block only one side has, or whose kind, literals or plugged-in blocks differ; `@main` for the top-level order) | L3 replay |
| **predict**: the starter is a whole program and is the reference (identical lowered IR) | L3 replay |
| **predict**: the program returns every fixture's answer, visible and hidden | L4 execution |
| **predict**: at least 2 visible cases; every visible number answer is whole and within ±999999 | L4 execution |

Unchanged and still applied to all nine: the reference passes every case,
the oracle agrees with every fixture and with the reference on 40 sampled
inputs. For predict that is the chain the task asked for: expected answer =
reference output (the starter is the reference) = oracle.

`content/capabilities.json`: `complete`, `repair`, `predict` are now
`supported`; `structure` and `ops` stay `blocked` with updated notes.

## App

**Editor (`lib/editor`, the smallest change that works — E1 is reworking
this folder):**

- `EditorController`: `readOnly` (constructor flag: nothing selects, places
  or changes; folds still work), `isLocked(id)`, `holdsLocked(id)`,
  `canEdit(id)`, `resetToStarter()`; `SelectionInfo.locked`. A locked block
  has no moves; a block that is locked or holds a locked one cannot be
  deleted; `setLiteral` on a locked block is refused. Refusals show *This
  block is part of the puzzle: it stays as it is.*
- `statement_tile.dart`: a small lock icon before a locked instruction's
  label; name chips do nothing on a locked or read-only block; no "add
  step" / "add else" in a read-only program.
- `reporter_tile.dart`: a locked or read-only value opens no number pad or
  name sheet. `hole_picker.dart`: `HolePicker.open` returns at once when
  read only. `script_view.dart`: no trailing "add step" when read only.
  `editor_bars.dart`: REPLACE is disabled like DELETE; a lock icon in the
  selection bar.

**Puzzle screen (`lib/screens/puzzle`):**

- The editor opens with the saved draft, else the best solution, else the
  **starter program** (`PuzzleEditor`: `initialGraph ?? puzzle.starter?.graph`).
  Opening is not an edit: nothing is saved until the player changes
  something, and there is nothing to undo.
- Menu: a puzzle with a starter offers **Start over** instead of *Clear
  the program*. It asks first (*Start over?* / Cancel / Start over), then
  puts the starter back as one undo step.
- The brief says what the mode asks, in one line (`modeHelp` in
  `lib/l10n/terms.dart`).
- `predict_view.dart` (`PredictPuzzle`, a `part` of `puzzle_screen.dart`):
  brief, hints and the program — read only — in one scroll; a pinned
  question panel (QUESTION n OF m, numbered dots, the inputs as
  `name = value`, the answer: the game's number pad, or TRUE / FALSE
  buttons); the answered count and **CHECK**. Answering moves on to the next
  open question. CHECK is enabled once every question is answered.
- `lib/state/run_puzzle.dart`: `checkPredictions(engine, puzzle, answers,
  {hintsUsed})` — the CHECK path.

**Results (`lib/screens/results`):** for a predict puzzle the verdict says
how many answers were right, lists each question with the player's answer
and *right* / *not what the program returns*, never shows the real answer,
shows no cost table (the program is not the player's), and returns with
BACK TO THE QUESTIONS — to the first wrong question, answers kept.

**Lists:** `ModeBadge` (`lib/shared/mode_badge.dart`) — COMPLETE / REPAIR /
PREDICT with the help line as its tooltip — on puzzle rows and, per world,
for the modes that world has. A solved predict puzzle's row says *Solved*
(no "best steps").

**Strings:** 32 new keys in `app_en.arb` / `app_tr.arb` (modes, help,
start over, locks, predict, two engine sentences); generated code
committed.

## Save

**The save format did not change** (`saveVersion` is still 1; no
migration step).

- complete / repair: the draft is the player's edited program, exactly as
  for every puzzle. A draft the player emptied is restored empty; Start
  over brings the starter back.
- predict: `recordRun(…, null, suite)` (the graph parameter is now
  nullable) records completion, last result and best (meaningful for
  hints) and stores no program. Answers are not saved.
- A save written before M1 decodes without issues and re-encodes to the
  same text; puzzles it does not mention open with their starter
  (`test/puzzle_modes_test.dart`, group *saving*).

## The nine puzzles

| Puzzle | World | Tier | Mode | What the player meets |
|---|---|---|---|---|
| Flag Lines `flag_lines` | 01 | 1 | complete | a locked loop with an empty body: add the line to the total, grow the line by 2 |
| Fence Posts `fence_posts` | 01 | 1 | repair | WHILE compares with LESS THAN: one post short exactly when a post lands on the end |
| Halve or Step `halve_or_step` | 01 | 2 | predict | IF / ELSE inside WHILE: halve an even number, take 1 from an odd one, count the moves |
| High-Water Marks `high_water_marks` | 02 | 2 | complete | everything but the IF that raises the best level (nothing locked; the starter runs and returns zeros) |
| No Step Down `no_step_down` | 02 | 2 | repair | LESS OR EQUAL where LESS THAN belongs: equal neighbours are turned away |
| One Pass `one_pass` | 02 | 2 | predict | one bubble pass counting swaps: the list changes under the comparisons |
| Mirror Shelf `mirror_shelf` | 04 | 2 | complete | two markers, locked: fill the hole in the locked `SET hi` and add the comparison |
| Glove Pairs `glove_pairs` | 04 | 3 | repair | a missing `INCREMENT j` after a match: wrong only when a size repeats |
| Closing In `closing_in` | 04 | 3 | predict | the marker on the smaller card moves; the markers meet on the largest |

Each has an independent oracle (`oracles/modes.dart`: a square, a division,
binary digits, prefix maxima, a sorted copy, "smaller than the largest
before it", a reversed copy, counts per size, the maximum), three hints,
Turkish text, and 6–9 hidden cases. The three repair starters each pass
one visible case and fail another. Listed by tier in `assets/worlds.json`.
`packages/algorun_content/tool/m1_emit.dart` builds the references with
the editor's commands and derives the starters from them; it rewrites the
18 files and may be re-run (it does not touch the Turkish text or the
world lists).

## Tests

| Suite | Before | Now |
|---|---|---|
| Engine `dart test` | 398 | **421** (+23 `test/starter_program_test.dart`: schema 16, predict grading 7) |
| Content `dart test` | 86 | **109** (+23 `test/starter_check_test.dart`) |
| Flutter `flutter test` | 540 | **599** (+41 `test/puzzle_modes_test.dart`, +18 from nine more puzzles in the campaign regression loop) |
| Validator | 149 of 149 · 154 puzzles | `PIPELINE 158 of 158 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 163 puzzle(s), 5 warning(s)` (the five unlisted probes, as before) |

`dart analyze` (engine, content) and `flutter analyze`: no issues.

## Emulator pass (2026-11-18)

AVD `algorun_phone` (headless, 1080 × 2400 at density 420 — 411 × 914 dp),
debug APK of this branch installed over the app already there, driven with
`adb` taps found through the accessibility tree. One puzzle of each mode,
start to finish, in English:

- **predict — Halve or Step:** worlds list (COMPLETE / REPAIR / PREDICT
  badges on worlds 01, 02, 04), puzzle row badge, the read-only program,
  three answers on the number pad with one wrong on purpose → WRONG ANSWER,
  "2 of 3 answers…", question 2 marked, no right answer shown → BACK TO THE
  QUESTIONS lands on question 2 with the old answer → corrected → CORRECT,
  *Puzzle solved.*, the row then says *Solved*.
- **repair — Fence Posts:** RUN on the starter → WRONG ANSWER (v1 passed,
  v2 expected 4, gave 3; 3 of 8 hidden) → select LESS THAN → REPLACE →
  LESS OR EQUAL → `pos`, `length` → RUN → CORRECT, 8 of 8 hidden.
- **complete — Flag Lines:** locked blocks show their lock; a locked SET
  has no moves and stays; the two missing instructions added through the
  picker, the name sheet and the number pad (9 → 17 blocks) → RUN → CORRECT.
  Start over asks, restores 9 blocks, UNDO brings 17 back; after a force
  stop CONTINUE reopens Flag Lines with the 17-block program.

The emulator was free when this ran and was shut down afterwards; it now
holds this branch's debug build and a save with these three solved.

## NOT TESTED

- No physical phone; the emulator pass was English only, one screen size,
  light theme. Turkish strings and dark theme are covered by widget tests
  (ARB parity, one 360 × 640 predict screen at ×1.6 in dark) but were not
  looked at on a device.
- The other six new puzzles were not played by hand on the emulator
  (their references run in the regression loop; their starters and answers
  in `puzzle_modes_test.dart`).
- The web build (`tool/web.sh`) and a release APK were not built.
- A yes / no predict puzzle on a device (none ships).
- TalkBack was not run; the new controls carry semantics labels, and the
  emulator pass found them through the accessibility tree.
- Baseline note: the first `flutter test` on untouched `main` in this
  worktree reported 539 passed and 1 failed — the stress probe's timing
  check ("an edit on the 82-block program rebuilds quickly"), with five
  sessions compiling at once. The same test passed in both later full runs.

## For the coordinator

**Counts this branch added: +9 campaign puzzles (149 → 158; 154 → 163
with the probes).** Test lines that pin campaign size, all changed here:

| File | Change |
|---|---|
| `test/campaign_regression_test.dart` | `'149 campaign puzzles'` / `hasLength(149)` → 158 |
| `test/campaign_test.dart` | 149 → 158; Foundations `hasLength(12)` → 15; Arrays `hasLength(13)` → 16 (and the two comments) |
| `test/responsive_test.dart` | `'1 of 149 puzzles solved'` → 158 |
| `test/localization_ui_test.dart` | `'0 of 149 puzzles solved'`, `'149 bulmacadan 0 tanesi çözüldü'` → 158 |
| `packages/algorun_content/test/pipeline_test.dart` | `hasLength(149)` → 158; the "mode the product cannot play" example and the coverage-gap example changed from `repair` to `ops` (repair is playable now) |
| `packages/algorun_content/test/content_validator_test.dart` | `puzzleCount` 154 → 163; `hasLength(149)` → 158; `'OK 154 puzzle(s)'` → 163 |
| `test/real_puzzles_test.dart` | `'0 of 12 solved'` → 15 (the Foundations card) |
| `test/screens_polish_test.dart` | `'0 of 12 solved · teaches variables, control'` → 15 |
| `test/stress_probe_test.dart` | its `PuzzleSaveHooks` stub: `runFinished(BlockGraph? graph, …)` |

Files other sessions are likely to touch too: `assets/worlds.json` (nine
lines inserted by tier in worlds 01, 02, 04), `assets/l10n/content_tr.json`
(nine entries appended), `content/coverage.json` (regenerate after
merging: run the validator with `--coverage`), `oracles/registry.dart`
(one import, one spread), `packages/algorun_engine/lib/algorun_engine.dart`
(one export), `lib/l10n/app_*.arb` (keys appended at the end; run
`flutter gen-l10n` after merging), `lib/l10n/terms.dart`,
`lib/l10n/engine_text.dart` (two entries), `tool/prog.dart` (`swap`).

Outside the area the task named, with the smallest change that works:
`lib/state/run_puzzle.dart` (`checkPredictions`), `lib/state/progress_providers.dart`
(nullable graph in `recordRun`), `lib/l10n/*`, `lib/shared/mode_badge.dart`
(new), and the `lib/editor` hunks listed under *App*.

**To carry into `PROJECT_STATE.md`:**

- Current state line and roadmap: M1 complete; 158 campaign puzzles.
- "Modes without a UI" (Known limitations) → only `trace`, `structure`,
  `ops` (and `complexity`, by decision) remain; point to this file.
- Roadmap row "later — starter programs for complete / repair modes":
  done (pairs and text remain).
- Package structure: `puzzles/predict.dart`, `starter_check.dart`,
  `oracles/modes.dart`, `tool/m1_emit.dart`, `lib/screens/puzzle/predict_view.dart`,
  `lib/shared/mode_badge.dart`, `test/puzzle_modes_test.dart`.
- Content contract: the `starter` field; schema rules above.
- Progression and local save: `recordRun` takes a nullable graph; the
  editor's restore order is draft → solution → starter → empty.
- Editor: locks, read-only programs, Start over.
- Content backlog table: worlds 01 (15), 02 (16), 04 (11); by mode
  complete 3 · repair 3 · predict 3.
- Test counts above.

## Known limits

- **Locks are an editor rule, not a grading rule.** RUN grades the
  program by its tests only. A draft from another version of a puzzle (or
  a hand-edited save) is not checked against the locks. Locks are in force
  while the program holds every locked block as the starter gave it (same
  id, kind and contents); a program that never held the starter — the
  test harness building a reference from nothing, a draft from another
  version — has none.
- **Lock marks are small.** Instructions show a lock icon; a locked value
  (a number, a name) shows it only in the selection bar after a tap. Left
  for after E1's editor rework.
- **Predict answers are numbers and yes / no only.** No list or text
  answer, no multiple choice; the schema refuses other outputs. No shipped
  predict puzzle returns yes / no (the UI and a test puzzle cover it).
- **Predict answers are not saved** between visits, and the right answer
  is never shown — a stuck player has the hints. With T1's step view
  merged, "watch it run" after a wrong answer would be the natural next
  step; nothing here depends on it.
- **A yes / no predict puzzle can be guessed** in 2ⁿ tries. Not prevented.
- **Hidden cases of a predict puzzle are never asked** (they stay hidden,
  locked decision 6); they only strengthen the oracle ↔ program check.
- **The number pad is borrowed** through a scratch `EditorController`
  holding one NUMBER block (`_numberFromPad`), so `literal_sheet.dart` was
  not changed while E1 works there. Worth a direct `NumberPad(initial,
  onSubmit)` once E1 has landed.
- **"Small" for a repair is a block count** (≤ 4 changed blocks). It does
  not judge whether the bug is realistic; the authoring rules do.
- **Redundancy (level 7) does not look at the mode.** No Step Down is
  reported as *related* to First Descent (same shape, another output type,
  so not a near duplicate). A repair or predict version of an existing
  build puzzle with the same inputs and output would be refused as a near
  duplicate; whether a new mode alone makes a new puzzle is a decision
  for the next content batch.
- The campaign regression loop plays the nine through `PuzzleEditor` with
  the reference loaded, like every puzzle; the mode-specific flows are in
  `test/puzzle_modes_test.dart`.

## The remaining modes

- **trace** — follow a given program step by step and answer about its
  state on the way (not only what it returns). Needs: T1's step view /
  trace data as the source of truth; questions about intermediate state in
  the schema (for example `ask: {after: <block id>, visit: n, variable:
  "x"}` per case) graded against the trace like `gradePredictions` grades
  outputs; the predict view's question panel with those questions. The
  read-only program, the number pad answer and the results view exist.
- **ops** — say how many operations a given program takes for an input.
  Needs only a variant of `gradePredictions` that compares the answer with
  `run.metrics.ops` (the operation model is already pinned by content),
  a mode switch in the predict view, a validator rule that the expected
  count is the reference's measured count, and teaching content for the
  operation model (what costs 1), which the game does not explain yet.
  The smallest of the three.
- **structure** — choose the data structure (or skeleton) that fits, then
  finish it. Needs several starters per puzzle (`starters: [{label,
  graph, locked}]` or a starter per choice with different `variables.pool`
  types), a chooser on the puzzle screen, a save field for the choice (a
  real save-format change: `saveVersion` 2 with a migration), and
  validator rules: at least one choice leads to a reference inside the
  budget, the others are proven to fail (a reject per choice).
