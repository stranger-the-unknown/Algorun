# Algorun project state

Handoff document for the next coding agent. Read this before changing
anything. It is written so you can continue without any previous conversation.

**Current milestone: 11 COMPLETE (progression, local persistence, save and resume — on the device only).**
**Next milestone: 12 — MS12 is next (large original content), see the roadmap.**

Do not implement the next milestone from this file unless the user explicitly asks.
Do not change the architecture.

Milestone commits: MS5 `06e2037c5d4841a33d69763d2385e0a8f834dc9c`,
MS6 `39956f967f8102f747be94bc3ad9de4c0703c674`,
MS7 `7d689dca871b33e58de23c2879d296aff6e74553`,
MS8 `9b005b88cc1953b9b629f890697746ffccca2939`,
MS9 `2be68bde64fc537c9a8e211c52d355a6d0c31d52`,
MS10 `c192118c079e73c8ff78b7fa71d00adf0285959a`,
L1 `d850525b2869271381356b27227e42648476192f`, MS11 — see `git log` (the commit
titled "Milestone 11: progression and local persistence").

---

## What this product is

Working title: **Algorun**. Android-first Flutter/Dart algorithm puzzle game.

The player constructs algorithms with Scratch-style typed visual blocks. No
syntax. No eval of generated Dart/JS/Kotlin. The game ships five real Medium-level
puzzles (MS8); campaign difficulty rises to Medium/Hard later.

There is **no TypeScript / React / web product codebase**. Flutter web exists
only as a host preview of the same Dart app.

## Locked decisions (do not reopen)

1. Flutter + Dart only. Android primary (`com.algorun`).
2. Engine is pure Dart: `packages/algorun_engine` must not import `package:flutter`.
3. First five puzzles are probes, not the difficulty ceiling. *(MS8 reading: the five real puzzles are the first real set, and still not the ceiling.)*
4. Per-puzzle `blocks.allow` is the editor palette. Full-catalog palette is a bug.
5. No Big-O analyzer in v1. Grade with `maxOps` / `maxAlloc` / `maxDepth`.
6. Local hidden tests are UI-hidden, not APK-secret. `VerdictSource.remote` is reserved.
7. `packages/algorun_content` is offline-only. The Flutter app must not import it.
8. Stay on Flutter/Dart.
9. *(MS7)* Puzzle JSON is data only. Validators are registry names; fixtures are canonical values; nothing in content is ever executed.
10. *(MS8)* Every puzzle a player can reach is proven solvable by a reference solution: a `BlockGraph` stored as data in `content/references/`, never bundled and never shown in the UI, which the content validator builds, lowers and runs through the real `TestRunner`.

Full lock text: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Pipeline

```
Puzzle JSON ──(MS7 closed schema + typed fixtures)──▶ Puzzle
  → BlockGraph            (MS2, built in the MS3 editor)
    → validate            (MS1/MS2)
      → AST / IR          (MS4)
        → Interpreter     (MS5)
          → TestRunner    (MS6)
            → SuiteResult → results screen
```

The whole path is live: RUN in the app goes block graph → validate → lower →
test runner → result.

## Package structure

