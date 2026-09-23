# Milestone L1

**L1 COMPLETE.** Language milestone: values that may be empty, and safe,
flow-sensitive narrowing. **MS11 is next** (progression + local save).

A block can now check whether a value that may be empty holds something, and
inside the branch that proved it, a variable reads as a plain value. That is
what was missing to walk a linked list, look at a tree's children, or count
with a map. There is no force-unwrap, no cast, no new type system, and the
player never sees `null`, `?`, `!` or a type annotation.

Previous milestone commits: MS8 `9b005b8`, MS9 `2be68bd`, MS10 `c192118`.

## The model

The existing `ValueType` already had a `nullable` flag; L1 uses it as is.

- **Values that may be empty.** `NEXT NODE` gives `listNode?`, `LEFT` / `RIGHT`
  give `treeNode?`, a map lookup gives `V?` — unchanged since MS2. A puzzle can
  declare a given or a pool variable with such a type (`"listNode?"`,
  `"treeNode?"`, `"num?"`), and `null` is its fixture value (an empty list is
  `null`).
- **Storing them is fine.** `child = LEFT node` into a `treeNode?` variable is a
  plain assignment.
- **Using them where a real value is needed is not.** A value that may be empty
  never fits a hole that needs a real value (a node hole, a number hole, a
  plain variable). The editor refuses the drop and lowering refuses the
  program, both with the same words:

  > This value may be empty here. Check that it is not empty first.

  (code `may_be_empty`). No compiler text, type names or Dart errors reach the
  player.
- `ValueType.asNonNullable` is the one new helper: the type a checked value
  reads as.

## New blocks

| Block | Id | Chrome | Shape |
|---|---|---|---|
| IS NOTHING | `logic.is_nothing` | LOGIC, `[value] IS NOTHING` | `T? → bool` |
| IS NOT NOTHING | `logic.is_not_nothing` | LOGIC, `[value] IS NOT NOTHING` | `T? → bool` |

They use the existing `verbObject` layout, so they render like
`[node] NEXT NODE`: a typed hole, then the label — for example
`WHILE [node] IS NOT NOTHING`. Same tiles, same 44 dp targets, same vertical
script, no text field.

Only a value that may be empty fits the hole (`treeNode?`, `listNode?`, `num?`,
a map lookup, `NEXT NODE …`). The editor and lowering refuse:

- a value that can never be empty — a number, a condition, a plain node, or a
  variable already checked at that spot: *This value is never empty here, so
  there is nothing to check.*
- NOTHING itself: *Check a value that may be empty, not NOTHING itself.*

An unfinished generic block (e.g. GET ELEMENT before its list is plugged in) is
allowed in the picker and decided once its type is known, like every other
hole. Puzzles opt in through `blocks.allow` as with any block.

There is deliberately **no** UNWRAP / CAST / FORCE / ASSERT NOT EMPTY block. A
force-unwrap would move the failure from the editor to a runtime crash, which
is exactly what L1 exists to prevent; the only way to use a value that may be
empty is to check it.

## Narrowing semantics

A variable is *narrowed* — it reads as its plain type — only where a check on
that very variable proved it holds something:

| Where | Narrowed |
|---|---|
| THEN of `IF x IS NOT NOTHING` | `x` |
| ELSE of `IF x IS NOTHING` | `x` |
| body of `WHILE x IS NOT NOTHING` | `x`, until the body writes `x` |
| right side of `A AND B` | what `A` proved |
| THEN / loop body of `A AND B` | what `A` and `B` proved |

Everything else proves nothing:

- THEN of `IS NOTHING`, ELSE of `IS NOT NOTHING` (no "empty-only" type is
  invented);
- OR, NOT, `EQUAL NOTHING` / `NOT EQUAL NOTHING` (they still compare; they do
  not narrow);
- a check on anything but a plain variable: `LEFT x IS NOT NOTHING` says
  nothing about a later `LEFT x` — no aliasing, no symbolic reasoning.

**Branch-local.** A fact never outlives the IF or loop that proved it: after
the IF, `x` may be empty again. Nested checks refine the flow they sit in:

```
x: treeNode?
IF x IS NOT NOTHING           ── x: treeNode
  y = LEFT x                  ── y: treeNode?
  IF y IS NOT NOTHING         ── x: treeNode, y: treeNode
  (after inner IF)            ── x: treeNode, y: treeNode?
(after outer IF)              ── x: treeNode?
```

**Writing a variable ends its narrowing.** SET, INCREMENT, DECREMENT, SWAP,
COPY and a FOR / FOR EACH counter write a variable; from that statement on, in the same
flow, it reads as declared again. The new value is not inspected (no
"assignment narrowing"): check it again.

