# Content authoring contract

How to add campaign puzzles — by hand or with an AI model. Everything an
author produces is an **untrusted candidate** until the content pipeline
accepts it. Nothing here is executed as code in the game: puzzles are JSON
data, reference solutions are block programs run by the sandboxed
interpreter, and oracles are Dart in the offline tooling.

## 1. The request

A content request names what to make, not how to phrase it. Fill
[`content/templates/request.json`](../content/templates/request.json):

| Field | Meaning |
|---|---|
| `family` | an algorithm family from [`content/capabilities.json`](../content/capabilities.json) with status `supported` or `partial` |
| `pattern` | the key reasoning pattern, `lower_snake_case`, new to the corpus (see `content/coverage.json`) |
| `world` / `concepts` / `prerequisites` | where the puzzle lives and what it builds on; prerequisites must be concepts the manifest teaches |
| `tier` | 1–5 (see §5) |
| `mode` | a mode with status `supported` in the capability audit |
| `structure` | the primary data structure (`array`, `grid`, `hash_map`, `hash_set`, `stack`, `queue`, `linked_list`, `tree`, `graph`, `scalar`) |
| `blocks` | the block patterns the intended solution needs (catalog ids) |
| `scale` | the largest input the hidden cases hold |
| `performance` | `correctness`, `budget`, `optimization` or `restricted` |
| `traps` | the edge cases and wrong strategies the hidden cases must catch |

Examples:

- *"A tier 3 sliding-window puzzle that needs a variable-size window and
  cannot be solved by a fixed-size scan"* → family `sliding_window`, a new
  pattern (not `variable_window_shortest`, which Quota Hours has), mode
  `build`, performance `budget`, traps: an all-bad input, k = 0, the best
  window at the end, the quadratic restart.
- *"A tier 4 graph puzzle needing BFS, with disconnected components"* →
  family `graph_connectivity` or `graph_bfs`, traps: a component that never
  meets node 0, isolated nodes, an unreachable goal.

Before writing, read `content/coverage.json` (what exists, by world, tier,
family, pattern and mode) and its `gaps`.

## 2. The candidate

Two files. [`content/templates/`](../content/templates/) holds an accepted
candidate as a worked example (`candidate_puzzle.json`,
`candidate_reference.json`: Patchy Signal):

1. `assets/puzzles/<world>/<id>.json` — the puzzle, in the closed schema
   (`packages/algorun_engine/lib/src/puzzles/parse.dart`). It ships in the
   app.
2. `content/references/<world>/<id>.json` — `puzzle`, `notes`, `spec`,
   `metrics`, `solution` (a `BlockGraph`, the editor's own format) and
   `rejects`. It never ships.

And one piece of code: an **oracle** in
`packages/algorun_content/lib/src/oracles/`, registered in `registry.dart`
under the id the spec names.

Then list the puzzle in its world in `assets/worlds.json`, and add the
world's folder to `pubspec.yaml` if it is new.

**Turkish text (U1).** The puzzle JSON is English and stays the source of
truth. Add the puzzle's Turkish `title`, `story` and `hints` (same number,
same order) to `assets/l10n/content_tr.json` — and a new world's title and
any new concept word there too. Block names in stories and hints stay
English in Turkish (`IS NOT NOTHING`, `LEFT`, `RETURN` …).
`test/localization_test.dart` fails until every listed puzzle has its
Turkish entry and every block name is kept. The validator and the engine
never read translations.

## 3. Rules for authors (and for AI output)

- **Original statements only.** Do not copy or lightly reword a problem
  from a judge, a book or a course. Invent the story; keep the algorithm
  honest.
- **No unsupported language features.** Only blocks in the catalog, only
  families and modes the capability audit marks supported or partial. No
  weighted graph edges, text operations, pairs or starter programs until the
  language or product has them (recursion and player functions came with
  L2, heaps of numbers with H). A
  family the language cannot express is a gap to record, not a problem to
  weaken until it fits.
- **No redundant variants.** A new story, new names, new number ranges or
  an inversion of an existing puzzle is not a new puzzle. The pipeline's
  redundancy check refuses near duplicates (§4, level 7); aim for a new
  reasoning pattern, constraint, structure choice, trade-off or mode.
- **An independent oracle.** The oracle must not be the reference
  algorithm: brute force, a different algorithm, or a direct reading of the
  definition. It must also provide `sample`, small random inputs inside the
  stated constraints.
- **Meaningful hidden cases.** Visible cases teach; hidden cases
  discriminate. A visible case shows the task on a real input (not only an
  empty or one-element one) with an answer a constant would not give, while
  the reject still passes it; the answers across all cases must differ (the
  validator refuses a puzzle whose cases all expect one answer). Generated
  fixtures are a draft: read them before committing (MS14 review). Cover empty and minimal inputs, duplicates, negatives where
  meaningful, near-maximum inputs and the adversarial pattern that breaks
  the tempting wrong strategy. Hidden cases never repeat visible ones.
- **Rejects.** Prove the traps: each tempting wrong strategy is a reject
  that passes every visible case and ends in its declared verdict
  (`wrongAnswer`, `runtimeError`, `memoryLimit`); for `budget` and
  `optimization`, a correct-but-slow reject ends in `operationLimit`.
- **Realistic budgets.** Budgets are deterministic operation counts, set a
  little above the reference (the validator warns above 80 %), far below
  the slow baseline (`performance.baselineFactor`). Never claim a
  complexity class.
