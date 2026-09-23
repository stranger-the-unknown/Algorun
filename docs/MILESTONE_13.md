# Milestone 13

**MS13 COMPLETE.** Mobile UX polish and real-device usability: the editor,
the screens around it and the Android shell were reworked so the existing
38-puzzle game is comfortable on a phone. No new language capability, no
new campaign content, no architecture change.

Previous milestone commits: L1 `d850525`, MS11 `033f3ec`, MS12 `c3f3d5d`.

## How it was verified — emulator only

**Testing was done on an Android emulator, not on a physical device.** No
phone was connected to this machine. BlueStacks was available but the
official emulator was used instead, because its screen size and density can
be set exactly per test (`adb shell wm size / wm density`).

| | |
|---|---|
| Emulator | Android Emulator 37.1.11, Windows WHPX acceleration, headless, software rendering (`-gpu swiftshader_indirect`) |
| AVD | Pixel 7 profile, `system-images;android-35;default;x86_64` (Android 15, AOSP), 1080 × 2400 @ 420 dpi |
| Phone sizes (dp) | 412 × 915 (native), 390 × 844 (`wm size 1170x2532`, density 480), 360 × 800 (`wm size 720x1600`, density 320); landscape by `wm user-rotation lock 1` |
| Navigation | three-button navigation bar (the harder case for insets) |
| Builds | `flutter build apk --debug` for the checklist, `flutter build apk --release` for timing |
| Driving | `adb shell input tap / swipe` located through the app's own accessibility tree (`uiautomator dump`), screenshots with `screencap`, logs through `flutter run --use-application-binary` |

Widget tests cover the same sizes (and more) at every commit; the emulator
pass is what found the bugs listed under *Stress-test findings*.

## Stress-test findings (before the fixes)

Found on the emulator or by the new tests, then fixed:

| Finding | Where | Fix |
|---|---|---|
| **RUN was hidden under the navigation bar** at 360 × 800 (Android 15 draws edge to edge) | puzzle screen | the RUN bar keeps clear of the system bars; every screen respects side insets in landscape |
| **The number pad never appeared** — numbers could not be changed on a device. The theme gave `FilledButton` an infinite minimum width; the pad's DONE button sits in a `Row`, so the sheet failed layout and only its dimmed barrier showed. Tests never used the app theme, so they missed it. | theme | a finite minimum (64 × 48); a test under the real theme types 42 and −42 and proves it (it fails with the old theme) |
| **INCREMENT / DECREMENT could never be placed.** The picker previewed them without a variable, which the connect rule refuses, so they were never offered; a palette tap was refused. The first campaign puzzle's reference uses INCREMENT. | `GraphTyping.compatiblePlacements` | offered once per number variable, like GET (`INCREMENT count`); the palette opens the picker for them |
| **One placement was two undo steps**: one UNDO undid only the connection and left an invisible block counted against the block budget | editor controller | a placement is one atomic step |
| **Delete left the children behind**, invisible but counted by `maxBlocks`; a long-press deleted instantly | editor | delete removes the block and everything inside it, as one step; long-press only selects |
| A program saved by the editor was **rejected by the content pipeline's replay** (it stores ELSE as a one-item list, the replay only read a ref) | content tooling | the replay reads both shapes (same program) |
| An empty value slot said **"This piece does not fit here."** | lowering message | "This block needs a value." (key / node / graph likewise) |
| At 360 × 800 with the brief open the program had ~125 dp; the empty program's "add step" was below the fold | puzzle layout | brief, hints and givens scroll with the program; an empty program is one large "add step" card |
| The last "add step" could not scroll above the picker sheet | script | room past the end of the program |
| Name sheet narrow and centred | sheets | every sheet spans the width |
| Light system navigation bar and a white launch flash | Android theme | dark window theme and launch background |
| Undo left "UNDO brings it back" on screen; "1 blocks" | editor | messages clear on undo / redo; singular / plural |
| Font ×1.6 overflowed the hint row and the wide palette rail | layout | flexible rows; overflow fails the responsive tests |
| Holes, name chips and "add step" were merged into their instruction's accessibility node | semantics | each is its own node (`Semantics(container: true)`) |

## Editor UX

The vertical, tap-to-place editor stays (no canvas, no text entry).