**Loops.**

- `WHILE node IS NOT NOTHING`: the body sees `node` as a real node until it
  writes `node`; `node = NEXT NODE node` makes it "may be empty" again for the
  rest of that pass, and the condition checks it before the next pass. After
  the loop, `node` may be empty.
- A loop keeps a fact from *outside* (an enclosing IF) only if nothing in the
  loop writes that variable — so the second iteration is exactly as safe as
  the first. The WHILE condition sees the same facts as the start of the body
  before the check.
- After any loop: the facts from before it, minus every variable the loop
  writes.

This is sound without any runtime help: a narrowed read is only ever of a
variable that no statement could have changed since the check ran. The runtime
still guards: reading a field of NOTHING is a runtime error, as before.

### One implementation

`packages/algorun_engine/lib/src/blocks/narrowing.dart` — `Narrowing.of(graph)`
walks the program once (cached per graph value) and records, for every block,
which variables are narrowed where it is evaluated. It is the only place the
rules live:

- `GraphTyping` reads it: a GET's output type (`resolveOutput`) and a GET being
  dropped (`canConnect`, `compatiblePlacements`) are typed *at the hole it goes
  into*. So the picker offers `node` for `NEXT NODE` inside
  `WHILE node IS NOT NOTHING`, and not outside it.
- The lowerer reads it: `VarExpr` of a narrowed variable carries the plain
  type, and every hole check (including SET, SWAP and COPY) uses it.

The phone and RUN therefore always agree. Because the editor only checks the
drop being made, an edit elsewhere can invalidate an earlier drop (e.g.
inserting `node = NEXT NODE node` above a read); lowering catches it before
anything runs, and RUN shows the same sentence with the block to fix.

## IR and interpreter

- IR: `UnaryOp.isNothing` and `UnaryOp.isNotNothing`, **appended** to the enum.
  IR JSON names operators, so every existing program reads unchanged. No
  narrowing metadata is stored in the IR and no editor logic enters it; a
  narrowed read is just a `VarExpr` with the plain type.
- Interpreter: `UnaryExpr` evaluates its value and returns `BoolValue(value is
  NilValue)` (or the negation). It never errors, whatever it is given. Cost is
  the usual one operation per executed block: `RETURN x IS NOTHING` is 3
  operations for NOTHING and for a node alike. The interpreter does no static
  typing; the operation model is unchanged (all recorded reference metrics
  match).

## Assignment rules

| Statement | Rule |
|---|---|
| SET `x` TO value | value must fit `x`'s declared type; a value that may be empty fits only a variable that may be empty, unless it is a narrowed variable |
| COPY / SWAP | same rule in both directions (L1 added the check these blocks were missing; neither is reachable from the editor) |
| SET NEXT node TO next | `node` must be a real node (narrowed is fine), `next` may be empty or NOTHING |

## What this makes expressible

```
count = 0; node = head
WHILE node IS NOT NOTHING
  count = count + 1
  node = NEXT NODE node
RETURN count
```

- linked lists: walk, count, sum, search (`WHILE node IS NOT NOTHING AND …`),
  unlink with SET NEXT through a checked variable;
- trees: look at LEFT / RIGHT, check, then read or keep walking one path
  (e.g. down the left spine) — iteratively, with no recursion;
- maps: `c = GET counts[key]; IF c IS NOT NOTHING …` — counting maps.

Tree BFS is expressible with the existing queue blocks: a `queue<treeNode>`,
`node: treeNode` for what DEQUEUE gives, `child: treeNode?` for LEFT / RIGHT,
and `IF child IS NOT NOTHING` before ENQUEUE (proven by an engine test; no
puzzle allows it yet).

## Probes

Two unlisted, bundled probes in `assets/puzzles/world_01/` (not campaign
puzzles; no world lists them), each with a reference solution in
`content/references/world_01/` that the content validator replays in the
editor, lowers and runs:

- `l1_list_probe` (Chain Probe): count the links of a `listNode?`, including
  the empty chain — `WHILE node IS NOT NOTHING … node = NEXT NODE node`.
  Recorded cost 109 operations (9 + 10 per link, ten links).
- `l1_tree_probe` (Branch Probe): LEFT of the root, `IS NOTHING` → 0, ELSE read
  its value. Recorded cost 9 operations.

## Compatibility

- Every existing BlockGraph, puzzle and reference loads and behaves exactly as
  before; the five reference costs are unchanged. No existing block's meaning
  changed. The only new refusals are for programs that would put a value that
  may be empty where a real one is needed — which could already only fail.
- The new blocks serialize as ordinary block instances (id + catalog id +
  slots); BlockGraph and IR JSON round-trip deterministically.
