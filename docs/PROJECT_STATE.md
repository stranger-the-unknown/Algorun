# Algorun project state

Handoff document for the next coding agent. Read this before changing
anything. It is written so you can continue without any previous conversation.

**Current milestone: 7 complete (closed puzzle schema, structured fixtures, FLOOR DIVIDE).**
**Next milestone: 8 (first five real algorithm puzzles). Not started.**

Do not implement Milestone 8 from this file unless the user explicitly asks.
Do not change the architecture.

Milestone commits: MS5 `06e2037c5d4841a33d69763d2385e0a8f834dc9c`,
MS6 `39956f967f8102f747be94bc3ad9de4c0703c674`, MS7 — see `git log` (the commit
titled "Milestone 7: …").

---

## What this product is

Working title: **Algorun**. Android-first Flutter/Dart algorithm puzzle game.

The player constructs algorithms with Scratch-style typed visual blocks. No
syntax. No eval of generated Dart/JS/Kotlin. Campaign difficulty is LeetCode
Medium/Hard later; the two shipped puzzles are engine/editor probes.

There is **no TypeScript / React / web product codebase**. Flutter web exists
only as a host preview of the same Dart app.

## Locked decisions (do not reopen)

1. Flutter + Dart only. Android primary (`com.algorun`).
2. Engine is pure Dart: `packages/algorun_engine` must not import `package:flutter`.
3. First five puzzles are probes, not the difficulty ceiling.
4. Per-puzzle `blocks.allow` is the editor palette. Full-catalog palette is a bug.
5. No Big-O analyzer in v1. Grade with `maxOps` / `maxAlloc` / `maxDepth`.
6. Local hidden tests are UI-hidden, not APK-secret. `VerdictSource.remote` is reserved.
7. `packages/algorun_content` is offline-only. The Flutter app must not import it.
8. Stay on Flutter/Dart.
9. *(MS7)* Puzzle JSON is data only. Validators are registry names; fixtures are canonical values; nothing in content is ever executed.

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
    state/run_puzzle.dart         the RUN path: graph → lower → runTests
  assets/
    worlds.json                   14 worlds; only world_01 has puzzles
    puzzles/world_01/
      ms1_contract_probe.json
      ms3_editor_probe.json
  packages/
    algorun_engine/               pure Dart, no Flutter
      lib/src/ast/                ir.dart (typed IR), lower.dart
      lib/src/blocks/             catalog, graph, typing, commands, chrome
      lib/src/execution/          AlgorunEngine, DefaultEngine, Interpreter, results
      lib/src/puzzles/            parse.dart (THE schema), puzzle.dart, world.dart
      lib/src/runner/             TestRunner, validator registry
      lib/src/runtime/            RuntimeValue, value_json.dart (fixture format), limits
      lib/src/types/              ValueType + parser
      test/                       245 tests
    algorun_content/              offline validator + CLI; not imported by the app
  docs/                           architecture + per-milestone notes
  test/widget_test.dart           Flutter editor / picker / RUN tests
```

App `pubspec.yaml` path-depends on `packages/algorun_engine` only.

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
| `arith.*` / `cmp.*` / `logic.*` | `BinaryExpr` / `UnaryExpr` (`arith.floor_div` → `BinaryOp.floorDiv`, MS7) |
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

### Content validator (MS7)

`packages/algorun_content`: `ContentValidator.validateContent(puzzles:, worldsSource:)` → `ContentReport` of errors and warnings, each with file and JSON path, in a stable order.

Errors: every schema rule; duplicate puzzle ids; a file not at `<world>/<id>.json`; a world listing a missing or invalid puzzle; a puzzle whose world is unknown or listed by another world; a malformed manifest. Warnings: no hints; `fn.*` allowed; whole-catalog allowlist; a puzzle no world lists; a prerequisite no world teaches.

### Editor (MS3) — do not regress

Scratch-style vertical stacks + typed holes. Phone: GIVENS + `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. IF+ELSE draw as one card. Picker = `allowlist ∩ compatiblePlacements`. No TextField for names/numbers (chips + pad). Labels via `BlockChrome` (GREATER THAN, never `cmp.gt`).

## Test results at MS7 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **245 passed** |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **16 passed** |
| Content validator over `assets/` | `OK 2 puzzle(s), 2 warning(s)` |
| Flutter `analyze` | no issues |
| Flutter `test` | **14 passed** |

Engine: MS4 goldens and lowering (86), MS5 interpreter (42), MS6 runner (25),
MS7 fixture codec (40), schema (37), FLOOR DIVIDE (14), plus contract tests.
Content: shipped assets, single-file rules, whole-set rules, determinism, and
the CLI on real and temporary malformed files. App: editor, picker, RUN path,
results rendering, and the shipped contract probe solved through the schema.

## Known limitations

### Open follow-ups

- **No reference solutions.** Content is proven well-formed and gradable, not solvable within its allowlist and `maxOps`. MS8 should add a reference `BlockGraph` per puzzle and have the content validator run it through `TestRunner`.
- **No random test generation.** No puzzle declares a generator and none was invented. A future generator must produce plain `TestCase` data for `TestRunner.runCases`, from a deterministic seed, within `FixtureLimits` — never executable content.
- **World prerequisites.** Worlds 12 and 13 require `recursion`, which no world teaches (content validator warning).

### Other

- Graph nodes carry no values (the runtime graph has none). `heap` / `pair` have no fixture form, runtime values or blocks.
- A graph whose program marked a node it does not have cannot be written as canonical JSON; the results screen falls back to the display form.
- `constraints.n` is recorded but not checked against fixture sizes.
- `hintsUsed` is 0 until hints ship (MS9). The suite runs every case even after a failure.
- The `PuzzleScreen` → `ResultsScreen` navigation is not pumped in a test; `runPuzzle` covers the logic.
- `maxDepth` stays at 1 until player-defined functions ship; `fn.def` / `fn.call` remain unsupported and hidden.
- Allocation has no collector: an unreachable container keeps its cells for the rest of the run.
- Generic unification is per-block, not Hindley–Milner. Editor is tap-to-place. Flutter web is preview-only.
- `ARCHITECTURE.md` spells the validator command `dart run algorun_content:validate`; use the command below.

## Exact commands

From the **repository root**. Requires Flutter 3.47+ / Dart 3.13+ (app pubspec: `sdk: ^3.13.0`). SDK at MS7 closeout: Flutter 3.47.2, Dart 3.13.2.

```bash
flutter pub get

# Engine (no Flutter)
cd packages/algorun_engine && dart analyze && dart test && cd ../..

# Content
cd packages/algorun_content && dart analyze && dart test && cd ../..
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json

# App
flutter analyze
flutter test
flutter run          # Android device/emulator
```

Every new or edited puzzle must pass the content validator before it is
committed under `assets/puzzles`.

Do not add a TypeScript app. Do not eval generated source. Do not start MS9–13 from a MS8 request.

## Milestone 8 contract (when asked)

First five real algorithm puzzles — still not the difficulty ceiling.

- Author five puzzles in `assets/puzzles/world_0x/` using the MS7 schema and fixture format; list them in `worlds.json`. Each needs visible and hidden fixtures covering its edge cases, a validator that fits its output, and a tight allowlist.
- Add a reference solution per puzzle (a `BlockGraph` in the content set, not executable code) and make the content validator run it through `TestRunner`, proving every puzzle is solvable within its own allowlist and `limits`.
- Use FLOOR DIVIDE for midpoints; do not change DIVIDE.
- Do not add scoring, hints, generators, a backend, or editor redesign. Keep all engine, content and app tests green.

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
| this file | MS7 handoff |
