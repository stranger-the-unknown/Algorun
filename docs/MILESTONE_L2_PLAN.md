# L2 — player functions and recursion (plan, in progress)

Branch `l2-recursion`. `main` stays at the stable tag **`v0.2-ms15`** (119
puzzles, light mode, web version, icon) until L2 is complete and every suite
passes; only then merge. The user asked for this on 2026-09-30 ("start, but
don't lose the current version"); their subscription ends around
2026-10-10, freeze 2026-10-09 / 10. If L2 is not complete by then, `main`
ships as it is and this branch waits for the next development month.

## Goal

Players define their own functions with blocks and call them, including
from inside themselves. That unblocks the capability-audit families
`recursion` and `backtracking` (world 12, target 15 puzzles) and recursive
tree puzzles. Heaps stay blocked (a separate value type).

## Where things stand

- `fn.def` (FUNCTION, a C-block with a `body`) and `fn.call` (CALL, a
  reporter) exist in `packages/algorun_engine/lib/src/blocks/catalog.dart`
  and `chrome.dart`, but `ast/lower.dart` refuses both (`_unsupported`, lines
  ~140 and ~551). No puzzle allows them.
- `limits.maxDepth` and `RunMetrics.peakDepth` already exist (MS10) — the
  natural budget for recursion depth; every puzzle so far runs at depth 1.
- Worlds 09 (heaps) and 12 (backtracking) are empty; world 12's prerequisite
  is the concept `recursion`, taught by no world (validator warning).

## Steps (each one committed and pushed on the branch, tests green)

1. **Design note** (this file): function shape, typing, scope, depth.
   Proposed: a FUNCTION block has a name, 0–3 typed parameters and a return
   type, declared like puzzle variables (no free-typed names); its body is a
   statement list; RETURN inside it returns from the function. Parameters
   and variables set inside are local (a new frame per call); the puzzle's
   inputs are not visible inside functions (pass them as arguments). CALL
   has one argument slot per parameter and the function's return type.
2. **Engine: IR and lowering** — `FunctionDef`, `CallExpr` in `ast/ir.dart`;
   lower FUNCTION blocks as separate entries (not statements of the main
   program); type-check arguments and returns; a function without a RETURN
   on some path is a validation error in words.
3. **Engine: interpreter** — call frames with their own variables; depth +1
   per call counted in `peakDepth`; `maxDepth` exceeded → `depthLimit`
   verdict (already a `ResultKind`); operations counted as today.
4. **Engine tests** — factorial, Fibonacci, tree size by recursion, mutual
   recursion refused or allowed (decide), depth limit, locals isolated,
   lists passed by reference.
5. **Save format / BlockGraph** — functions live in the same graph; check
   `entryIds` handling and editor replay (`algorun_content` L3) for
   multiple roots; bump `saveVersion` only if the stored shape changes.
6. **Editor UI** — a "Functions" area above the program with ADD FUNCTION,
   a name / parameter sheet (reuse the variable picker), CALL in the palette
   listing defined functions. Widget tests under the real theme.
7. **Content pipeline** — `content/capabilities.json`: `recursion`
   supported, `backtracking` supported; oracles and references for the first
   recursive puzzles; a new concept `recursion` taught somewhere (world 08
   or a small new chapter) so world 12 can open.
8. **Content** — first recursive puzzles (tree height, sum of a tree,
   power set count, permutations count, N-queens-style placements…) and
   Turkish text, through the unchanged 7-level pipeline.
9. **Docs, APK, merge** — `MILESTONE_L2.md`, PROJECT_STATE, then merge into
   `main` only with all suites green and an emulator pass.

## Status

- 2026-09-30: branch and tag created, this plan written.
- 2026-10-01: steps 1–9 done on the branch — engine (`85a79e8`), editor and
  pipeline (`dbc1e74`), world 12 with six puzzles (`1d8c24a`), editor polish
  (`a99ccb0`), docs; merged into `main`. Decisions taken in step 1: the
  puzzle declares each function (name, at most 3 typed parameters, return
  type) and the player writes the body; FUNCTION blocks sit at the top of the
  program; one CALL block per arity; a function sees only its parameters and
  its own variables; mutual recursion works (any FUNCTION may CALL any
  other). Details: [`MILESTONE_L2.md`](MILESTONE_L2.md).
