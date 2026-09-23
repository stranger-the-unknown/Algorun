# Milestone 11

**MS11 COMPLETE.** Progression, local persistence, save and resume. **MS12 is
next** (large original content) — only when asked.

A player can now solve puzzles, unlock what comes next, close the app, reopen
it and carry on: CONTINUE reopens the last puzzle with the program exactly as
it was left, solved puzzles stay solved, best results stay best. Everything is
on the device: no account, no backend, no sync, no leaderboard, no score.

Previous milestone commits: MS10 `c192118`, L1 `d850525`.

## Architecture

```
lib/progress/                 pure Dart — no Flutter, no dart:io (a test enforces it)
  save_data.dart              PlayerSave, PuzzleProgress, RunNumbers, RunRecord,
                              PlayerSettings, CurrentSession, BestMetric
  save_codec.dart             encodeSave / decodeSave: the versioned JSON format
  campaign.dart               Campaign, evaluateCampaign → CampaignProgress (the unlock rules)
  progress_ledger.dart        completes(), openPuzzle, saveDraft, recordRun: pure updates
  progress_store.dart         ProgressStore interface, MemoryProgressStore
  file_progress_store.dart    FileProgressStore (the one file that touches the device)
lib/state/progress_providers.dart   progressStoreProvider, campaignProvider,
                              progressProvider (ProgressNotifier: autosave), campaignViewProvider
lib/state/progress_text.dart  player wording for locks and statuses
```

The four kinds of state are kept apart:

| State | Where | Stored? |
|---|---|---|
| `CampaignProgress` — mastered concepts, world and puzzle status, what a lock waits for, the current puzzle | `evaluateCampaign(campaign, save)` | **no**, derived every time |
| `PuzzleProgress` — per puzzle: version, completed, best, solution, draft, last run | `PlayerSave.puzzles` | yes |
| `PlayerSettings` — `showBriefOnOpen` | `PlayerSave.settings` | yes |
| `CurrentSession` — last world + puzzle | `PlayerSave.session` | yes |

Unlocks are never stored: storing them would let them drift from the content.
Widgets never touch storage or JSON — they call `ProgressNotifier`, which calls
a `ProgressStore`. The engine was not changed.

## Unlocking — data-driven

Only the content's own metadata decides: world `concepts` and `prerequisites`
in `assets/worlds.json`, puzzle `prerequisites` in each puzzle. No puzzle or
world id appears in the rules.

1. A world is **open** when every concept in its `prerequisites` is mastered —
   or when the player has already solved one of its puzzles (a content update
   can never lock a world the player has played).
2. A world is **complete** when it is open and every puzzle it lists is
   solved. A world with no puzzles yet completes as soon as it opens, so a
   missing chapter never blocks the chapters after it.
3. A concept is **mastered** when a complete world teaches it.
4. A puzzle is **open** when its world is open and each of its own
   `prerequisites` is mastered or taught by that same world.

Rules 1–3 feed each other and are applied until nothing changes (mastered
concepts only grow). The shipped campaign, from a fresh install:

| After | Open |
|---|---|
| nothing | Foundations (no puzzles), **Arrays** → The Smallest Cart |
| The Smallest Cart | + **Hash Maps**, Two Pointers (no puzzles) → **Sliding Window**, **Stack & Queue**, Greedy (no puzzles) |
| Relay Towers | + Linked Lists, Trees (no puzzles) → **Graphs** (Fewest Rides needs `queue`: mastered), Heaps |
| — | Backtracking and Dynamic Programming need `recursion`, which no world teaches: locked (the known validator warning); Advanced Algorithms needs `dp` |

The dev probes (`ms1_contract_probe`, `ms3_editor_probe`, `l1_list_probe`,
`l1_tree_probe`) are in no world: they are not part of the `Campaign`, are
never recorded, and a save that claims them changes nothing. They still open
from the default `/puzzle` route and play normally, unsaved.

## Completion rule

A RUN completes its puzzle exactly when the test runner's verdict is
`ResultKind.correct`: every visible and hidden case right, within every budget
the puzzle sets — operations (including per-case budgets), memory, depth — and
within the block budget (checked before anything runs). A correct answer over
the operation budget is `operationLimit`, so it does **not** complete the
puzzle; neither does a wrong answer, a runtime error or an invalid program.
Hints never matter. Completion is never taken back. (`completes(suite)` in
`progress_ledger.dart`.)