**Selection.** Tap or long-press an instruction or value to select it (accent
2 px outline, haptic tick). The **selection bar** replaces the palette while
something is selected: `SELECTED  WHILE · 11 blocks` and

| Instruction | Value |
|---|---|
| UP, DOWN (within its list), OUT (after the block that holds it; out of ELSE lands after the IF), IN (into the block just above, at the end), COPY (the instruction with everything inside, just below it), DELETE (with everything inside) | REPLACE (empties the slot and opens its picker), DELETE (empties the slot) |

Every action is **one undo step** and is made of the engine's own commands
(`DisconnectCommand` + `AttachStatementCommand`, `AddBlockCommand` +
`ConnectCommand`, `RemoveBlockCommand`) applied atomically, so
`GraphTyping.canConnect` still decides what is allowed. Android back first
lets go of a selection, then leaves the puzzle.

**Insertion.** Tapping a slot or "add step" scrolls it into the top part of
the screen, then opens the **typed picker**: *Choose a piece — For the
condition of WHILE. Only pieces that fit this slot are listed.* with a close
button; it lists exactly `GraphTyping.compatiblePlacements` within the
allowlist (the UI never type-checks). A new block is selected and scrolled
into view, unfolding whatever hides it. The palette stays for browsing:
instructions go to the selected list or the end of the program, values into
the selected slot, INCREMENT / DECREMENT open the picker.

**Nesting.** Each C-block body has a 2 px rail in the block's colour and a
label (THEN / DO / ELSE); nesting costs ~24 dp per level. A C-block folds to
one line with *Folded · 66 blocks inside* (tap to open); the menu has *Fold
every block*, *Unfold every block* and *Clear the program* (undoable). Folds
are saved with the draft in the blocks' own `collapsed` field (execution
ignores it); a fold is not an undo step and does not mark the puzzle
"edited since the last run".

**Density.** Instruction rows ≥ 48 dp, value pills 36 dp (40 wide), empty
slots 40 × 64 dp with a `+` and their name, variable names squared with ▾ so
they never read as values. Long names wrap.

**Bottom bar.** UNDO · REDO · `23 / 40 blocks` (what `maxBlocks` counts;
warning icon and colour when over) · *Saved on this device* / *Practice · not
saved* · RUN (shows RUNNING while the cases run).

**Restored programs** drop blocks the program does not reach (left by the old
delete): they never ran and only counted against the budget.

## Layout rules

| Screen height / width | Layout |
|---|---|
| ≥ 560 dp high, < 840 wide (phones, portrait) | feedback line · scroll (brief, hints, givens, program) · palette (two rows) or selection bar · run bar |
| < 560 dp high (landscape phones) | as above without the palette (the picker is the insertion path) |
| ≥ 840 dp wide | palette as a 280 dp side rail |
| every screen | side insets respected; bottom bar above the navigation bar; lists scroll |
| system font | honoured up to ×1.6 (`MediaQuery.withClampedTextScaling`); larger values are capped |

## Other screens

- **Results**: a verdict card with icon + headline + one-sentence meaning for
  every `ResultKind` (Correct, Wrong Answer, Runtime Error, Operation Limit,
  Memory Limit, Depth Limit, Invalid Program), the engine's detail under it;
  PROGRESS lines; visible cases; hidden cases as a count only; **WHAT IT
  COST** as a table of used vs budget (steps, memory cells, depth, blocks,
  hints) with a warning icon on the row over budget. After a solve: **NEXT:
  <PUZZLE>** (the next open unsolved puzzle in campaign order) and BACK TO
  PUZZLE. After *Invalid Program*, BACK selects the block to fix and says
  why.
- **Worlds**: what each world teaches, progress bar + *n of m solved*, lock
  icon + *Locked — learn arrays first*, CURRENT.
- **Puzzles**: world title in the app bar, *n of m solved · teaches …*, tier
  and mode per puzzle (*Tier 3 · budget*).
- **Locked puzzle**: why, and how concepts are learned.
- **Home**: progress bar; scrolls on short screens.
- **Puzzle**: *Solved. Keep improving, or try the next one.* with **BEST**
  (Load best solution); hints as cards, *counted, never charged*.
- **Settings**: debug builds only, *Developer → Open the editor stress
  probe*.