```
algorun/                          Flutter app (repository root)
  lib/                            UI, editor, Riverpod
    editor/                       Scratch-style editor (MS3)
    screens/                      home, worlds, puzzle, results, settings
    puzzles/asset_repository.dart loads assets through the engine schema
    state/providers.dart          engineProvider → DefaultEngine
    state/run_puzzle.dart         the RUN path: graph → lower → runTests (+ hintsUsed)
    state/hint_session.dart       HintSession: hints revealed in this visit (MS9)
    progress/                     MS11, pure Dart except file_progress_store.dart:
      save_data.dart              PlayerSave, PuzzleProgress, RunNumbers, RunRecord, PlayerSettings, CurrentSession
      save_codec.dart             encodeSave / decodeSave: the versioned save format
      campaign.dart               Campaign, evaluateCampaign → CampaignProgress (unlock rules)
      progress_ledger.dart        completes(), openPuzzle, saveDraft, recordRun (pure updates)
      progress_store.dart         ProgressStore interface, MemoryProgressStore
      file_progress_store.dart    FileProgressStore: one JSON file in the app support directory
    state/progress_providers.dart progressStoreProvider, campaignProvider, progressProvider (autosave), campaignViewProvider
    state/progress_text.dart      player wording for locks and statuses
  assets/                         bundled with the app
    worlds.json                   14 worlds; 02, 03, 05, 06 and 10 have puzzles
    puzzles/world_01/             ms1_contract_probe, ms3_editor_probe, l1_list_probe, l1_tree_probe (unlisted dev probes)
    puzzles/world_02/             smallest_cart
    puzzles/world_03/             twin_beacons
    puzzles/world_05/             quota_hours
    puzzles/world_06/             relay_towers
    puzzles/world_10/             fewest_rides
  content/references/<world>/<id>.json   reference solutions: offline only, NOT bundled
  packages/
    algorun_engine/               pure Dart, no Flutter
      lib/src/ast/                ir.dart (typed IR), lower.dart
      lib/src/blocks/             catalog, graph, typing, commands, chrome
      lib/src/blocks/narrowing.dart       Narrowing: where a value that may be empty is known to hold something (L1)
      lib/src/execution/          AlgorunEngine, DefaultEngine, Interpreter, results
      lib/src/puzzles/            parse.dart (THE schema), puzzle.dart, world.dart
      lib/src/runner/             TestRunner, validator registry
      lib/src/runtime/            RuntimeValue, value_json.dart (fixture format), limits
      lib/src/types/              ValueType + parser
      lib/src/execution/performance.dart  BudgetOverrun, SuitePerformance (MS10)
      lib/src/runner/benchmark.dart       measureCase, benchmark, PerformanceReport (MS10)
      test/                       341 tests
    algorun_content/              offline validator, reference checker, editor replay, CLI
  docs/                           architecture + per-milestone notes
  test/widget_test.dart           Flutter editor / picker / RUN tests
  test/real_puzzles_test.dart     the five real puzzles through the bundle and RUN
  test/hint_session_test.dart     hint session, the five puzzles' hints, hintsUsed through RUN
  test/hint_ui_test.dart          the hint interaction on the real puzzle screen
  test/performance_ui_test.dart   budget wording and the results screen (MS10)
  test/nullable_editor_test.dart  IS NOT NOTHING in the editor, the picker and RUN (L1)
  test/progress/                  save format, progression, best results, sessions (MS11, no widgets)
  test/progression_ui_test.dart   fresh install, locks, CONTINUE, restore, RUN completing a puzzle, settings (MS11)
  test/support/                   shared test helpers (campaign from files, progress fixtures)
  lib/state/performance_text.dart player wording for budgets (MS10)
```

App `pubspec.yaml` path-depends on `packages/algorun_engine` only; its one
package dependency beyond Flutter and Riverpod is `path_provider` (MS11, to
find the save directory).

## Important APIs

### Engine

```dart
abstract interface class AlgorunEngine {
  ValidationReport validate(BlockGraph graph, Puzzle puzzle);
  LowerResult lower(BlockGraph graph, Puzzle puzzle);          // never throws
  RunResult run(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
  SuiteResult runTests(Program program, Puzzle puzzle);
}
```

`DefaultEngine` is the shipping implementation: `lower` runs full `validate`
first, `run` is the MS5 interpreter, `runTests` is the MS6 runner.

### Typed ports (MS2) — do not change

- `PortKind` = `{statement, expression, elseClause}`.
- `GraphTyping.canConnect` is the snap/picker source of truth.
- `GraphTyping.compatiblePlacements` filters the hole picker.
- *(L1)* `GraphTyping` types a GET where it is (or is being dropped) through `Narrowing` — see "Values that may be empty".
- `GraphHistory` + reversible commands. Failed connects do not push undo.
- Top-level stack is `@main.body`.
- Variables live on `BlockGraph.variables`. GIVENS = `puzzle.io.inputs`. CREATE names come from `puzzle.variablePool` (chips only).
- Canvas `x` / `y` / `collapsed` are UI-only. Lowering ignores them.

### IR (MS4)

Closed, typed, JSON-serializable (`Program.toJson` / `fromJson`). No callbacks, no UI metadata.

| Node | Shape |
|---|---|
| `Program` | `entry` (`main`) + `functions` |
| `FnDecl` | name, params, optional return type, body, `srcBlockId` |
| `Stmt` | seq, if (optional else), while, forRange, forEach, break, continue, return, assign, inc, dec, expr |
| `Expr` | lit, var, binary, unary, call, index, field, null, new — each has `ValueType` + `srcBlockId` |
| `LValue` | var, index, field |

| Blocks | IR |
|---|---|
| `var.set` | `AssignStmt` + `VarLValue` |
| `var.inc` / `var.dec` | `IncStmt` / `DecStmt` |
| `ctrl.if` + optional `ctrl.else` | **one** `IfStmt` |
| `ctrl.while` / `ctrl.for_range` / `ctrl.foreach` | `WhileStmt` / `ForRangeStmt` / `ForEachStmt` |
| `ctrl.break` / `continue` / `return` | matching stmts |
| `arith.*` / `cmp.*` / `logic.*` | `BinaryExpr` / `UnaryExpr` (`arith.floor_div` → `BinaryOp.floorDiv`, MS7; `logic.is_nothing` / `logic.is_not_nothing` → `UnaryOp.isNothing` / `isNotNothing`, L1) |
| `arr.get` / `arr.set` | `IndexExpr` / `AssignStmt` + `IndexLValue` |
| `ll.*` / `tree.*` | `FieldExpr` / `FieldLValue` |
| other catalog ops (`arr.len`, `map.get`, mutators, …) | `CallExpr` / `ExprStmt` with the catalog id as callee |
| `fn.def` / `fn.call` | unsupported |

