# T1 — Step by step

**T1 COMPLETE on its branch** (`claude/t1-step-trace-d1bb5c`, not merged). After
a RUN, the player opens any **visible** case from the results screen and walks
their own program through it: forward and back one instruction at a time, play
and pause with a speed, the block that just ran marked in the program, every
name with its value as it stands, the value that just changed pointed out, and
— inside a function — every call that is still open with its own values.

The question it answers is the player's: *at which step did it start going
wrong?*

Asked for by the user on 2026-11-18, when the freeze was lifted. Built next to
four other sessions (E1 editor, L3 blocks, M1 puzzle kinds, MS16 content); see
"For the coordinator" at the end.

No puzzle, budget, validator rule or unlock rule changed. No architecture
change: the engine stays pure Dart, nothing is evaluated or generated, content
is still data.

## What the player sees

| Where | What |
|---|---|
| Results screen | Every row under CASES has **STEP THROUGH** (`ADIM ADIM İZLE`). A failed case's button is in the foreground colour, a passed one's is quieter. The HIDDEN section is a count, as before: no row, no button. |
| `/trace` | Top to bottom on a phone: the case (`expected … · you gave …`), the program (read only) with the block that just ran outlined and marked with an arrow, one sentence about what that step did, what it has cost so far, VALUES, and the controls. From 720 dp wide the program and the values sit side by side, inside `ContentWidth.editor`. |
| The marked block | An instruction that ran: accent outline, a play arrow. IF and WHILE also carry what their condition came to (`TRUE` / `FALSE`). The failure that stopped a run: danger colour and an error icon on the instruction, and the outline on the exact value block that failed. The program scrolls just enough to keep the marked line in view. |
| The sentence | `Start. These are the given values.` · `The condition is FALSE: THEN is skipped.` · `The loop starts a pass.` · `Nothing left: the loop ends.` · `pairs starts, one level deeper.` · `RETURN gives back 5.` · `The program’s answer: 7` · `Stopped here. This program went too many levels deep.` Engine messages go through `engineText`, so they are Turkish in Turkish. |
| Cost so far | `Steps used so far: 37 of 7,200` — the same count, against the same budget, as the result screen's Steps row — and `Depth 4 of 80` inside a call. |
| VALUES | One row per name of the frame on show. A name the step just bound says **new**, one it rebound or whose content it changed says **changed**, with a bar in the warn colour down the row's edge (colour and words, never colour alone). |
| Collections | A list is a row of cells numbered from 0; the cell that changed is outlined and bold. A stack names its `top` (last item), a queue its `front`, a heap its `top` and lists smallest (or largest) first. A set is cells without numbers, a map is `key: value` cells. Appending marks the new cell only; taking from an end marks nothing in what is left. |
| Linked lists, trees, graphs | A chain `1 → 2 → 3 → NOTHING` with, under each node, the names that hold it (`head`, `cur`); a chain that comes back on itself ends in `loops back` instead of running on. A tree is an outline (root, then LEFT / RIGHT one step in). A graph lists each node with who it leads to and a check on the visited ones. |
| CALLS | Shown when more than one call is open: `CALLS · 4 OPEN`, then the calls innermost first (`4 · pairs  month=3, memo={…}`), built lazily so 160 open calls cost a handful of widgets. Tapping one shows that call's names (`main is waiting for the call it made to finish.`); the next step shows the running call again. |
| Controls | Slider over the whole run, `12 / 48`, then first · back one · play / pause · forward one · last · speed (`0.5×`, `1×`, `2×`, `4×` = 1, 2, 4, 8 instructions a second). All 48 dp. Stepping by hand pauses a run that is playing; play at the end starts over. |
| Help | The `?` in the app bar: five short paragraphs (what Forward does, what VALUES shows, CALLS, what "steps used" counts, hidden cases stay hidden). |

Position is written `12 / 48` without the word *step*: on the results screen
"Steps" already means counted operations, and a trace stop is one instruction,
which usually costs several. The screen shows both and names only the second.

## Hidden cases (locked decision 6)

A trace shows every input and every value on the way to the answer, so tracing
a hidden case would hand the player the fixture. Three independent layers keep
that from happening:

1. **Engine.** `traceVisibleCase(program, puzzle, caseId)` is the only way the
   app starts a trace. It looks for the id among `puzzle.visibleTests` and
   returns null otherwise. There is no variant that takes a `TestCase`.
