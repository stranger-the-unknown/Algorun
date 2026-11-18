# Milestone 16 — content batch 4

Content only, written with the blocks the game has today. No engine, editor
or screen code changed. No shipped puzzle was edited, so no `version` bump.
Unlock rules are unchanged, and no new world, concept word or asset folder
was added.

**Status: complete.** 36 puzzles in three parts, 149 → 185 campaign puzzles.

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

## The batch at a glance

| World | Before | Added | Now / target |
|---|---|---|---|
| 02 Arrays | 13 | 4 | 17 / 30 |
| 03 Hash Maps | 10 | 4 | 14 / 25 |
| 04 Two Pointers | 8 | 4 | 12 / 20 |
| 05 Sliding Window | 9 | 3 | 12 / 20 |
| 06 Stack & Queue | 10 | 3 | 13 / 25 |
| 07 Linked Lists | 11 | 2 | 13 / 20 |
| 08 Trees | 12 | 3 | 15 / 30 |
| 10 Graphs | 15 | 3 | 18 / 30 |
| 11 Greedy | 8 | 3 | 11 / 20 |
| 13 Dynamic Programming | 10 | 4 | 14 / 30 |
| 14 Advanced | 1 | 3 | 4 / 8 |

Foundations, Heaps and Recursion were full and are unchanged.

- **Tiers of the 36:** tier 3 × 8, tier 4 × 21, tier 5 × 7 (After the Rain,
  Longest Crawl, Shortest Ring, The Parts Aisle, Two Loads of Salt, Every
  Cold Spell, The Twice-Read Clue). The campaign is now 1: 9 · 2: 43 ·
  3: 60 · 4: 58 · 5: 15.
- **Modes of the 36:** build 17 · budget 10 · edge 4 · optimize 3 ·
  restricted 2. Performance classes: correctness 17 · budget 14 ·
  optimization 3 · restricted 2 (four `build` puzzles carry a proven slow
  baseline and say so in their story: Level Score, One Straight Cut, Shared
  Watch, Far from Zero).
- **Worlds 05, 08, 10 and 13 have their first tier 5; world 14 its first
  tier 4.** Coverage gaps: 49 → 41.

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

- `cheap_seats`: `maxOps` 10 000 is set by hand, not at twice the reference
  (3 475). A binary search in every row is a fair second solution; it was
  built and run against the final fixtures (it passes) and then removed
  again. The big halls are wide and shallow (20 × 200, 30 × 150) so that
  this stays true; reading every seat needs more than two budgets.
- `next_lineup`: `maxOps` 30 000 by hand (the reference needs 1 872). The
  puzzle is about equal numbers and the wrap-round, not speed.
- `rod_triangles`: `maxOps` 450 000 by hand (the reference needs 71 852 on
  80 rods) so that a binary search for every pair fits (estimated at about
  360 000, not built); every set of three still needs more than two budgets.
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

## Part 3 — Dynamic Programming, Advanced, Stack & Queue, Linked Lists (12 puzzles, 173 → 185)

