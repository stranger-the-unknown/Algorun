# Milestone 7

Puzzle schema hardening. The content contract is now closed, typed and
checked before anything reaches gameplay. No new puzzles, no editor changes,
no scoring.

Previous milestone commits: MS5 `06e2037c5d4841a33d69763d2385e0a8f834dc9c`,
MS6 `39956f967f8102f747be94bc3ad9de4c0703c674`.

## Files

Created under `packages/algorun_engine/`:

- `lib/src/runtime/value_json.dart` — canonical fixture format: `valueFromJson`, `valueToJson`, `FixtureFormatException`, `FixtureLimits`, `fixtureTypeProblem`, `fixtureTags`
- `test/value_json_test.dart` — 40 tests: round trips for every value, format errors, typed decoding, limits, unencodable values
- `test/puzzle_schema_test.dart` — 37 tests: the closed schema, fixtures, validators, worlds manifest
- `test/floor_divide_test.dart` — 14 tests: FLOOR DIVIDE from catalog to a graded puzzle

Modified in the engine:

- `lib/src/puzzles/parse.dart` — rewritten as the closed schema. Collects every issue with a JSON path. `readPuzzleJson` / `readWorldsJson` never throw; `parsePuzzleJson` / `parseWorldsJson` throw `SchemaException`
- `lib/src/puzzles/puzzle.dart` — `TestCase.input` / `output` are decoded `RuntimeValue`s; `Puzzle.outputValidator` is a `ValidatorId`; `Puzzle.meta`
- `lib/src/runtime/runtime_value.dart` — the old untagged `valueFromJson` is gone (one conversion path)
- `lib/src/runner/validators.dart` — `validatorAccepts` / `validatorNeeds`; `treeEqual` compares real trees only
- `lib/src/runner/test_runner.dart` — consumes decoded fixtures; shows canonical JSON for visible cases
- `lib/src/blocks/catalog.dart`, `lib/src/blocks/chrome.dart` — `arith.floor_div` / FLOOR DIVIDE
- `lib/src/ast/ir.dart`, `lib/src/ast/lower.dart` — `BinaryOp.floorDiv`
- `lib/src/execution/interpreter.dart` — floor division
- `lib/algorun_engine.dart` — exports `value_json.dart`
- `test/lower_test.dart`, `test/interpreter_test.dart`, `test/test_runner_test.dart` — test puzzles are now valid content (fixtures match their io; tagged tree; unknown validator is a schema error)

Content package (`packages/algorun_content/`):

- `lib/src/content_validator.dart` — rewritten on top of the engine schema; adds whole-set checks
- `bin/validate.dart` — deterministic output, `OK` / `FAILED` summary, skips a manifest kept next to the puzzles
- `test/content_validator_test.dart` — 16 tests, including the real assets and the CLI on temporary malformed files

App:

- `test/widget_test.dart` — the shipped contract probe loads through the hardened schema and RUN solves it

No asset had to change: both shipped puzzles already pass the closed schema.

## One schema, one conversion path

```
puzzle JSON ──readPuzzleJson──▶ Puzzle            (closed schema, every issue with a path)
                 │
                 └─ fixtures ──valueFromJson(type:)──▶ TestCase.input / output  (RuntimeValue)
                                                          │
                              TestRunner ─────────────────┘  (no second conversion)
                                  └─ runProgram copies input on entry (MS5), so fixtures never change
```

The game's parser *is* the schema. The content validator calls the same
`readPuzzleJson` and adds only what needs the whole file set. The game and
the tool cannot disagree about what a puzzle is.

## Puzzle schema

Unknown fields are errors at every level. Field names that look like behavior
(`generator`, `script`, `code`, `eval`, `predicate`, `expression`, …) get a
dedicated "Puzzle JSON is data only" error. The only open door is `meta`:
flat text / number / boolean values the engine never reads.

