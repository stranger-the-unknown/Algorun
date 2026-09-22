# Algorun project state

Handoff document for the next coding agent. Read this before changing anything.

**Current milestone: 4 complete (BlockGraph → typed Program IR).**
**Next milestone: 5 (Interpreter / VM). Not started.**

Do not implement Milestone 5 from this file unless the user explicitly asks. Do not change the architecture.

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
        → Interpreter     (MS5, NOT STARTED)
          → TestRunner    (MS6)
            → Result + metrics
```

MS3 shipped the Scratch-style editor on the MS2 graph. MS4 lowers that graph to a typed `Program`. `UnimplementedEngine.run` / `runTests` still return `ResultKind.invalidProgram` with a milestone message.

## Package structure

```
algorun/                          Flutter app (this repo root after clone)
  lib/                            UI, editor, Riverpod
    editor/                       Scratch-style editor (MS3)
    screens/                      home, worlds, puzzle, results, settings
    puzzles/asset_repository.dart
    state/providers.dart          engineProvider → UnimplementedEngine
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
      lib/src/execution/          AlgorunEngine + UnimplementedEngine
      lib/src/puzzles/            Puzzle JSON model + parser
      test/                       86 tests as of MS4 closeout
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

`UnimplementedEngine.lower` runs full `validate` (allowlist, budget, structure) first, then `Lowerer`.

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

### Editor (MS3) — do not regress

Scratch-style vertical stacks + typed holes. Phone: GIVENS + `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. IF+ELSE draw as one card. Picker = `allowlist ∩ compatiblePlacements`. No TextField for names/numbers (chips + pad). Labels via `BlockChrome` (GREATER THAN, never `cmp.gt`).

## Test results at MS4 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **86 passed** |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues, **3 passed** |
| Flutter `analyze` | no issues |
| Flutter `test` | **9 passed** |

Engine goldens A–J plus for-range, for-each, catalog `arr.len`, JSON round-trip, positions-do-not-affect-IR, invalid graphs, no-throw.

## Known limitations

- No interpreter (MS5). RUN still reports unimplemented.
- `fn.def` / `fn.call` remain unsupported / hidden from the editor.
- Collection ops that are not index/field lower as catalog-id `CallExpr` for the VM.
- for-range `step` is optional in IR; an empty hole does not invent `1`.
- Generic unification is per-block, not Hindley–Milner.
- Probe puzzles are not interview difficulty.
- Editor is tap-to-place; no paletted drag.
- Flutter web is preview-only; Android is the product.

## Exact commands

From the **repository root** (the Flutter app root: contains `pubspec.yaml` + `lib/` + `packages/`).

Requires Flutter 3.47+ / Dart 3.13+ (SDK used at closeout: Flutter 3.47.5, Dart 3.13.4).

```bash
flutter pub get

# Engine (no Flutter)
cd packages/algorun_engine && dart analyze && dart test && cd ../..

# Content validator
cd packages/algorun_content && dart analyze && dart test && cd ../..
dart run packages/algorun_content:validate assets/puzzles assets/worlds.json

# App
flutter analyze
flutter test
flutter run          # Android device/emulator
```

Do not add a TypeScript app. Do not eval generated source. Do not start MS6–13 from a MS5 request.

## Milestone 5 contract (when asked)

Implement a sandboxed, deterministic interpreter over `Program` (not `BlockGraph`).

- Input: `Program` + `Map<String, RuntimeValue>` + `RunLimits`.
- Output: `RunResult` with `ResultKind` + metrics (`ops`, `alloc`, `depth`).
- Honor `maxOps` / `maxAlloc` / `maxDepth`.
- Use `srcBlockId` for traces (`TraceSink` already exists).
- No Dart/JS `eval`. No codegen.
- `runTests` can stay stubbed until MS6 unless the user expands the request.
- Do not change the MS2 typed-port model or the MS3 editor UX.
- Do not change IR shape unless a genuine interpreter bug in lowering is found; prefer keeping MS4 goldens green.

## Milestone docs

| File | Status |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | locked |
| [`MILESTONE_1.md`](MILESTONE_1.md) | complete — skeleton + contracts |
| [`MILESTONE_2.md`](MILESTONE_2.md) | complete — typed ports + undo |
| [`MILESTONE_3.md`](MILESTONE_3.md) | complete — visual editor |
| [`MILESTONE_4.md`](MILESTONE_4.md) | complete — lowering |
| this file | MS4 handoff |
