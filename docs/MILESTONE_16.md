# Milestone 16 — content batch 4

Content only, written with the blocks the game has today. No engine, editor
or screen code changed. No shipped puzzle was edited, so no `version` bump.
Unlock rules are unchanged, and no new world, concept word or asset folder
was added.

**Status: PARTS 1 and 2 of 3 written in this file so far.** (Part 3's section
is added by its commit.)

Branch `claude/ms16-content-be9897`, on top of `main` = `4fbbfed`.

## What the batch is for

The freeze of 2026-10-02 left ten worlds well under their targets and only
two tier 5 puzzles outside Heaps and Recursion. Earlier batches also showed
what cheap content looks like: visible cases that teach nothing, puzzles a
constant answers, stories that disagree with their cases, oracles that mirror
the reference. This batch was written against that list:

- every puzzle has an **oracle that reads the definition** (every pair, every
  stretch, every arrangement, minute by minute), never the reference's
  technique;
- every puzzle has at least one **reject that passes the visible cases** and
  fails hidden ones, and every timed puzzle a correct-but-slow baseline;
- the generator kit refuses a case list that a lazy answer satisfies: one of
  the inputs, its length, sum, maximum, minimum, first or last element, the
  input list itself or reversed; a yes/no puzzle needs three cases of each
  answer; visible answers must differ;
- budgets were set so that a **second honest solution still passes** where one
  exists (see the per-puzzle notes), and a puzzle whose difficulty is its
  edge cases is not also a race;
- tiers 3–4 carry the batch, with real tier 5 puzzles added;
- modes other than `build` are used where the puzzle really is one.

## Part 1 — Arrays, Hash Maps, Two Pointers (12 puzzles, 149 → 161)

| World | Puzzle (id) | Tier | Mode / class | Pattern | The idea in one sentence |
|---|---|---|---|---|---|
| 02 Arrays | The Turned Belt (`turned_belt`) | 3 | budget / budget | `rotated_sorted_minimum` | Binary search for the smallest number in a sorted list that was turned, comparing the middle with the last plate. |
| 02 Arrays | Coats of Paint (`fence_coats`) | 4 | budget / budget | `difference_marks_then_running_total` | Mark each painting shift at its start and just past its end, then one running total gives every board. |
| 02 Arrays | Cheap Seats (`cheap_seats`) | 4 | optimize / optimization | `staircase_count_sorted_grid` | In a grid sorted along rows and columns, a staircase walk from the end of the first row counts the affordable seats. |
| 02 Arrays | Tomorrow's Set List (`next_lineup`) | 4 | edge / correctness | `next_arrangement_in_place` | The next arrangement in dictionary order, in place: pivot from the right, swap with the rightmost bigger, reverse the tail. |
| 03 Hash Maps | Level Score (`level_score`) | 4 | build / budget | `longest_run_between_equal_leads` | The longest run with as many 1s as 0s is the widest gap between two equal running leads; a map keeps each lead's first position. |
| 03 Hash Maps | The Spy's Cipher (`spy_cipher`) | 3 | edge / correctness | `two_way_mapping_check` | Two messages fit one cipher only if a map holds in both directions. |
| 03 Hash Maps | Four Shelves (`four_shelves`) | 4 | budget / budget | `pair_totals_meet_in_the_middle` | Count lunches of four items by counting the totals of the first two shelves in a map and looking up the rest. |
| 03 Hash Maps | One Straight Cut (`plank_wall`) | 4 | build / budget | `most_shared_running_total` | The cut that saws the fewest planks runs where the most rows share a joint, and a joint is a running total. |
| 04 Two Pointers | After the Rain (`after_rain`) | 5 | restricted / restricted | `fill_from_the_lower_end` | Water held between towers with two marks and two running maxima, in 16 memory cells. |
| 04 Two Pointers | Rod Triangles (`rod_triangles`) | 4 | budget / budget | `count_pairs_above_fixed_longest` | For each longest rod, two marks count all pairs before it that make a triangle at once. |
| 04 Two Pointers | Shared Watch (`shared_watch`) | 4 | build / budget | `two_interval_lists_shared_time` | Walk two sorted lists of watches together and always move on from the watch that ends first. |
| 04 Two Pointers | Far from Zero (`far_from_zero`) | 3 | build / budget | `merge_inward_by_distance` | The farthest reading from zero is always at one end of a sorted log, so two marks build the list in one walk. |

Rejects (each passes the visible cases and ends in the verdict shown):