| World | Puzzle (id) | Tier | Mode / class | Pattern | The idea in one sentence |
|---|---|---|---|---|---|
| 13 Dynamic Programming | Weekly Menu (`weekly_menu`) | 3 | build / correctness | `three_running_totals_no_repeat` | Three dishes with daily costs and never the same dish twice running: three running totals, one per last dish. |
| 13 Dynamic Programming | The Shared Route (`shared_route`) | 4 | build / correctness | `common_subsequence_rows` | The longest list two diaries share in the same order, filled row by row with only the row before. |
| 13 Dynamic Programming | The Square Plot (`square_plot`) | 4 | optimize / optimization | `largest_square_min_of_three` | The largest all-fertile square: each cell is 1 plus the smallest of its three upper-left neighbours. |
| 13 Dynamic Programming | Two Loads of Salt (`two_loads`) | 5 | budget / budget | `two_deals_four_running_states` | At most two buy-then-sell deals: four running numbers, the second load's cost reduced by the first deal's gain. |
| 14 Advanced | Assembly Hours (`assembly_hours`) | 4 | build / correctness | `kahn_longest_chain_hours` | Hours for a job whose steps wait on each other: waiting counts, a queue of ready steps and the longest chain; -1 on a circle. |
| 14 Advanced | Friend Groups (`friend_groups`) | 4 | budget / budget | `union_find_groups_over_time` | The number of groups after every friendship: union-find in a list, shortening the way to a leader. |
| 14 Advanced | Festival Stage (`festival_stage`) | 4 | build / correctness | `weighted_schedule_table_search` | Non-overlapping slots for the largest total crowd: a table over requests sorted by end, and a search for the last one that ends in time. |
| 06 Stack & Queue | Every Cold Spell (`cold_spells`) | 5 | budget / budget | `stretch_minimums_by_end` | The sum of the coldest reading over every stretch, by the night a stretch ends on, with a stack of colder nights. |
| 06 Stack & Queue | The Smallest Ribbon (`smallest_ribbon`) | 4 | build / correctness | `smallest_kept_row_with_cuts` | Keep exactly `keep` beads in order so the row is smallest: a stack that pops bigger beads while cuts remain. |
| 06 Stack & Queue | The Lone Request (`lone_request`) | 3 | build / correctness | `first_single_in_stream` | After each call, the earliest song requested exactly once: a queue in first-request order and two sets. |
| 07 Linked Lists | The Twice-Read Clue (`twice_read_clue`) | 5 | budget / budget | `floyd_cycle_entry` | Where a looping chain begins to repeat: the slow and fast walkers meet, then a walker from the head meets the slow one at the loop's first card. |
| 07 Linked Lists | Two Trains, One Track (`two_trains`) | 4 | build / correctness | `merge_sorted_by_relinking` | Merge two sorted chains by relinking only, with no new node and no dummy head. |

Rejects (each passes the visible cases and ends in the verdict shown):

| Puzzle | Rejects |
|---|---|
| `weekly_menu` | each day the cheapest dish that is not yesterday's (wrongAnswer) |
| `shared_route` | takes the next place each peak appears, never looking back (wrongAnswer) |
| `square_plot` | tries every square cell by cell (operationLimit); looks above and to the left but not diagonally (wrongAnswer) |
| `two_loads` | tries every town between the two deals and scans both sides again (operationLimit); the two biggest unbroken climbs (wrongAnswer); adds up every rise, as if deals were unlimited (wrongAnswer) |
| `assembly_hours` | starts a step as soon as the first step it waits for is done (wrongAnswer) |
| `friend_groups` | renames a whole group at every friendship (operationLimit); follows the chain to the leader every time and never shortens it (operationLimit); moves only one of the two friends into the other group (wrongAnswer) |
| `festival_stage` | takes every band that fits after the last one taken (wrongAnswer) |
| `cold_spells` | goes through every stretch (operationLimit); counts a stretch once for each of its equal coldest nights (wrongAnswer) |
| `smallest_ribbon` | cuts at most one bead in front of each new bead (wrongAnswer) |
| `lone_request` | drops at most one song from the front after each call (wrongAnswer) |
| `twice_read_clue` | checks each card against all the cards before it (operationLimit); remembers the numbers on the cards in a set (wrongAnswer) |
| `two_trains` | always puts the left train's front car first (wrongAnswer) |

Notes:

- **Explicit limits on every part 3 puzzle.** The kit's default (twice the
  reference) would turn a `build` puzzle into a hidden race. Build puzzles
  get room for a plain second solution: `weekly_menu` 20 000,
  `shared_route` / `assembly_hours` / `festival_stage` / `smallest_ribbon`
  600 000, `two_trains` 300 000, `lone_request` 1 000 000 (the largest of the
  batch; Rising Line, shipped, has 1 186 500). Timed puzzles sit at about
  three times their reference.
- `two_loads` and `twice_read_clue` are **budget** puzzles: a quadratic
  solution (split and rescan; compare each card with all earlier ones)
  would otherwise pass and the tier 5 would not be honest. Each has that
  solution as a proven baseline and says so in its story.
- `friend_groups` needs the way to a leader to be shortened (or union by
  size, estimated to fit, not built): a plain parent-pointer union-find is
  a second proven slow baseline on the 1 200-camper case. Story and hint 3
  say so. Declared factor 2.
- `cold_spells`: the reference sums "stretches that end tonight", which
  equal readings cannot break; the tie trap is proven by the reject. A
  correct two-pass solution was built and fits the budget.
