# E1 — Editor comfort for long programs

**E1 COMPLETE**: all five goals, plus one accessibility fix found on the
device; emulator pass done at 360 × 800 dp (see "Emulator").
Branch `claude/e1-editor-8a8a35`, based on `main` = `4fbbfed`. Requested by
the user on 2026-11-18, when the freeze was lifted, as one of five sessions
running side by side (T1 tracing, **E1 editor**, L3 new blocks, M1 puzzle
kinds, MS16 content).

The longest reference solutions were tiring to build one step at a time:
Cheapest Crossing 160 blocks, Maze Paths ~100, Seating Plan ~80. E1 makes a
long program comfortable on a 360 × 800 phone. No change to the engine, the
block catalog, any puzzle, budget or validator rule, the save format or the
architecture.

`docs/PROJECT_STATE.md` and `README.md` are **not** edited by this branch
(the coordinator merges five branches); what they should say is at the end
of this file.

## What changed, by goal

One commit per goal, in this order, then one fix and this document.

### 1. Search in the picker and the palette — `a6bf914`

- A search button in the piece picker (`picker-search`) and in the palette
  (`palette-search`, phone row and side rail) opens a search box.
- A block answers to its English name as the editor shows it (`GET
  ELEMENT`), to its Turkish name from the block reference
  (`blockGuide[id].tr`: `döngü` finds WHILE), and to the variable or function
  it names (`total`, `INCREMENT i`, `CALL fact`). Any part of a name, words
  in any order, any case; Turkish letters fold onto their plain neighbours
  (`dongu` = `döngü` = `DÖNGÜ`).
- Search only **narrows**: the picker still lists what
  `GraphTyping.compatiblePlacements` accepts for the slot, the palette what
  `blocks.allow` gives. A block the puzzle does not allow is never listed.
- **The keyboard.** MS13 promised "no TextField, no system keyboard". That
  still holds for programming: the search box is the one text field of the
  editor and is only *built* after the player taps the search button, so
  nothing opens a keyboard by itself (the three older tests that assert
  `find.byType(TextField), findsNothing` pass unchanged).
- The picker sheet now sizes itself (`isScrollControlled`): the same 9/16 of
  the screen as before, lifted above the keyboard while searching.
  Everything under its title scrolls (the "For the condition of WHILE…"
  sentence included), so it fits a 360 × 640 phone at font ×1.6.

### 2. Copy and paste — `007cce3`

- **COPY** (the copy icon in the selection bar's title row, key
  `selection-copy`, for instructions *and* values) takes the selected block
  with everything inside it to the editor's clipboard. The program does not
  change: no undo step, no edit.
- **PASTE** is offered first in the picker of any slot the copy fits (key
  `picker-paste`, under the heading COPIED): tap an "add step" row or an
  empty value slot, choose PASTE. The copy is selected and scrolled into
  view; one UNDO takes all of it back.
- **Typing.** A paste is rebuilt with the engine's own commands
  (`AddBlockCommand` + `ConnectCommand` per block), root first and then
  top-down, so `GraphTyping.canConnect` decides every connection in the place
  it lands in: a number does not go into a condition, an instruction not into
  a value slot, `SET total TO c PLUS 1` not outside `IF c IS NOT NOTHING`
  (*This value may be empty here…*). `canPaste` asks by running the same
  commands without keeping the result. A refused paste changes nothing and
  is not an undo step.
- The old one-tap copy **below** the block stays where it was in the
  selection bar. Its label changed from COPY / KOPYALA to **CLONE / ÇOĞALT**
  (tooltip still *Duplicate* / *Çoğalt*), because COPY now means the
  clipboard. (DUPLICATE was tried first: it pushed DELETE off a 360 dp bar.)
- Neither COPY nor CLONE multiplies a block the puzzle does not allow
  (`blocks.allow`): a FUNCTION, or a block a starter program gave. Inside a
  FUNCTION a paste that reads a given the function cannot see is refused,
  like the picker refuses to offer it.
- The clipboard belongs to one `EditorController` (one visit to one puzzle).
  It is not saved and does not travel between puzzles — see "Decisions".

### 3. Folding — `826ecfc`