## Accessibility

- Contrast (WCAG): `faint` text raised from 4.1:1 to 5.9:1 on the
  background (5.1:1 at worst), `danger` from 4.7:1 to 5.7:1; empty-slot
  outlines 3.6:1. Small labels never below 11 sp.
- Touch targets: icon buttons, chips and palette rows 48 dp; instruction rows
  48 dp; value pills 36 dp inside their 48 dp rows.
- Colour never alone: every verdict, lock, solve and over-budget value also
  has an icon and words.
- Semantics: holes (*Empty condition slot*), name chips (*Variable count,
  change*), "add step", selection-bar actions, pad keys (*Change sign*,
  *Delete last digit*), − / + (*One less* / *One more*) are separate labelled
  nodes; duplicate progress-bar and row-icon labels removed.
- Font scaling to ×1.6 without overflow on every target size (tested).
- **Not verified with TalkBack** itself; the accessibility tree was inspected
  with `uiautomator`.

## Android behaviour (emulator)

| Check | Result |
|---|---|
| Back button | results → puzzle; puzzle with a selection → selection cleared, then → list; worlds → home |
| Background | an edit made 0.2 s before HOME (inside the 800 ms debounce) was written (`onHide` / `onPause` flush) |
| Process recreation | `am kill` of the backgrounded app, relaunch: CONTINUE reopened the puzzle with that edit |
| Insets | status bar, three-button navigation bar, landscape side bar: nothing covered (after the fixes) |
| Keyboard | never shown: `dumpsys input_method` → `mInputShown=false`; no `TextField` / `EditableText` anywhere (tests) |
| Upgrade | the MS12 build's save was read by MS13 unchanged |

## Real-device checklist (emulator, 360 × 800 unless noted)