2. **Screen.** `TraceScreen` shows *This case cannot be stepped through.* for a
   `CaseResult` that is not `visible`, and for one whose id is not a visible
   case even if it claims to be.
3. **Results.** The button is built per row of `SuiteResult.visible`. Hidden
   cases never were rows.

Tests: `trace_test.dart` (*a hidden case cannot be traced…*),
`trace_session_test.dart` (*a session opens for a visible case only*),
`trace_ui_test.dart` group *hidden cases* (one button per visible case and
nowhere else; the hidden input's numbers appear at no step of the trace; a
forged hidden `CaseResult` is refused in both shapes).

## Engine

### Events (`execution/engine.dart`, `interpreter.dart`)

The interpreter already called an optional `TraceSink`; it now reports enough
to follow a run.

| Kind (`TraceKinds`) | When | Carries |
|---|---|---|
| `start` | main's frame is ready, before its first instruction | the given values |
| `call` | a player function was entered, parameters bound | `blockId` = the FUNCTION block |
| `if`, `while` | **after** the condition was worked out (was: before) | `value` = the answer |
| `forRange`, `forEach` | the loop bound its name(s) for a pass | |
| `loopEnd` *(new)* | a FOR / FOR EACH had nothing left — also when it never ran | |
| `assign`, `inc`, `dec` | after the write | |
| `expr` *(new)* | an instruction that is one working block (APPEND, PUSH, a CALL on its own line) | `value` = what it gave back |
| `break`, `continue` *(new)* | | |
| `return` | **after** the value was worked out (was: before); the frame is still open | `value` |
| `halt` *(new)* | the failure that stops the run, once, last | `message`, `blockId` = the failing block, the frames as they stood |

`TraceEvent` gained `frames` (the call stack as `TraceFrame`s: `serial`,
`function`, `blockId`, live `vars`), `depth`, `value`, `message`. `locals`
(display text of the running frame) is now worked out on first read instead of
on every event.

**Contract change, small:** `frames` and `locals` are live — valid while the
sink runs. `kind`, `blockId`, `opIndex`, `depth`, `message` stay valid
afterwards. The one existing test that read `locals` after the run now reads
it in the sink. Nothing else used the trace.

An event never counts an operation. With no sink the interpreter does one null
check per would-be event and keeps no frame list; the only other difference is
a `catch … rethrow` in `_invoke`, which costs nothing unless a run fails.

### Recording (`execution/trace.dart`)

```dart
TraceRecording recordTrace(Program program, Map<String, RuntimeValue> input, RunLimits limits,
    {int from = 0, TraceLimits traceLimits = TraceLimits.standard});
```

