# Milestone 14 — second content batch

Content only. The MS12 pipeline is unchanged. Recursion and player-defined
functions were not built. Worlds 09 (heaps) and 12 (backtracking) stay empty.
No already-shipped puzzle was edited, so no `version` bump. Unlock rules are
unchanged.

The batch is **47 puzzles** (85 campaign puzzles in total, plus the same 5
unlisted probes). It stops there for a real playtest. Do not continue toward
the ~300 coverage target until that playtest says what is missing.

## What was added

Appended to the existing worlds, in the same order the worlds already had:

| World | New puzzles |
|---|---|
| 02 Arrays | First Descent, Second Highest, Even Prefixes, Nested Distinct, Loudest Pair |
| 03 Hash Maps | Pair Tickets, Same-Value Span, Shared Values |
| 04 Two Pointers | Exact Gaps, Pairs Under, Sorted Union, Closest Gap |
| 05 Sliding Window | Windows at Least, One Dropout, Peak Windows |
| 06 Stack & Queue | Counter Sum, Josephus Line, Ticket Minutes, Stack Sorted |
| 07 Linked Lists | Tail Lamp, Cold Cars, Named Car, End Gap, Rising Links |
| 08 Trees | Left Vine, Right Marks, Lone Tree, Node Census, Leaf Census, Lowest Leaf |
| 10 Graphs | Platform Doors, Direct Hop, Silent Stops, Scout Reach, Scout Last, Biggest Patch, Source Radius, Last Layer |
| 11 Greedy | Cookie Gifts, Dock Overlap, Leap Reach |
| 13 DP | Plank Ways, Step Toll, Aisle Cost, Open Lanes, Diagonal Haul, Pack Bins |

Modes in the batch: build, budget, edge, optimize (baseline 5× or 8×), and
restricted (a memory cap). Each puzzle has:

- an independent oracle in `packages/algorun_content` (not the reference),
- a reference graph built with editor commands, replayed by the validator,
- one reject that passes every visible case and ends in the declared verdict
  (`wrongAnswer`, `operationLimit`, or `memoryLimit`),
- Turkish title, story, and hints; block names stay English.

`content/coverage.json` was regenerated.

## Validator

```
PIPELINE 85 of 85 campaign puzzle(s) accepted, 5 probe(s) checked
OK 90 puzzle(s), 7 warning(s)
```

The seven warnings are the same as before: world 12 still requires untaught
recursion and never opens, and the five probes are unlisted.

## Not done here

Flutter is not installed in the environment that generated this batch, so
`flutter test` and an emulator pass were not run there (the review below ran
them). The widget tests that
hardcode the campaign size were updated to 85 (`campaign_test`,
`campaign_regression_test`, `localization_ui_test`, `responsive_test`).
`dart test` in `algorun_engine` and `algorun_content` is the check that was
run. The new puzzles are covered by `campaign_regression_test` when Flutter
is available: it builds each reference through the picker.

## Review and integration (2026-09-25)

An independent review before merging into `main`. The QA commit named in the
hand-off (`48ecd94`, `docs/MILESTONE_14_QA.md`) was never pushed — GitHub
answers "No commit found" — so its numbers could not be used; everything
below was re-checked from the content itself.

**How it was checked.** The validator, the three test suites, and a scratch
cross-check outside the repository: for each of the 47 puzzles a solver
written *from the story text alone*, compared with the fixtures, the oracle
and the reference program on every fixture plus ~300 random inputs per
puzzle (14 596 runs), and a scan of the fixtures for answers a constant
program would get right.

### Fixed