| # | Step | Result |
|---|---|---|
| 1 | Fresh launch (`pm clear`) | ENTER, *0 of 38 puzzles solved* |
| 2 | Open first puzzle | Foundations → Warm Readings; empty-program card |
| 3 | Insert blocks | SET count TO 0 (name sheet, number pad), FOR EACH r IN readings, IF, INCREMENT count, RETURN count — all by taps through the typed picker |
| 4 | Deeply nested editing | stress probe: SET added in the innermost THEN (5 levels), moved OUT twice (stayed in view), 4 × UNDO back to 82 blocks; fold all / unfold |
| 5 | Undo / redo | 11 → 10 → 11 blocks |
| 6 | Run | RUN → results |
| 7 | Hints | SHOW HINT 1, counted as *1 hint* in WHAT IT COST |
| 8 | Wrong answer | GREATER OR EQUAL: WRONG ANSWER, *5 of 6 hidden cases passed* |
| 9 | Performance failure | The Smallest Cart with its slow draft (save prepared by the game's own codec): OPERATION LIMIT, *650,000+* vs 130,000 with a warning icon |
| 10 | Correct completion | REPLACE → GREATER THAN: CORRECT, *Puzzle solved.*, NEXT: HIGHEST TIDE |
| 11 | Leave puzzle | edit, HOME, process killed |
| 12 | Relaunch | *1 of 38*, *Last played: Warm Readings · Foundations* |
| 13 | Continue | reopened Warm Readings |
| 14 | Restore program | the edited draft (9 blocks) |
| 15 | Load best solution | BEST → 11 blocks, *UNDO brings back the program you had* |
| 16 | Open later world | Arrays (after Foundations), CURRENT tag |
| 17 | Locked puzzle / world | Hash Maps: tap does nothing, *Locked — learn arrays first* |
| 18 | Reset progress | confirmation dialog → ENTER, *0 of 38* |
| — | Other sizes | stress probe at 390 × 844 and 412 × 915; editor in landscape 800 × 360 |
| — | Invalid program | an empty slot: INVALID PROGRAM; BACK selects the block |

## Performance

The interpreter was not touched. UI measurements:

| Measure | Result |
|---|---|
| Widget test, debug: select + undo on the 82-block probe | 72–128 ms per edit and rebuild (test-mode timing) |
| Release APK, emulator (software GPU): scrolling Busiest Level (90 blocks) | median frame interval 27.2 ms, p90 39.1 ms |
| Same, the plain Worlds list, for comparison | median 21.5 ms, p90 41.7 ms |
| Release APK, emulator: RUN → results on Busiest Level (8 cases, 14,345 steps worst case) | results on screen by the first capture, 0.4 s after the tap |

The emulator renders in software, so its frame times are not a phone's; the
90-block editor scrolls within ~25 % of a trivial list on the same emulator,
so the editor is not the bottleneck. Top-level instructions are built
lazily; nested bodies are built with their block. Frame timing on a real
phone is still to be measured.

## Engine and content changes (small, each a blocker)

- `GraphTyping.compatiblePlacements` offers INCREMENT / DECREMENT per
  variable (the connect rules are unchanged). +3 engine tests.
- Lowering: clearer messages for an empty value / key / node / graph slot.
  No test asserted the old wording.
- Content replay: reads ELSE stored as a one-item list. +3 content tests.
- New unlisted probe `world_01/ms13_stress_probe` with a reference (the
  pipeline checks it: replay, lowering, 8 cases). The campaign is unchanged:
  38 puzzles, all accepted; coverage unchanged.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` / `dart test` | no issues / **350 passed** (347 + 3) |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues / **85 passed** (82 + 3) |
| Content validator | `PIPELINE 38 of 38 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 43 puzzle(s), 7 warning(s)` |
| Flutter `analyze` / `test` | no issues / **235 passed** (114 + 121) |
| `flutter build apk --debug` | built |

New Flutter tests:

- `editor_actions_test.dart` (13): placement is one step; delete a subtree
  and a value; duplicate; up / down / out / into, out of ELSE; available
  moves; folds saved, restored, not an edit; fold all and reveal; strays
  dropped on restore; fold-only save keeps *edited since run*; singular;
  problem focus.
- `stress_probe_test.dart` (6): the 82-block program built through typed
  placement equals its reference file and runs correct; on 360 × 800:
  scroll, select, delete, undo, redo; deep insertion through the picker
  (instructions only, revealed); fold every block, restore folded, unfold by
  tap; back clears the selection; rebuild time guard.
- `responsive_test.dart` (11): home → worlds → continue → hint → RUN → NEXT →
  back on 360 × 800, 390 × 844, 412 × 915, 800 × 360 and 915 × 412 at font
  ×1 and ×1.6 (any overflow fails), RUN / NEXT clear of the system bars, no
  text field; font ×2 capped.
- `campaign_regression_test.dart` (77): for each of the 38 puzzles, the
  palette reads as words, the reference is rebuilt by taps through the picker
  and runs with the reference's operation count, save / restore is exact; it
  renders, runs and reports CORRECT at 360 × 800 without naming a hidden
  case.
- `screens_polish_test.dart` (11): every verdict's icon and sentence, hidden
  as a count, NEXT only after a solve, `nextPuzzle`, world and puzzle-list
  wording, lock icon label.
- `literal_sheets_test.dart` (3): the number pad and name sheet under the
  real theme; INCREMENT per number variable; an empty slot after RUN.
- Updated: the results-table assertions in four existing tests
  (`costRow` helper), two finders that now scope to the program.

## Content-generation readiness

The editor can now build every shipped reference by taps (tested for all
38), including INCREMENT, ELSE, deep nesting and 80–90-block programs on a
360 dp phone. Authoring a new batch through the MS12 pipeline is unblocked
from the UI side. Keep new references inside what the picker offers (the
campaign regression test checks it for every listed puzzle).

## Known limitations

- **No physical device**; emulator frame times are software-rendered.
  TalkBack was not run.
- **No drag and drop.** Blocks move with UP / DOWN / OUT / IN one step at a
  time; moving across distant branches takes several taps.
- Moves check the drop with `GraphTyping`, but narrowing facts that change
  with a new position are reported by lowering at RUN, not at the move.
- RETURN is still not checked against the puzzle's output type (an empty
  RETURN is a wrong answer, not an invalid program).
- In landscape the brief and givens take most of the height (they scroll);
  the palette is hidden below 560 dp.
- The picker is a flat list per category; very long allowlists are not
  searchable.
- The stress probe opens from Settings in debug builds only.
- `puzzle_screen.dart` was reformatted by `dart format` while rewritten.

## Confirmation

Milestone 13 is complete. Do not start another milestone from this
document.