- `twice_read_clue`: the oracle is the fixture's own `cycleTo`, as Loop
  Detector's is.
- `square_plot`: the visible fields hold no L-shaped corner, so the
  no-diagonal reject passes them; hidden cases hold the L shapes.
- Not verified by building them: the left / right lists solution of
  `two_loads` and union by size for `friend_groups` are estimated to fit
  their budgets.

## Changed or dropped (part 3)

| Idea | What happened |
|---|---|
| Two voyages / paid talks / coldest stretches / first single / loop start | Kept with new stories and ids: `two_loads`, `festival_stage`, `cold_spells`, `lone_request`, `twice_read_clue`. |
| "Keep the `keep` smallest beads" as the reject of `smallest_ribbon` | Fails the visible cases; replaced by the IF-instead-of-WHILE mistake. |
| "Forgets the cars left over" as a reject of `two_trains` | Can never pass a visible case. |
| Fewest changes to turn one necklace into another (edit distance) | The same table as The Shared Route; one of the two was enough for this batch. Kept in reserve as a tier 5. |
| Longest rising line within a budget (tails list and binary search) | The same question as Rising Line with a tighter budget and a new coat of paint. |
| Lowest water level that lets a hiker cross a grid (search the answer + flood fill) | About 80 blocks of grid BFS inside a binary search; too close to Cheapest Crossing for what it would add. |
| A list that reads the same both ways, in almost no memory (middle, reverse half, compare) | Three techniques the world already teaches one by one; kept in reserve. |
| Evaluate a list of numbers and operator codes with a stack | Needs made-up operator codes (-1 for plus …) to stand in for text. Text is blocked; not faked. |

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

## Results

