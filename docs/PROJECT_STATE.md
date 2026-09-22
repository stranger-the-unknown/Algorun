# Algorun project state

Handoff document for the next coding agent. Read this before changing anything.

**Current milestone: 6 complete (fixtures → interpreter → validator → SuiteResult; RUN is live).**
**Next milestone: 7 (Puzzle schema hardening). Not started.**

Do not implement Milestone 7 from this file unless the user explicitly asks. Do not change the architecture.

Milestone commits: MS5 `06e2037c5d4841a33d69763d2385e0a8f834dc9c`.

---

## What this product is

Working title: **Algorun**. Android-first Flutter/Dart algorithm puzzle game.

The player constructs algorithms with Scratch-style typed visual blocks. No syntax. No eval of generated Dart/JS/Kotlin. Campaign difficulty is LeetCode Medium/Hard later; current puzzles are engine/editor probes.

There is **no TypeScript / React / web product codebase**. Flutter web exists only as a host preview of the same Dart app.

## Locked decisions (do not reopen)

1. Flutter + Dart only. Android primary (`com.algorun`).
2. Engine is pure Dart: `packages/algorun_engine` must not import `package:flutter`.
3. First five puzzles are probes, not the difficulty ceiling.
4. Per-puzzle `blocks.allow` is the editor palette. Full-catalog palette is a bug.
5. No Big-O analyzer in v1. Grade with `maxOps` / `maxAlloc` / `maxDepth`.
6. Local hidden tests are UI-hidden, not APK-secret. `VerdictSource.remote` is reserved.
7. `packages/algorun_content` is offline-only. The Flutter app must not import it.
8. Stay on Flutter/Dart.

Full lock text: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Pipeline (current vs next)

```
Puzzle JSON
  → BlockGraph            (MS2)
    → validate            (MS1/MS2)
      → AST / IR          (MS4, done)
        → Interpreter     (MS5, done)
          → TestRunner    (MS6, done)
            → Result + metrics
```

MS3 shipped the Scratch-style editor on the MS2 graph. MS4 lowers that graph to a typed `Program`. MS5 runs that `Program` in a sandboxed, deterministic VM with op / alloc / depth budgets. MS6 grades it against the puzzle's fixtures with named validators.

The whole path is live: RUN in the app goes block graph → validate → lower → test runner → result. No placeholder remains.

## Package structure

```
algorun/                          Flutter app (this repo root after clone)
  lib/                            UI, editor, Riverpod
    editor/                       Scratch-style editor (MS3)
    screens/                      home, worlds, puzzle, results, settings
    puzzles/asset_repository.dart
    state/providers.dart          engineProvider → DefaultEngine
    state/run_puzzle.dart         the RUN path: graph → lower → runTests
  assets/
    worlds.json
    puzzles/world_01/
      ms1_contract_probe.json
      ms3_editor_probe.json
  packages/
    algorun_engine/               pure Dart, no Flutter
      lib/src/ast/ir.dart         typed Program / Stmt / Expr / LValue
      lib/src/ast/lower.dart      lower(graph, puzzle) → LowerResult
      lib/src/blocks/             catalog, graph, typing, commands, chrome
      lib/src/execution/          AlgorunEngine + DefaultEngine + Interpreter
      lib/src/puzzles/            Puzzle JSON model + parser
      lib/src/runner/             TestRunner + validator registry
      lib/src/runtime/            RuntimeValue + RunLimits / RunMetrics
      test/                       154 tests as of MS6 closeout
    algorun_content/              offline CLI validator, not imported by app
  docs/                           architecture + per-milestone notes
  test/widget_test.dart           Flutter editor / picker / RUN tests
```

App `pubspec.yaml` path-depends on `packages/algorun_engine` only.

## Important APIs

### Engine

```dart
abstract interface class AlgorunEngine {
  ValidationReport validate(BlockGraph graph, Puzzle puzzle);
  LowerResult lower(BlockGraph graph, Puzzle puzzle);
  RunResult run(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
  SuiteResult runTests(Program program, Puzzle puzzle);
}
```

Public convenience:

```dart
LowerResult lower(BlockGraph graph, Puzzle puzzle);
```

- Success → `LowerResult.ok` with a `Program`.
- Failure → structured `ValidationMessage`s. Game-facing copy. Never compiler jargon.
- Never throws on a malformed graph.

`DefaultEngine.lower` runs full `validate` (allowlist, budget, structure) first, then `Lowerer`. `DefaultEngine.run` forwards to the MS5 interpreter.

### Typed ports (MS2) — do not change

- `PortKind` = `{statement, expression, elseClause}`.
- `GraphTyping.canConnect` is the snap/picker source of truth.
- `GraphTyping.compatiblePlacements` filters the hole picker.
- `GraphHistory` + reversible commands. Failed connects do not push undo.
- Top-level stack is `@main.body`.
- Variables live on `BlockGraph.variables`, not on the block. GIVENS = `puzzle.io.inputs`. CREATE names come from `puzzle.variablePool` (chips only).
- Canvas `x` / `y` / `collapsed` are UI-only. Lowering ignores them.