- The one wording change: a value that may be empty in a hole that needs a
  real one now gets the sentence above (code `may_be_empty`) instead of the
  generic "This piece does not fit here."

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **341 passed** (297 + 44) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **46 passed** (37 + 9) |
| Content validator (assets + worlds + references) | `OK 9 puzzle(s), 6 warning(s)` + 7 INFO lines |
| Flutter `analyze` | no issues |
| Flutter `test` | **50 passed** (44 + 6) |

Engine (`test/nullable_test.dart`): a variable that may be empty; the plain
variable refusal (lowering and editor, same words); narrowing in THEN; the
unchecked read refused; nullable again after the IF; IS NOTHING narrows ELSE
only; ELSE of IS NOT NOTHING not narrowed; nested narrowing with the types the
editor sees at each spot; two variables; AND; OR / NOT / EQUAL NOTHING do not
narrow; no aliasing of `LEFT x`; wrong types for the check (number, condition,
NOTHING, plain node, an already-checked variable); malformed checks; an
unknown variable; writes end narrowing (SET, loop writes vs outer checks, WHILE
reassignment, after the loop, FOR, COPY / SWAP); runtime IS NOTHING / IS NOT
NOTHING on NOTHING and on a node; a number is not NOTHING; one-operation cost,
identical across runs; IR JSON round trip runs the same; tree LEFT / RIGHT;
tree breadth-first with a queue of nodes;
linked list NEXT NODE and SET NEXT; map lookup; the WHILE walk; the picker;
chrome wording; BlockGraph JSON round trip.

Content (`test/nullable_probe_test.dart`): both probes replay in the editor,
validate, lower and pass every case; the checker passes them with their
recorded cost; they are unlisted; the chain probe handles the empty chain; a
loop checking the wrong way and a read in the wrong arm are refused by replay,
lowering and the checker with the game's sentence.

App (`test/nullable_editor_test.dart`): the chain walk built tap by tap and
solved by RUN; the picker offers `node` for NEXT NODE only inside the check;
the check's hole lists only values that may be empty; a step moved above a
read is caught at RUN with the sentence and the block; the script shows
`IS NOT NOTHING` with no ids, `?`, `null` or text fields; the condition picker
offers both checks.

## Files

Created:

- `packages/algorun_engine/lib/src/blocks/narrowing.dart` — `Narrowing`
- `packages/algorun_engine/test/nullable_test.dart` — 44 tests
- `packages/algorun_content/test/nullable_probe_test.dart` — 9 tests
- `test/nullable_editor_test.dart` — 6 tests
- `assets/puzzles/world_01/l1_list_probe.json`, `assets/puzzles/world_01/l1_tree_probe.json`
- `content/references/world_01/l1_list_probe.json`, `content/references/world_01/l1_tree_probe.json`
- `docs/MILESTONE_L1.md`

Modified:

- engine: `types/value_type.dart` (`asNonNullable`), `blocks/catalog.dart`
  (two ids and definitions), `blocks/chrome.dart` (two labels),
  `blocks/typing.dart` (narrowed GET types, `may_be_empty`, the check's hole
  rule), `ast/lower.dart` (narrowed reads, `may_be_empty`, the two checks,
  SWAP / COPY types), `ast/ir.dart` (two appended `UnaryOp`s),
  `execution/interpreter.dart` (the two ops)
- content: `test/content_validator_test.dart` (9 puzzles)
- docs: `PROJECT_STATE.md`, `README.md`

## Known limitations

- No narrowing through OR or NOT, and none after an IF whose THEN always
  returns / breaks (`IF x IS NOTHING: RETURN 0` does not narrow what follows —
  use IF / ELSE). Both are deliberate; they need path reasoning L1 avoids.
- Assigning a real node to a variable that may be empty does not narrow it;
  check it again.
- Only plain variables are narrowed; a check on `LEFT x` or `GET counts[key]`
  itself is a real check but proves nothing for later reads.
- The editor checks each drop where it is made; an edit elsewhere can
  invalidate it, which lowering reports before RUN (not highlighted live).
- Renaming a placed GET (`SetLiteralsCommand`) is not type-checked by the
  editor, as before L1; lowering still refuses the result.
- RETURN is not checked against the puzzle's output type (unchanged): returning
  a value that may be empty for a `num` puzzle lowers, and NOTHING is graded as
  a wrong answer.
- Recursion and player-defined functions are still unsupported, so tree
  traversal beyond one path needs a queue or stack of nodes.
- EQUAL between a number and a number that may be empty is still refused by
  the generic `T, T` rule.

## Confirmation

Language milestone L1 is complete. Do not start Milestone 11 from this
document.