### Interpreter (MS5)

```dart
RunResult runProgram(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
```

Tree-walks the IR. Never sees a `BlockGraph`, never evals, no clock / random / I/O. Never throws.

- `ResultKind.correct` = ran to completion; verdicts are the runner's.
- Budgets are checked *before* a step: `maxOps` = one op per executed block (loop header once per iteration; `seq`, call wrappers and short-circuited operands free), `maxAlloc` = live collection cells, `maxDepth` = function frames (`ResultKind.depthLimit`).
- Deterministic: insertion-ordered maps and sets, `for each` iterates a snapshot, the `for range` counter is loop-owned, given values are deep-copied on entry.
- DIVIDE keeps whole results whole (`8 / 2` → `2`, `7 / 2` → `3.5`). FLOOR DIVIDE is below. Dividing by zero is a runtime error. List positions must be whole numbers inside the list.
- Equality is by value for number / text / yes-no / empty; containers, nodes and graphs are only equal to themselves.
- `RuntimeValue` is sealed: `Nil Num Bool Str Array Map Set Stack Queue Deque ListNode TreeNode Graph`. Adding one means updating `valuesEqual`, `value_json.dart` and the interpreter's copy.

Details: [`MILESTONE_5.md`](MILESTONE_5.md).

### Test runner (MS6)

```dart
final class TestRunner {
  SuiteResult run(Program program, Puzzle puzzle);                              // puzzle.allTests, visible first
  SuiteResult runCases(Program program, Puzzle puzzle, List<TestCase> cases);   // generator seam
}
```

- Cases arrive decoded and type-checked by the schema (`TestCase.input` / `output` are `RuntimeValue`s). The runner does no conversion of its own.
- Each case gets a fresh interpreter, which copies its input, so cases cannot see each other and fixtures never change.
- The runner invents one verdict, `wrongAnswer`; every other failure is the interpreter's own, with its message and `srcBlockId`.
- Metrics: worst `ops` / `peakAlloc` / `peakDepth` across cases, `blocks` = distinct `srcBlockId`s, `hintsUsed` = 0 until MS9.
- Hidden cases never enter `SuiteResult.visible`; only `HiddenSummary(passed, total)` leaves. `firstFailureCaseId` is set only for a visible failure.
- Visible `CaseResult.input` / `expected` / `actual` are canonical fixture JSON, so the results screen shows both sides in the author's format.

App side: `lib/state/run_puzzle.dart` holds the RUN path. Details: [`MILESTONE_6.md`](MILESTONE_6.md).

### Content contract (MS7)

**One schema.** `packages/algorun_engine/lib/src/puzzles/parse.dart` is the only definition of a puzzle. The game loads through it and the content validator calls it.

```dart
PuzzleRead readPuzzleJson(String source);   // never throws: puzzle or every issue with a JSON path
Puzzle parsePuzzleJson(String source);      // throws SchemaException(issues)
WorldsRead readWorldsJson(String source);
WorldsManifest parseWorldsJson(String source);
```

**One conversion path** for values (`lib/src/runtime/value_json.dart`):

```dart
RuntimeValue valueFromJson(Object? json, {ValueType? type, FixtureLimits limits});  // throws FixtureFormatException only
Object? valueToJson(RuntimeValue value, {FixtureLimits limits});                    // canonical JSON
String? fixtureTypeProblem(ValueType type);                                         // can this type be a fixture?
```

Schema rules, in short (full table in [`MILESTONE_7.md`](MILESTONE_7.md)):

- Closed at every level: unknown fields are errors. Behavior-shaped names (`generator`, `script`, `eval`, `predicate`, …) get a "data only" error. `meta` is the one open door: flat text / number / boolean, never read.
- Required: `id title world tier mode story io blocks limits fixtures`. Ids and world / chapter / concept names are `lower_snake_case`.
- `tier` 1–5; `mode` from the `PuzzleMode` enum; `limits.maxOps` 1–10,000,000, `maxDepth` 1–10,000, `maxAlloc` 1–1,000,000; `blocks.maxBlocks` 1–500.
- `blocks.allow` non-empty, known catalog ids, no repeats; `forbid` known and disjoint from `allow`.
- `io` types must parse and have a fixture form (not `void`, `heap`, `pair`; set items and map keys are num / str / bool).
- Fixtures: `visible` and `hidden` non-empty; case ids unique across both; `in` has exactly the declared inputs; `out` required. Every value is decoded against its declared type — nullability and element types included.
- `validators.output` is a registry name (default `equal`) and must fit `io.output`; `io.output.order: "any"` needs an order-free validator.

