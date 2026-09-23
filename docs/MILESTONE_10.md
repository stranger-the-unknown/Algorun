# Milestone 10

Deterministic performance metrics and optimization challenges. A solution can
now be *correct* and still fail because it uses too many operations — and the
player sees exactly how many it used against the budget, so improving a
correct algorithm shows as measurable progress. No Big-O analyzer.

Previous milestone commits: MS7 `7d689dc`, MS8 `9b005b8`, MS9 `2be68bd`.

## The operation model is unchanged

The MS5 interpreter was not touched. Its rules stand exactly:

- every executed block costs 1 operation;
- a loop header costs 1 per iteration;
- `seq` and the statement wrapper around a call are free;
- a short-circuited AND / OR side is neither run nor charged;
- a budget is checked *before* the step it would pay for, so a program that
  needs exactly `maxOps` operations passes and one that needs `maxOps + 1`
  fails.

Every MS1–MS9 test passes unmodified except one app test that asserted the
old results-screen sentence (see UI). All five recorded reference costs match
the numbers measured in MS8 (28,008 / 59,944 / 85,212 / 65,204 / 23,467), and
they are now pinned in the reference files, so any future change to the
operation model shows up as a content error.

## Budgets

| Budget | Where | Over it |
|---|---|---|
| operations | `limits.maxOps` — the one authoritative puzzle budget, per case | `operationLimit` |
| operations, one case | `fixtures.*[i].maxOps` — optional, **only tighter** than `limits.maxOps` | `operationLimit` |
| memory cells | `limits.maxAlloc` | `memoryLimit` |
| depth | `limits.maxDepth` | `depthLimit` |
| blocks | `blocks.maxBlocks` | the program is refused before it runs |