Run on the final commit of the branch (2026-11-18, the machine shared with
four other sessions):

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` / `dart test` | no issues / **398 passed** (unchanged) |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues / **86 passed** (unchanged count; the pinned sizes moved) |
| Content validator | `PIPELINE 185 of 185 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 190 puzzle(s), 5 warning(s)`: the five known probe warnings, none about a campaign puzzle |
| `flutter analyze` / `flutter test` | no issues / **612 passed** (540 + 72: the campaign regression builds every new puzzle's reference by taps at 360 × 800 and runs it, two tests per puzzle) |

Baseline before the batch, same machine: engine 398, content 86, Flutter
540, validator 149 of 149.

After each part's commit the content tests were also run on a clean export
of that commit (parts 1 and 2 carry empty oracle files for the later parts),
and the campaign Flutter tests (campaign, regression, localization,
responsive) on the working tree: 364, 388 and 412 passed.

**Validator time.** Measured back to back on exports of `main` and of this
branch, same disk, load average about 10: 18–20 s for 149 puzzles, 25–26 s
for 185 (about +7 s, +38 % for +24 % puzzles). The new puzzles are heavier
than the old average because most have two or three rejects, and the test
runner re-measures every over-budget case of a slow baseline with up to a
million extra operations. The fourth commit cut what it could without
weakening a puzzle: one long case per timed puzzle where one proves the
baseline, declared factors capped (the validator runs a baseline up to that
many budgets), trees of 60 levels instead of 200. **Not measured on a quiet
machine.**

**Size.** `assets/puzzles` grew from 2.7 MB to 3.5 MB. The largest new file
is `shared_ancestor.json` (126 KB: nested trees print with their
indentation; shipped `range_count.json` is 596 KB for the same reason).

## Known limits

- Oracles are as independent as their author made them; samples are small
  (40 seeded inputs per puzzle in the validator, 200 in the kit).
- Several budgets rest on an estimate of a second solution's cost, not on a
  built program; each is named in the notes above.
- `both_ends` is mechanically close to Rush Hour (89 % block similarity).
- `longest_crawl` (world 08) needs a map, which the unlock order does not
  guarantee the player has met; it is the world's tier 5.
- Seven tier 5 puzzles were added at once; none has been played by a person.
  Tiers are the authors' judgement plus the validator's heuristic (no
  warning).
- The Turkish text was written by the model that wrote the English; no
  native speaker has read it.

## NOT TESTED

- No APK was built and nothing was run on the emulator (it was in use by
  another session) or on a phone. The widget tests build and run every new
  puzzle at 360 × 800, in English; one Turkish puzzle screen is covered by
  the existing localization UI test, not the new puzzles' Turkish text on a
  screen.
- No web build, and the web start-up time with 36 more puzzle files was not
  measured.
- No person has solved any of the 36 puzzles in the editor; hints were not
  tried by a player.
- The validator's time on an unloaded machine.

## For the coordinator (merge notes)

- **This branch adds 36 puzzles: 149 → 185** (190 files with the five
  probes). M1 adds puzzles at the same time, so every pinned size below
  conflicts; the merged values are this branch's numbers plus M1's count.
- Test lines this branch touched (all are sizes, nothing else):
  - `test/campaign_test.dart`: the test title and `hasLength(149)` → 185;
    Arrays `hasLength(13)` → 17 and its comment.
  - `test/campaign_regression_test.dart`: `'149 campaign puzzles'` and
    `hasLength(149)` → 185.
  - `test/localization_ui_test.dart`: `0 of 149 puzzles solved` and
    `149 bulmacadan 0 tanesi çözüldü` → 185.
  - `test/responsive_test.dart`: `1 of 149 puzzles solved` → 185.
  - `test/real_puzzles_test.dart`: a comment (149 → 185).
  - `packages/algorun_content/test/pipeline_test.dart`: `hasLength(149)` →
    185.
  - `packages/algorun_content/test/content_validator_test.dart`:
    `puzzleCount, 154` → 190, `hasLength(149)` → 185,
    `'OK 154 puzzle(s)'` → `'OK 190 puzzle(s)'`.
- Shared data files: `assets/worlds.json` (eleven worlds' puzzle lists, kept
  in tier order), `assets/l10n/content_tr.json` (36 new entries under
  `puzzles`, nothing else), `content/coverage.json` (generated: after the
  merge **regenerate it** with `--coverage`, do not merge it by hand).
- Oracles: `packages/algorun_content/lib/src/oracles/batch7.dart`,
  `batch8.dart`, `batch9.dart`, registered in `registry.dart` (three imports
  and three spread lines). If M1 also adds a `batchN.dart`, rename one side.
- No engine, editor, screen, ARB or `pubspec.yaml` change. No new block is
  used: `arr.swap`, `var.swap`, `var.copy`, `ctrl.continue`, `lit.str` and
  `arith.div` were avoided because no shipped reference uses them.
- For `PROJECT_STATE.md` (not edited here): the campaign size (185) and the
  per-world table in "Content backlog and coverage"; tiers 1: 9 · 2: 43 ·
  3: 60 · 4: 58 · 5: 15; modes build 112 · budget 30 · edge 29 · optimize 8
  · restricted 6; performance classes correctness 129 · budget 43 ·
  optimization 8 · restricted 5; the test table (Flutter 612, validator 185
  of 185); the milestone list (MS16, content batch 4); `assets/worlds.json`
  "14 worlds, 185 puzzles"; the ideas kept in reserve (edit distance,
  palindrome list in no memory, shortest stretch with the top frequency) in
  the backlog.

## Tooling (not in the repository)

The generators are scratch scripts in `.content-tools/bin/` of the main
checkout (git-excluded): `kit16.dart` (the MS15 kit plus: the checkout to
write to comes from `ALGORUN_ROOT`; `maxOps` / `maxAlloc` / `factorCap`
overrides; `optimization` and `restricted` classes; the lazy-answer and
Turkish block-label checks), `prog16.dart` (the program builder plus BREAK,
NOTHING, REMOVE KEY, SIZE), one script per part (`ms16a.dart`, `ms16b.dart`,
`ms16c.dart`), and `timing16.dart` / `phases16.dart` (where the validator's
time goes). They were written and run from a copy of that folder inside the
worktree, so that `package:` imports resolve to the worktree's packages, and
copied back at the end. Parts 2 and 3 were drafted by two forks of the
authoring session, each writing only its generator and its oracle file and
checking against a scratch copy of the content; the main session reviewed
their text and cases, tightened budgets and fixtures, wrote the files and
ran the tests. **Do not re-run the scripts with `--write` after a hand edit
of a generated file**: they overwrite puzzle, reference, the `worlds.json`
order and the Turkish entries, and every random case of a script comes from
one seed, so removing a case regenerates the ones after it.
