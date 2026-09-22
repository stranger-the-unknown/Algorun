# Milestone 5

Program IR → sandboxed, deterministic interpreter. No editor changes. No test runner.

## Files

Created under `packages/algorun_engine/`:

- `lib/src/execution/interpreter.dart` — `Interpreter`, top-level `runProgram(program, input, limits, {trace})`
- `lib/src/execution/default_engine.dart` — `DefaultEngine` (validate → lower → run)
- `test/interpreter_test.dart` — 42 tests: control flow, expressions, collections, nodes, budgets, sandbox, trace, pipeline

Modified:

- `lib/src/runtime/runtime_value.dart` — `SetValue`, `StackValue`, `QueueValue`, `DequeValue`, `ListNodeValue`, `TreeNodeValue`, `GraphValue`, `primitiveKey`
- `lib/src/runner/validators.dart` — `valuesEqual` covers the new runtime values
- `lib/algorun_engine.dart` — exports `default_engine.dart` / `interpreter.dart`
- `lib/state/providers.dart` — `engineProvider` → `DefaultEngine`
- `test/engine_contract_test.dart`, `test/lower_test.dart` — engine rename

Removed:

- `lib/src/execution/unimplemented_engine.dart` — `UnimplementedEngine` is now `DefaultEngine`. `run` is implemented, so the old name was a lie. `runTests` is still the Milestone 6 stub.

## API

```dart
RunResult runProgram(
  Program program,
  Map<String, RuntimeValue> input,
  RunLimits limits, {
  TraceSink? trace,
});
```

`AlgorunEngine.run` forwards to it. A fresh `Interpreter` runs each program, so
nothing carries between runs.

- Never throws. Every failure is a `RunResult` with a `ResultKind`, a
  game-facing `message`, and the `srcBlockId` of the block to highlight.
- `ResultKind.correct` means **ran to completion**. Comparing output against
  what a puzzle expects is the test runner's job (MS6), not the VM's.
- Output is the value of `return`, or `NilValue` when the program ends without
  one.
- The interpreter walks the IR only. It never sees a `BlockGraph`, never evals
  Dart or JS, never generates source, and never touches clock, random, or I/O.

## Determinism

Same `Program` + same input + same limits → same output **and** same metrics.

- Map and set iteration is insertion ordered.
- `for each` iterates a snapshot: appending inside the loop does not extend it.
- The `for range` counter belongs to the loop; assigning to the loop variable
  inside the body cannot change the iteration count.
- Given values are deep-copied on entry, so a run cannot mutate the fixtures
  the test runner will reuse for the next case. Copying is free.

## Budgets

Budgets are checked **before** a step is taken, so `RunMetrics` reports work
that actually happened, never the step that broke the budget.

| Budget | Counts | Over budget |
|---|---|---|
| `maxOps` | one op per executed block; a loop header costs one op per iteration | `ResultKind.operationLimit` |
| `maxAlloc` | live collection cells: container = 1, each stored element = 1, removal gives the cell back | `ResultKind.memoryLimit` |
| `maxDepth` | function frames — only recursion nests | `ResultKind.runtimeError` |
| `maxArrayLen` / `maxMapSize` | per-container growth on append / push / insert | `ResultKind.memoryLimit` |

`seq` and the statement wrapper around a call are lowering artifacts and cost
nothing, so a block never pays twice. `AND` / `OR` short-circuit, so a skipped
right side is neither evaluated nor charged.

`ResultKind.timeLimit` stays unused: wall-clock is a UI watchdog, not a grade.

## Semantics worth knowing

- Division keeps whole results whole: `8 / 2` is `2`, `7 / 2` is `3.5`. Dividing
  or taking a remainder by zero is a runtime error.
- A list position must be a whole number inside the list.
- Equality compares numbers, text, yes/no and empty by value. A list, map, set,
  node or graph is only equal to itself — no hidden O(n) compare inside one op.
- `var.swap` swaps two names; it is the one call that reads its arguments as
  names instead of values.
- `ll.*` / `tree.*` read and write node fields. Reading through an empty node
  is a runtime error ("There is nothing here."), not a crash.
- A callee the VM does not know (including `fn.call`) is
  `ResultKind.invalidProgram`, never a partial run.
- A `CallExpr` whose callee names a function in the `Program` is a real call.
  Lowering does not emit those yet; the path exists so the VM does not have to
  change when player-defined functions arrive.

## Trace

`TraceSink` receives a `TraceEvent` per executed statement: `opIndex`, `kind`
(`assign`, `if`, `while`, `forRange`, `forEach`, `inc`, `dec`, `return`), the
`blockId`, and the current names with their displayed values. Without a sink
the VM does no trace work.

## Tests

`packages/algorun_engine` — **129 passed** (86 from MS4 + 42 new + 1 split
contract test).

New coverage: for-range (up, down, zero step, loop-owned counter), for-each
(index var, snapshot), while with break / continue, if / else, inc / dec,
division rules, short-circuit, equality, list / map / set / stack / queue
round trips, out-of-range position, empty stack, swap, linked-list relink,
empty-node read, graph neighbors and marks, all four budgets, metrics, input
immutability, determinism, JSON round-trip execution, missing entry, unknown
callee, trace events, and graph → lower → run end to end.

## Known limitations

- No test runner (MS6). RUN in the app still reports unimplemented, because
  the puzzle screen calls `runTests`, not `run`.
- `valueFromJson` decodes numbers, text, yes/no, lists and maps. Fixtures for
  `listNode`, `treeNode`, `graph` and `set` need a tagged JSON form — that
  belongs to MS6 / MS7 with the schema, so the VM's node and graph paths are
  currently exercised from Dart, not from puzzle JSON.
- `heap` and `pair` have runtime types in `ValueType` but no catalog blocks and
  no runtime values yet.
- There is no integer-division or floor block, so a classic `(lo + hi) / 2`
  midpoint yields `1.5` and fails as a position. MS8 content needs either an
  `arith.floor` / `arith.div_int` block or puzzle wording that avoids it.
- `maxDepth` is enforced but stays at 1 in practice until player-defined
  functions ship.
- Allocation has no collector: a container that becomes unreachable still
  holds its cells for the rest of the run.

## Confirmation

Milestone 5 is complete. Do not start Milestone 6 from this document.