A case budget larger than `limits.maxOps` is a schema error ("conflicting
budgets"): there is exactly one place that sets how generous the puzzle is,
and a case can only ask for less. Per-case budgets are how a puzzle says
"the large input must stay under X operations" without loosening the small
ones.

Budgets are operation counts, not time. Wall-clock time is never part of a
verdict.

## Correct but too slow

The verdict is decided exactly as before: a case that runs out of its budget
is `operationLimit`, with the interpreter's own message and metrics.

What is new is a **measurement**. When a case runs out, the runner runs the
same program on the same input once more with room up to
`overrunCeiling(budget)` — five budgets, with at most one million extra
operations so a RUN stays short on a phone. That second run never changes the
verdict. It records a `BudgetOverrun` for the case:

- `measuredOps`: how many operations it really needed (or the ceiling, if it
  was still running);
- `finished`: whether it completed within the ceiling;
- `outputCorrect`: whether its answer matches under the puzzle's validator.

`SuiteResult.performance` (`SuitePerformance`) sums this over every case,
visible and hidden, as counts only:

| Field | Meaning |
|---|---|
| `opsBudget` | the puzzle's `limits.maxOps` |
| `worstOps` | the most operations any case needed (measured when over budget) |
| `overBudgetCases` | how many cases went over their budget |
| `overBudgetFinished` | every over-budget case finished within its ceiling |
| `correctWhereFinished` | every case that finished gave the right answer |
| `worstOverrun` | the numbers of the case furthest over its own budget — never its name |
| `correctButOverBudget` | all of the above: the result is correct, only too slow |

`SuiteResult.metrics` keeps its MS6 meaning (worst operations *under* the
budget, peak memory, peak depth, blocks, hints), so nothing that read it
changes.

## Performance declarations

```json
"limits": { "maxOps": 60000, "maxDepth": 32, "maxAlloc": 4000 },
"performance": { "required": true, "baselineFactor": 10 },
"fixtures": { "hidden": [ { "id": "large", "in": {…}, "out": …, "maxOps": 30000 } ] }
```

- `performance` is closed data: `required` (true/false) and `baselineFactor`
  (a whole number from 2 to 1000, only with `required`). No formulas: a field
  named like `formula` or `expression` is refused as "data only".
- `required: true` says meeting the budget is the point of the puzzle. The
  content validator then demands a proof in the reference file: at least one
  reject that passes every visible case and ends in `operationLimit` — a
  correct-but-slow baseline.
- `baselineFactor: k` demands that this baseline needs at least `k` times a
  case's budget on some case. Because every passing solution stays within the
  budget, any passing solution beats the baseline by at least `k` on that
  case. This is how a "minimum improvement over a baseline" is expressed
  without a second budget number.
- An optimization puzzle is simply: correct fixtures + a validator,
  `limits.maxOps` (+ optional case budgets), optional `blocks.maxBlocks`, and
  optionally `performance`. The modes `optimize` / `budget` stay labels.

Twin Beacons (`budget` mode) now declares
`"performance": {"required": true, "baselineFactor": 10}`; its "compare every
pair" reject proves it. No other puzzle content changed.

## Reference performance

The reference checker now:

- prints an INFO line per reference — operations, memory cells, depth and
  blocks against the puzzle's limits;
- checks the reference file's recorded `metrics`
  (`{"ops", "peakAlloc", "peakDepth", "blocks"}`) against a fresh
  measurement, and refuses any difference ("the reference or the operation
  model changed"); a missing record is a warning that prints the values to
  record;
- enforces `performance.required` and `baselineFactor` as above.

Reference metrics are content metadata for tooling. The app never loads them.

## Multi-size checks and the benchmark API

`benchmark(program, puzzle, {cases})` → `PerformanceReport` (pure Dart,
`runner/benchmark.dart`):

- `PerformanceSample` per case: `caseId`, `visible`, `inputSize`, `ops`,
  `peakAlloc`, `peakDepth`, `finished`;
- `BudgetCheck` per case: its budget, the operations used, pass / fail;
- `passed`.

`inputSize` is the total size of a case's collection inputs (list, set, map,
stack, queue, deque elements; linked-list, tree and graph nodes). It is a
size for plotting, not the `n` of a proof.

The report names hidden cases, so it is content tooling and analytics only;
it never reaches the player UI. It fits no curve and names no complexity
class. Explicit fixtures are the size profiles in MS10 — small, medium and
large cases, each with an optional tighter `maxOps`. There is still no
fixture generator.

## What the engine does **not** claim

- It does not prove, estimate or display a Big-O class.
- It does not infer complexity from measurements across sizes.
- Numbers are deterministic operation counts from one interpreter; the same
  program and input always give the same numbers, on any device.
- A complexity statement exists only if a content author writes it in a
  puzzle's story or hints.

## UI

Results screen, minimum changes, same style:

- **Operation limit** now explains itself instead of "This program took too
  many steps.":
  - *The result is correct, but this solution uses too many operations:
    58 against a budget of 30.* — every case finished and was right;
  - *Every case that finished came out right, but this solution uses too many
    operations: it was still running after 300,000, and the budget is
    60,000.* — some case was still running at its ceiling;
  - *This solution uses too many operations (…), and not every answer is
    right either.*
- **WHAT IT COST** shows the measured operations over budget (`300,000+`
  when still running), with thousands separators; the rest of the line is
  unchanged (`… · 2 hints`).
- A new line under it: **Budget: 60,000 steps · 4,000 cells · depth 32 ·
  30 blocks**.
- Every result kind still shows its own label: CORRECT, WRONG ANSWER,
  RUNTIME ERROR, OPERATION LIMIT, MEMORY LIMIT, DEPTH LIMIT, INVALID PROGRAM.

No stars, no XP, no scores.

## Files

Created:

- `packages/algorun_engine/lib/src/execution/performance.dart` — `BudgetOverrun`, `SuitePerformance`, `overrunCeiling`
- `packages/algorun_engine/lib/src/runner/benchmark.dart` — `measureCase`, `benchmark`, `PerformanceSample`, `BudgetCheck`, `PerformanceReport`, `inputSize`
- `packages/algorun_engine/test/performance_test.dart` — 17 tests
- `lib/state/performance_text.dart` — player wording, numbers only
- `test/performance_ui_test.dart` — 9 tests

Modified:

- engine: `suite_result.dart` (`CaseResult.overrun`, `SuiteResult.performance`), `test_runner.dart` (runs cases through `measureCase`), `puzzle.dart` (`PerformanceSpec`, `TestCase.maxOps`, `Puzzle.opsBudgetFor`), `parse.dart` (`performance`, case `maxOps`, `formula` is code-like), `algorun_engine.dart` (exports); tests: `shipped_puzzles_test.dart`, `puzzle_schema_test.dart`
- content: `content_issue.dart` (`Severity.info`), `reference_check.dart` (metrics, INFO, performance rules), tests
- app: `results_screen.dart`, `test/real_puzzles_test.dart` (new sentence)
- data: `assets/puzzles/world_03/twin_beacons.json` (`performance`), `content/references/*/*.json` (`metrics`)

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **297 passed** (272 + 25) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **37 passed** (32 + 5) |
| Content validator (assets + worlds + references) | `OK 7 puzzle(s), 4 warning(s)` + 5 INFO lines |
| Flutter `analyze` | no issues |
| Flutter `test` | **44 passed** (35 + 9) |

Engine: exact budget boundary (3 passes, 2 fails), MS6 metrics and message
unchanged over budget, repeated runs identical, JSON-round-tripped programs
cost the same, memory and depth budgets at their exact boundaries, correct
but slow measured (58 against 30), slow and wrong told apart, the ceiling,
per-case budgets turning away a quadratic solution on the large case only,
case isolation in any order, benchmark samples and checks, input sizes, the
five reference costs reproducible, Twin Beacons' declared performance.
Schema: `performance` closed, no formulas, `baselineFactor` rules, case
budgets. Content: INFO line, metrics recorded / drifted / unknown field,
`required` with and without a baseline, `baselineFactor` met and unmet, a
fast program cannot pose as the baseline. App: wording, the budget line, the
three operation-limit sentences, no complexity words, the results screen for
a correct-but-slow and an optimized run.

## Known limitations

- The measurement ceiling (five budgets, at most one million extra
  operations) means a hopeless solution is only known to be "still running";
  its correctness beyond the ceiling is not claimed.
- Measuring an over-budget case costs up to six budgets of work on RUN; the
  cap keeps it bounded, but a very slow solution still takes a moment.
- Memory and depth have no overrun measurement: they stop as before.
- `blocks` in metrics counts distinct blocks in the lowered program (an
  ELSE joins its IF), which can be one less than the editor's block count.
- There is no fixture generator; size profiles are explicit fixtures.
- Nullable narrowing (L1) is unchanged and still required before tree,
  linked-list, counting-map or advanced graph content.

## Confirmation

Milestone 10 is complete. Do not start L1 or Milestone 11 from this document.
