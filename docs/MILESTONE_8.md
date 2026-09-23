# Milestone 8

The first five real algorithm puzzles, each proven solvable by a reference
solution that the content validator builds, lowers and runs through the real
`TestRunner`. No hints UI, no scoring, no progression, no new editor.

Previous milestone commits: MS5 `06e2037`, MS6 `39956f9`, MS7 `7d689dc`.

## The five puzzles

| # | Title | World | Pattern | Mode | Tier |
|---|---|---|---|---|---|
| 1 | Twin Beacons | `world_03` Hash Maps | complement lookup with a hash set | `budget` | 2 |
| 2 | Quota Hours | `world_05` Sliding Window | variable-size sliding window | `build` | 3 |
| 3 | Relay Towers | `world_06` Stack & Queue | monotonic stack | `build` | 3 |
| 4 | The Smallest Cart | `world_02` Arrays | binary search on the answer (FLOOR DIVIDE) | `build` | 3 |
| 5 | Fewest Rides | `world_10` Graphs | BFS shortest path on a graph | `build` | 3 |

Five different reasoning patterns, not five stories over one algorithm. All
wording and scenarios are original.

### 1. Twin Beacons — `assets/puzzles/world_03/twin_beacons.json`

Report the position of the first beacon whose strength, added to some earlier
beacon's, hits the tuning number exactly; `-1` if none.

- **Insight:** each beacon has exactly one missing partner (`tuning − strength`).
  Remember what has passed in a set and ask before adding.
- **Correct but too slow:** comparing every pair is right, and passes every
  visible case, but needs about 22 million steps on the 2,000-beacon logs
  against a budget of 60,000. This is the game's "correct but too slow"
  showcase; the puzzle is in `budget` mode.
- **Edge-case trap:** adding a strength *before* asking pairs a beacon with
  itself when its strength is half the tuning number. Hidden cases catch it.
- Also: empty and single-beacon logs, equal twins, negative strengths, zero
  tuning, and a case where the first completed pair is not the one with the
  smallest first position.

### 2. Quota Hours — `assets/puzzles/world_05/quota_hours.json`

Shortest run of consecutive hours whose energy total reaches the quota; `0` if
the whole day falls short. Every hour produces at least one unit.

- **Insight:** because every hour is positive, a window can grow on the right
  and shrink on the left without ever looking back; each hour enters and
  leaves once.
- **Strategy choice:** trying every run is correct but quadratic (about 38
  million steps on a 2,000-hour day against 120,000).
- **Edge-case trap:** starting "best" one past the longest possible run and
  forgetting to turn it into `0` when nothing fits.

### 3. Relay Towers — `assets/puzzles/world_06/relay_towers.json`

For every tower, how many positions east is the nearest strictly taller
tower; `0` if none. Output is a list.

- **Insight:** keep the towers still waiting for an answer on a stack, by
  position. Heights on the stack never rise from bottom to top, so a new tower
  settles waiting towers from the top.
- **Strategy choice:** looking east from every tower is correct but quadratic
  on a long falling ridge.
- **Edge-case trap:** equal heights are not taller. Popping on `≤` instead of
  `<` passes the visible cases and fails the plateaus.

### 4. The Smallest Cart — `assets/puzzles/world_02/smallest_cart.json`

Parcels leave in a fixed order; a cart takes the next parcels while they fit
its capacity. Smallest whole capacity that clears the conveyor within the
allowed number of trips.

- **Insight:** "fits in time" only ever turns from false to true as capacity
  grows, so binary-search the *capacity*, testing each candidate with one walk
  of the conveyor. This is the least mechanical of the five: nothing in the
  wording says "search".
- **FLOOR DIVIDE, genuinely:** capacities are whole numbers, so the midpoint
  must be one. The same program with DIVIDE probes fractional capacities and
  fails (engine test).
- **Strategy choice:** raising the capacity one unit at a time is correct but
  walks the conveyor thousands of times.

### 5. Fewest Rides — `assets/puzzles/world_10/fewest_rides.json`

Fewest one-way rides from `start` to `goal` on a rail map; `0` when they are
the same station, `-1` when the goal is unreachable.

- **Non-linear structure:** the map is a tagged `graph` fixture (MS7) — one-way
  rides, loops, self-loops, a city split in two, and a 500-station city.
- **Strategy choice:** the same program with a stack instead of a queue still
  finds routes but explores the deepest branch first and reports a longer one.
  A hidden case is built so that it does.