| Puzzle | Rejects |
|---|---|
| `turned_belt` | looks at every plate (operationLimit); compares the middle plate with the first plate (wrongAnswer on a belt that never turned) |
| `fence_coats` | paints board by board (operationLimit); no bounds check past the last board (runtimeError) |
| `cheap_seats` | looks at every seat (operationLimit) |
| `next_lineup` | strict comparisons that stall on equal numbers (wrongAnswer); no wrap after the last order (wrongAnswer) |
| `level_score` | every run from every start (operationLimit); forgets the lead of 0 before the first goal (wrongAnswer) |
| `spy_cipher` | a map in one direction only (wrongAnswer); compares the number of different values on each side (wrongAnswer) |
| `four_shelves` | four nested loops (operationLimit); a set of totals instead of counts (wrongAnswer) |
| `plank_wall` | tries every place across the wall (operationLimit); counts only each row's first joint (wrongAnswer) |
| `after_rain` | two lists of running maxima (memoryLimit); looks both ways from every tower (operationLimit) |
| `rod_triangles` | every set of three (operationLimit); GREATER OR EQUAL, which counts flat triples (wrongAnswer) |
| `shared_watch` | every watch against every watch (operationLimit); moves on from the watch that started first (wrongAnswer) |
| `far_from_zero` | searches the whole log for every entry (operationLimit) |

Budget notes:

- `cheap_seats`: `maxOps` 16 000 is set by hand, not at twice the reference.
  A binary search in every row is a fair second solution; it was built and
  run against the fixtures (it passes) and then removed again. The big halls
  are wide and shallow (30 × 300, 40 × 240) so that this stays true.
- `next_lineup`: `maxOps` 30 000 by hand (the reference needs 1 872). The
  puzzle is about equal numbers and the wrap-round, not speed.
- `rod_triangles`: `maxOps` 700 000 by hand (the reference needs 127 212) so
  that a binary search for every pair fits (estimated at about 560 000, not
  built); every set of three still needs more than three budgets.
- `after_rain`: `maxAlloc` 16, so the memory-hungry reject can pass the two
  visible cases (5 and 6 towers) and fails on every long street.
- `spy_cipher` is mode `edge` but its story states the operation budget,
  because the 300-number cases turn away comparing every pair of positions.

## Part 2 — Trees, Graphs, Greedy, Sliding Window (12 puzzles, 161 → 173)

| World | Puzzle (id) | Tier | Mode / class | Pattern | The idea in one sentence |
|---|---|---|---|---|---|
| 08 Trees | Shared Ancestor (`shared_ancestor`) | 3 | restricted / restricted | `bst_split_point_descent` | In a search tree, walk down from the root to the node where the two labels part; no stack, 8 memory cells. |
| 08 Trees | Full Rows (`full_rows`) | 4 | edge / correctness | `bfs_no_node_after_gap` | A tree is filled row by row exactly when a breadth-first walk never meets a node after an empty place. |
| 08 Trees | Longest Crawl (`longest_crawl`) | 5 | build / correctness | `postorder_depths_longest_path` | The longest path between any two nodes without recursion: two stacks give children before parents, a map keeps depths by label. |
| 10 Graphs | Two Buttons (`lift_buttons`) | 4 | build / correctness | `bfs_over_generated_states` | Fewest presses of an up and a down button: BFS over floors the program works out itself, with no graph given. |
| 10 Graphs | Breaking News (`news_towns`) | 4 | build / correctness | `count_sources_of_one_way_network` | In a one-way network with no way back, the towns that must be told are exactly those with no incoming road. |
| 10 Graphs | Shortest Ring (`shortest_ring`) | 5 | build / correctness | `bfs_from_every_node_shortest_cycle` | The shortest cycle of a two-way network: BFS from every node with its own distance and parent lists. |
| 11 Greedy | Drum Line (`drum_line`) | 4 | budget / budget | `fewest_handovers_by_reach_layers` | Fewest hand-overs along a line by tracking how far each number of hand-overs can reach; -1 when stuck. |
| 11 Greedy | Set Breaks (`playlist_cuts`) | 4 | build / correctness | `cut_at_farthest_last_occurrence` | Cut a list into the most parts that share no value by closing a part at the farthest last occurrence met so far. |
| 11 Greedy | Sign Flips (`sign_flips`) | 3 | edge / correctness | `flip_losses_then_parity_on_smallest` | Exactly k sign flips on a sorted ledger: losses first, and an odd remainder costs the entry closest to zero. |
| 05 Sliding Window | The Parts Aisle (`parts_aisle`) | 5 | budget / budget | `shortest_window_covering_multiset` | The shortest stretch that covers a list with repeats: a need-count map and a "still missing" counter. |
| 05 Sliding Window | Both Ends (`both_ends`) | 4 | optimize / optimization | `slide_split_between_two_ends` | Taking k items from the two ends leaves one free number, how many come from the left; slide that split. |
| 05 Sliding Window | Night Coffee (`night_coffee`) | 3 | build / correctness | `fixed_window_best_gain_over_base` | What is counted anyway plus the best fixed window of what would otherwise be lost. |

Rejects (each passes the visible cases and ends in the verdict shown):