**Fixture format** — plain JSON for `null`, numbers, booleans, text and arrays; every object is tagged:

```json
{"type": "map", "entries": [["a", 1], ["b", 2]]}
{"type": "set", "items": [1, 2, 3]}
{"type": "stack", "items": [1, 2, 3]}
{"type": "queue", "items": [1, 2, 3]}
{"type": "deque", "items": [1, 2, 3]}
{"type": "listNode", "values": [1, 2, 3]}
{"type": "listNode", "values": [3, 2, 0, -4], "cycleTo": 1}
{"type": "treeNode", "value": 2, "left": {"type": "treeNode", "value": 1}, "right": null}
{"type": "graph", "nodes": [{"id": 0, "neighbors": [1]}, {"id": 1, "neighbors": [0]}], "visited": [0]}
```

Stacks are bottom → top, queues and deques front → back. An empty linked list is `null`. Graph neighbors must name existing nodes, keep their order, and may form cycles and self-loops; edges are directed. Limits: 10,000 values and 1,000 nesting levels per value.

**Validator registry** (`lib/src/runner/validators.dart`), closed:

| Validator | Output must be |
|---|---|
| `equal` | anything (strict, shape included) |
| `listEqualByValue` | array, stack, queue, deque, listNode |
| `unorderedArray` | array, set, stack, queue, deque, listNode |
| `setEqual` | array, set |
| `unorderedPairs` | array of arrays |
| `treeEqual` | treeNode |

### Integer division (MS7)

DIVIDE is unchanged. **FLOOR DIVIDE** (`arith.floor_div`, `num × num → num`,
MATH category) returns the largest whole number not above `left / right`:
`7 → 3`, `8 → 4`, `-7 → -4` (all ÷ 2), `7 ÷ -2 → -4`. Always whole, so it is a
valid list position (`nums[(lo + hi) FLOOR DIVIDE 2]`). Zero denominator is a
runtime error. Lowers to `BinaryOp.floorDiv`; one op.

### Content validator (MS7, MS8)

`packages/algorun_content`: `ContentValidator.validateContent(puzzles:, worldsSource:, references:)` → `ContentReport` of errors and warnings, each with file and JSON path, in a stable order.

Errors: every schema rule; an expected answer that fails its own validator; duplicate puzzle ids; a file not at `<world>/<id>.json`; a world listing a missing or invalid puzzle; a puzzle whose world is unknown or listed by another world; a malformed manifest; every reference rule above. Warnings: no hints; `fn.*` allowed; whole-catalog allowlist; a puzzle no world lists; a prerequisite no world teaches; a reference above 80 % of a budget; references not given.

### The five puzzles (MS8)

| Title | Id / world | Pattern | Mode, tier | What it turns away |
|---|---|---|---|---|
| Twin Beacons | `twin_beacons` / 03 | complement lookup, hash set | budget, 2 | all pairs (op budget); add before asking (hidden trap) |
| Quota Hours | `quota_hours` / 05 | variable sliding window | build, 3 | all runs (op budget); unconverted placeholder (hidden trap) |
| Relay Towers | `relay_towers` / 06 | monotonic stack | build, 3 | looking east (op budget); popping on equal heights (hidden trap) |
| The Smallest Cart | `smallest_cart` / 02 | binary search on the answer, FLOOR DIVIDE | build, 3 | one-unit steps (op budget); a DIVIDE midpoint |
| Fewest Rides | `fewest_rides` / 10 | BFS shortest path on a `graph` fixture | build, 3 | depth-first with a stack (hidden trap) |

Tree BFS was not chosen because at MS8 the language could not traverse a tree;
L1 closed that gap (see "Values that may be empty"). Per-puzzle rationale,
budgets and cases are in [`MILESTONE_8.md`](MILESTONE_8.md).

### Reference solutions (MS8)

A puzzle declares `"reference": {"strategy": "<lower_snake_case>"}`. Its
solution lives at `content/references/<world>/<id>.json`:

```json
{ "puzzle": "<id>", "notes": "…", "solution": { <BlockGraph JSON> },
  "rejects": [ { "name": "…", "expect": "operationLimit", "graph": { <BlockGraph JSON> } } ] }
```

`ReferenceChecker` (`packages/algorun_content/lib/src/reference_check.dart`)
proves the following for the solution:

- It uses only allowed blocks, stays within `maxBlocks` and is structurally
  sound (`engine.validate`).
- It is **buildable in the editor**: `replayInEditor` rebuilds it top-down with
  `AddBlockCommand` / `AttachStatementCommand` / `ConnectCommand`, starting from
  the givens and the pool and using only editor-settable literals.
