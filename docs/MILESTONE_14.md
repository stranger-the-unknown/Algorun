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
`flutter test` and an emulator pass were not run. The widget tests that
hardcode the campaign size were updated to 85 (`campaign_test`,
`campaign_regression_test`, `localization_ui_test`, `responsive_test`).
`dart test` in `algorun_engine` and `algorun_content` is the check that was
run. The new puzzles are covered by `campaign_regression_test` when Flutter
is available: it builds each reference through the picker.

## Next

Play the batch. The following content batch, and any language work
(recursion / player functions), waits on those notes.