- Also: start equals goal, one-way only, a single isolated station.

### Why not tree BFS

The suggested fourth area was tree traversal. It cannot be written in today's
block language: `tree.left` / `tree.right` return `treeNode?`, every block that
reads a node needs a non-null `treeNode`, and there is no block that narrows a
nullable value after a `NOTHING` check. The same holds for walking a linked
list (`ll.next` is `listNode?`). A puzzle that cannot be built is not a puzzle,
so it was replaced by binary search on the answer, which also gives FLOOR
DIVIDE its real use. The graph puzzle carries the non-linear structure.

### Difficulty rationale

Tier 2–3, practical Medium. Each puzzle has a tempting approach that is
correct on small inputs (all-pairs, all-runs, look-east, one-unit steps, DFS)
and a better one that needs an insight. Four of the five are budget-sensitive
through `maxOps`; two have a hidden edge-case trap that the visible cases do
not show. Budgets are about twice what the reference needs, so a reasonable
variation of the intended approach fits and the naive one is tens to hundreds
of times over.

| Puzzle | Reference blocks / max | Reference worst ops / maxOps | Naive on the biggest case |
|---|---|---|---|
| Twin Beacons | 23 / 30 | 28,008 / 60,000 | ≈ 22,000,000 |
| Quota Hours | 47 / 60 | 59,944 / 120,000 | ≈ 38,000,000 |
| Relay Towers | 42 / 55 | 85,212 / 170,000 | over budget on the falling ridge |
| The Smallest Cart | 56 / 70 | 65,204 / 130,000 | over budget on the few-trips conveyor |
| Fewest Rides | 58 / 70 | 23,467 / 50,000 | (DFS is wrong, not slow) |

These are deterministic operation counts from the MS5 interpreter, not Big-O
proofs.

## Reference solutions

A reference solution is **data**: a `BlockGraph` in the same JSON the editor
saves, stored outside the app bundle.

```
content/references/<world>/<puzzle id>.json
```

```json
{
  "puzzle": "twin_beacons",
  "notes": "Why this is the intended approach.",
  "solution": { "variables": {...}, "entryIds": [...], "blocks": {...} },
  "rejects": [
    { "name": "compare every pair", "expect": "operationLimit", "graph": {...} },
    { "name": "add before asking",  "expect": "wrongAnswer",    "graph": {...} }
  ]
}
```

- `pubspec.yaml` bundles only `assets/`, so references never ship and the app
  has no code that reads them. There is no "view solution" anywhere.
- A puzzle declares `"reference": {"strategy": "<lower_snake_case>"}` (schema,
  MS8). The strategy tag names the approach for tooling — for example to spot
  two puzzles that are the same idea — and is never shown to players.
- **Rule:** every puzzle a player can reach (listed by a world) must declare
  reference metadata, and every puzzle that declares it must have a reference
  file that passes. Nothing is keyed to puzzle ids.

### What a reference must prove

For the solution:

1. The file parses and is closed (`puzzle`, `notes`, `solution`, `rejects`);
   `puzzle` matches.
2. `solution` is a well-formed `BlockGraph`.
3. `engine.validate`: only allowed blocks, within `maxBlocks`, structurally
   sound.