- **Words players read.** Stories and hints use block labels (NODE VALUE,
  IS NOT NOTHING), never catalog ids or hidden case names; hints go from the
  idea to the approach, three of them.
- **Never "fix" an expected answer to match the reference.** If the oracle
  disagrees with a fixture or the reference, find out which is wrong.

## 4. The pipeline

```
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references --coverage content/coverage.json
```

A candidate is **accepted** only when no level reports an error against it:

| Level | Checks |
|---|---|
| 1 schema | closed puzzle schema; file location; manifest; reference file shape; `spec` |
| 2 blocks | allowlist and block budget; the family and mode in the capability audit |
| 3 replay | the reference rebuilt through the editor's own commands; lowering |
| 4 execution | every visible and hidden case through the real `TestRunner`; every reject in its declared verdict; the oracle agrees with every fixture and with the reference on sampled inputs; hidden cases not copies of visible ones |
| 5 performance | budgets and headroom; recorded `metrics` match; `performance.required` baseline and `baselineFactor`; the spec's performance class matches the puzzle |
| 6 progression | every listed puzzle and world reachable under the game's own unlock rules; no cycles; no prerequisite nobody teaches |
| 7 corpus | not a near duplicate; difficulty advice; coverage gaps |

The CLI prints `ACCEPTED` / `REJECTED … at L4 execution` per puzzle. Write
`metrics` from the first run's "Measured: …" warning. Commit
`content/coverage.json` regenerated (a test compares it).

## 5. Difficulty

Tiers 1–5 describe reasoning, not size:

| Tier | Typically |
|---|---|
| 1 | one pass, one idea, one state variable |
| 2 | one structure used plainly, or a simple running state; an edge case to respect |
| 3 | a known technique applied with care (two pointers, a stack, BFS, binary search), several states |
| 4 | a non-obvious insight or two interacting ideas; traps a plausible approach falls into; often a budget |
| 5 | several concepts combined, or an insight that is hard to see even knowing the technique |

The validator estimates a tier from the reference (block count, loop
nesting, structures built, state variables, concepts, performance
requirement — never block count alone) and warns only on clear mismatches.

## 6. When the language is the limit

If the idea needs something the capability audit marks `blocked`, stop:
record the family and the puzzle idea in the backlog (`PROJECT_STATE.md`,
"Content backlog"). Do not fake recursion with puzzle-specific blocks, do
not simulate a heap with a sorted list inside a budget that makes it
pointless, do not weaken the problem until it fits.

## 7. Puzzles that open with a program (M1)

Since M1 a puzzle may carry a **starter program**, and three modes are
built on it. (This supersedes "no starter programs" in §3; everything else
in §1–§6 applies unchanged: the oracle, the fixtures, the seven levels.)

```json
"starter": {
  "graph": { <BlockGraph JSON, the format of a reference solution> },
  "locked": ["b1", "b6"]
}
```

`graph` is data in the editor's own format: it is only ever read by the
same validate → lower → interpreter path as a player's program. `locked`
(optional) names blocks the player cannot delete, move or change; the empty
slots of a locked block can still be filled. The schema refuses a starter
that uses a block outside `blocks.allow`, a name that is not an input or a
pool variable, more blocks than `blocks.maxBlocks`, or a lock on a block it
does not have.

| Mode | The starter is | The pipeline demands |
|---|---|---|
| `complete` | half a program: instructions or values are missing | it does **not** pass; the reference **only adds** to it (every starter block is in the reference with the same id, contents and neighbours in the same order) |
| `repair` | a whole program with one mistake | it lowers and runs; it does **not** pass; it differs from the reference in at most **4 blocks** (`repairMaxChangedBlocks`) |
| `predict` | the whole program, shown read only | it **is** the reference (the same lowered program); it returns every fixture's answer; at least 2 visible cases; `io.output` is `num` or `bool`; number answers fit the pad (whole, ±999999) |

For every starter: it is rebuilt through the editor's commands like a
reference (so it is typed and buildable; empty slots are fine), and every
locked block is in the reference, unchanged and in the same place.

**Write the reference first and derive the starter from it**, so the two
share block ids — the rules above compare by id. `tool/m1_emit.dart` shows
how: take blocks out (complete), turn one block into another or drop one
instruction (repair), change nothing (predict).

Rules for authors:

- **complete** — leave a scaffold that reads as a program with a gap, not a
  pile of loose blocks. The story's last sentence says what is there and
  what is missing. Lock the scaffold when the point is the gap; leave it
  free when rearranging is part of the task.
- **repair** — one realistic slip: a bound, a comparison that is too strict
  or too loose, a missing update, a wrong starting value. Never something
  absurd at a glance. The mistake must let **some visible case pass and
  some fail**, so the failing case points at it; the validator prints how
  many cases the starter fails. The story says what goes wrong ("sometimes
  one short"), never where. Both the wrong block and the right one are in
  `blocks.allow`. Usually lock nothing: a lock would say where the mistake
  is not.
- **predict** — the player is graded against what the interpreter returns,
  so the story must **not** describe the algorithm; it sets the scene and
  asks what the program returns. Each visible case is one question; pick
  inputs whose answers differ and that can be traced by hand in a minute or
  two (the third hint may trace an input that is *not* a question). Hidden
  cases are never shown: they exist so the oracle and the program are
  compared on the edges. The oracle matters most here — it must be a
  different characterisation of the result (a formula, a property), never
  the program replayed.
- Hints work as everywhere: idea, approach, strongest guidance. For repair
  the last hint may name the fix.
- Turkish text as in §2. Words like TRUE, FALSE and block labels stay
  English.