Folding the body of IF / WHILE / FOR / FOR EACH / FUNCTION, the count of
hidden blocks (*Folded · 6 blocks inside*), fold all / unfold all and saving
the folds exist since MS13. E1 adds:

- **A fold never hides the selection.** Folding a block that holds the
  selected one moves the selection to the folded block (the outermost one
  for *fold all*), so the selection bar never acts on something off screen.
- Tests on the longest programs and on every body kind (below).
- `EditorController.hiddenCount(id)`, and a key on each fold button
  (`fold:<blockId>`).

### 4. Long press, then drag — `829777e`

- Long press an instruction, then move the finger: the block is picked up.
  A plain long press still only selects (the drag starts after 8 dp of
  movement). UP / DOWN / OUT / IN stay in the selection bar, unchanged.
- **Where it lands** is the gap between two instructions nearest to the
  finger, shown by a line as wide as that list (so the indentation says
  which body). Empty bodies take a drop on their "add step" row.
- **Valid and invalid places.** The line is in the accent colour where the
  drop is accepted and in the danger colour where it is not; the tag under
  the finger then says why, in the player's language. Lifting the finger on
  a refused place moves nothing and puts the reason on the feedback line.
- **Typing.** `EditorController.checkMove` runs the engine's own detach +
  attach on a copy of the graph, and then asks `GraphTyping.canConnect`
  again for every connection *inside* the moved block in its new place. A
  connection that was fine before and is refused there refuses the drop:
  a value that may be empty outside its check, a BREAK carried out of its
  loop inside an IF. (Connections that were already refused before the move
  do not count, so a program that is being repaired can still be
  rearranged.) A block cannot be dropped inside itself. FUNCTION blocks,
  values and ELSE are not picked up.
- **Scrolling while dragging.** Within 72 dp of the top or bottom edge of
  the program the list scrolls by itself (up to 900 dp/s), and the drop place
  follows. The whole program stays built during a drag.
- **Undo.** A drop is one `GraphHistory` step (one batch of the engine's
  `DisconnectCommand` + `AttachStatementCommand`); starting, moving and
  cancelling a drag are none.
- Pointer moves never go through the controller or Riverpod: the drag layer
  repaints its own overlay; the controller is told only at the start and the
  end (`beginDrag` / `endDrag`), which dims the dragged block.

### 5. Finding your way — `0e1aa47`

- **Program outline** (app bar, list icon, *Program outline* / *Program
  özeti*): every instruction on one numbered line, indented by nesting, in
  the editor's own words (`SET x TO (readings GET ELEMENT i)`). A tap goes
  to that block: selected, scrolled into view, whatever was folded around it
  opened. The sheet opens on the selected block's line.
- **START / END** (BAŞ / SON) at the top of the outline jump to the first
  instruction and to the "add step" row after the last one, without touching
  the selection.
- Line numbers live in the outline, not on the blocks: a number gutter would
  cost width that deep nesting needs on a 360 dp phone.

### 6. Found on the device: buttons a screen reader could not press — `f8eaab4`

Not one of the five goals. The emulator's accessibility dump showed "add
step", the empty value slots, the name chips and the selection bar's
actions as labelled but not clickable: each is a `Semantics` node that hides
its children (`excludeSemantics: true`) and did not offer the tap itself.
That was so since MS13. Since UP / DOWN / OUT / IN stay in the bar *for*
accessibility, they have to be pressable: those nodes now carry `onTap`
(`AddStepButton`, `HoleWidget`, `NameChip`, the empty-program button,
`_BarAction`), as do E1's PASTE chip and outline lines. A disabled action
still reports itself disabled and offers no tap.

## New and changed API

`lib/editor/` — everything here is additive unless marked **changed**.

