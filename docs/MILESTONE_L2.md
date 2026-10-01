# L2 — player functions and recursion

**L2 COMPLETE.** Players write functions with blocks and CALL them,
including from inside themselves. World 12 opens as **Recursion &
Backtracking** with its first six puzzles. Built on branch `l2-recursion`
and merged into `main` with every suite green; the version before it is
tagged **`v0.2-ms15`**. Plan and step history: [`MILESTONE_L2_PLAN.md`](MILESTONE_L2_PLAN.md).

## How functions work

| Piece | Where | What |
|---|---|---|
| Declaration | puzzle JSON `functions` (`puzzles/parse.dart`) | `[{"name", "params": [{"name", "type"}], "returns"}]`; lower_snake_case names, at most 3 parameters, a name keeps one type everywhere, a parameter is never an input. The puzzle gives the signature; the player builds the body (players never invent names, as with variables since U1). |
| FUNCTION block | `blocks/functions.dart` | `FunctionSetup.ensure` puts a `fn.def` block with id `fn_<name>` for each function at the top of the program, the signature in its literals (`name`, `params` as `node:treeNode?;depth:num`, `returns`), and declares the parameters. The editor runs it on open, on load and after CLEAR PROGRAM; the content replay runs it too. A FUNCTION cannot be deleted, copied or moved; statements move in and out of it. It is not in any palette, the allowlist and block budget skip it, and block counts leave it out. |
| CALL | `fn.call`, `fn.call1`, `fn.call2`, `fn.call3` | One block per number of values passed (ports `a1`…`a3`); the literal `name` picks the function. The picker offers `CALL <name>` per function of that arity. |
| Typing | `blocks/typing.dart` | CALL's type is the function's return type, each value hole the parameter's type, and RETURN inside a FUNCTION expects the function's return type. Narrowing needed no change: a FUNCTION body starts with no facts. |
| Lowering | `ast/lower.dart` | Top-level FUNCTIONs become `FnDecl`s next to `main`; CALL becomes a `CallExpr` on the function's name. Refused in words (English and Turkish): a FUNCTION inside another block, an unknown function, a wrong number of values, a given read inside a function ("pass it in as a value"), two FUNCTIONs with one name. |
| Running | `execution/interpreter.dart` | The VM already ran named `FnDecl`s in new frames (MS5 left the path for this). Each call has its own variables; lists, maps and other collections passed in are the same object. Depth +1 per call counts against `limits.maxDepth` (`DEPTH LIMIT` verdict). A function that ends without RETURN stops the run: "FUNCTION name ended without RETURN." |
| Editor | `lib/editor/` | The FUNCTION header shows `FUNCTION name (params)`; CALL shows its function; the names bar has an `INSIDE <name>` row with the parameters; inside a FUNCTION the picker does not offer givens that are not its parameters. The brief lists FUNCTIONS YOU WRITE with types. The block reference explains FUNCTION and CALL (one entry for every CALL arity). |
| Content pipeline | `algorun_content` | Capability audit: `recursion` and `backtracking` supported. The replay starts from `FunctionSetup`, fills each FUNCTION's body and checks its signature. The validator warns about FUNCTION in a palette and about a CALL with no function of its arity. |

## World 12 — Recursion & Backtracking

Concepts `recursion`, `backtracking`; opens after Trees (`prerequisites:
tree`). Before L2 it required the concept `recursion`, which no world
taught, so it never opened (two standing validator warnings, now gone).

| Puzzle | Tier | Function | What it teaches | The trap (its reject) |
|---|---|---|---|---|
| Stack of Coins | 3 | `sum_from(stack, i)` | a list summed with no loop (no loop blocks offered) | base case at the last coin (fails on an empty stack) |
| Tree Total | 3 | `total(node)` | recursion over both branches | stopping at a missing LEFT branch |
| Exact Weight | 3 | `ways(w, i, rest)` | take or skip, decide at the end | stopping as soon as nothing is left (zero weights) |
| Even Branches | 4 | `levels(node)` | height or -1 in one pass | comparing only the root's branches |
| Change Ways | 4 | `pay(c, i, rest)` | combinations by coin index | counting every order |
| Watchtowers | 5 | `place(row, size, cols)` | place, CALL, take back (n towers, no shared column or diagonal) | never taking a tower back |

