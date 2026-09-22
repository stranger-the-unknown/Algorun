# Milestone 6

Fixtures → interpreter → named validator → `SuiteResult`. RUN in the app now
grades a real program. No editor redesign, no scoring, no new content.

MS5 commit: `06e2037c5d4841a33d69763d2385e0a8f834dc9c`.

## Files

Created:

- `packages/algorun_engine/lib/src/runner/test_runner.dart` — `TestRunner`, `countBlocks`
- `packages/algorun_engine/test/test_runner_test.dart` — 25 tests
- `lib/state/run_puzzle.dart` — `runPuzzle(engine, graph, puzzle) → RunOutcome`, the whole RUN path in one testable place

Modified:

- `lib/src/execution/result_kind.dart` — adds `ResultKind.depthLimit`
- `lib/src/execution/interpreter.dart` — depth overflow reports `depthLimit` instead of folding into `runtimeError`
- `lib/src/execution/suite_result.dart` — `CaseResult.input/expected/actual` (visible only), `SuiteResult.firstFailureOpIndex/firstFailureCaseId`, `ok` / `allPassed` helpers
- `lib/src/execution/default_engine.dart` — `runTests` calls the runner
- `lib/src/runner/validators.dart` — closed comparator registry, cross-shape comparison
- `lib/algorun_engine.dart` — exports `test_runner.dart`
- `lib/screens/puzzle/puzzle_screen.dart` — RUN lowers the editor graph and grades it
- `lib/screens/results/results_screen.dart` — visible cases, hidden count, metrics
- `test/widget_test.dart` — 4 RUN / results tests
- `packages/algorun_engine/test/{engine_contract,interpreter}_test.dart` — MS6 behavior

## Architecture

```
Program (MS4 IR)
  → per case: fresh Interpreter (MS5)           isolation
    → input binding from TestCase.input          valueFromJson per case
      → RunResult + RunMetrics                   budgets from puzzle.limits
        → named validator                        closed registry
          → CaseResult
            → SuiteResult                        visible list + hidden counts
```

```dart
final class TestRunner {
  const TestRunner();
  SuiteResult run(Program program, Puzzle puzzle);
  SuiteResult runCases(Program program, Puzzle puzzle, List<TestCase> cases);
}
```

- **Isolation.** Every case gets its own `Interpreter` and its own decoded
  input, and the interpreter deep-copies what it is given. A case cannot see
  another case's state, and a run cannot mutate the puzzle's fixtures.
- **Order.** `run` grades `puzzle.allTests` — visible first, then hidden — so
  "first failure" is the one the player can see. Every case runs; the suite
  does not stop early, so the hidden summary is always complete.
- **Failures are the interpreter's.** The runner invents exactly one verdict,
  `wrongAnswer`. Limit and runtime failures are passed through with the
  message and `srcBlockId` MS5 produced.
- **Metrics.** `ops`, `peakAlloc` and `peakDepth` are the worst any single
  case needed, because budgets are per run. `blocks` counts distinct
  `srcBlockId`s in the IR. `hintsUsed` is session state the engine does not
  hold and stays 0 until MS9.
- **Generator seam.** `runCases` takes plain `TestCase` data, so a future
  generator can hand over cases without the runner ever executing content.

## Validator registry

`outputValidators` maps `ValidatorId` → `OutputComparator`. Puzzle JSON names
one; it can never carry a predicate. An unknown name is
`ResultKind.invalidProgram` ("This puzzle does not have a checker the game
knows."), never an exception and never a silent pass.

| Id | Compares |
|---|---|
| `equal` | strict, shape included — a linked list is not an array |
| `listEqualByValue` | ordered values across array / stack / queue / deque / set / linked list |
| `unorderedArray` | order-free, repeats count |
| `setEqual` | order-free, repeats ignored |
| `unorderedPairs` | pairs, order-free outside and inside each pair |
| `treeEqual` | structural; the expected side may be a `{value,left,right}` fixture |

`almostEqual` is deliberately absent: no puzzle needs float tolerance yet, and
a closed registry is the point. Adding one is a line here plus a line in the
enum.

Comparators are deterministic, side-effect free, and cycle-safe (a relinked
list ends the walk instead of hanging).

## Hidden tests

- Hidden cases never appear in `SuiteResult.visible`; only `HiddenSummary`
  (passed / total) leaves the engine.
- `firstFailureCaseId` is filled only when the failing case is visible. A
  hidden failure says "A hidden case did not come out the way the puzzle
  expects." and nothing more.
- `firstFailureBlockId` and `firstFailureOpIndex` are the player's own program,
  so they are reported for hidden failures too.
- The results screen renders `suite.visible` and a hidden count, and says
  hidden inputs and answers are not shown.

## Result states

`correct`, `wrongAnswer`, `runtimeError`, `operationLimit`, `memoryLimit`,
`depthLimit`, `invalidProgram`. `timeLimit` stays unused — wall clock is a UI
watchdog, not a grade.

## Application wiring

`runPuzzle` is the RUN path: `lower` → on failure the lowering's own message as
`invalidProgram`, otherwise `runTests`. `PuzzleScreen._run` calls it and pushes
the result; `ResultsScreen` shows the verdict, per-case rows (with given /
expected / you gave on a failure), the hidden count, and
`steps · cells · depth · blocks`.

RUN no longer shows a placeholder. The playable path is real:
block graph → validate → lower → test runner → result.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **154 passed** (129 + 25) |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues, **3 passed** |
| Content validator over `assets/` | OK 2 puzzles |
| Flutter `analyze` | no issues |
| Flutter `test` | **13 passed** (9 + 4) |

Engine additions: all visible pass, visible wrong answer with both sides,
hidden failure as a summary, no hidden payload, unknown checker, runtime
failure with block and op index, operation / memory / depth budgets, program
that cannot start, unordered permutation through the runner, strict `equal`,
list comparator (including a cycle), tree comparator, `setEqual`,
`unorderedPairs`, registry completeness, case isolation, fixture immutability,
repeated runs, JSON round-trip grading, `runCases`, and
graph → validate → lower → runTests.

App additions: RUN grades real fixtures, RUN on an empty canvas says what to
fix, results show visible cases with a hidden count only, and a wrong visible
case shows expected vs actual while the hidden case stays a number.

## Known limitations

- **Integer division** is still open. Checked as instructed: no current puzzle
  divides, and the catalog has no floor / integer-division block, so MS6 does
  not need it. Left as a follow-up rather than changing what DIVIDE means.
- **Node / graph fixtures** still have no tagged JSON form, so `listNode`,
  `treeNode`, `graph` and `set` cases are written from Dart. The runner needs
  no change when that lands: only `valueFromJson` does.
- **No random generation.** No puzzle declares a generator, so none was
  invented. `runCases` is the seam.
- `hintsUsed` is always 0 until hints exist (MS9).
- The whole suite runs even after a failure, which is deterministic but does
  more work than a judge that stops early.
- Allocation still has no collector (MS5 limitation).
- The RUN button's own widget path is covered through `runPuzzle`; the
  `PuzzleScreen` → `ResultsScreen` navigation itself is not pumped in a test,
  because the screen loads its puzzle through a `FutureBuilder` on a real
  asset. Making the repository injectable would fix that; it is app plumbing,
  not MS6.

## Confirmation

Milestone 6 is complete. Do not start Milestone 7 from this document.
