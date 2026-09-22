# Algorun project state

Handoff document for the next coding agent. Read this before changing anything.

**Current milestone: 5 complete (Program IR → sandboxed interpreter).**
**Next milestone: 6 (Test runner). Not started.**

Do not implement Milestone 6 from this file unless the user explicitly asks. Do not change the architecture.

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
          → TestRunner    (MS6, NOT STARTED)
            → Result + metrics
```

MS3 shipped the Scratch-style editor on the MS2 graph. MS4 lowers that graph to a typed `Program`. MS5 runs that `Program` in a sandboxed, deterministic VM with op / alloc / depth budgets.

`DefaultEngine.runTests` still returns `ResultKind.invalidProgram` with a milestone message, and the puzzle screen's RUN calls `runTests` — so the app still shows "not implemented" until MS6 wires fixtures through `run`.

## Package structure

```
algorun/                          Flutter app (this repo root after clone)
  lib/                            UI, editor, Riverpod
    editor/                       Scratch-style editor (MS3)
    screens/                      home, worlds, puzzle, results, settings
    puzzles/asset_repository.dart
    state/providers.dart          engineProvider → DefaultEngine
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
      lib/src/runtime/            RuntimeValue + RunLimits / RunMetrics
      test/                       129 tests as of MS5 closeout
    algorun_content/              offline CLI validator, not imported by app
  docs/                           architecture + per-milestone notes
  test/widget_test.dart           Flutter editor/picker tests
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

### Editor (MS3) — do not regress

Scratch-style vertical stacks + typed holes. Phone: GIVENS + `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. IF+ELSE draw as one card. Picker = `allowlist ∩ compatiblePlacements`. No TextField for names/numbers (chips + pad). Labels via `BlockChrome` (GREATER THAN, never `cmp.gt`).

## Test results at MS5 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **129 passed** |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues, **3 passed** |
| Content validator over `assets/` | OK 2 puzzles |
| Flutter `analyze` | no issues |
| Flutter `test` | **9 passed** |

Engine goldens A–J plus for-range, for-each, catalog `arr.len`, JSON round-trip, positions-do-not-affect-IR, invalid graphs, no-throw. MS5 adds 42 interpreter tests (control flow, expressions, collections, nodes and graphs, budgets, sandbox, trace, and graph → lower → run end to end).

## Known limitations

- No test runner (MS6). RUN in the app still reports unimplemented: the puzzle screen calls `runTests`, not `run`.
- `valueFromJson` has no tagged form for `listNode` / `treeNode` / `graph` / `set` fixtures yet, so those VM paths are tested from Dart, not from puzzle JSON. MS6/MS7 schema work.
- No integer-division or floor block, so `(lo + hi) / 2` yields `1.5` and fails as a position. MS8 content needs `arith.floor` / `arith.div_int` or wording that avoids the midpoint.
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

Requires Flutter 3.47+ / Dart 3.13+. The app pubspec asks for `sdk: ^3.13.0` (MS4 asked for `^3.13.4`, which made `flutter pub get` fail on Flutter 3.47.2). SDK used at MS5 closeout: Flutter 3.47.2, Dart 3.13.2.

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

Do not add a TypeScript app. Do not eval generated source. Do not start MS7–13 from a MS6 request.

## Milestone 6 contract (when asked)

Implement `runTests`: run every fixture through the MS5 interpreter and grade it.

- Input: `Program` + `Puzzle`. Build each case's input from `TestCase.input` and `puzzle.io.inputs`; run under `puzzle.limits.asLimits`.
- Compare with `compareOutputs(parseValidatorId(puzzle.outputValidator), actual, expected)` — the named validators already exist in `runner/validators.dart`.
- Output: `SuiteResult` — `visible` case results, `hiddenSummary` counts only, worst `ResultKind`, aggregate metrics, `firstFailureBlockId`.
- Hidden fixture payloads must never reach UI state.
- `valueFromJson` needs a tagged form before `listNode` / `treeNode` / `graph` / `set` fixtures can be written in puzzle JSON.
- Wire the puzzle screen's RUN to the real suite (it already calls `runTests`, currently with `Program.empty` — it has to lower the editor graph first).
- Do not change the MS2 typed-port model, the MS3 editor UX, or the IR shape; prefer keeping MS4 goldens and MS5 interpreter tests green.

## Milestone docs

| File | Status |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | locked |
| [`MILESTONE_1.md`](MILESTONE_1.md) | complete — skeleton + contracts |
| [`MILESTONE_2.md`](MILESTONE_2.md) | complete — typed ports + undo |
| [`MILESTONE_3.md`](MILESTONE_3.md) | complete — visual editor |
| [`MILESTONE_4.md`](MILESTONE_4.md) | complete — lowering |
| [`MILESTONE_5.md`](MILESTONE_5.md) | complete — interpreter |
| this file | MS5 handoff |
