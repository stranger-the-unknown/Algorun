# Milestone 4

BlockGraph → typed Program IR. No interpreter. No editor changes.

## Files

Created under `packages/algorun_engine/`:

- `lib/src/ast/ir.dart` — typed Program / FnDecl / Stmt / Expr / LValue + JSON
- `lib/src/ast/lower.dart` — `LowerResult`, `Lowerer`, top-level `lower(graph, puzzle)`
- `test/lower_test.dart` — goldens A–J, Editor Probe, invalid graphs

Modified:

- `lib/algorun_engine.dart` — exports `ir.dart` / `lower.dart`
- `lib/src/execution/engine.dart` — `AlgorunEngine.lower`
- `lib/src/execution/unimplemented_engine.dart` — validate, then lower; run still stubbed
- `test/engine_contract_test.dart` — empty lower fails safely

## IR

Closed, typed, JSON-serializable. No callbacks. UI metadata is not represented.

- **Program** — `entry` (`main`) + `functions`
- **FnDecl** — name, params, optional return type, body, `srcBlockId`
- **Stmt** — seq, if (optional else), while, forRange, forEach, break, continue, return, assign, inc, dec, expr
- **Expr** — lit, var, binary, unary, call, index, field, null, new — each carries `ValueType` + `srcBlockId`
- **LValue** — var, index, field

Every important node keeps `srcBlockId` for later highlighting / traces.

## API

```
lower(BlockGraph graph, Puzzle puzzle) → LowerResult
```

`LowerResult.ok` is a `Program`. Failure is structured `ValidationMessage`s (game-facing copy, never compiler jargon). Never throws.

Pipeline: BlockGraph → `GraphStructure` → lower → Program. `UnimplementedEngine.lower` runs full `validate` (allowlist, budget, structure) first.

Same valid graph always yields the same JSON. Positions, collapsed, selection, and camera are ignored.

## Mapping (catalog, not puzzle ids)

| Blocks | IR |
|---|---|
| `var.set` | `AssignStmt` + `VarLValue` |
| `var.inc` / `var.dec` | `IncStmt` / `DecStmt` |
| `ctrl.if` + optional `ctrl.else` | one `IfStmt` |
| `ctrl.while` | `WhileStmt` |
| `ctrl.for_range` | `ForRangeStmt` (loop var, start, end, optional step) |
| `ctrl.foreach` | `ForEachStmt` (item var + collection) |
| `ctrl.break` / `ctrl.continue` / `ctrl.return` | matching stmts |
| `arith.*` / `cmp.*` / `logic.*` | `BinaryExpr` / `UnaryExpr` |
| `arr.get` | `IndexExpr` |
| `arr.set` | `AssignStmt` + `IndexLValue` |
| `ll.*` / `tree.*` | `FieldExpr` / `FieldLValue` |
| other catalog ops (`arr.len`, `map.get`, mutators, …) | `CallExpr` / `ExprStmt` with catalog id as callee |
| `fn.def` / `fn.call` | `unsupported` |

Variables resolve against puzzle inputs ∪ `graph.variables`. Unresolved names fail. Types reuse `ValueType` / `GraphTyping` — no second type system.

## Tests

Goldens A–J (SET, arith, IF, IF/ELSE as one node, WHILE, nested IF in WHILE, array GET, assignment src map, RETURN, Editor Probe combination). Positions do not change IR. JSON round-trip. for-range / for-each / `arr.len` catalog mapping.

Invalid: missing expr, unresolved variable, unknown block, wrong-kind nesting, illegal ELSE, unknown port, unsupported `fn.call`, type mismatch, no-throw.

## Known limitations

- No interpreter (MS5). RUN still reports unimplemented.
- `fn.def` / `fn.call` remain unsupported.
- Collection ops that are not index/field lower as catalog-id `CallExpr` for the VM.
- for-range `step` is optional in IR; an empty hole does not invent `1`.
- Generic unification is still per-block (`GraphTyping`), not Hindley–Milner.

## Confirmation

Milestone 4 is complete. Do not start Milestone 5 from this document.