### IR (MS4)

Closed, typed, JSON-serializable (`Program.toJson` / `fromJson` / `toJsonString`). No callbacks. No UI metadata.

| Node | Shape |
|---|---|
| `Program` | `entry` (`main`) + `functions` |
| `FnDecl` | name, params, optional return type, body, `srcBlockId` |
| `Stmt` | seq, if (optional else), while, forRange, forEach, break, continue, return, assign, inc, dec, expr |
| `Expr` | lit, var, binary, unary, call, index, field, null, new — each has `ValueType` + `srcBlockId` |
| `LValue` | var, index, field |

Catalog mapping (not puzzle ids):

| Blocks | IR |
|---|---|
| `var.set` | `AssignStmt` + `VarLValue` |
| `var.inc` / `var.dec` | `IncStmt` / `DecStmt` |
| `ctrl.if` + optional `ctrl.else` | **one** `IfStmt` |
| `ctrl.while` | `WhileStmt` |
| `ctrl.for_range` | `ForRangeStmt` |
| `ctrl.foreach` | `ForEachStmt` |
| `ctrl.break` / `continue` / `return` | matching stmts |
| `arith.*` / `cmp.*` / `logic.*` | `BinaryExpr` / `UnaryExpr` |
| `arr.get` | `IndexExpr` |
| `arr.set` | `AssignStmt` + `IndexLValue` |
| `ll.*` / `tree.*` | `FieldExpr` / `FieldLValue` |
| other catalog ops (`arr.len`, `map.get`, mutators, …) | `CallExpr` / `ExprStmt` with catalog id as callee |
| `fn.def` / `fn.call` | `unsupported` |

Types reuse `ValueType` / `GraphTyping`. No second type system.

### Interpreter (MS5) — do not change without a reason

```dart
RunResult runProgram(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
```

Tree-walks the IR only. Never sees a `BlockGraph`, never evals, never generates source, no clock / random / I/O. Never throws: failures come back as a `RunResult` with game-facing copy and the failing `srcBlockId`.

- `ResultKind.correct` = **ran to completion**. Verdicts belong to MS6.
- Budgets are checked *before* a step, so `RunMetrics` reports work that happened: `maxOps` = one op per executed block (loop header = one per iteration, `seq` / call wrappers free, short-circuited operands free), `maxAlloc` = live collection cells (removal gives the cell back), `maxDepth` = function frames.
- Deterministic: insertion-ordered maps and sets, `for each` iterates a snapshot, the `for range` counter is loop-owned, given values are deep-copied so a run cannot mutate fixtures.
- Division keeps whole results whole (`8 / 2` → `2`, `7 / 2` → `3.5`); dividing by zero is a runtime error. Positions must be whole numbers inside the list.
- Equality is by value for number / text / yes-no / empty; a list, map, set, node or graph is only equal to itself.
- Unknown callee (including `fn.call`) → `ResultKind.invalidProgram`.
- New runtime values live in `runtime/runtime_value.dart`: `SetValue`, `StackValue`, `QueueValue`, `DequeValue`, `ListNodeValue`, `TreeNodeValue`, `GraphValue`. `RuntimeValue` is sealed — adding one means updating `valuesEqual` in `runner/validators.dart`.

Details: [`MILESTONE_5.md`](MILESTONE_5.md).

### Test runner (MS6)

```dart
final class TestRunner {
  SuiteResult run(Program program, Puzzle puzzle);                              // puzzle.allTests
  SuiteResult runCases(Program program, Puzzle puzzle, List<TestCase> cases);   // generator seam
}
```

`DefaultEngine.runTests` calls it. Visible cases first, then hidden; every case runs.

- Each case gets its own `Interpreter` and its own decoded input — cases cannot see each other, and a run cannot mutate the fixtures.
- The runner invents one verdict, `wrongAnswer`. Every other failure is passed through from MS5 with its message and `srcBlockId`.
- `SuiteResult.metrics`: worst `ops` / `peakAlloc` / `peakDepth` across cases (budgets are per run), `blocks` = distinct `srcBlockId`s in the IR, `hintsUsed` = 0 until MS9.
- Hidden cases never enter `SuiteResult.visible`; only `HiddenSummary(passed, total)` leaves. `firstFailureCaseId` is set only for a visible failure; `firstFailureBlockId` / `firstFailureOpIndex` are the player's own program and are always reported.
- Comparators live in a closed registry (`outputValidators`): `equal`, `listEqualByValue`, `unorderedArray`, `setEqual`, `unorderedPairs`, `treeEqual`. Puzzle JSON names one and can never carry a predicate. An unknown name grades as `invalidProgram`.
- `ResultKind.depthLimit` exists as of MS6; MS5 used to fold it into `runtimeError`.

App side: `lib/state/run_puzzle.dart` holds the whole RUN path, so the screen stays a button and the path stays testable.