## Save format (version 1)

```json
{
  "saveVersion": 1,
  "puzzles": {
    "smallest_cart": {
      "puzzleVersion": 1,
      "completed": true,
      "best": {"ops": 65204, "peakAlloc": 0, "peakDepth": 1, "blocks": 55, "hintsUsed": 0},
      "lastRun": {"result": "correct", "ops": 65204, "peakAlloc": 0, "peakDepth": 1, "blocks": 55, "hintsUsed": 0},
      "solution": { <BlockGraph JSON> },
      "draft": { <BlockGraph JSON> },
      "editedSinceRun": false
    }
  },
  "settings": {"showBriefOnOpen": true},
  "session": {"worldId": "world_02", "puzzleId": "smallest_cart"}
}
```

| Field | Meaning |
|---|---|
| `puzzleVersion` | the puzzle `version` the results were earned on |
| `completed` | set by a completing RUN, never unset; stored plainly because progression depends on it |
| `best` | independent best metrics over completing runs; only with `completed` |
| `lastRun` | the latest RUN, any verdict (`result` is a `ResultKind` name) |
| `solution` | the program of the completing run with the fewest operations; only with `completed` |
| `draft` | the program as last left in the editor |
| `editedSinceRun` | the draft changed after the last RUN |

- **Deterministic**: keys are sorted at every level, lists keep their order;
  the same save is always the same text.
- **Programs are `BlockGraph` JSON**, the editor's own format: blocks,
  connections (`slots`: `ref` / `list`), literals, variables with their types,
  statement nesting, and the per-block `x` / `y` / `collapsed` UI fields that
  are already part of it (kept, ignored by execution). Never IR — it is
  regenerated by lowering on RUN, so saved programs follow the current rules.
  Not saved: selection, the open picker, drag state, folds held only in the
  controller, hint panel state, traces, runtime values, interpreter state.
- **Only player state**: no hidden cases, no reference solutions or notes, no
  validator internals, no IR, nothing executable (tests check the keys and
  scan the text).

### Reading: nothing crashes, nothing is invented

| Input | Result |
|---|---|
| no save | a fresh save |
| not JSON / not an object | unusable: the text is **kept aside**, play starts fresh |
| `saveVersion` missing, not a whole number ≥ 1, or newer than this build | unusable, kept aside |
| older `saveVersion` | upgraded through the migration table, one step at a time |
| `puzzles` not an object | puzzle progress dropped; settings and session kept |
| a puzzle id that is not `lower_snake_case`, or an entry that is not an object | that entry dropped |
| `puzzleVersion` unreadable | read as 0 (an older version: the version policy applies) |
| `completed` anything but `true` / `false` | not completed |
| `best` malformed, or present without `completed` | best dropped |
| `lastRun` with an unknown result or bad numbers | last run dropped |
| a program that does not decode, uses an unknown block, points at a missing block, has a cycle or a bad variable type | that program dropped (`GraphStructure.validate`); an unfinished program with empty holes is fine |
| `settings` / `session` malformed | defaults / no session |
| a puzzle id the campaign does not list (deleted, renamed, a probe) | kept in the save, ignored by progression; a session pointing at it offers no CONTINUE |

Every dropped part is a `SaveIssue` with its JSON path, printed to the debug
log and kept on `ProgressNotifier.issues`; the player is never blocked.

### Unknown fields

Ignored at every level and not written back. A future build may add a field
without a new `saveVersion` only if an older build losing it is harmless;
anything else needs a version bump and a migration.

### Migrations

`save_codec.dart` holds `_migrations`: a map from a version to a function that
turns that version's JSON into the next. Version 1 has none. A save newer than
the build is never guessed at: it is kept aside and the game starts fresh
(nothing is overwritten in place).

### Puzzle versions

