# Milestone 2

Typed block/port model and reversible graph mutations. Pure Dart in
`packages/algorun_engine`. No editor UI, no drag-drop, no lowering, no
interpreter.

## Files

Created under `packages/algorun_engine/`:

- `lib/src/blocks/ports.dart` — `PortKind` / `PortDirection` / `PortArity`,
  `PortDefinition`, `PortRef`, `Connection`, `BlockParent`, `@main`
- `lib/src/blocks/definition.dart` — `BlockRole`, `BlockDefinition`, port helpers
- `lib/src/blocks/catalog.dart` — `BlockCatalog` port layouts for every catalog id
- `lib/src/blocks/block_graph.dart` — `BlockGraph`, `BlockInstance`, slot bindings,
  JSON, detach/remove, `parentOf`
- `lib/src/blocks/typing.dart` — `GraphTyping.canConnect` (snap source of truth)
- `lib/src/blocks/structure.dart` — `GraphStructure.validate` for malformed graphs
- `lib/src/blocks/commands.dart` — `GraphHistory` + reversible commands
- `lib/src/types/parse_type.dart` — `parseValueType` extracted for graph JSON
- `test/connect_test.dart`
- `test/commands_test.dart`
- `test/graph_json_test.dart`

Modified:

- `lib/src/types/value_type.dart` — generics (`T`/`K`/`V`), `subst`, nullability
- `lib/src/puzzles/parse.dart` — re-exports `parseValueType`
- `lib/src/validation/validation_report.dart` — optional `port` field
- `lib/src/execution/unimplemented_engine.dart` — runs `GraphStructure`
- `lib/algorun_engine.dart` — exports the new modules
- `test/catalog_test.dart` — every id has a definition with ports
- `test/value_type_test.dart` — parse + accepts coverage

## Key API decisions

- **Kind first, then type.** `PortKind` is `{statement, expression, elseClause}`.
  A value never sits in a statement stack. ELSE is a real kind, not a catalog
  filter: only `ctrl.else` produces `elseClause`.
- **`GraphTyping.canConnect` is the single source of truth.** Milestone 3 must
  call this for snap previews. `ConnectCommand` already does. Failed connects
  do not push undo. `allowReparent` is reserved for live drag.
- **`GraphTyping.orient`** turns two ports into from→to when exactly one is an
  output. UI does not re-encode direction.
- **Generics unify per block.** `arr.get` with `array<T>` + `index:num` infers
  `T` from the plugged array; the output follows `T`. `array<num>` does not
  fit an `array<bool>` hole. No implicit `num`→`bool`.
- **Variables live on the graph**, not on the block. `var.set` / `var.get`
  resolve `literals['name']` against `BlockGraph.variables`.
- **Top-level stack is `@main.body`.** Same attach API as C-block bodies.
- **Canvas `x`/`y`/`collapsed` are UI-only.** JSON round-trips them; execution
  ignores them.
- **Messages are game-facing.** `"This block needs a condition."` — never
  syntax or compiler terms.

## Tests added

- Compatible: IF/WHILE bool, ARRAY.GET index num, SET matches declared type
- Incompatible: num→IF, bool→index, SET wrong type, undefined variable, input→input
- Nullable vs non-nullable (null, `node?` vs required node)
- Array generic: GET output follows element type; `array<num>` ≠ `array<bool>`
- Statement nesting: break outside loop, IF/WHILE bodies, value vs instruction
- IF/ELSE: ELSE only on IF else port; THEN and ELSE are independent stacks
- Duplicate connections, already-attached, disconnect frees the hole
- Add/remove/move, undo/redo, failed command does not push history
- JSON round trip, malformed JSON, malformed graph structure

`dart analyze`: no issues. `dart test`: 51 passed.

## How to run

From `algorun/packages/algorun_engine`:

```
dart analyze
dart test
```

Engine tests do not need Flutter.

## Known limitations

- No visual editor (MS3), no drag-drop, no AST lowering (MS4), no interpreter (MS5)
- `fn.def` / `fn.call` exist in the catalog but have no body-binding semantics yet
- Generic unification is per-block, not whole-graph Hindley–Milner
- Local hidden tests remain UI-hidden, not APK-secret
- Flutter shell still uses the MS1 unimplemented engine; it does not yet consume
  `GraphTyping`

## Confirmation

Milestone 2 is complete. Do not start Milestone 3 from this document.