Details: [`MILESTONE_6.md`](MILESTONE_6.md).

### Editor (MS3) — do not regress

Scratch-style vertical stacks + typed holes. Phone: GIVENS + `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. IF+ELSE draw as one card. Picker = `allowlist ∩ compatiblePlacements`. No TextField for names/numbers (chips + pad). Labels via `BlockChrome` (GREATER THAN, never `cmp.gt`).

## Test results at MS6 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **154 passed** |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues, **3 passed** |
| Content validator over `assets/` | OK 2 puzzles |
| Flutter `analyze` | no issues |
| Flutter `test` | **13 passed** |

Engine goldens A–J plus for-range, for-each, catalog `arr.len`, JSON round-trip, positions-do-not-affect-IR, invalid graphs, no-throw. MS5 adds 42 interpreter tests (control flow, expressions, collections, nodes and graphs, budgets, sandbox, trace, graph → lower → run). MS6 adds 25 runner tests (grading, hidden isolation, every budget, the comparator registry, case isolation, fixture immutability, repeated runs, JSON round-trip grading, graph → validate → lower → runTests) and 4 app tests (RUN grades real fixtures, RUN on an empty canvas, results rendering, hidden stays a count).

## Known limitations

### Follow-ups carried forward

- **Integer division.** Re-checked at MS6: no current puzzle divides and the catalog has no floor / integer-division block, so nothing is blocked today. `(lo + hi) / 2` yields `1.5` and then fails as a list position, so a binary-search puzzle needs a decision **before MS8 content**: add a typed `arith.floor` or `arith.div_int` block. Do not silently change what DIVIDE means.
- **Node / graph fixtures.** `valueFromJson` has no tagged form for `listNode` / `treeNode` / `graph` / `set`, so those cases are written from Dart, not from puzzle JSON. Only `valueFromJson` has to change; the runner is already shape-agnostic. Belongs with MS7 schema hardening.

### Other

- No random test generation: no puzzle declares a generator. `TestRunner.runCases` is the seam — plain `TestCase` data in, never executable content.
- `hintsUsed` is always 0 until hints ship (MS9).
- The suite runs every case even after a failure: deterministic and complete, but more work than a judge that stops early.
- The `PuzzleScreen` → `ResultsScreen` navigation is not pumped in a test; `runPuzzle` covers the logic. `AssetPuzzleRepository` would have to be injectable to test the screen itself.
- `maxDepth` is enforced but stays at 1 until player-defined functions ship.
- Allocation has no collector: an unreachable container still holds its cells for the rest of the run.
- `heap` / `pair` have `ValueType` entries but no catalog blocks and no runtime values.
- `fn.def` / `fn.call` remain unsupported / hidden from the editor.
- Collection ops that are not index/field lower as catalog-id `CallExpr` for the VM.
- for-range `step` is optional in IR; an empty hole does not invent `1`.
- Generic unification is per-block, not Hindley–Milner.
- Probe puzzles are not interview difficulty.
- Editor is tap-to-place; no paletted drag.
- Flutter web is preview-only; Android is the product.

## Exact commands

From the **repository root** (the Flutter app root: contains `pubspec.yaml` + `lib/` + `packages/`).

Requires Flutter 3.47+ / Dart 3.13+. The app pubspec asks for `sdk: ^3.13.0` (MS4 asked for `^3.13.4`, which made `flutter pub get` fail on Flutter 3.47.2). SDK used at MS6 closeout: Flutter 3.47.2, Dart 3.13.2.

```bash
flutter pub get

# Engine (no Flutter)
cd packages/algorun_engine && dart analyze && dart test && cd ../..

# Content validator
cd packages/algorun_content && dart analyze && dart test && cd ../..
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json

# App
flutter analyze
flutter test
flutter run          # Android device/emulator
```

Do not add a TypeScript app. Do not eval generated source. Do not start MS8–13 from a MS7 request.

## Milestone 7 contract (when asked)

Harden the puzzle schema now that the whole pipeline runs real fixtures.

- Give `valueFromJson` a tagged form for `listNode`, `treeNode`, `graph` and `set` so those cases can be written in puzzle JSON. Nothing in `TestRunner` should have to change.
- Teach `packages/algorun_content` to check what the runner now depends on: the named validator exists, fixture inputs cover `io.inputs`, declared types match the fixture shapes, and `limits.maxOps` is reachable for a reference solution.
- Decide the integer-division question before MS8 content: a typed `arith.floor` / `arith.div_int` block, or puzzle wording that avoids a midpoint. Do not change what DIVIDE means.
- Keep the schema closed: no predicates, no code, no generator that executes anything. A generator, if it arrives, produces `TestCase` data for `TestRunner.runCases`, with a deterministic seed and bounded size.
- Do not change the MS2 typed-port model, the MS3 editor UX, the MS4 IR shape, or MS5/MS6 semantics; keep all 154 engine tests green.

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
| this file | MS6 handoff |