4. **Buildable in the editor** (`replayInEditor`): the graph is rebuilt
   top-down with the editor's own commands (`AddBlockCommand`,
   `AttachStatementCommand`, `ConnectCommand`), starting from the givens and
   creating names only from the variable pool. Every connection must pass
   `GraphTyping.canConnect`, literals must be ones the editor can set (names,
   whole numbers within the pad's ±999,999, true/false). A reference that no
   player could assemble is refused.
5. It lowers.
6. `engine.runTests`: every visible and every hidden case passes, inside
   `maxOps`, `maxAlloc` and `maxDepth`.
7. Headroom: a warning when it uses more than 80 % of any budget.

For each reject: it must be buildable too, pass **every visible case** (it
has to look right), and end the full suite in exactly the declared result
kind. This is how a puzzle proves that its budget turns away the correct but
slow approach, or that a hidden case catches the tempting mistake.

Content tooling may name hidden cases in its messages ("Wrong Answer on hidden
case `h1`"); the player UI never does.

### Every fixture's answer must satisfy its own validator

Added to the per-puzzle checks. With today's comparators this always holds;
it guards future comparators.

## Hidden-test policy

- Visible cases show the behaviour without the algorithm: two small cases per
  puzzle, none of them hitting the trap.
- Hidden cases cover, where they apply: empty and minimal inputs, boundary
  sizes (2,000 elements, 300 parcels, 500 stations), duplicates and equal
  values, negatives, zero, unreachable and disconnected goals, cycles and
  self-loops, the edge-case traps above, and worst-case patterns that defeat
  the naive approach.
- Hidden cases stay counts in the player UI (MS6). They ship in the APK, as
  every local hidden test does (locked decision 6).
- Expected outputs were computed by brute-force oracles independent of the
  reference strategies (all-pairs, all-runs, look-east, one-unit capacity
  search, BFS cross-checked with Floyd–Warshall on small maps), so a wrong
  reference cannot bless its own answers.

## Content validator

```
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references
```

- New third argument: the references directory. Without it the run still
  checks everything else and says "Reference solutions were not checked".
- New library files: `editor_replay.dart` (buildability), `reference_check.dart`
  (`ReferenceChecker`), `content_issue.dart` (issue types, split out).
- Errors added: a playable puzzle without reference metadata; reference
  metadata without a file; a reference file with no puzzle; malformed
  reference; wrong `puzzle`; a solution outside the allowlist or block budget,
  not buildable, not lowerable, or failing any case; a reject that fails a
  visible case or ends in the wrong result.

## App integration

- `assets/worlds.json`: the five puzzles are listed in worlds 2, 3, 5, 6 and
  10. The two MS1/MS3 probes stay in the bundle (tests and the editor seed use
  them) but are no longer listed, so players never see them.
- `pubspec.yaml`: bundles the new world folders.
- World cards say "1 puzzle", not "probe"; worlds with puzzles open, empty
  worlds stay locked, exactly as before.
- The puzzle screen opens with its story visible.
- Nothing else changed: the editor uses each puzzle's allowlist and variable
  pool, RUN goes through `runPuzzle` → `TestRunner`, and the results screen
  shows visible cases and a hidden count.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **271 passed** (245 + 26) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **31 passed** (16 + 15) |
| Content validator (assets + worlds + references) | `OK 7 puzzle(s), 4 warning(s)` |
| Flutter `analyze` | no issues |
| Flutter `test` | **20 passed** (14 + 6) |

Engine (`shipped_puzzles_test.dart`, 24 + 2 schema): for every puzzle — real
puzzle shape, reference through JSON → BlockGraph → validate → lower →
TestRunner, round trip; every reject ends as declared; the all-pairs program
would be right with unlimited steps; DIVIDE instead of FLOOR DIVIDE fails; the
graph fixtures are real graphs with unreachable and zero-distance goals; budget
cases hit `constraints.n.max`.

Content: the shipped set with references; a correct reference; missing
metadata; missing file; orphan file; malformed JSON; not a block graph; wrong
puzzle; unknown field; forbidden block; over `maxBlocks`; over `maxOps`; wrong
answer (names the hidden case); not buildable (editor-unsettable literal, name
outside the pool, and the same graph accepted once the pool has it); rejects
that end as declared, that end otherwise, that fail a visible case, and that
name `correct`; the CLI with and without references.

App: the worlds list exactly the five; each loads from the bundle as a real
puzzle; references are not bundled; RUN solves all five with their references;
the all-pairs program shows as OPERATION LIMIT with hidden cases as a count and
no hidden ids; world cards count puzzles.

## Known limitations

- **No null narrowing in the language.** Trees and linked lists cannot be
  traversed past their first node, and `map.get` values (`V?`) cannot be used
  in arithmetic, so counting maps are out; arrays and sets carry these puzzles.
  A typed "if not NOTHING" / unwrap block is the smallest fix and should come
  before tree, linked-list or counting content.
- **Hints are content only.** Every puzzle has three progressive hints, but the
  UI does not show them yet (MS9).
- **Reference authoring has no tool.** The five references were written as
  data outside the repository (a scratch generator), and are checked by the
  validator. Saving a graph from the editor as a reference would make authoring
  practical at scale.
- Graph fixtures do not enforce "stations are numbered 0 to n-1"; the puzzle
  states it and the fixtures follow it.
- Allocation still has no collector, so `graph.neighbors` arrays count toward
  `maxAlloc` for the whole run; budgets account for it.
- Worlds unlock when they have puzzles; there is no progression (by design,
  MS11).
- Worlds 12 and 13 still require `recursion`, which no world teaches (warning).

## Confirmation

Milestone 8 is complete. Do not start Milestone 9 from this document.