| Where | What |
|---|---|
| `block_search.dart` (new) | `BlockSearch.fold / words / haystack / matches(catalogId, query, {literals})`. |
| `block_search_field.dart` (new) | `BlockSearchField(onChanged, onClose)`: the search box. |
| `block_drag.dart` (new) | `BlockDragLayer(controller, child)` + `BlockDragLayerState` (`press` / `move` / `release` / `cancel`, `target`, `targetAllowed`), `DropTarget(to, index)`, `DropAnchor.tile / .listEnd`, `BlockDragHandle`. |
| `block_text.dart` (new) | `BlockText.line(graph, id)`, `BlockText.value(graph, id)`: a block in words. |
| `program_outline.dart` (new) | `programOutline(graph)` → `List<OutlineLine>`; `ProgramOutline.show(context, controller)`. |
| `EditorController` | `clipboard` (`BlockClip`), `canCopy(id)`, `copySelected()`, `copyTree(id)`, `canPaste(to, {index})`, `paste(to, {index})`; `hiddenCount(id)`; `draggingId`, `canDrag(id)`, `beginDrag(id)`, `endDrag()`, `checkMove(id, to, index)` → `DropCheck`, `moveTo(id, to, index)`; `jumpTo(id)`, `scrollTo(id)`, `scrollToEnd()`, `EditorController.endOfProgram`. |
| `SelectionInfo` | new field `canCopy` (default false). `canDuplicate` is now also false for a block outside `blocks.allow`. |
| `ScriptView` | constructor **unchanged**. It now wraps its scroll view in a `BlockDragLayer` and builds the whole program while a drag is on. |
| `StatementTile` | constructor **unchanged**. It wraps itself in `DropAnchor.tile` + `Opacity`; its long press is now a `BlockDragHandle` (was `InkWell.onLongPress`). Without a `BlockDragLayer` above, a long press only selects, as before. |
| `revealWhenBuilt` | new optional `alignment` (default 0.3, as before). |
| `HolePicker.show` | **changed inside**: `isScrollControlled`, search, PASTE. Signature unchanged; still clears the hole on dismiss (`63ad3c6`). |
| `PaletteTray`, `BlockActionsBar`, `RunBar` | constructors unchanged. |
| `PuzzleEditor` (`puzzle_screen.dart`) | one more app bar button (key `open-outline`). The only edit outside `lib/editor/`. |

Strings (`app_en.arb`, `app_tr.arb`, generated code committed): added
`searchBlocks`, `closeSearch`, `noBlockMatches`, `actionDuplicate`,
`copyForPaste`, `pasteHere`, `clipboard`, `noticeClipCopied`,
`noticeClipCopiedWithInside`, `noticePasted`, `noticePastedWithInside`,
`noticeNotInsideItself`, `programOutline`, `outlineStart`, `outlineEnd`,
`goToStart`, `goToEnd`, `outlineLine`, `outlineEmpty`. Removed `actionCopy`
(replaced by `actionDuplicate`). The ARB entries were inserted next to
related keys, not appended, to keep merges with the other sessions small;
after merging, run `flutter gen-l10n` rather than merging `lib/l10n/gen/` by
hand.

## Decisions

- **Folds are saved** (kept as MS13 had it): written into the draft through
  `BlockInstance.collapsed`, restored on open, never an undo step and never
  "edited since the last run". Reason: a player folds a 160-block program to
  find their way in it, and finding it unfolded after every visit would undo
  that work; it costs nothing (the field already exists, lowering ignores
  it, the tests prove folded and unfolded programs lower to the same IR and
  run with the same cost). What is *not* saved: the selection, the
  clipboard and the search text.
- **The clipboard is per editor, not global.** A copy can only ever hold
  blocks the open puzzle allows, so pasting cannot bring a block into a
  puzzle that forbids it, and nothing new is written to the save.
- **A drag is stricter than UP / DOWN / OUT / IN.** The step buttons keep
  their MS13 rule (the block's own attach is typed; narrowing that changes
  with the new position is reported by lowering at RUN). A drop also
  re-checks what is inside the moved block. The buttons were left alone on
  purpose ("do not regress").
- **Search is by name only**: no descriptions, no categories (the category
  chips already do that).
- **Navigation is an outline in a sheet**, not floating buttons over the
  program (they would cover fold buttons and slots at the right edge) and
  not a number gutter (width).

## For the other sessions (merge notes)