| Puzzle | Rejects |
|---|---|
| `shared_ancestor` | writes down the path to one member (memoryLimit); takes the first member for the smaller one (wrongAnswer) |
| `full_rows` | only refuses a right child beside an empty left (wrongAnswer); resets the "gap seen" flag at every row (wrongAnswer) |
| `longest_crawl` | measures only at the root (wrongAnswer) |
| `lift_buttons` | always presses toward the goal (wrongAnswer); a stack instead of a queue (wrongAnswer) |
| `news_towns` | counts towns that no road leaves (wrongAnswer); tells the lowest-numbered unreached town again and again (wrongAnswer) |
| `shortest_ring` | searches from village 0 only (wrongAnswer) |
| `drum_line` | the quadratic table (operationLimit); always hands to the farthest drummer in reach (wrongAnswer) |
| `playlist_cuts` | ends a set at the last track of its opening style (wrongAnswer) |
| `sign_flips` | forgets the flips left over (wrongAnswer); spends the odd flip on the first entry that was never negative (wrongAnswer) |
| `parts_aisle` | restarts from every bin (operationLimit); treats a kind listed twice as needed once (wrongAnswer) |
| `both_ends` | every split summed from scratch (operationLimit); takes the fuller end each time (wrongAnswer) |
| `night_coffee` | the coffee on the k busiest nights, wherever they are (wrongAnswer) |

Notes:

- `both_ends` is reported by the validator as *related* to Rush Hour (the
  same program shape, 89 % block similarity; a near duplicate starts at
  90 % with the same concepts). To the player it is a different puzzle (the
  step is seeing that only one number is free), but mechanically it is a
  fixed window. Its concepts are `sliding_window, two_pointers`.
- Fixed limits: `drum_line` `maxAlloc` 4 000 and `parts_aisle` `maxAlloc`
  20 000, so their slow baselines reach the operation limit before the memory
  limit; `longest_crawl` (80 000 operations, 2 000 cells) and `shortest_ring`
  (300 000 operations, 20 000 cells) are roomy on purpose: they are
  correctness puzzles with several honest approaches.
- `parts_aisle` declares the prerequisites `arrays, hash_map`, as Market
  Variety does. `longest_crawl` (world 08) uses a map: its concepts list
  `hash_map`, but it declares no prerequisite, so nothing in the unlock order
  changes.
- `news_towns` is tier 4 on a 40-block reference: the tier rests on the
  insight and on the two traps.
- `lift_buttons` has three visible cases (5, 4 and -1), found by search so
  that both rejects pass them.

## Changed or dropped (part 2)

| Idea | What happened |
|---|---|
| Relay towers passing a message | Kept as Drum Line: Relay Towers (world 06) already has radio towers and Leap Reach has stones. |
| Shopping list along market stalls | Kept as The Parts Aisle: Market Variety already walks market stalls in the same world. |
| Set Breaks returning only the number of sets | Returns the list of set sizes: the count alone made the reference trivial for tier 4 and was easier to fluke. |
| Both Ends as "total minus the lightest window" | The reference slides the split instead; the other form sat even closer to Rush Hour. |
| Tree level puzzles (right-side view, deepest-row sum, level averages) | All are the level-by-level walk that Canopy Height and Widest Level already teach. |
| Count the nodes with no larger label above them | The same root-to-leaf state on a second stack as Trail Sum. |
| Fewest roads to walk through a warehouse grid, damp spreading in a cellar grid | Classic judge problems that would have been reworded rather than invented; Two Buttons covers "build the graph yourself" with an original setting. |
| Largest total with fewest interval points / covering a line with intervals | The same earliest-end reasoning as One Room. |

## Ideas dropped (part 1)

| Idea | Why it was dropped |
|---|---|
| Product of all the other values, without DIVIDE | Products outgrow the number pad's ±999 999 unless the values are nearly all 1, which makes the cases trivial. |
| Count pairs with a given difference (set, `k = 0` trap) | A retelling of Exact Gaps (world 04). |
| Any two equal values within k positions | Too close to Same-Value Span and Second Scan. |
| Count stretches whose total is a multiple of k | The same map-of-running-totals reasoning as Level Stretches. |
| Three-way partition in place (0 / 1 / 2) | Counting and rewriting solves it in two plain passes; nothing forces the pointer technique. |
| Shortest stretch in which some value already appears as often as the most frequent value of the whole list | Three maps for a tier 4 that teaches little beyond counting; kept in reserve. |
| A wrong-answer reject for `cheap_seats` and `far_from_zero` | No tempting wrong strategy passes a visible case that still shows the task (mixed signs, rows with different cut-offs); only the slow baseline is proven. |

## Tooling (not in the repository)

The generators are scratch scripts in `.content-tools/bin/` of the main
checkout (git-excluded): `kit16.dart` (the MS15 kit plus: the checkout to
write to comes from `ALGORUN_ROOT`; `maxOps` / `maxAlloc` overrides;
`optimization` and `restricted` classes; the lazy-answer and Turkish
block-label checks), `prog16.dart` (the program builder plus BREAK, NOTHING,
REMOVE KEY, SIZE), and one script per part: `ms16a.dart`, `ms16b.dart`,
`ms16c.dart`. **Do not re-run them with `--write` after a hand edit of a
generated file**; they overwrite puzzle, reference, `worlds.json` order and
the Turkish entries.