| Severity | Finding | Fix |
|---|---|---|
| critical | Exact Gaps (every answer 0), Stack Sorted (every answer true) and Last Layer (every answer 1) were solved by a program that returns a constant. | Cases with other answers (pairs at the gap, impossible wagon orders, wide last layers). The validator now refuses a puzzle whose cases all expect one answer (level 4 error, with a test). |
| critical | Step Toll: the story and hint 2 let you jump from the start straight to the second stone; the reference, oracle and fixtures always charge the first stone (`[2, 2]` → 4; the story gives 2). | Story and hint 2 (English and Turkish) now say you start on the first stone and pay it. Nothing else changed. |
| critical | `test/campaign_test.dart` failed: it expected the four MS12 Arrays puzzles to open the next worlds; Arrays now lists nine. | The test reads the world's list from the manifest. |
| important | Visible cases did not teach: 27 of 47 puzzles showed only empty or one-element inputs, and in 17 a constant passed every visible case (the generator picked the two cheapest cases the reject survives). | Every puzzle has two illustrative visible cases that its reject still passes (the MS12 rule). The old visible cases stay as hidden edge cases; weak hidden sets gained discriminating cases. No answer, algorithm or story (other than below) changed. |
| important | New tier-2 entry puzzles were appended after the tier-3/4 ones, so Linked Lists, Trees, Graphs and DP still opened on tier 3. | Each world lists its puzzles by tier (stable; equal tiers keep their order). Last Layer's text no longer points at Source Radius, which now comes after it. |
| important | About twenty oracles repeated their reference's algorithm (DP tables, greedy walks, two pointers, sliding windows, the Ticket Minutes closed form), which the authoring contract forbids. | Replaced with brute force or a direct reading of the definition (every pair, every window, every path, every subset, the queue simulated minute by minute, union-find, relaxation). |
| important | Ambiguous stories: Leap Reach (exact leap or up to the number?), Scout Last (mark on push or on pop — the answers differ), Counting Out (story says n and k, inputs are `people` and `count`). | Stories say it (English and Turkish). |
| important | Restricted puzzles' memory caps equalled the tempting set on one element, so no meaningful visible case could exist. | Nested Distinct 2 → 4 and Exact Gaps 1 → 5 memory cells; longer hidden shelves / rows still exceed them. Their operation budgets follow the batch's own rule (509 → 568, 463 → 536). |
| important | The largest programs had block budgets of 1.10–1.17 × the reference (MS12 puzzles ≈ 1.3 ×): a different but reasonable build ran out of blocks. | Sorted Union, Peak Windows, Last Layer, Aisle Cost, Diagonal Haul and Open Lanes raised to ⌈1.3 × reference⌉. |
| minor | Hint wording (Lone Tree, Leaf Census, Named Car, Platform Doors, Lowest Leaf); the coverage test failed on a Windows checkout with CRLF line ends. | Reworded; the test normalises line ends. |

`metrics` in 24 reference files were re-recorded for the new fixtures.

### Not changed (decisions for the user)

- **World completion still needs every listed puzzle** (MS11 rule). Arrays
  is now 9 puzzles before Hash Maps, Two Pointers, Stack & Queue or Greedy
  open; Graphs is 13. A mastery threshold would be an unlock-rule change.
- **Budgets of correctness puzzles** stay at ~1.4–2.8 × the reference, like
  the MS12 ones; a much slower but correct build can still hit OPERATION
  LIMIT on the largest case.
- `packages/algorun_content/tool/ms14_*.dart` is the draft generator. **Do
  not re-run `ms14_emit.dart`**: it would overwrite the reviewed fixtures,
  stories and budgets.
- Some rejects can only be satisfied by narrow visible cases (Lone Tree,
  Leaf Census, Node Census, Biggest Patch, One Dropout, Diagonal Haul, Aisle
  Cost, Open Lanes, Leap Reach, Step Toll): their visible cases are
  illustrative but simple by construction of the MS12 rule.

### Result

Validator `PIPELINE 85 of 85 campaign puzzle(s) accepted` · `OK 90
puzzle(s), 7 warning(s)` (the seven known ones). Story-based solvers,
fixtures, oracles and references agree on all 14 596 runs. Engine 350,
content 86, Flutter 364 tests pass; `flutter analyze` is clean.

## Next

Play the batch. The following content batch, and any language work
(recursion / player functions), waits on those notes.
