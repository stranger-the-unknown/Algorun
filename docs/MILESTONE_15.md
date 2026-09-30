# Milestone 15 — content batch 3 (in progress)

Content only, through the unchanged MS12 pipeline. No engine, block, unlock
rule or schema change; no shipped puzzle edited (no `version` bump).
Recursion and player-defined functions are still not built.

**Why now, before a playtest.** MS14 said to play before adding more. The
user decided otherwise on 2026-09-30: their subscription ends around
2026-10-10, so they want the game developed as far as possible now, will
playtest afterwards and bring the notes to the next development month. They
are also asked to play a little every day meanwhile, so early notes can be
fixed in this month.

## Part 1 — Foundations 2 → 12

Foundations had two puzzles, both array scans. It now teaches the language
itself — IF / ELSE, comparisons at an edge, FOR (and that it stops before
its TO value), WHILE (including a loop that must not run), FLOOR DIVIDE and
REMAINDER, AND / OR — before the Arrays world. The two old puzzles keep their
place at the front (tests and the U1 walkthrough use Warm Readings); the new
ones follow by tier.

| # | Puzzle | Tier | Mode | Inputs → output | What it teaches | The trap (its reject) |
|---|---|---|---|---|---|---|
| 3 | Museum Tickets | 1 | build | age → price | IF chains, three bands | ages exactly 6 and 65 (`≤ 6` / `> 65`) |
| 4 | Stair Lights | 1 | build | steps, gap → lights | FOR, REMAINDER | the top step (a loop TO `steps` misses it) |
| 5 | Party Tables | 1 | edge | guests, seats → tables | FLOOR DIVIDE, REMAINDER | exact fits and 0 guests (always `+ 1`) |
| 6 | Doubling Jar | 1 | edge | coins, goal → weeks | WHILE | a jar already at the goal (first week counted before the check) |
| 7 | Digit Wheels | 1 | edge | number → digits | WHILE, FLOOR DIVIDE | 0 has one digit (`while > 0` gives 0) |
| 8 | Three Planks | 2 | build | a, b, c → yes / no | AND, strict comparison | flat frames (`≥`); only one side checked |
| 9 | Lighthouse and Bell | 2 | build | seconds, flash, ring → count | exactly one of two conditions | shared seconds (OR); the last second (loop TO `seconds`) |
| 10 | Longest Dry Spell | 2 | build | rain → days | running and best values | a spell that runs to the last day |
| 11 | Hill Tops | 2 | build | heights → count | neighbours with GET ELEMENT | flat tops (`≥`) |
| 12 | Lift Trips | 2 | build | weights, capacity → trips | a running load, a final group | an exact fit (`≥`); an empty queue (starting at one trip) |

Each has an independent oracle in
`packages/algorun_content/lib/src/oracles/foundations.dart` (a division, an
inclusion–exclusion count, bit length, sorting, every start day, explicit
trip lists — never the reference's loop), a reference built with editor
commands, one or two rejects that pass both visible cases and fail a hidden
one with `wrongAnswer`, two illustrative visible cases with different
answers, hidden cases on every edge, Turkish title, story and hints.
Budgets are about twice the reference's worst case; block limits are
generous for a first world (1.6 × the reference, at least + 6).

`content/capabilities.json` gained the family **`control_flow`** (IF / ELSE,
WHILE, FOR, REMAINDER, FLOOR DIVIDE on plain numbers). The language always
could; the audit had no family for a puzzle without a list.

**How it was produced.** A generator in the session scratchpad (not in the
repository) built each reference and reject with the editor's commands,
took every expected answer from the oracle, checked that the reference
passes, that each reject passes the visible cases and ends in its verdict,
and that the reference and the oracle agree on 200 random inputs; the
answers were then read against the stories by hand.

### Result

Validator `PIPELINE 95 of 95 campaign puzzle(s) accepted, 5 probe(s)
checked` · `OK 100 puzzle(s), 7 warning(s)` (the seven known ones; the new
puzzles only get "related" notes — same loop-and-IF shape, different
pattern). Engine 350, content 86, Flutter 405 tests pass; the campaign
regression test builds every new reference by taps at 360 × 800. Tests that
counted 85 puzzles or two Foundations puzzles now read the manifest or say
95 / 12. A new puzzle with only number inputs and no variables was checked
in the browser at phone size.