| Field | Type | Rule |
|---|---|---|
| `id` | text | **required**, `lower_snake_case` |
| `version` | whole number | ≥ 1, default 1 |
| `title` | text | **required** |
| `world` | text | **required**, `lower_snake_case` |
| `chapter` | text | `lower_snake_case` |
| `tier` | whole number | **required**, 1–5 |
| `mode` | text | **required**: `build complete repair optimize structure trace predict edge budget restricted complexity ops` |
| `concepts`, `prerequisites` | list of text | `lower_snake_case`, no repeats |
| `story` | text | **required** |
| `io.inputs[]` | `{name, type}` | **required** list (may be empty); names unique, start lowercase; type must have a fixture form |
| `io.output` | `{type, order?}` | **required**; `order` is `exact` (default) or `any` |
| `constraints` | `{n: {min, max}, notes}` | whole numbers ≥ 0, `min ≤ max` |
| `blocks.allow` | list of block ids | **required**, non-empty, known ids, no repeats |
| `blocks.forbid` | list of block ids | known ids, not also allowed |
| `blocks.maxBlocks` | whole number | 1–500 |
| `limits.maxOps` | whole number | **required**, 1–10,000,000 |
| `limits.maxDepth` | whole number | 1–10,000, default 256 |
| `limits.maxAlloc` | whole number | 1–1,000,000, default 10,000 |
| `limits.notes` | text | |
| `scoring` | `{blockBudget, hintPenalty}` | 1–500; true/false |
| `hints`, `edgeCases` | list of text | |
| `validators.output` | validator name | default `equal`; must fit `io.output` |
| `fixtures.visible[]`, `fixtures.hidden[]` | `{id, in, out}` | **required**, each non-empty; ids unique across both; `in` has exactly the declared inputs; `out` required (`null` allowed only for a nullable output) |
| `verdictSource` | text | `local` (default) or `remote` |
| `variables.pool[]` | `{name, type}` | names unique, not an input, type not `void` |
| `meta` | object | flat text / number / boolean only |

Types that have a fixture form: `num`, `bool`, `str`, `null`, `array<T>`,
`map<K,V>`, `set<T>`, `stack<T>`, `queue<T>`, `deque<T>`, `listNode`,
`treeNode`, `graph`, each optionally `?`. Set items and map keys must be
`num`, `str` or `bool`. `void`, `heap` and `pair` have no fixture form and are
rejected in `io`.

The worlds manifest is closed the same way: `{worlds: [{id, title, index,
concepts, prerequisites, puzzles}]}`, unique ids, unique indexes, and no puzzle
listed by two worlds.

## Structured fixture format

Plain JSON where it cannot be misread; every JSON object is tagged with
`"type"`. Nothing is guessed from an object's shape.

| JSON | Runtime value |
|---|---|
| `null` | nothing (`NilValue`) |
| `3`, `-2.5` | `num` (finite) |
| `true` | `bool` |
| `"abc"` | `str` |
| `[1, 2, 3]` | `array` |
| `{"type": "map", "entries": [["a", 1], ["b", 2]]}` | `map` — entry order kept; keys num / str / bool, unique |
| `{"type": "set", "items": [1, 2]}` | `set` — items num / str / bool, unique, order kept |
| `{"type": "stack", "items": [1, 2, 3]}` | `stack` — bottom → top |
| `{"type": "queue", "items": [1, 2, 3]}` | `queue` — front → back |
| `{"type": "deque", "items": [1, 2, 3]}` | `deque` — front → back |
| `{"type": "listNode", "values": [1, 2, 3]}` | linked list head. Non-empty; the empty list is `null` |
| `{"type": "listNode", "values": [3, 2, 0, -4], "cycleTo": 1}` | the last node links back to index 1 |
| `{"type": "treeNode", "value": 2, "left": {…}, "right": null}` | tree; `left` / `right` may be omitted (= null) |
| `{"type": "graph", "nodes": [{"id": 0, "neighbors": [1]}, …], "visited": [0]}` | adjacency list |

Graphs: node ids are numbers and unique; every neighbor and every `visited`
entry must name an existing node; neighbor order is kept (it decides BFS / DFS
order); cycles, self-loops and repeated edges are legal. Edges are directed —
list both directions for an undirected graph. `visited` is optional and only
needed when a puzzle starts from a partly-marked graph. Graph nodes carry no
values: the runtime graph has none.

Canonical output (`valueToJson`) always writes tree children and graph
`neighbors`, writes `cycleTo` only for a cyclic list, writes `visited` only
when non-empty and sorted ascending. `valueFromJson(valueToJson(v))` equals
`v`; `valueToJson(valueFromJson(j))` is the canonical spelling of `j`.

With a declared type, decoding checks the value against it (including
nullability and element types) and containers carry the declared element
types. A plain array is never accepted where a set, stack or queue is
declared.

Limits (`FixtureLimits.standard`): at most 10,000 values and 1,000 levels of
nesting per fixture value — a skewed tree of hundreds of nodes fits, a
pathological file does not.