Oracles in `packages/algorun_content/lib/src/oracles/batch5.dart` (a fold,
an explicit stack, heights per node, bit masks, a DP table, permutations).
`maxDepth` is set per puzzle (32–80).

### Second batch and the finale (2026-10-01): 6 → 15 of 15

| Puzzle | Tier | Function(s) | What it teaches | The trap (its reject) |
|---|---|---|---|---|
| Digit Root | 3 | `digits(m)`, `root(m)` | two functions, one calling the other | stopping at 10 (LESS OR EQUAL) |
| Lucky Picks | 3 | `pick(low, left, rest)` | k different digits in increasing order | picking the same digit again |
| Lantern Rows | 3 (edge) | `rows(left, on)` | a BOOLEAN parameter carries state | base case at one lantern (DEPTH LIMIT on an empty row) |
| Catalogue Check | 4 | `ok(node, low, high)` | bounds passed down a search tree | comparing a node with its children only |
| Island Size | 4 | `fill(g, r, c)` | flood fill, marking with SET ELEMENT on a row | counting diagonal neighbours |
| Power Steps | 4 (budget) | `power(b, e)` | halving the exponent, the half kept in a variable | one step per exponent; the half CALLed twice (both OPERATION LIMIT) |
| Rabbit Months | 4 (budget) | `pairs(month, memo)` | memo in a map passed by reference | no memo (OPERATION LIMIT) |
| Maze Paths | 5 | `walk(g, r, c)` | mark, try four ways, unmark | never clearing a square |
| Seating Plan | 5 | `seat(table, last, used)` | orders of guests with a used list; a dead end is not a plan | a guest never stands up again |

Oracles in `oracles/batch6.dart`: a closed form (digit root), bit masks,
an off/on table, an in-order walk, BFS with a queue, `modPow`, iteration,
every simple path on an explicit stack, and a table over sets of guests
(bit masks) for Seating Plan.

Two engine fixes came out of this batch:

- **Generic names kept apart when connecting.** An empty GET ELEMENT (`T`)
  dropped into LENGTH OF (`array<T>`) was read as `T = array<T>` and
  refused, so nobody could build `LENGTH OF (grid's row r)` top-down. The
  plugged block's open type names are renamed before binding
  (`typing.dart` `_apart`; `connect_test.dart`).
- **RETURN, BREAK and CONTINUE without exceptions.** They were Dart throws,
  and a throw records the whole stack, so each RETURN deep in a recursion
  cost hundreds of microseconds. They now travel up as values (`_Flow`).
  A recursion that runs into its step budget went from 3.4 s to 0.1 s; all
  reference checks together from 21.5 s to 8.7 s. On a phone this is what
  keeps a slow recursive answer from freezing the screen.

## Tests

Engine **371** (+17, `test/functions_test.dart`: schema, setup, typing,
factorial with depth 6, tree height, depth limit, own variables per call and
a shared list, every lowering error, a missing RETURN; +4 with the second
batch: GET ELEMENT into LENGTH OF, RETURN out of nested loops, BREAK leaves
only its own loop, BREAK outside a loop). Content **86**.
Flutter **486**: `test/functions_editor_test.dart` (the FUNCTION on open,
not counted, not removable, kept by CLEAR PROGRAM; the picker inside it),
the campaign regression test builds all fifteen world 12 references tap by
tap (FUNCTION bodies included), runs, saves and restores them, and renders
each at 360 × 800. Validator `PIPELINE 134 of 134 campaign puzzle(s)
accepted` · `OK 139 puzzle(s), 5 warning(s)` (the five unlisted probes).

Checked by hand: in the browser at phone size (the brief, the FUNCTION
block, a RETURN in its body, the picker's `CALL sum_from`, no givens
inside) and on the Android emulator (Stack of Coins opens with its function;
RUN on an empty program gives WRONG ANSWER, no crash). Seating Plan in the
web build at 375 × 812: the brief, `FUNCTION seat (table, last, used)` on
one line, the INSIDE seat row, and WRONG ANSWER with both visible cases.

## Not done

- World 12 is full (15 of 15); heaps (world 9) stay blocked.
- Functions are declared by the puzzle; a player cannot add a function or
  change a signature.
- The palette chip CALL places the first function of its arity when a
  puzzle has two with the same number of values; the slot picker lists each.