- **T1 (step trace).** As of 03:55 on 2026-11-18 its branch does not touch
  `lib/editor/` (it draws the program with its own `trace_program_view`), so
  nothing of E1 reaches the trace screen. If a later screen reuses
  `ScriptView` read-only: the view now carries a `BlockDragLayer`, and
  `_dragHandle(...)` in `statement_tile.dart` is the one place both tile
  kinds get their tap and long press from.
- **M1 (starter programs, locked blocks, read-only predict view).** Its
  branch adds `EditorController.readOnly`, `isLocked(id)` and
  `holdsLocked(id)` and makes `selection.moves` empty for a locked block.
  E1's new entry points do not know about them. **After merging both, add
  three guards** (they are one line each, and M1's tests will not catch
  their absence because E1's gestures did not exist on its branch):
  - `canDrag(id)`: `&& !readOnly && !isLocked(id)` — otherwise a locked
    block can be dragged away, and a predict puzzle's program can be
    rearranged by a long press. (`BlockDragLayerState.press` calls
    `selectBlock`, which M1 already makes a no-op when read-only, then
    `canDrag`.)
  - `canCopy(id)`: `&& !readOnly` (copying a locked block is harmless only
    if its kind is in `blocks.allow`; E1 already refuses a kind that is
    not).
  - `paste` / `moveTo`: `if (readOnly) return null / false;` for safety; the
    picker that offers PASTE does not open in a read-only editor.
  M1 also hides the "add step" rows when read-only; they are now wrapped in
  `DropAnchor.listEnd(...)`, so that hunk will conflict textually (keep both:
  the `if (!controller.readOnly)` around the `DropAnchor`). A starter program
  loaded through `initialGraph` or `replaceGraph` needs nothing from E1.
- **L3 (new blocks).** Nothing in E1 names a new block. Search finds a block
  by `BlockChrome.labelOf(id)` at once and by its Turkish name as soon as
  `blockGuide` has an entry; the outline words come from the block's chrome
  layout and ports. A new C-block folds, drags and outlines like the others
  as long as its layout is `BlockLayout.cBlock`.
- Likely textual conflicts: `lib/editor/statement_tile.dart` (gesture
  lines), `lib/editor/script_view.dart` (the wrapper at the end of `build`),
  `lib/editor/editor_controller.dart` (additions in the middle of the
  class), the ARB files and `lib/l10n/gen/`.

## Tests

Six new test files, all under the real app theme (`buildAppTheme`), on a
360 × 800 phone unless said otherwise, with the campaign and references read
from the repository files. Shared helpers: `test/support/editor_harness.dart`
(`openEditor`, `editorOf`, `tapVisible`, `inScript`, `inSheet`).

| File | Tests | What it proves |
|---|---|---|
| `test/editor_search_test.dart` | 14 | Folding of Turkish letters; English and Turkish names, names of variables; every catalog block is found by its own label and an unknown block id does not throw. Palette: no text field until asked, a query narrows the row, the hit places the block, Turkish query in a Turkish UI, a block outside `blocks.allow` is never listed, closing restores the categories, the side rail. Picker: narrows the typed list, only what fits is ever listed, a dismissed sheet still clears the slot (`63ad3c6`), the sheet sits above a 300 dp keyboard, 360 × 640 at ×1.6. |
| `test/editor_clipboard_test.dart` | 16 | COPY changes nothing (same graph object, no undo step); PASTE brings the whole subtree under new ids as one undo step, redo; paste at a position; a value pastes only into a slot of its type; an instruction never into a value slot or an ELSE port; narrowing refuses a paste outside its check; the clipboard is a snapshot; folds travel; a block outside `blocks.allow` is neither copied nor cloned; CLONE unchanged. On the phone: copy a value → empty slot → PASTE → UNDO; an instruction with its body into another list; PASTE only offered where it fits; search and PASTE; Turkish and DELETE still reachable at 360 dp; the copy button's semantics. |
| `test/editor_folds_test.dart` | 15 | The five programs cover IF, WHILE, FOR, FOR EACH and FUNCTION. For `cheapest_crossing` (160 blocks), `maze_paths`, `seating_plan`, `hill_tops`, `warm_readings`: folded and unfolded lower to the same IR JSON and run correct with the same operations and block count; folding is no undo step; the folds restore from the saved program. The hidden-block count; the selection leaves a fold. On the phone: each body kind folds to one line with its count and opens again; the 160-block program folded still runs; Turkish. |
| `test/editor_drag_test.dart` | 23 | Controller: one undo step, redo; position semantics; into a body, into ELSE and out; never inside itself; BREAK outside a loop refused directly and when carried inside an IF; a value that may be empty refused; FUNCTION / value / ELSE not picked up; begin / end are not edits; on the 160-block program a spread sample of every (block, place) pair — each accepted drop leaves a structurally sound program and one UNDO restores the exact text. On the phone: a long press alone only selects and the step buttons are there; drag down the program (line, tag, dimmed block, nothing moves before the finger lifts, UNDO / REDO); drop on an empty ELSE and between instructions; a refused place is red, says why, takes no drop; the line turns from refused to accepted as the finger moves; Turkish reason; a block with its body; its own body is not a place; a cancelled gesture; a long press on a value still selects the value; the screen reader's long press. On the 82-block stress program: resting at the bottom edge scrolls more than a screen and the drop lands at the end in one undo step; the top edge scrolls back; a block four levels deep comes out to the top level. |
| `test/editor_outline_test.dart` | 11 | The words of a line (parentheses, FOR / FOR EACH / FUNCTION, empty slots); every instruction of **every shipped reference** (149 puzzles, > 1,500 lines) is one numbered line with a real name; numbering, depth, ELSE rows; folds do not hide lines and `jumpTo` unfolds; `scrollTo` / `scrollToEnd` leave the selection alone. On the phone: END and START on the stress program; a line selects, reveals and unfolds its block and the sheet reopens on it; the 160-block program in Turkish; 360 × 640 at ×1.6; an empty program. |

`test/editor_semantics_test.dart` (2 tests): through the semantics tree, a
name chip, MOVE DOWN / MOVE UP, "add step", an empty slot, PASTE and an
outline line each offer a tap and do their job when pressed; a disabled
action offers none.

Existing tests changed: none. (`test/support/editor_harness.dart` is new;
the selection bar's label change from COPY to CLONE touched no test.)

### Results on this branch

Baseline on `main` (`4fbbfed`) before any change, 2026-11-18: engine 398,
content 86, validator 149 of 149; Flutter 539 passed and 1 failed — the
MS13 timing guard *an edit on the 82-block program rebuilds quickly*
(< 1500 ms), which failed once while five sessions were compiling on the same
machine and has passed in every run since (it is a wall-clock test).

After the last feature commit (`0e1aa47`), one run of everything; `flutter
analyze` and `flutter test` were run again after `f8eaab4` (which changes only
`lib/editor/` and one test file, so the engine, the content package and the
validator were not re-run for it):

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` / `dart test` | no issues / **398 passed** (unchanged) |
| `packages/algorun_content` `dart analyze` / `dart test` | no issues / **86 passed** (unchanged) |
| Content validator | `PIPELINE 149 of 149 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 154 puzzle(s), 5 warning(s)`; `content/coverage.json` unchanged |
| `flutter analyze` | no issues |
| `flutter test` | **621 passed** (540 on `main` + 81: search 14, clipboard 16, folds 15, drag 23, outline 11, semantics 2) |
| `flutter build apk --debug` | built at `0e1aa47` (the build the emulator pass used); not rebuilt after `f8eaab4` |

## Known limits

- **Values are not dragged.** Only instructions are picked up; a value
  moves by COPY → PASTE (and DELETE of the original). A drag of a value
  would need drop targets on every slot.
- **A drop is typed where it lands, not everywhere.** Moving a block can
  still invalidate an instruction that stays behind (for example moving
  `SET x` below a use of `x` that relied on narrowing); lowering reports
  that at RUN, as before E1.
- **UP / DOWN / OUT / IN are less strict than a drag** (see "Decisions").
- **The clipboard holds one block** (with its subtree), per visit to a
  puzzle. There is no multi-selection: several sibling instructions are
  copied one at a time, or by copying the block that holds them.
- **Search needs the system keyboard**, the first place in the editor that
  does. It is opt-in (a button), and names are matched by substring only —
  no typo tolerance.
- **The outline is a snapshot** taken when the sheet opens; it is read-only
  (no reordering inside it) and does not show values that are too long for
  one line (ellipsis).
- **Line numbers are only in the outline**, not on the blocks.
- **Landscape phones still have no palette** (height < 560 dp): the picker,
  with search, remains the way to add blocks there. Not addressed by E1.
- **Auto-scroll speed is fixed** (up to 900 dp/s in a 72 dp band); it was
  tuned in widget tests and on the emulator, not on a physical phone.
- Found on the way, **not fixed (outside `lib/editor/`)**: under the widget
  test font the hint row (`_HintBar` in `puzzle_screen.dart`) overflows by
  21 px on a 360 dp phone in Turkish at font ×1.6. The test font is wider
  than the real one, and the existing ×1.6 tests use English or landscape,
  so this may not show on a device; worth one look on a phone.

## Emulator

Android 15 emulator (AVD `algorun_phone`, software rendering), debug APK of
the last feature commit, **360 × 800 dp** (`wm size 720x1600`,
`wm density 320`), light theme, English, 2026-11-18 04:34–04:43. The
emulator is shared by the five sessions; E1 waited its turn (M1, T1, then
E1) and reset `wm size` / `wm density` afterwards. Driven with `adb shell
input` located through the app's own accessibility dump (`uiautomator
dump`), as in MS13. Program: the 82-block stress probe (Settings →
DEVELOPER, debug builds).

| Step | Seen |
|---|---|
| Open the stress probe | App bar: reference, **Program outline**, options; palette row starts with **Search blocks**; all four carry their labels in the accessibility dump. |
| Palette search | Tap search → the system keyboard opens (`mInputShown=true`) and the palette stays above it; typing `dongu` leaves only WHILE; *Close search* closes the keyboard and brings the categories back. |
| Outline | Sheet with START / END and numbered lines (`Line 7: WHILE i LESS THAN (readings LENGTH)`); END closes it and shows RETURN and the last "add step"; later START shows the PROGRAM label and the first instruction. |
| Drag (accepted) | Hold `INCREMENT i` (last line of the outer WHILE), move below the loop: the block dims, the tag `INCREMENT i` sits by the finger, the line is drawn full width above RETURN; lifting moves it to the top level, selected, UNDO enabled; the bar shows UP / DOWN / OUT / IN / CLONE / DELETE, all on screen. |
| COPY → PASTE | Copy icon: *Copied INCREMENT i. Tap where it should go, then choose PASTE.*; "add step" of the loop: the picker shows COPIED / `PASTE INCREMENT i` first; PASTE: *Pasted INCREMENT i.*, 83 of 120 blocks; UNDO: 82. |
| Outline → a nested block | `Line 12: PUT counts x (c PLUS 1)` (inside ELSE of IF c IS NOTHING): selected (`PUT · 6 blocks`), scrolled into view. |
| Drag (refused) + auto-scroll | Hold that PUT, move to the bottom edge and rest there: the program scrolls by itself to its end; the line under RETURN is red and the tag reads *PUT · 6 blocks — This value may be empty here. Check that it is not empty first.*; lifting moves nothing, the feedback line repeats the reason, still 82 blocks. |
| Picker search | "add step" → search → `ret`: the sheet sits above the keyboard with one hit, RETURN; tapping it places the block (83) and closes the keyboard; UNDO. |
| Fold | Program options → Fold every block; START jumps to the top with the folds in place. |

Two things the device pass taught:

- `adb shell input draganddrop` holds for Android's own long-press time
  (400 ms), which is shorter than Flutter's (500 ms): the gesture scrolled
  instead of dragging. Separate `input motionevent DOWN` / `MOVE` / `UP`
  with a 1.2 s hold behave like a finger. A person has to hold for half a
  second, like every other long press in the app.
- The accessibility dump showed "add step", the value slots, the name chips
  and the selection bar's actions as labelled but **not clickable**: their
  `Semantics` node hid its children (`excludeSemantics`) without offering
  the tap itself. That was so before E1. Fixed in the commit after the five
  goals: those nodes, and E1's PASTE chip and outline lines, now carry
  `onTap` (`test/editor_semantics_test.dart`, 2 tests, presses each through
  the semantics tree).

Eight screenshots of the pass are in the sessions' shared notes folder
(`E1-screenshots/`), not in the repository.

## NOT TESTED

- **A physical phone.** Everything above is the emulator: software
  rendering, synthetic touch events. The feel of the drag (the 500 ms hold,
  the 8 dp start slop, the 900 dp/s edge scroll, the tag's place by a real
  thumb) has not been felt by a hand.
- **TalkBack.** Labels and tap actions were checked through the semantics
  tree in widget tests and the accessibility dump; no screen-reader session
  was run. The semantics fix above was made *after* the emulator pass and is
  covered by widget tests only.
- **Turkish, dark theme and font ×1.6 on the device.** Widget tests cover
  them (Turkish strings for search, paste, drag reasons, outline, folds; the
  dark palette in every E1 test file; ×1.6 for the picker search and the
  outline); the emulator pass was English, light, ×1.0.
- **The 160-block program on the device.** There is no debug path that loads
  a reference solution into the app (references are offline data, by
  design); the device pass used the 82-block stress probe. The 160-block
  `cheapest_crossing` reference is exercised by widget and controller tests
  (folds, drag sample, outline).
- **Other sizes.** 390 × 844, 412 × 915, landscape and the ≥ 840 dp side
  rail were not opened on the emulator; one widget test runs palette search
  in the side rail at 1000 × 700.
- **Web build** (mouse long press and drag, browser keyboard for search):
  not built, not run.
- **The release APK**: not built (debug APK only). Nothing was published.
- **Merged with the other four branches**: not tried; see the merge notes.

## For `docs/PROJECT_STATE.md` (coordinator)

Replace the "Editor (MS13)" line under *Known limitations → Other* with:

> **Editor (E1).** Instructions are dragged (long press, then move); values
> are not. A drop is typed where it lands; an instruction left behind can
> still be invalidated and is reported at RUN. UP / DOWN / OUT / IN keep the
> looser MS13 rule. One clipboard block per visit; no multi-selection.
> Search opens the system keyboard (opt-in). Landscape phones lose the
> palette (the picker remains). The stress probe opens from Settings in
> debug builds only.

Add to "Editor (MS3, MS13) — do not regress" (and retitle it "MS3, MS13,
E1"):

> - **Search (E1).** A search button in the picker and the palette; English
>   and Turkish block names, variable names. It only narrows the typed
>   picker list and `blocks.allow`. No text field exists until the button is
>   tapped.
> - **Copy / paste (E1).** COPY (selection bar title row) for instructions
>   and values; PASTE first in the picker of a slot it fits; rebuilt through
>   the engine's commands, one undo step. CLONE (was COPY) duplicates below.
>   Nothing outside `blocks.allow` is multiplied.
> - **Drag (E1).** Long press, then move: a line shows the place, accent =
>   accepted, danger = refused with the reason; the program scrolls near the
>   edges; one undo step per drop. `EditorController.checkMove` is the rule.
> - **Outline (E1).** App bar → every instruction on a numbered line; tap to
>   go; START / END.
> - A fold never hides the selection (E1). Folds stay saved in the draft.

In the same section, the sentence "No canvas, no drag, no TextField (names
are chips, numbers a pad)" becomes "No canvas; no TextField except the
opt-in block search (names are chips, numbers a pad); the selection bar is
UP / DOWN / OUT / IN / CLONE / DELETE for instructions, REPLACE / DELETE for
values, COPY for both".

Package structure: add `block_search.dart`, `block_search_field.dart`,
`block_drag.dart`, `block_text.dart`, `program_outline.dart` under
`lib/editor/`, the six `test/editor_*_test.dart` files (search, clipboard, folds, drag, outline,
semantics) and `test/support/editor_harness.dart`. Milestone docs table: `MILESTONE_E1.md`
— editor comfort for long programs. Roadmap: E1 complete.

Test table: Flutter **621 passed** on this branch alone (540 on
`main`); engine, content and validator unchanged.
