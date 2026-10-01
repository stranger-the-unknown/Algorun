# Milestone H — heaps (plan)

World 09 "Heaps" has been empty since MS12: the language had no heap value,
blocks or display. H adds them, then the world's puzzles. Started
2026-10-01 at the user's request ("başla"), before the 2026-10-09/10 freeze.

Safety, as in L2: the version before H is tag `v0.3-l2` on `main`; all H
work happens on branch `heaps`, one commit per step, pushed. It is merged
into `main` only when complete and green. If it is not done by the freeze,
`main` ships as it is.

## Language decisions

- One type, `heap<num>`: numbers only. Priority with a payload (Dijkstra,
  merging lists) is written by the puzzle as one number (`distance × 100 +
  stop`); pairs stay out of the language.
- Two constructors so nobody needs the negation trick: **NEW MIN HEAP** and
  **NEW MAX HEAP**. The order belongs to the value, not to the blocks.
- Blocks: **INSERT** value INTO heap (statement), **TAKE TOP** (reporter,
  removes and returns the top), **TOP** (reporter, reads it), **SIZE**,
  **IS EMPTY**. TAKE TOP / TOP on an empty heap stop with a runtime error,
  like POP on an empty stack.
- Cost: every block is one step, like map and set blocks; INSERT takes one
  memory cell and TAKE TOP frees it.
- No heap in a puzzle's inputs or output (no fixture form to read); a heap
  is shown in traces and results as its items in the order TAKE TOP would
  give them.
- Turkish: the app already says "yığın" for stack, so a heap is
  "öncelik kuyruğu".

## Steps

1. Engine: `HeapValue`, the seven blocks (catalog, chrome, lowering, VM,
   typing and hole messages, display), tests.
2. App: Block Reference entries, EN/TR terms and engine messages, palette
   and editor tests.
3. Content tooling: capability `heap` supported, generator helpers,
   oracles file.
4. World 09, first batch (8 puzzles), each with reference, reject and an
   independent oracle.
5. World 09 up to 15 if time allows.
6. Docs (`MILESTONE_H.md`, PROJECT_STATE, README), checks in the browser
   at phone size, merge into `main`.

## Status

- [x] 1 engine — `HeapValue`, seven blocks, `test/heap_test.dart` (engine 381)
- [ ] 2 app
- [ ] 3 content tooling
- [ ] 4 world 09 batch 1
- [ ] 5 world 09 batch 2
- [ ] 6 docs, checks, merge
