# Milestone 12

**MS12 COMPLETE.** A scalable, mechanically provable content pipeline, and a
first expansion batch of 33 new puzzles through it — from 5 campaign puzzles
to 38, in 12 worlds, every one accepted at all seven levels.

Previous milestone commits: MS10 `c192118`, L1 `d850525`, MS11 `033f3ec`.

The engine's language and runtime were not changed. One pure function moved
into the engine: the MS11 unlock rules (`evaluateUnlocks`, in
`packages/algorun_engine/lib/src/puzzles/progression.dart`), so the app and
the content validator run the *same* code — the app's `evaluateCampaign`
now delegates to it, with identical results (all MS11 progression tests pass
unchanged).

## The pipeline

```
candidate puzzle JSON + reference file (+ an oracle in the tooling)
  → L1 schema        closed puzzle schema, file location, manifest, reference file, spec
  → L2 blocks        allowlist, block budget, language capability audit (family, mode)
  → L3 replay        reference rebuilt through the editor's own commands, lowered
  → L4 execution     real TestRunner on visible + hidden cases; rejects in their declared verdict;
                     oracle ↔ fixtures; oracle ↔ reference on sampled inputs; hidden ≠ visible
  → L5 performance   budgets and headroom, recorded metrics, performance.required / baselineFactor,
                     spec performance class vs the puzzle
  → L6 progression   reachability under the game's unlock rules, cycles, unlearnable prerequisites
  → L7 corpus        near duplicates, difficulty advice, coverage matrix and gaps
  → ACCEPTED
```

```bash
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references --coverage content/coverage.json
```

Every finding carries its level (`ERROR [L4 execution] …`), every puzzle a
verdict (`ACCEPTED world_07/loop_detector.json` or `REJECTED … at L2 blocks,
L5 performance`), then a summary: `PIPELINE 38 of 38 campaign puzzle(s)
accepted, 4 probe(s) checked · tiers 1:2 2:8 3:13 4:13 5:2 · 62 coverage
gap(s)`. `capabilities.json` and `coverage_targets.json` are read from the
directory that holds the references directory. A full run takes about five
seconds.

Code (`packages/algorun_content/lib/src/`): `content_validator.dart`
(orchestration, verdicts), `reference_check.dart` (levels 1–5 per
reference), `content_spec.dart` (spec, capability audit), `oracles/`
(oracle framework and 38 oracles), `progression_check.dart` (level 6),
`redundancy.dart`, `coverage.dart`, `difficulty.dart` (level 7),
`content_issue.dart` (`Level`, `PuzzleVerdict`).

## The content specification

Each campaign puzzle's reference file carries a `spec` — authoring metadata,
offline only:

```json
"spec": {
  "family": "linked_list_traversal",
  "pattern": "floyd_cycle",
  "structure": "linked_list",
  "secondary": ["nullable_check", "two_pointers"],
  "performance": "correctness",
  "traps": ["a lasso whose loop does not include the first piece", "a piece pointing at itself", "…"],
  "oracle": "loop_detector"
}
```

`family` must be in the capability audit and not blocked; `pattern` is the
redundancy key; `structure` is from a closed list; `performance` is
`correctness | budget | optimization | restricted` and must match the puzzle
(`budget` ⇒ `performance.required`; `optimization` ⇒ mode `optimize` +
`required`; `restricted` ⇒ mode `restricted`); `traps` are what the hidden
cases and rejects catch; `oracle` names an oracle in the tooling. A listed
puzzle without a spec is refused at L1.