- It lowers.
- It passes every visible and hidden case through `engine.runTests` within the
  puzzle's limits. The checker warns above 80 % of any budget.

Each reject must be buildable, pass every visible case, and end the suite in
exactly its declared `ResultKind`. That is how "correct but too slow" and
hidden traps are proven, not just claimed.

Rules: every puzzle a world lists must declare reference metadata, every
puzzle that declares it must have a passing reference file, and a reference
file with no puzzle is an error. Nothing is keyed to puzzle ids.

### Hints (MS9)

- Data: `Puzzle.hints`, a plain list of text in the author's order (idea →
  approach → stronger guidance). Every real puzzle has three. Nothing is
  generated or derived from the reference solution.
- UI: puzzle screen, directly under the BRIEF. **SHOW HINT n** reveals the next
  hint and becomes **NO MORE HINTS** (disabled) after the last. The
  **HINTS used/total** row opens and closes the revealed list. A puzzle without
  hints shows no hint row. Hints are never revealed automatically.
- `HintSession` (`lib/state/hint_session.dart`, pure Dart) is the only thing
  that counts. Only revealing a *new* hint counts; opening, closing, re-running
  or tapping the disabled button does not. The session lives as long as the
  puzzle screen; revealed hints are never persisted (only a run's hint count
  is kept as a metric since MS11).
- `hintsUsed`: RUN passes `HintSession.used` to `runPuzzle(..., hintsUsed:)`,
  which stamps it with `SuiteResult.withHintsUsed` (both the graded and the
  "cannot run yet" path). The `TestRunner` itself always reports 0 and grading
  never reads hints. The results screen shows it on the WHAT IT COST line.
  It is a metric only: no scoring, stars or penalties read it.
- The content validator warns when a hint quotes an internal block id or a
  hidden case id.

Details: [`MILESTONE_9.md`](MILESTONE_9.md).

### Performance (MS10)

**Operation model — unchanged since MS5, pinned by content.** Every executed
block costs 1 operation; a loop header costs 1 per iteration; `seq` and call
wrappers are free; a short-circuited AND / OR side is neither run nor charged;
a budget is checked *before* the step it pays for (a program needing exactly
`maxOps` passes, `maxOps + 1` fails). The five reference files record their
measured cost (`metrics`), and the content validator refuses any drift, so a
change to these rules can never slip in silently. If one is ever needed:
document it, re-record the metrics, and state the compatibility impact.

**Budgets.** `limits.maxOps` is the one authoritative operation budget, per
case. A fixture case may declare `"maxOps"` only *tighter* (a larger value is a
schema error). `limits.maxAlloc` (memory cells) and `limits.maxDepth` (frames)
stop a run as before; `blocks.maxBlocks` refuses the program before it runs.
No budget is wall-clock time.

**Correct but too slow.** A case over its operation budget is
`ResultKind.operationLimit`, exactly as in MS6 (same message, same
`SuiteResult.metrics`). The runner then re-runs that case once with room up to
`overrunCeiling(budget)` (5 budgets, at most +1,000,000 operations) purely to
measure it: `CaseResult.overrun` (visible cases) and `SuiteResult.performance`
(`SuitePerformance`: `opsBudget`, `worstOps`, `overBudgetCases`,
`overBudgetFinished`, `correctWhereFinished`, `worstOverrun`,
`correctButOverBudget`) — counts only, never a hidden case's name or data.

**Puzzle side.** `"performance": {"required": true, "baselineFactor": k}` —
closed data, no formulas. `required` makes the validator demand a
correct-but-slow baseline (a reject that passes the visible cases and expects
`operationLimit`); `baselineFactor` demands that baseline needs at least `k`
times a case budget, so every passing solution beats it by `k`. Twin Beacons
declares `required: true, baselineFactor: 10`.

**Reference performance.** The checker prints an INFO line per reference
(operations, memory, depth, blocks against the limits) and compares the
recorded `metrics` with a fresh measurement.

**Benchmark API** (content tooling / analytics, never the player UI — it names
hidden cases): `benchmark(program, puzzle, {cases})` → `PerformanceReport` of
`PerformanceSample` (`caseId`, `visible`, `inputSize`, `ops`, `peakAlloc`,
`peakDepth`, `finished`) and `BudgetCheck`s. `inputSize` = total size of the
collection inputs.

**No Big-O.** The engine never proves, estimates or displays a complexity
class and never infers one from sizes. Player text talks about operations and
budgets only; a complexity statement exists only if a content author writes
it into a story or hint.