Every failure is a `FixtureFormatException` with a path into the value
(`$.nodes[0].neighbors[0]`); inside a puzzle it becomes a schema issue at
`fixtures.visible[0].in.g.nodes[0].neighbors[0]`.

## Integer division

Decision: **DIVIDE keeps its meaning; FLOOR DIVIDE is a separate block.**

| | |
|---|---|
| Catalog id | `arith.floor_div` |
| Label | FLOOR DIVIDE (MATH, infix, next to DIVIDE and REMAINDER) |
| Ports | `left: num`, `right: num` → `num` |
| IR | `BinaryExpr(BinaryOp.floorDiv)` — appended to the closed operator set; existing IR JSON is unchanged |
| Result | the largest whole number not above `left / right` |
| Examples | `7 → 3` (÷2), `8 → 4`, `1 → 0` (÷3), `7.5 → 3` (÷2), `-7 → -4` (÷2), `7 → -4` (÷-2), `-7 → 3` (÷-2) |
| Zero | runtime error "You cannot divide by zero." on that block |
| Cost | one op, like every block |

The result is always a whole number, so it is a valid list position and loop
bound: `nums[(0 + 3) FLOOR DIVIDE 2]` works where the DIVIDE version fails with
"A position has to be a whole number." Whole operands use exact integer
arithmetic; other operands floor the real quotient. Negative numbers exist in
the language, so the rule is spelled out: rounding is toward minus infinity,
not toward zero.

## Validator registry

Closed, by name only. Each validator declares which outputs it can grade;
a mismatch is a schema error, not a runtime surprise.

| Validator | Grades | Output must be |
|---|---|---|
| `equal` | strict, shape included | anything |
| `listEqualByValue` | ordered values across sequence shapes | array, stack, queue, deque or listNode |
| `unorderedArray` | order-free, repeats count | array, set, stack, queue, deque or listNode |
| `setEqual` | order-free, repeats ignored | array or set |
| `unorderedPairs` | order-free outside and inside each pair | an array of arrays |
| `treeEqual` | same values in the same shape | treeNode |

`io.output.order: "any"` requires `unorderedArray`, `setEqual` or
`unorderedPairs`.

## Content validator

`dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json`

Errors (exit 1):

- every schema rule above, per file, with a JSON path
- duplicate puzzle ids across files
- a file not at `<world>/<id>.json`, which is where the game loads it from
- a world listing a puzzle that does not exist or failed the schema
- a puzzle whose `world` is not in the manifest, or that another world lists
- a malformed worlds manifest

Warnings (advice):

- no hints
- `fn.def` / `fn.call` allowed (hidden from the editor, cannot run)
- the allowlist is the whole catalog
- a puzzle no world lists
- a prerequisite no world teaches

Files are checked in path order, so the same set always gives the same report.
The shipped assets pass with two warnings: worlds 12 and 13 require
`recursion`, which no world teaches yet. That is a content gap for later, not
an error.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **245 passed** (154 + 91) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **16 passed** (replaces the 3 MS1 tests) |
| Content validator over `assets/` | `OK 2 puzzle(s), 2 warning(s)` |
| Flutter `analyze` | no issues |
| Flutter `test` | **14 passed** (13 + 1) |

## Known limitations

- **No reference solutions.** The validator proves a puzzle is well-formed and
  gradable, not that it is solvable within its allowlist and `maxOps`. That
  needs a reference `BlockGraph` in the schema and belongs with real content
  (MS8).
- **No random generation.** No puzzle declares a generator, so none was
  invented. `TestRunner.runCases` takes plain `TestCase` data; a future
  generator must produce exactly that, from a deterministic seed, within
  `FixtureLimits`.
- **Graph nodes have no values** because the runtime graph has none.
- `heap` and `pair` have no fixture form (and no runtime values or blocks).
- A graph whose program marked a node it does not have cannot be written back
  as canonical JSON (`valueToJson` refuses cleanly); results fall back to the
  display form.
- `io.output.order` is checked for consistency with the validator but the
  runner still decides only by the validator.
- `constraints.n` is recorded but not checked against fixture sizes: it does
  not say which input it measures.
- `ARCHITECTURE.md` still spells the validator command as
  `dart run algorun_content:validate`; the working form is the one above.

## Confirmation

Milestone 7 is complete. Do not start Milestone 8 from this document.