Authoring requests and the rules for AI-drafted candidates:
[`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md), with
`content/templates/request.json` and a worked example.

## AI output is untrusted: independent oracles

A reference solution cannot prove its own answers. Every campaign puzzle has
an **oracle**: plain Dart in the content tooling (never in puzzle data,
never in the app), written the simplest obviously-correct way and not the
reference's algorithm — brute force over all pairs / windows / starts,
Bellman-Ford relaxation instead of BFS, union-find instead of search,
recursion (allowed in tooling) instead of an explicit stack, a quadratic DP
instead of two running states, the fixture's own `cycleTo` instead of
Floyd's markers. Each oracle also samples small random inputs inside the
puzzle's constraints.

At level 4 three things must agree:

1. **oracle ↔ fixtures** — every visible and hidden expected output, checked
   even when the reference fails (a wrong fixture is named, never blamed on
   the program);
2. **reference ↔ fixtures** — the real `TestRunner`;
3. **reference ↔ oracle** on 40 deterministic random inputs per puzzle
   (seeded by the puzzle id), run by the real interpreter within the
   puzzle's limits.

A disagreement fails the puzzle. The validator never "fixes" an expected
answer to match the reference. Tests prove both failure modes: a wrong
reference whose fixtures were written to match it (caught by the oracle), and
a reference that only fits its own fixtures (caught by sampling).

Authoring itself added a fourth check: expected outputs were computed by a
fast implementation and cross-checked against a brute force before they
were written (scratch tooling, outside the repository).

## Progression reachability (level 6)

`checkProgression` plays the campaign with `evaluateUnlocks` as a player who
solves everything the moment it opens. Whatever is still closed is reported:

| Finding | Severity |
|---|---|
| a prerequisite no world teaches, needed by a world with puzzles or by a listed puzzle | error |
| a world with puzzles, or a listed puzzle, that never opens — with the concepts it waits for and why each is never mastered | error |
| circular gating, reported as the cycle itself (`Circular gating: world_b → world_c → world_b`); covers worlds waiting on each other, a puzzle gated behind its own world, a world requiring what only its dependants teach | error |
| a world with no puzzles that never opens (Backtracking waits for recursion) | warning |
| a prerequisite taught only later in the manifest order | warning |

The rules are never changed to make content pass. One content decision was
made in the data: Dynamic Programming required `recursion`, which no world
teaches and the language lacks; its puzzles are iterative, so it now
requires `greedy`. Backtracking still requires `recursion` and stays locked,
with no puzzles.

## Redundancy (level 7)

A deterministic fingerprint per puzzle — never the title or story:
`pattern`, io signature (`(array<num>,num)->num`), concepts, the reference's
statement **skeleton** (every instruction by catalog id, nested as nested;
names, literals and expressions left out) and a **block histogram** (catalog
ids that carry meaning, weighted Jaccard similarity).

| Verdict | Rule |
|---|---|
| near duplicate — **error** against the later puzzle in campaign order | same io signature, and either the same pattern with the same skeleton or ≥ 80 % similarity, or a *different* pattern with the same skeleton, the same concepts and ≥ 90 % similarity (a renamed pattern does not hide a duplicate) |
| related — info | same pattern, or same skeleton, or ≥ 80 % similarity |
| unique | otherwise |

The shipped corpus: no near duplicates; two related pairs (Two Teams and
Nearest Depot are both BFS relatives of Fewest Rides, with different
patterns and inputs).

## Coverage matrix (level 7)

`content/coverage.json` (committed, regenerated by `--coverage`; a test
fails if it is stale) counts accepted puzzles by world (with tiers, families
and patterns), tier, mode, structure, family, performance class and concept,
lists every puzzle's metadata, and reports **gaps** against
`content/coverage_targets.json` (planning targets for ~300 puzzles: per
world a target count and the tiers it should span, per family and per mode a
minimum). Gaps the language or the product cannot fill yet are marked
`blocked by the language` / `blocked: …`.

## Difficulty (level 7)

`DifficultySignals` measures the reference: blocks, loop nesting, structures
the program builds (not the inputs it is handed), state variables, concepts,
and a performance requirement. Half a point each for ≥ 30 and ≥ 55 blocks,
nested and triple-nested loops, ≥ 2 and ≥ 3 structures, ≥ 5 state variables,
≥ 4 concepts and a budget; the estimate is 1 + the rounded points. It warns
only when the reference looks at least two tiers harder than declared, or a
tier 4–5 puzzle is trivial — a short program can be a hard puzzle
(Loop Detector is tier 4 with 32 blocks). Calibrated on this corpus: no
warnings.

## Language capability audit

`content/capabilities.json` — the audit, as data the validator enforces.

| Status | Families |
|---|---|
| **supported** | array scan, prefix sum, binary search, hash map, hash set, two pointers, sliding window, stack, monotonic stack, queue, linked-list traversal (L1), linked-list relinking, tree traversal (iterative), graph BFS, iterative DFS, connectivity, topological order, greedy, iterative DP, grid DP, multi-concept |
| **partial** | monotonic deque (no deque blocks; a list with a head index stands in) |
| **blocked by the language** | recursion (no player functions), backtracking, heap / priority queue (no blocks, value or fixture form), weighted shortest path (no edge weights, no heap), building list or tree nodes (no node constructor, no child setters), strings (no text operations; the editor cannot enter text), built-in sorting, bit manipulation, pairs / tuples |

| Mode | Status |
|---|---|
| build, budget, optimize, restricted, edge | supported |
| complete, repair, structure, trace, predict, ops | blocked by the product: they need a starter program or an answer UI the schema and editor do not have |
| complexity | blocked by design: the game never claims a complexity class |

No puzzle in this batch needs a blocked capability; no recursion or heap
content was fabricated.

## The first expansion batch (33 puzzles)

| World | New puzzles (tier, mode) |
|---|---|
| 01 Foundations | Warm Readings (1), Highest Tide (1) |
| 02 Arrays | Lowest Balance (2), Shelf Totals (3, budget), Departure Board (3, budget) |
| 03 Hash Maps | Loudest Echo (2), Level Stretches (4), Longest Streak (4) |
| 04 Two Pointers | Matched Pair (2, restricted), Widest Basin (4, optimize) |
| 05 Sliding Window | Rush Hour (2, budget), Patchy Signal (3), Market Variety (4) |
| 06 Stack & Queue | Sealed Crates (2), Undo Button (2, edge), Largest Billboard (5) |
| 07 Linked Lists | Middle Car (3), Reverse the Train (3), Drop the Faulty Cars (3), Loop Detector (4, edge) |
| 08 Trees | Canopy Height (3), Busiest Level (4), Trail Sum (4), Sorted Grove (4) |
| 10 Graphs | Island Count (3), Two Teams (4), Task Order (4), Nearest Depot (4, budget) |
| 11 Greedy | One Good Trade (2, budget), Fuel Loop (4) |
| 13 Dynamic Programming | Quiet Street (3), Exact Change (4) |
| 14 Advanced | Many Shortest Routes (5) |

Every new puzzle has an original story, three hints, 2 visible and 5–8
hidden cases (edges, duplicates, negatives where meaningful, near-maximum
inputs, the adversarial case), a reference `BlockGraph`, recorded metrics,
a spec and an oracle; 32 of 33 have rejects proving their traps: 13
correct-but-slow baselines (`operationLimit`), 18 tempting wrong strategies
(`wrongAnswer`), one crash on an unguarded edge (`runtimeError`, Undo
Button) and one memory-hungry approach (`memoryLimit`, Matched Pair).
Reverse the Train relies on its hidden cases alone (its tempting mistakes
cannot pass the visible cases, so they cannot be declared as rejects).

**L1 in use.** All 8 tree and linked-list puzzles narrow with IS NOTHING /
IS NOT NOTHING (a test checks it): fast/slow markers, Floyd's cycle check
(nodes compared by identity), in-place relinking with SET NEXT, BFS by
levels, parallel stacks of nodes and running totals, an iterative in-order
walk. Three map-counting puzzles (Loudest Echo, Level Stretches, Market
Variety) check the looked-up count for NOTHING before using it.

**Performance.** 15 puzzles are `budget` class (11 new and four from MS8:
Twin Beacons already declared `performance.required`; Quota Hours, Relay
Towers and The Smallest Cart now declare what their slow rejects already
proved), one `optimization` (Widest Basin, a 10×
baseline factor), one `restricted` (Matched Pair: 4 memory cells, so a set
of complements fails with `memoryLimit`), 21 correctness only. Budgets are
operation counts; every reference stays under 80 % of them.

## Current content

| | Count |
|---|---|
| Campaign puzzles accepted | **38** (5 from MS8 + 33) |
| Dev probes (unlisted) | 4 |
| By tier | 1: 2 · 2: 8 · 3: 13 · 4: 13 · 5: 2 |
| By mode | build 28 · budget 6 · edge 2 · optimize 1 · restricted 1 |
| By performance class | correctness 21 · budget 15 · optimization 1 · restricted 1 |
| By structure | array 15 · graph 6 · linked list 4 · stack 4 · tree 4 · hash map 3 · hash set 2 |
| By world | 01: 2 · 02: 4 · 03: 4 · 04: 2 · 05: 4 · 06: 4 · 07: 4 · 08: 4 · 09: 0 · 10: 5 · 11: 2 · 12: 0 · 13: 2 · 14: 1 |
| Distinct reasoning patterns | 38 |

Counts by concept and family are in `content/coverage.json`.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` / `dart test` | no issues / **347 passed** (341 + 6 unlock-rule tests) |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues / **82 passed** (46 + 36) |
| Content validator (all puzzles, worlds, references) | `PIPELINE 38 of 38 campaign puzzle(s) accepted, 4 probe(s) checked` · `OK 42 puzzle(s), 6 warning(s)` |
| Flutter `analyze` / `test` | no issues / **114 passed** (111 + 3) |
| `flutter build apk --debug` | built |

New content tests (`test/pipeline_test.dart`): a valid candidate accepted;
malformed candidate, missing and malformed spec; blocked family, unknown
family, unplayable mode, a block outside the allowlist (L2); an unbuildable
reference (L3); a wrong reference with matching wrong fixtures, a reference
that only fits its fixtures, a wrong fixture named against the oracle, an
unknown oracle, hidden cases repeating visible ones, rejects caught or not
(L4); over budget, drifted metrics, a budget spec without
`performance.required` (L5); a reachable campaign, worlds in a cycle, a
puzzle gated behind its own world, unlearnable prerequisites, an unreachable
puzzle in an open world, warnings for empty worlds and order (L6); a
restated puzzle and a renamed pattern as near duplicates, related and unique
pairs, the coverage matrix and its gaps, deterministic output, difficulty
advice, duplicate ids (L7); and the shipped corpus — 38 of 38 accepted, the
committed coverage matrix up to date, every oracle used by exactly one
puzzle, no blocked family or unplayable mode, tree and list content using
the L1 checks.

Engine (`test/progression_test.dart`): the unlock rules on their own.
App: the MS11 progression and persistence tests now run against a frozen
copy of the MS11 manifest (`test/fixtures/ms11_worlds.json`), so the rules
are tested independently of content growth; `test/campaign_test.dart`
checks the shipped campaign (38 puzzles, a fresh install starts at
Foundations, a player who solves everything reaches every puzzle, the
unlock order); two MS8/MS11 tests that asserted the five-puzzle campaign
were updated to the grown one.

## Files

Created: `packages/algorun_engine/lib/src/puzzles/progression.dart`,
`packages/algorun_engine/test/progression_test.dart`;
`packages/algorun_content/lib/src/{content_spec,progression_check,redundancy,coverage,difficulty}.dart`,
`packages/algorun_content/lib/src/oracles/` (framework, registry, 10 files of
oracles), `packages/algorun_content/test/pipeline_test.dart`;
`content/capabilities.json`, `content/coverage_targets.json`,
`content/coverage.json`, `content/templates/`; 33 puzzles under
`assets/puzzles/` and their references under `content/references/`;
`test/campaign_test.dart`, `test/fixtures/ms11_worlds.json`;
`docs/CONTENT_AUTHORING.md`, `docs/MILESTONE_12.md`.

Modified: the content validator, reference checker, CLI and issue model;
the engine export list; the app's `campaign.dart` (delegates to the engine
rule); `assets/worlds.json` (38 puzzles listed, DP prerequisite);
`pubspec.yaml` (six more puzzle folders); the five MS8 references (`spec`)
and three MS8 puzzles (`performance.required`, no change to grading, so no
version bump); app and content tests as described; `PROJECT_STATE.md`,
`README.md`.

## Known limitations

- The redundancy fingerprint depends on the author choosing an honest
  `pattern`; the structural rule catches renamed duplicates only when the
  programs are nearly identical. A differently *programmed* restatement of
  the same exercise can pass as "related".
- Oracles are hand-written Dart per puzzle: a future batch needs one oracle
  per puzzle, reviewed as carefully as the puzzle. They are only as
  independent as their author made them.
- Sampled inputs are small (the oracles are brute force); large-input
  behaviour is covered by the fixtures, not by sampling.
- Coverage targets are a plan, not a rule; the gaps are reported as
  information.
- Difficulty advice is a calibrated heuristic; tiers remain an authoring
  judgement.
- Modes needing a starter program (complete, repair, trace, predict,
  structure, ops) cannot be authored until the schema and editor support
  one; every puzzle in this batch is a build-style puzzle in its mode.
- Several worlds hold only 2 puzzles; Heaps and Backtracking hold none
  (blocked by the language).

## Confirmation

Milestone 12 is complete: the pipeline is proven on a 33-puzzle batch.
Mass content generation is a separate, future step. Do not start another
milestone from this document.