**UI.** The results screen explains an operation limit ("The result is
correct, but this solution uses too many operations: 58 against a budget of
30." / "Every case that finished came out right, but … still running after
300,000 …" / "… and not every answer is right either."), shows the measured
operations on the WHAT IT COST line (`300,000+` when still running), and adds
a `Budget: … steps · … cells · depth … · … blocks` line.

Details: [`MILESTONE_10.md`](MILESTONE_10.md).

### Values that may be empty (L1)

**Model.** `ValueType.nullable` as it always was: `NEXT NODE` → `listNode?`,
`LEFT` / `RIGHT` → `treeNode?`, a map lookup → `V?`; givens and pool variables
may be declared `listNode?` / `treeNode?` / `num?` (fixture `null`). Storing
such a value in a variable that may be empty is fine. Putting it where a real
value is needed (a node or number hole, a plain variable, SWAP / COPY) is
refused by the editor and by lowering with *This value may be empty here.
Check that it is not empty first.* (code `may_be_empty`).

**Blocks.** `logic.is_nothing` IS NOTHING and `logic.is_not_nothing` IS NOT
NOTHING — LOGIC, `verbObject` layout (`[node] IS NOT NOTHING`), `T? → bool`.
Only a value that may be empty fits; a plain value / an already-checked
variable ("never empty here") and NOTHING itself are refused. There is no
unwrap / cast / force block, by design.

**Narrowing** (`lib/src/blocks/narrowing.dart`, the one implementation, read by
`GraphTyping` and the lowerer): a plain variable reads as its plain type in
THEN of `IF x IS NOT NOTHING`, ELSE of `IF x IS NOTHING`, the body of
`WHILE x IS NOT NOTHING`, and across AND (right side and branch). OR, NOT,
EQUAL NOTHING and checks on anything but a plain variable narrow nothing.
Branch-local: after the IF or loop the variable may be empty again. Any write
(SET, INCREMENT, DECREMENT, SWAP, COPY, a FOR counter) ends the narrowing for
the rest of that flow; a loop keeps an outer fact only if the loop never
writes that variable.

**IR / runtime.** Two appended `UnaryOp`s (old IR JSON reads unchanged); the
interpreter returns `BoolValue(value is NilValue)` (or its negation), never
errors, one operation per block as always. No narrowing metadata in the IR.

**Probes.** `l1_list_probe` (count a chain, `WHILE node IS NOT NOTHING … node =
NEXT NODE node`, 109 ops) and `l1_tree_probe` (LEFT of the root, IS NOTHING /
ELSE, 9 ops): unlisted, bundled, with reference files the validator replays,
lowers and runs.

Details: [`MILESTONE_L1.md`](MILESTONE_L1.md).

### Progression and local save (MS11)

**State.** `PlayerSave` (stored) = `puzzles` (per puzzle `PuzzleProgress`:
`puzzleVersion`, `completed`, `best`, `solution`, `draft`, `lastRun`,
`editedSinceRun`) + `settings` (`PlayerSettings.showBriefOnOpen`) + `session`
(`CurrentSession`: last world and puzzle). `CampaignProgress` (unlocked
worlds, mastered concepts, statuses, what a lock waits for, the current
puzzle) is **derived** by `evaluateCampaign(campaign, save)` every time and
never stored. `Campaign` = the worlds manifest + every puzzle a world lists;
the dev probes are not in it, are never recorded and never affect anything.

**Unlock rules** (data only — world `concepts` / `prerequisites`, puzzle
`prerequisites`; no id is special): a world opens when its prerequisites are
mastered or the player already solved one of its puzzles; it completes when
open and every listed puzzle is solved (a world with no puzzles completes as
it opens); a complete world masters its concepts; a puzzle opens when its
world is open and its own prerequisites are mastered or taught by its world.
Applied to a fixpoint. Fresh install: Arrays (The Smallest Cart) is open;
solving it opens Hash Maps, Sliding Window (via the empty Two Pointers) and
Stack & Queue; Relay Towers opens Graphs (via the empty Linked Lists and
Trees).

**Completion rule.** A RUN completes its puzzle exactly when
`suite.kind == ResultKind.correct` — every case right within every budget.
Correct but over the operation budget (`operationLimit`) does not complete.
Hints never matter. Completion is never taken back.

**Best results.** Five independent minima over completing runs (`ops`,
`peakAlloc`, `peakDepth`, `blocks`, `hintsUsed`), each replaced only when
strictly better; no combined score. A failing run changes only `lastRun`.
`solution` = the program of the completing run with the fewest operations
(first wins a tie); the puzzle screen can load it back (undoable).

**Save format** (`save_codec.dart`, `saveVersion: 1`): deterministic JSON
(sorted keys); programs are `BlockGraph` JSON, never IR; only player state.
Reading never throws and never invents a completion: unusable text (not JSON,
no / bad / newer version) is kept aside and play starts fresh; a damaged
section (one puzzle entry, one program, the settings, the session) is dropped
on its own with a `SaveIssue`; a program must pass `GraphStructure.validate`
(unfinished holes are fine). Unknown fields are ignored and not written back.
Older versions go through a migration table (empty for v1). A puzzle with a
different `version` keeps `completed` and `draft`, and clears `best`,
`solution` and `lastRun` (the editor says the puzzle changed).

**Storage.** `FileProgressStore`: `algorun_save.json` in
`getApplicationSupportDirectory`, written to `.tmp` then renamed; an unusable
save is copied to `algorun_save.unreadable-<millis>.json`. `main.dart`
installs it; the provider default is `MemoryProgressStore`, so tests never
touch the device. Web (preview) keeps progress in memory.

**Autosave** (`ProgressNotifier`): a new editor `BlockGraph` updates the draft
in memory and is written after 800 ms of quiet; opening a puzzle, RUN, a
settings change, leaving the puzzle and the app being hidden / paused /
detached (`AppLifecycleListener` in `AlgorunApp`) write at once. Writes never
overlap; nothing is recorded before the save has loaded; failures are
reported (`ProgressNotifier.issues`, debug log), never thrown.

**UI.** Home: PROGRESS card, CONTINUE (last puzzle) or ENTER on a fresh
install. Worlds / Puzzles: open, solved, locked (*Locked — learn arrays
first*), no puzzles yet, CURRENT. Puzzle: restores `draft` → `solution` →
empty; solved check; Load best solution; locked by route shows why. Results:
PROGRESS lines (*Puzzle solved.* / *New best: …* / *Now open: …*). Settings:
brief preference, Reset progress (confirmed).

Details: [`MILESTONE_11.md`](MILESTONE_11.md).

### Editor (MS3) — do not regress

Scratch-style vertical stacks + typed holes. Phone: GIVENS + `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. IF+ELSE draw as one card. Picker = `allowlist ∩ compatiblePlacements`. No TextField for names/numbers (chips + pad). Labels via `BlockChrome` (GREATER THAN, never `cmp.gt`).

## Test results at MS11 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **341 passed** |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **46 passed** |
| Content validator (assets + worlds + references) | `OK 9 puzzle(s), 6 warning(s)` + 7 INFO lines |
| Flutter `analyze` | no issues |
| Flutter `test` | **111 passed** |

Engine: MS4 lowering (86), MS5 interpreter (42), MS6 runner (26), MS7 codec
(40), schema (41), FLOOR DIVIDE (14), MS8 shipped puzzles (30), MS10
performance (17), L1 values that may be empty (44), contract tests. Content:
shipped set with references, every reference rule, reference metrics and
performance rules, hint leak warnings, CLI, the two L1 probes end to end. App:
editor, picker, RUN, results, the five real puzzles, hints, budget wording,
IS NOT NOTHING in the editor; MS11 save format (22), progression and best
results (18), sessions and autosave (9), purity guards (2), progression UI
(10).

The six warnings are known and deliberate: worlds 12 and 13 require
`recursion` (no world teaches it yet), and the four dev probes are unlisted.

**Widget tests and assets:** load the campaign from the repository files
(`test/support/campaign_files.dart`), never through `rootBundle` inside a
widget test — the bundle caches a pending load made in fake async and the next
test waits on it forever.

## Known limitations

### Open follow-ups

- **Narrowing is deliberately small (L1).** No narrowing through OR / NOT or after an IF whose THEN always returns (use IF / ELSE); assigning a real value does not narrow (check again); only plain variables narrow. The editor checks each drop where it is made, so an edit elsewhere can invalidate an earlier drop — lowering reports it before RUN. RETURN is still not checked against the puzzle's output type. Tree traversal beyond one path needs a queue or stack of nodes until recursion exists.
- **Hints are a metric only.** `hintsUsed` is shown and kept per run (`lastRun`, `best`) but never scored and never blocks anything; revealed hints are not persisted (MS9, MS11).
- **Progression is deliberately simple (MS11).** A world completes only when every listed puzzle is solved (no mastery threshold yet); inconsistent content (a puzzle needing a concept only a later world teaches) can deadlock and is not yet caught by the validator; an edit less than 800 ms before a kill without a lifecycle event is lost; one save slot, no export, no per-puzzle reset; the campaign loads every listed puzzle at start-up; unreadable-save copies are never cleaned up; web does not persist.
- **Performance is counted, not scored.** No stars or scores read the budgets yet. A hopeless solution is only known to be "still running" at the measurement ceiling; its correctness beyond it is not claimed. Memory and depth have no overrun measurement. There is no fixture generator: size profiles are explicit fixtures with optional per-case `maxOps` (MS10).
- **Reference authoring has no tool.** References are hand-authored JSON checked by the validator; saving an editor graph as a reference would make authoring scale.
- **No random test generation.** A future generator must produce plain `TestCase` data for `TestRunner.runCases`, deterministic and within `FixtureLimits`, never executable content.
- **World prerequisites.** Worlds 12 and 13 require `recursion`, which no world teaches (warning).

### Other

- Graph nodes carry no values (the runtime graph has none). `heap` / `pair` have no fixture form, runtime values or blocks.
- A graph whose program marked a node it does not have cannot be written as canonical JSON; the results screen falls back to the display form.
- `constraints.n` is recorded but not checked against fixture sizes.
- `hintsUsed` is 0 until hints ship (MS9). The suite runs every case even after a failure.
- The `PuzzleScreen` → `ResultsScreen` navigation is not pumped in a test; `runPuzzle` covers the logic.
- The two MS1/MS3 probes stay bundled (tests, the editor seed, the screen's default route) but no world lists them; neither do the two L1 probes.
- Graph fixtures do not enforce "stations are numbered 0 to n-1"; `fewest_rides` states it and its fixtures follow it.
- `maxDepth` stays at 1 until player-defined functions ship; `fn.def` / `fn.call` remain unsupported and hidden.
- Allocation has no collector: an unreachable container keeps its cells for the rest of the run.
- Generic unification is per-block, not Hindley–Milner. Editor is tap-to-place. Flutter web is preview-only.
- `ARCHITECTURE.md` spells the validator command `dart run algorun_content:validate`; use the command below.

## Exact commands

From the **repository root**. Requires Flutter 3.47+ / Dart 3.13+ (app pubspec: `sdk: ^3.13.0`). SDK at MS11 closeout: Flutter 3.47.2, Dart 3.13.2.

```bash
flutter pub get

# Engine (no Flutter)
cd packages/algorun_engine && dart analyze && dart test && cd ../..

# Content
cd packages/algorun_content && dart analyze && dart test && cd ../..
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references

# App
flutter analyze
flutter test
flutter run          # Android device/emulator
```

Every new or edited puzzle must pass the content validator — with the
references directory — before it is committed under `assets/puzzles`. A new
playable puzzle needs a reference file in `content/references/` and a world
listing it; its folder must be in `pubspec.yaml` to ship.

Do not add a TypeScript app. Do not eval generated source. Do not start one milestone from another milestone's request.

## Roadmap

| Order | Milestone | Status |
|---|---|---|
| 1–10 | skeleton → typed blocks → editor → lowering → interpreter → test runner → schema → five puzzles → hints → performance metrics | complete |
| L1 | Language: values that may be empty, IS NOTHING / IS NOT NOTHING, narrowing | complete |
| 11 | Progression + local save | complete |
| **12** | **Large original content** | **next** — tree / linked-list / counting-map content is expressible (L1) and progression is live (MS11) |
| 13 | Mobile UX polish | planned |

## Milestone 12 contract (next — when asked)

Large original content, through the existing pipeline only.

- New puzzles are data: each passes the content validator with a reference
  solution (editor replay, lowering, every case within budget) and its
  rejects, and is listed by exactly one world. No engine change unless a
  puzzle genuinely needs one, documented as its own step.
- Fill the chapters that have no puzzles yet (two pointers, linked lists,
  trees, heaps, greedy …) in the order the manifest's prerequisites define;
  progression then unlocks them with no code change. Keep `concepts` /
  `prerequisites` consistent so every puzzle stays reachable (consider a
  validator check for it, and a per-world mastery threshold if worlds grow
  large).
- Bump a puzzle's `version` for any incompatible change to a shipped puzzle
  (saved best results for it are then cleared, completion kept).
- Keep every test green and the validator passing with references.

## Milestone docs

| File | Status |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | locked |
| [`MILESTONE_1.md`](MILESTONE_1.md) | complete — skeleton + contracts |
| [`MILESTONE_2.md`](MILESTONE_2.md) | complete — typed ports + undo |
| [`MILESTONE_3.md`](MILESTONE_3.md) | complete — visual editor |
| [`MILESTONE_4.md`](MILESTONE_4.md) | complete — lowering |
| [`MILESTONE_5.md`](MILESTONE_5.md) | complete — interpreter |
| [`MILESTONE_6.md`](MILESTONE_6.md) | complete — test runner |
| [`MILESTONE_7.md`](MILESTONE_7.md) | complete — puzzle schema hardening |
| [`MILESTONE_8.md`](MILESTONE_8.md) | complete — five real puzzles + reference solutions |
| [`MILESTONE_9.md`](MILESTONE_9.md) | complete — hint system |
| [`MILESTONE_10.md`](MILESTONE_10.md) | complete — deterministic performance metrics |
| [`MILESTONE_L1.md`](MILESTONE_L1.md) | complete — values that may be empty and narrowing |
| [`MILESTONE_11.md`](MILESTONE_11.md) | complete — progression and local persistence |
| this file | MS11 handoff |