- `TraceRecording`: `result` (the run's `RunResult`), `totalSteps`, `firstStep`,
  `steps`, `cutByCells`, `complete`, `holds(i)`, `stepAt(i)`, `objectAt(id, i)`,
  `objectBefore(id, i)` (what a step changed it from, or null).
- `TraceStep`: `index`, `opIndex`, `kind`, `blockId`, `frames`
  (`TraceFrameSnapshot`: `serial`, `function`, `blockId`, `vars`), `value`,
  `message`, `changed` (names the running frame bound in this step),
  `changedObjects` (collections / nodes / graphs whose content changed).
- `TraceValue` (sealed): `TraceNothing`, `TraceNumber`, `TraceBool`, `TraceText`,
  `TraceRef(id)`, `TraceUnknown(text)`.
- `TraceObject` (sealed): `TraceSequence(shape, items)` for
  array / set / stack / queue / deque / minHeap / maxHeap, `TraceMap`,
  `TraceListNode`, `TraceTreeNode`, `TraceGraph`.
- `changedPositions(before, after)`, `changedEntries(before, after)`: which
  cells to point out.

How it stays small:

- Values are copied into immutable snapshots, and **what did not change is the
  same object as one step earlier**: a frame's names, a list, a node. A
  recording costs what the program changed, not steps × data. Each object keeps
  a short list of versions; `objectAt` is a binary search.
- Frames that are waiting cannot rebind a name, so a recursion 150 deep holds
  about one frame snapshot per step, not 150 (tested).
- Two names for one list are one `TraceRef`; linked nodes are separate objects,
  so a cycle is just a reference (the walk is a worklist, not recursion).
- A value kind the recorder does not know becomes `TraceUnknown` with its
  display text (`jsonEncode(value.toJson())`). The code is if-chains, not
  exhaustive switches, so **a new `RuntimeValue` subclass compiles and shows as
  text** until someone teaches the recorder its shape.

### Limits: a window, not a cut-off

`TraceLimits(maxSteps: 2000, maxCells: 1500000)`.

A recording holds one contiguous **window** of the run and always knows the
run's full length. Past the window's last step the recorder only counts. The
screen asks for another window when the player moves outside the one it has —
`recordTrace(..., from: n)` runs the program again from the start, which is
exact because the interpreter is deterministic. So:

- memory is bounded by `maxSteps` steps and the changes inside them;
- time per window is bounded by `maxCells` values looked at (a list of 1 000
  numbers costs 1 000 at every step it is reachable), so a huge value makes
  windows shorter, never the phone slower; a window always holds at least one
  step;
- nothing is unreachable: the last step of a 300 000-operation run is one tap
  on *last* away, and a window loaded by a jump is centred on the target so the
  steps that led up to a failure are there.

The player is told when a run is windowed, in the warn colour under the
sentence: *A long run: 2,004 instructions ran. They load 2,000 at a time as
you move through it.* Loading itself is silent.

A run is always finite: it is the graded run, under the case's own operation
budget (`caseLimits`, new in `runner/benchmark.dart`, the same limits
`measureCase` uses).

### Proof that tracing changes nothing

Two claims, one test (`trace_parity_test.dart`):

1. **Off = before T1.** `tool/run_digest.dart` runs every reference solution
   and every reject in `content/references` on every fixture of its puzzle,
   visible and hidden, under the runner's limits, and fingerprints verdict,
   operations, peak memory, peak depth, output, failing block and message per
   puzzle. `test/golden/pre_t1_runs.json` is that file's output **from the
   engine at commit 4fbbfed** (extracted with `git archive`; it uses only API
   that existed then). Today's engine must produce the same fingerprints.
2. **On = off.** In the same pass each run is repeated with a sink that only
   counts and once more through `recordTrace`; all three must report the same
   line.

152 puzzles (149 campaign + 3 probes with references), 3 050 runs: 2 953 run
to completion, 75 stop on the operation limit, 12 on memory, 9 on a runtime
error and 1 on depth. The longest is 141 120 steps and 212 are longer than one
window, so the windowed path is exercised too. A puzzle whose files were edited after the golden
was written is skipped by its `source` fingerprint — its numbers no longer say
anything about the engine — and the test needs more than half the corpus to
still be comparable. Regenerate after an intended engine change with

```bash
cd packages/algorun_engine && dart run tool/run_digest.dart > test/golden/pre_t1_runs.json
```

(which then proves only on = off for that change; say so in the commit).

The content validator's own reference metrics (level 5) passing unchanged is a
second, independent witness of claim 1.

## App

| Piece | Where | What |
|---|---|---|
| Session | `lib/state/trace_session.dart` | `TraceSession` (a `ChangeNotifier`): position, `next` / `previous` / `first` / `last` / `goTo`, play / pause / `cycleSpeed`, the frame on show, and window loading (the next window when stepping forward, the window that ends at the target when stepping back, a centred one on a jump). `TraceSession.forCase` is null for anything but a visible case. |
| Screen | `lib/screens/trace/trace_screen.dart` | `TraceArgs(puzzle, graph, caseResult, limits)`, `TraceScreen`; route `/trace` in `lib/app.dart` (without arguments it goes home, like `/results`). |
| Program | `lib/screens/trace/trace_program_view.dart` | `TraceProgramView(graph, currentId, failed, badge)`. |
| Values | `lib/screens/trace/trace_values.dart` | `TraceVariableRow`, `TraceValueView`, `traceValueText` (one-line text of any value), `traceChain`, `traceContentChanged`. Everything is bounded: 48 cells / entries / nodes, then `+452 more`. |
| Results | `lib/screens/results/results_screen.dart` | `ResultsArgs.graph` (optional) and the button on `_CaseRow`. |
| Puzzle | `lib/screens/puzzle/puzzle_screen.dart` | **One line**: RUN passes `graph: _controller.graph` to the results. |
| Strings | `app_en.arb`, `app_tr.arb` | 49 keys, all `trace…`, appended at the end of both files; generated code committed. Block words (TRUE, FALSE, NOTHING, THEN, RETURN…) stay English in Turkish, as everywhere. |

### The program view does not reuse the editor's tiles

The task suggested reusing `script_view.dart` and the tile widgets. They are
not reusable read-only without editing them: `StatementTile`, `ReporterTile`
and `HoleWidget` take an `EditorController` and build the editor's controls
into every tile (add-step rows, pickers on tap, the ▾ name chips, fold
buttons), and `ScriptView` owns the scroll view, so an `AbsorbPointer` around
it would stop scrolling too. Making them read-only means a flag threaded
through five files that the E1 session is rewriting at the same time.

So `TraceProgramView` draws the same shapes itself — category strip, C-blocks
with THEN / DO / ELSE and a rail, value pills, the same labels — from the same
`BlockChrome`, `BlockDefinition` and `FunctionSignature`, and imports from
`lib/editor` only `EditorTheme` and the two text widgets `BlockLabel` /
`BlockWord`. **No file under `lib/editor` was changed.** It has no knowledge of
particular blocks beyond the handful the editor also special-cases (names on
SET / INCREMENT / FOR, FROM / TO / BY, literals, CALL); **a block added by L3
draws through the general case** (label + filled slots) without touching this
file. Rows are tighter than the editor's (36 dp, not 48): nothing here is a
touch target.

If E1 ends with read-only-capable tiles, switching to them is a contained
change: `TraceProgramView` is one widget with four inputs.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **428 passed** (398 before; +29 `trace_test.dart`, +1 `trace_parity_test.dart`) |
| `packages/algorun_content` `dart test` | **86 passed** (unchanged) |
| Content validator | `PIPELINE 149 of 149 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 154 puzzle(s), 5 warning(s)` (unchanged) |
| `flutter analyze` | no issues |
| `flutter test` | **FLUTTER_COUNT passed** (540 before; +26 `trace_ui_test.dart`, +5 `trace_session_test.dart`) |

`trace_parity_test.dart` takes about 50 s (it runs the corpus three times,
the rejects that run to their operation limit included); the engine suite went
from about 10 s to about 60 s.

What the new tests hold:

- **Events** (9): order and block per kind; a loop that never runs; IF / WHILE
  answers; BREAK / CONTINUE; expression instructions; frames, serials and
  RETURN values through a recursion; a failure in a nested call (block,
  message, frames still open); operation and depth limits end in one `halt`.
- **Recording** (12): every step of a short run; which names a step bound;
  sharing (waiting frames, an untouched list); a version per change with its
  "before"; aliasing; fixtures never change; map / set / stack / queue / heap
  order and `changedPositions`; relinking and a cycle; trees and graphs; a
  failed run.
- **Limits** (6): one window and the right total; **any window says exactly
  what the whole recording says about its steps** (compared step by step,
  values resolved, across loops and across calls); past the end; closing on
  `maxCells` with windows in a row covering the run; at least one step;
  recursion 150 deep and a 300 000-operation spin stay bounded.
- **Cases** (2): a visible case traces with the runner's exact operation,
  memory and depth counts; hidden ids return null.
- **Widgets** (26): opening state; forward / back with the marked block and
  the `new` / `changed` tags at each step; first / last and the answer; play,
  pause, speed, stop at the end, stepping pauses; the slider; help; the five
  hidden-case tests; frames, CALLS, picking a waiting frame; a whole wrong
  recursion stepped to its end; a recursion to the depth limit (80 frames, only
  the top ones built); a windowed run forward, to the end and back; each kind
  of value; a 500-item list and an unknown value kind; 360 × 800 in light / dark
  × English / Turkish × text ×1.0 / ×1.6 with every step of a 60-block program
  (no overflow, controls clear of the system bars, the marked line in view);
  1600 × 900; and the real app: saved wrong program → RUN → STEP THROUGH → back
  → BACK TO PUZZLE.

## Emulator

EMULATOR_SECTION

## Known limits

- **Granularity is the instruction.** A step is one instruction block; the
  value blocks inside it are not stepped through one by one (their cost shows
  in "steps used"). A failure still points at the exact value block.
- **State shown is after the block ran**, not before. `SET x TO x + 1` shows
  the new `x`; the old one is one step back.
- **Going to a far window re-runs the case.** Instant for ordinary cases; for
  the largest budgets in the corpus (about 1.2 million operations) a window
  change is a noticeable pause on a phone. It runs on the UI thread (Flutter
  web has no isolates to move it to). Not measured on a real device.
- **Trees are an outline, not a drawing**; graphs are an adjacency list. Enough
  to read values and see what changed; a picture would be nicer.
- **Aliasing is shown for nodes only** (names under a node). Two names holding
  the same list both show it and both say `changed`, but nothing says "these
  are one list".
- **`changed` on a waiting frame** means "something this name reaches changed
  in this step"; a waiting frame cannot be rebound, so there is no `new` there.
- **Display caps.** 48 cells / entries / nodes per value; a change beyond the
  shown part of a list is reported as *a change further on*, not located.
- **No trace before a RUN, and none for a program that does not lower** (there
  are no cases to open). The trace is of the program as it ran; it does not
  follow edits.
- **Nothing is saved**: position and speed are gone when the screen closes.
- **Heap is listed in take order**, not as the binary heap it is stored as.
- The engine's `maxNesting` guard, array / map size limits and every other
  failure surface as the same `halt` step; none got special wording.

## NOT TESTED

NOT_TESTED_SECTION

## For the coordinator

**Move into `PROJECT_STATE.md`:**

- Current state line: T1 step-by-step trace is in (this document).
- Package structure: `lib/screens/trace/` (screen, program view, values),
  `lib/state/trace_session.dart`, `packages/algorun_engine/lib/src/execution/trace.dart`,
  `…/runner/case_trace.dart`, `…/tool/run_digest.dart`, `…/test/golden/pre_t1_runs.json`,
  `test/trace_ui_test.dart`, `test/trace_session_test.dart`,
  `test/support/trace_fixtures.dart`.
- Important APIs → Interpreter: the event table above; `frames` / `locals` are
  live during the sink. New section "Step trace (T1)": `recordTrace`,
  `traceVisibleCase`, `TraceLimits`, the window rule, the hidden-case rule.
- Test table: engine 428, Flutter FLUTTER_COUNT (plus whatever the other sessions add).
- Known limitations: the list above. Remove *"The `PuzzleScreen` →
  `ResultsScreen` navigation is not pumped in a test"* — `trace_ui_test.dart`
  (*in the app*) pumps RUN → results → trace → back.
- "Adding a `RuntimeValue`" (Interpreter section) gets a fourth place to
  update, optional: `trace.dart` (`_tracked`, `_object`) and
  `trace_values.dart`. Without it the value still shows, as text.

**Where this branch touches other sessions' ground:**

| File | Change | Likely conflict |
|---|---|---|
| `lib/screens/puzzle/puzzle_screen.dart` | one added argument in `_run` (`graph: _controller.graph`) | E1, if it reworks `_run`: keep the argument |
| `lib/screens/results/results_screen.dart` | `ResultsArgs.graph`, `_CaseRow.onTrace` + button | M1, if new puzzle kinds change the case rows |
| `lib/l10n/app_*.arb` + `gen/` | 49 keys appended at the end | every session appends there: keep both sides, run `flutter gen-l10n` |
| `lib/app.dart` | `/trace` route, one import | trivial |
| `packages/algorun_engine/lib/src/execution/interpreter.dart` | `_emit` sites, `_invoke` frame push / catch, `_emitHalt` | **L3**: new statement kinds should `_emit` after they run (an instruction with no event is a step the player cannot stop on — the trace still works, it just skips that line). New blocks that are `CallExpr`s inside `_call` need nothing. |
| `packages/algorun_engine/lib/algorun_engine.dart` | two exports | trivial |
| `packages/algorun_engine/lib/src/runner/benchmark.dart` | `caseLimits` added | none expected |
| `packages/algorun_engine/test/interpreter_test.dart` | the old trace test reads `locals` inside the sink | none expected |

**After merging the others, check:**

1. `dart test test/trace_parity_test.dart` in the engine. If L3 changed what a
   run costs on purpose, the golden says so loudly; regenerate it then, and
   note that claim 1 (off = before T1) was proven on this branch at 4fbbfed.
   Puzzles MS16 adds are not in the golden and are simply not compared with
   the past; they are still run traced and untraced against each other.
2. A puzzle using an L3 block, opened in the trace: it should draw (general
   case) and, if L3 added a value kind, show it as text.
3. If M1 adds puzzle kinds whose visible cases are not `visibleTests` run
   through `TestRunner` (a predict or repair mode), `traceVisibleCase` will
   return null for them and the button will open *This case cannot be stepped
   through.* — hide the button for those rows or teach `traceVisibleCase`.

Not done on purpose: `README.md` and `PROJECT_STATE.md` are untouched; nothing
was merged, pushed or published.
