# Milestone 9

The hint system. Every real puzzle already carried three progressive hints as
data (MS8); now players can reveal them, one at a time, and the number they
revealed reaches the results screen as `hintsUsed`. The puzzle-solving engine
is unchanged.

Previous milestone commits: MS6 `39956f9`, MS7 `7d689dc`, MS8 `9b005b8`.

## Behaviour

- Hints are the puzzle's own `hints` list — ordinary declarative data, shown
  exactly as written, in the author's order: the idea, then the approach, then
  stronger guidance. No hint is generated, computed, or taken from the
  reference solution.
- Nothing is shown up front. **SHOW HINT 1** reveals the first hint; the same
  button then reads **SHOW HINT 2**, then **SHOW HINT 3**. After the last one it
  reads **NO MORE HINTS** and is disabled.
- Hints are never revealed automatically, not even after a failed RUN.
- The **HINTS n/total** row opens and closes the list of hints already
  revealed. Opening or closing never reveals and never counts.
- A puzzle with no hints shows no hint row at all, and still runs.

### Where

Puzzle screen, directly under the BRIEF, in the same small-caps style:

```
BRIEF                                       ▴
  <story>
HINTS  1/3                 ▾   💡 SHOW HINT 2
  1. <first hint>
GIVENS …
```

## `hintsUsed`

- `hintsUsed` = the number of hints revealed during the current visit to the
  puzzle (`HintSession.used`, `lib/state/hint_session.dart`). Revealing hint 2
  makes it 2. Re-opening the list, running again, or tapping the disabled
  button does not change it.
- The session belongs to the puzzle screen. Leaving the puzzle ends it;
  nothing is saved, synced, or sent anywhere.
- RUN passes the count to `runPuzzle(..., hintsUsed:)`, which stamps it into
  `SuiteResult.metrics.hintsUsed` with `SuiteResult.withHintsUsed`, on both the
  graded path and the "cannot run yet" path.
- The engine never sets it: the `TestRunner` reports 0, because hints are
  session state, and grading never looks at them. A solved puzzle grades
  identically with or without hints.
- The results screen shows it in **WHAT IT COST**:
  `… steps · … cells · depth … · … blocks · 2 hints`. It is a metric only: no
  score, stars, penalty or leaderboard reads it yet (`scoring.hintPenalty`
  stays unread data).

Note: before MS9 the results screen did not show hints at all; the count is
new on that line.

## What hints never show

The hint UI renders `Puzzle.hints` strings and nothing else. It has no path to
the reference `BlockGraph` (never bundled), the IR, hidden cases or their
payloads, or validator internals.

The content validator now warns when a hint quotes an internal block id
(`arr.len` — use the label, LENGTH) or names a hidden case. The five shipped
puzzles trigger neither, and an app test checks their hints for block ids,
hidden case ids and the word "reference".

## Files

Created:

- `lib/state/hint_session.dart` — `HintSession`: pure Dart, the only place that counts
- `test/hint_session_test.dart` — 11 tests: the session, the five puzzles' hints, `hintsUsed` through `runPuzzle`
- `test/hint_ui_test.dart` — 6 widget tests of the real puzzle screen

Modified:

- `lib/screens/puzzle/puzzle_screen.dart` — `_HintBar`; the editor is now the public `PuzzleEditor` so tests can open a puzzle without asset I/O
- `lib/state/run_puzzle.dart` — `hintsUsed:` parameter
- `lib/screens/results/results_screen.dart` — hints on the cost line
- `packages/algorun_engine/lib/src/runtime/limits.dart` — `RunMetrics.copyWith`
- `packages/algorun_engine/lib/src/execution/suite_result.dart` — `SuiteResult.withHintsUsed`
- `packages/algorun_engine/test/test_runner_test.dart` — stamping keeps every other field
- `packages/algorun_content/lib/src/content_validator.dart` + test — hint leak warnings

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **272 passed** (271 + 1) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **32 passed** (31 + 1) |
| Content validator (assets + worlds + references) | `OK 7 puzzle(s), 4 warning(s)` (unchanged) |
| Flutter `analyze` | no issues |
| Flutter `test` | **35 passed** (20 + 15) |

Covered: zero hints; three hints; revealing the first, second and third;
asking past the last; repeated opening and closing; `hintsUsed` equal to the
revealed count; the count on the results screen after RUN; a puzzle without
hints shows no action and still runs; the five real puzzles expose their three
hints in order and leak nothing; grading is identical with and without hints.

## Known limitations

- **Nullable values cannot be narrowed** — unchanged, and out of scope here.
  It is now recorded as the planned language milestone L1 in
  [`PROJECT_STATE.md`](PROJECT_STATE.md).
- `hintsUsed` is not persisted and not scored, by design.
- The probe puzzles' hints are stale MS1/MS3 text; the probes are not listed
  for players.

## Confirmation

Milestone 9 is complete. Do not start the next milestone from this document.