Each puzzle entry records `puzzleVersion`. When a puzzle ships with a
different `version`, opening it keeps `completed` (unlocks never go backwards)
and the draft (the player's work), and clears `best`, `solution` and `lastRun`
— they measured a different puzzle. The editor shows: *This puzzle changed
since you last played it. Your program was kept; RUN shows what to update.*
A content author bumps `version` for an incompatible change (new cases, new
inputs, new budgets).

## Storage

One JSON file, `algorun_save.json`, in the app's private support directory
(`path_provider`'s `getApplicationSupportDirectory`; on Android the app's
internal storage, no permission, removed with the app).

- Writes go to `algorun_save.json.tmp`, flushed, then renamed over the save,
  so a crash mid-write leaves the previous save intact.
- An unusable save is copied to `algorun_save.unreadable-<millis>.json` before
  anything can overwrite it.
- Why: one small versioned document is all MS11 needs. `shared_preferences`
  is meant for small preferences, not a growing document of programs;
  SQLite / Hive / Isar would add a database for a single record. The only new
  dependency is `path_provider` (Flutter team, to find the directory).
- Flutter web (preview only) keeps progress in memory.
- `main.dart` installs the file store; by default `progressStoreProvider` is a
  `MemoryProgressStore`, so no test ever touches device storage.

## Autosave

| Trigger | Write |
|---|---|
| a new program in the editor (place, connect, remove, undo, redo, a literal, load best) | the draft updates in memory at once; written after 800 ms without further change |
| opening a puzzle | at once (the session) |
| RUN | at once (last run; completion, best and solution when it completes) |
| a settings change | at once |
| leaving the puzzle screen | at once (pending edit flushed) |
| the app is hidden, paused or detached (`AppLifecycleListener`) | at once |

Writes never overlap. A change counts only when the editor's `BlockGraph`
changes: selection, the hole picker, the hint panel and scrolling never write.
Nothing is recorded before the save has loaded (a fresh save written over a
real one would lose it). A failed write is reported and play continues from
memory.

## Best results

`best` holds five independent minima over **completing** runs: operations
(`ops`, the worst case across the puzzle's cases), memory cells
(`peakAlloc`), depth (`peakDepth`), blocks, and hints used. Each metric is
replaced only when a new completing run is strictly better on that metric, so
the fewest operations and the fewest blocks may come from different runs.
There is no combined score. A failing run never touches `best`, `completed`
or `solution`; it only replaces `lastRun`. `solution` follows the fewest
operations (the earlier program stays on a tie). The puzzle screen offers
**Load best solution** (one undo step brings the previous program back).

## Hints

Hints are not a consumable. The hint session still lives only as long as the
puzzle screen: reopening a puzzle starts with no hints revealed. The number
of hints revealed before a RUN is kept only as a metric of that run
(`lastRun.hintsUsed`, and the lowest in `best.hintsUsed`); it never affects
completion or unlocks.

## Current session

`session` = the last opened campaign puzzle and its world. Its editable
program is that puzzle's `draft`; its last known result is its `lastRun`;
whether it changed after that run is `editedSinceRun`. Nothing of a run is
stored — no interpreter, no half-executed program. Opening a puzzle restores
`draft`, else `solution`, else an empty script with the givens.

## UI

- **Home**: a PROGRESS card (*1 of 5 puzzles solved*, *Last played: The
  Smallest Cart · Arrays*). With a session: **CONTINUE** (reopens that puzzle)
  and WORLDS; on a fresh install: ENTER, as before. Nothing opens a puzzle
  without a tap.
- **Worlds**: each card says *0 of 1 solved*, *Solved* / *All n solved* (check
  icon), *No puzzles yet*, or *Locked — learn two pointers first* (lock icon,
  not tappable); the world of the last puzzle is tagged CURRENT. Titles and
  numbers come from `worlds.json`; nothing is hardcoded.
- **Puzzles**: rows show *Not started*, *In progress · last run: wrong answer*,
  *Solved · best 65,204 steps · 55 blocks*, or a lock with what it waits for;
  CURRENT marks the last puzzle. Locked rows do not open.
- **Puzzle**: restores the saved program; a check icon beside a solved
  puzzle's title; **Load best solution**; the brief opens as the settings say.
  A locked puzzle reached by its route shows *This puzzle is locked. It opens
  once you have learned arrays.*
- **Results**: a PROGRESS section when something changed — *Puzzle solved.*,
  *New best: fewest steps, fewest blocks.*, *Now open: Hash Maps, Sliding
  Window, Stack & Queue.*
- **Settings**: *Show the brief when a puzzle opens*; **Reset progress** (asks
  first, deletes the save).

## L1 compatibility

IS NOTHING / IS NOT NOTHING are ordinary blocks in `BlockGraph` JSON, so they
save and load like any other. Tests save the L1 probes' reference programs,
read them back, and check the lowered IR is byte-identical and that running
them gives the same verdict, outputs, operations and blocks as before saving.

## Tests

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **341 passed** (unchanged) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **46 passed** (unchanged) |
| Content validator (assets + worlds + references) | `OK 9 puzzle(s), 6 warning(s)` + 7 INFO lines (unchanged) |
| Flutter `analyze` | no issues |
| Flutter `test` | **111 passed** (50 + 61) |
| `flutter build apk --debug` (the new `path_provider` plugin on Android) | built `app-debug.apk` |

New (all pure Dart except the widget tests):

- `test/progress/save_codec_test.dart` (22): round trip, deterministic text,
  fresh install, not-JSON, wrong versions, damaged puzzle progress (no
  invented completion), broken programs dropped, unknown and malformed ids,
  a deleted puzzle, damaged sections isolated, unknown fields, player state
  only; programs — simple, nested IF / ELSE, loops, variables and literals,
  L1 predicates (same run and same IR after a save), positions and folds; the
  file store — atomic write, unreadable save kept aside, clear.
- `test/progress/progression_test.dart` (18): the fresh campaign, completing a
  real puzzle, prerequisites through empty chapters, a locked puzzle can be
  neither opened nor recorded, probes never count, over budget and wrong
  answers do not complete, hints never block; best results — first, failed
  runs, better, worse and tied operations, independent metrics, restart;
  puzzle prerequisites, the "played worlds stay open" rule, manifest order,
  the version policy.
- `test/progress/session_test.dart` (9): last puzzle, draft, solved puzzle
  (and the solution when there is no draft), an edited unsolved puzzle across
  restarts; debounced edits, immediate RUN, a failing store, an unreadable
  save, settings and reset.
- `test/progress/pure_dart_test.dart` (2): `lib/progress` stays pure Dart; no
  screen or editor file touches storage.
- `test/progression_ui_test.dart` (10): the fresh-install flow, solved and
  locked presentation, a locked puzzle by route, CONTINUE with the restored
  program, Load best solution and save on leaving, RUN completing a puzzle
  with the PROGRESS lines and the save written, a failed RUN, settings and
  reset, the brief preference, progress wording.

Changed: `test/widget_test.dart` (the home test now gets the campaign from
files — see below) and `test/real_puzzles_test.dart` (the world-card test
checks progression instead of "Locked — content in later milestones").
Shared helpers: `test/support/campaign_files.dart`,
`test/support/progress_fixtures.dart`. Widget tests load the campaign from
the repository files: `rootBundle` caches a pending asset load made inside a
test's fake async zone, and the next test would wait on it forever.

## Files

Created: `lib/progress/{save_data,save_codec,campaign,progress_ledger,progress_store,file_progress_store}.dart`,
`lib/state/progress_providers.dart`, `lib/state/progress_text.dart`, the test
files above, `docs/MILESTONE_11.md`.

Modified: `lib/main.dart` (file store), `lib/app.dart` (lifecycle flush),
`lib/editor/editor_controller.dart` (`initialGraph`, `replaceGraph`),
`lib/screens/home/home_screen.dart`, `world_select/world_select_screen.dart`,
`puzzle/puzzle_list_screen.dart`, `puzzle/puzzle_screen.dart` (open, lock,
restore, autosave hooks, load best), `results/results_screen.dart` (PROGRESS),
`settings/settings_screen.dart`, `pubspec.yaml` / `pubspec.lock`
(`path_provider`), two existing tests, `docs/PROJECT_STATE.md`, `README.md`.
The engine, content package and content are unchanged.

## Known limitations

- A world completes only when **every** puzzle it lists is solved; there is no
  per-world mastery threshold yet (MS12 may want one — a schema addition).
- The rules can deadlock on inconsistent content (a puzzle needing a concept
  only a later world teaches); the content validator does not yet check that
  every puzzle is reachable.
- An edit made less than 800 ms before the process is killed *without* a
  lifecycle event is lost (Android normally pauses the app first).
- Saved programs are checked structurally on load and by lowering on RUN, not
  re-lowered on open; a changed puzzle shows a notice instead.
- One save slot, no export or import, no per-puzzle reset.
- The campaign loads every listed puzzle at start-up (five today); a large
  MS12 campaign may want a lighter index.
- Unreadable-save copies are kept and never cleaned up.
- Flutter web (preview) does not persist.

## Confirmation

Milestone 11 is complete. The project is ready for MS12 (large original
content). Do not start MS12 from this document.
