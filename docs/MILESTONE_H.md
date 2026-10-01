# Milestone H — heaps

World 09 "Heaps" had been empty since MS12 because the language had no heap.
H adds heaps of numbers to the engine, the editor and both languages, and
fills the world with 15 puzzles. Requested by the user on 2026-10-01
("başla"), built on branch `heaps` (the version before is tag `v0.3-l2`),
merged into `main` when green. Plan and step log: `MILESTONE_H_PLAN.md`.

## The language

| Block | Kind | What it does |
|---|---|---|
| NEW MIN HEAP | reporter → `heap<num>` | an empty heap with its smallest number on top |
| NEW MAX HEAP | reporter → `heap<num>` | an empty heap with its largest number on top |
| INSERT | statement (heap, value) | puts a number in |
| TAKE TOP | reporter → num | removes and gives the top number |
| TOP | reporter → num | reads the top number |
| SIZE | reporter → num | how many numbers it holds |
| IS EMPTY | reporter → bool | TRUE when it holds nothing |

- Numbers only. A priority with a payload is one number: `pages × 1000 +
  job` (Print Shop), `cost × 1000 + square` (Cheapest Crossing); the
  stories say so. Pairs stay out of the language.
- The order belongs to the value (`HeapValue.isMax`), so the other blocks
  are shared by both kinds.
- Every block is one step; the heap takes a memory cell and so does every
  number in it. TAKE TOP / TOP on an empty heap stop with a runtime error
  ("This heap is empty.").
- A heap has no fixture form: no puzzle takes or returns one. It is shown
  in traces and results as `{"type": "heap", "order": "min", "items": [...]}`
  in the order TAKE TOP would give them.
- Turkish says **öncelik kuyruğu** (the app already says "yığın" for a
  stack): "sayı öncelik kuyruğu", "Bu öncelik kuyruğu boş."
- Block Reference: seven entries and a Heap concept card.

Engine: `HeapValue` (`runtime_value.dart`, a binary heap), `CollKind.minHeap`
/ `maxHeap`, catalog, chrome, lowering, VM, hole messages, display.

## World 09 — Heaps (15 of 15)

| Puzzle | Tier | Mode | What it teaches | The trap (its reject) |
|---|---|---|---|---|
| Top Scores | 2 | build | MAX heap, TAKE TOP k times | fewer scores than k: TAKE TOP on an empty heap |
| Halving Piles | 2 | build | the top changes as you go | halving the piles in turn |
| Ticket Order | 3 | budget | heap sort | selection sort (OPERATION LIMIT) |
| Rope Joining | 3 | build | join the two smallest, put the join back | joining in the given order |
| Last Stone | 3 | edge | smash the two largest | the pile can end empty |
| Seat Desk | 3 | build | lowest free number | a counter that never reuses a seat |
| Meeting Rooms | 3 | edge | MIN heap of end times | a meeting starting as another ends |
| Podium Place | 3 | restricted | k-th largest in k cells | a heap of everything (MEMORY LIMIT) |
| Deadline Jobs | 4 | build | keep the best jobs that fit | never giving a job up |
| Bricks and Ladders | 4 | build | ladders for the largest climbs | bricks first, then ladders |
| Print Shop | 4 | build | shortest job first, two values in one number | first come, first printed |
| Factory Codes | 4 | budget | generate in order, a set against duplicates | testing every number (OPERATION LIMIT) |
| Running Median | 5 | budget | two heaps | a sorted list (OPERATION LIMIT) |
| Fuel Stops | 5 | build | decide late, take the best passed | the smallest station passed |
| Cheapest Crossing | 5 | build | Dijkstra on a grid of tolls | right and down only |

Oracles in `packages/algorun_content/lib/src/oracles/heaps.dart` use no
heap: sorting, scanning, events in time order, a table over stops, three
pointers, relaxation until nothing improves. The capability audit marks
`heap` and `weighted_shortest_path` supported (costs live in a grid; graphs
still have no weights). Generators: `.content-tools/bin/w09.dart`,
`w09b.dart` (git-excluded).

## Tests

Engine **381** (+10, `test/heap_test.dart`: the heap in both orders against
a sort, display, every block run, an empty heap, memory, typing, a program
built from blocks). Content **86** (the example of a blocked family is now
`sorting_builtin`). Flutter **517** (+1 localization test for the heap words;
the campaign regression test builds all 15 world 09 references tap by tap,
runs, saves and restores them, and renders each at 360 × 800). Validator
`PIPELINE 149 of 149 campaign puzzle(s) accepted` · `OK 154 puzzle(s), 5
warning(s)` (the five unlisted probes).

Checked by hand in the web build at 375 × 812: "09 Heaps — 0 of 15", Top
Scores' brief and variables, the LISTS palette with all seven heap blocks,
and the heap cards in the Block Reference (EN and TR text).

## Not done

- Heaps hold numbers only; no heap of text, no pairs.
- No puzzle takes or returns a heap (no fixture form).
- Graphs still carry no edge weights; weighted shortest paths use a grid.
