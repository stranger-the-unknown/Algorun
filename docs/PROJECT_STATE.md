# Algorun project state

Handoff document for the next coding agent. Read this before changing
anything. It is written so you can continue without any previous conversation.

**Current state: H — heaps — is in (see MILESTONE_H.md): heaps of numbers (NEW MIN HEAP / NEW MAX HEAP, INSERT, TAKE TOP, TOP, SIZE, IS EMPTY) and world 09 Heaps with 15 puzzles; 149 campaign puzzles. Before it, L2 (MILESTONE_L2.md) brought player functions, recursion and world 12 (15 puzzles). Versions before: tag `v0.3-l2` (before H), `v0.2-ms15` (before L2).**
**Why the corpus grows before the playtest (user decision, 2026-09-30):** the user's subscription ends around 2026-10-10; they want the game developed as far as possible now, and will playtest afterwards and bring notes to the next development month. Plan: MS15 content (Foundations, then thin worlds) → recursion and player functions only if content is done by 2026-10-05 → freeze on 2026-10-09 / 10 (tests, APK, web build, a test checklist in `bekleyen-isler.md`). See [`MILESTONE_15.md`](MILESTONE_15.md).

**Frozen for playtest on 2026-10-02** (tag `freeze-2026-10-02`, a week before the planned 10-09/10 date because development was done): every suite green (engine 381, content 86, Flutter 517, validator 149/149), release APK `Algorun-2026-10-02.apk` in the repo root (untracked; signed with the same debug key as earlier APKs, so it installs over them and keeps progress) smoke-tested on the `algorun_phone` emulator, the playtest checklist in `bekleyen-isler.md` (git-excluded). The user considers the game essentially finished once the playtest finds no serious bugs; after that, work is mainly fixes from the notes and more puzzles as they play. Campaign locks stay off until the user calls the game ready.
**Web version online since 2026-10-02:** https://stranger-the-unknown.github.io/algorun-play/ — GitHub Pages from the public repository `stranger-the-unknown/algorun-play`, which holds only the built web files (the source stays private; the user chose this over Cloudflare / Netlify because it needs no new account). Publish an update with `tool/publish_web.sh` (builds with `--base-href /algorun-play/` and pushes). The browser version can download its save as a file and load it back (Settings → SAVE FILE; `lib/progress/save_files*.dart`, `saveFilesProvider`), so clearing the browser's data need not lose progress; the phone has no such section. The campaign's puzzles load in parallel (they were 150 requests in a row on the web).

Do not implement the next milestone from this file unless the user explicitly asks.

**Also complete (UX/playtest):** editor scroll-follows a block moved with UP/DOWN (MS13 reveal path + visibility check); **every build, release included, unlocks all campaign puzzles** (user decision, 2026-09-25: a playtester never re-solves puzzles to reach the ones under test). `main` sets `PlaytestFlags.unlockAllPuzzles = !PlaytestFlags.campaignLocks`; `campaignLocks` is `--dart-define=ALGORUN_LOCKS=true` (default off). The lock rules stay in `evaluateCampaign` and in the tests (which do not run `main`); completions are recorded as usual. When the campaign is ready for players, make `campaignLocks` default to true. Does not change unlock rules, validators, or budgets.
**App icon (2026-09-30):** Grok's variation 4 (two graphite blocks and a sage-green play-arrow block on `#F4F4F5`), redrawn as clean geometry; master `branding/algorun_icon.svg`, Android adaptive vector icon with a themed (monochrome) layer, legacy PNGs, iOS and web icons. See [`branding/README.md`](../branding/README.md).
**Light mode (U2, 2026-09-30):** Settings → APPEARANCE: Light / Dark / System (default System, follows the device), saved in `settings.theme`, kept by reset progress. Colours come from `context.palette` (`AppPalette.light` / `.dark`, a `ThemeExtension`); never write a fixed colour in a widget. Both palettes are held to the MS13 contrast rules by `test/theme_test.dart`. See [`MILESTONE_U2.md`](MILESTONE_U2.md).
**Web version on a computer (W1, 2026-09-30):** the same Dart app built with Flutter web, played in a desktop browser: progress saved in the browser's local storage (`BrowserProgressStore`), screens kept to a readable width on wide windows (`ContentWidth`), a reload or the browser's forward button opens home instead of a screen without its arguments. `tool/web.sh` builds when the code changed and serves it at http://localhost:8080. Not published anywhere yet. See [`MILESTONE_W1.md`](MILESTONE_W1.md).
Do not change the architecture.

Milestone commits: MS5 `06e2037c5d4841a33d69763d2385e0a8f834dc9c`,
MS6 `39956f967f8102f747be94bc3ad9de4c0703c674`,
MS7 `7d689dca871b33e58de23c2879d296aff6e74553`,
MS8 `9b005b88cc1953b9b629f890697746ffccca2939`,
MS9 `2be68bde64fc537c9a8e211c52d355a6d0c31d52`,
MS10 `c192118c079e73c8ff78b7fa71d00adf0285959a`,
L1 `d850525b2869271381356b27227e42648476192f`,
MS11 `033f3ec63dc137e1b74a7b2b20d2233da0fe3da8`,
MS12 `c3f3d5d75c128f62ea1547715bb89a0f62d41857`,
MS13 `10f6ec447778b92bf65eab579ba17d904cb6df17`, U1 — see `git log` (the
commit titled "U1: Turkish localization, block reference, number entry and
puzzle variables").

---

## What this product is

Working title: **Algorun**. Android-first Flutter/Dart algorithm puzzle game.

The player constructs algorithms with Scratch-style typed visual blocks. No
syntax. No eval of generated Dart/JS/Kotlin. The game ships 119 campaign puzzles
in 12 worlds (five from MS8, 33 from MS12, 47 from MS14), tiers 1–5. The
corpus stops here for a playtest; it is not on the way to 300 until that
playtest says so. Since L2 world 12 (recursion) has 15 puzzles; since H
world 09 (heaps) has 15.

There is **no TypeScript / React / web product codebase**. The web version
(W1) is the same Dart app built with Flutter web, not a second implementation.

## Locked decisions (do not reopen)

1. Flutter + Dart only. Android primary (`com.algorun`).
2. Engine is pure Dart: `packages/algorun_engine` must not import `package:flutter`.
3. First five puzzles are probes, not the difficulty ceiling. *(MS8 reading: the five real puzzles are the first real set, and still not the ceiling.)*
4. Per-puzzle `blocks.allow` is the editor palette. Full-catalog palette is a bug.
5. No Big-O analyzer in v1. Grade with `maxOps` / `maxAlloc` / `maxDepth`.
6. Local hidden tests are UI-hidden, not APK-secret. `VerdictSource.remote` is reserved.
7. `packages/algorun_content` is offline-only. The Flutter app must not import it.
8. Stay on Flutter/Dart.
9. *(MS7)* Puzzle JSON is data only. Validators are registry names; fixtures are canonical values; nothing in content is ever executed.
10. *(MS8)* Every puzzle a player can reach is proven solvable by a reference solution: a `BlockGraph` stored as data in `content/references/`, never bundled and never shown in the UI, which the content validator builds, lowers and runs through the real `TestRunner`.
11. *(MS12)* Content is an untrusted candidate until the pipeline accepts it at all seven levels. Every campaign puzzle has a `spec` and an independent oracle in the offline tooling; a disagreement between oracle, fixtures and reference fails the puzzle, and an expected answer is never changed to match a reference.

Full lock text: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Pipeline

```
Puzzle JSON ──(MS7 closed schema + typed fixtures)──▶ Puzzle
  → BlockGraph            (MS2, built in the MS3 editor)
    → validate            (MS1/MS2)
      → AST / IR          (MS4)
        → Interpreter     (MS5)
          → TestRunner    (MS6)
            → SuiteResult → results screen
```

The whole path is live: RUN in the app goes block graph → validate → lower →
test runner → result.

## Package structure

```
algorun/                          Flutter app (repository root)
  lib/                            UI, editor, Riverpod
    editor/                       Scratch-style editor (MS3; reworked for phones in MS13)
      editor_controller.dart      EditorController: typed placement, selection, moves, copy, delete, folds (MS13)
      editor_bars.dart            FlashBanner, BlockActionsBar (selection), RunBar (undo / redo / count / RUN) (MS13)
    dev/stress_probe.dart         the 82-block editor stress program, built through EditorController.place (MS13)
    l10n/                         U1: app_en.arb (template) + app_tr.arb, gen/ (generated, committed), l10n.dart (context.l10n),
                                  terms.dart (game words), engine_text.dart (engine sentences → Turkish), content_text.dart (puzzle text)
    guide/guide_data.dart         U1: the block reference's content (73 blocks, 12 concepts, EN + TR)
    screens/                      home, worlds, puzzle, results, settings, guide (U1: block reference)
    state/l10n_providers.dart     U1: languageProvider, contentTextProvider (Turkish content loaded only when chosen)
    puzzles/asset_repository.dart loads assets through the engine schema
    state/providers.dart          engineProvider → DefaultEngine
    state/run_puzzle.dart         the RUN path: graph → lower → runTests (+ hintsUsed)
    state/hint_session.dart       HintSession: hints revealed in this visit (MS9)
    progress/                     MS11, pure Dart except file_progress_store.dart:
      save_data.dart              PlayerSave, PuzzleProgress, RunNumbers, RunRecord, PlayerSettings, CurrentSession
      save_codec.dart             encodeSave / decodeSave: the versioned save format
      campaign.dart               Campaign, evaluateCampaign → CampaignProgress (unlock rules)
      progress_ledger.dart        completes(), openPuzzle, saveDraft, recordRun (pure updates)
      progress_store.dart         ProgressStore interface, MemoryProgressStore
      file_progress_store.dart    FileProgressStore: one JSON file in the app support directory
    state/progress_providers.dart progressStoreProvider, campaignProvider, progressProvider (autosave), campaignViewProvider
    state/progress_text.dart      player wording for locks and statuses
  assets/                         bundled with the app
    worlds.json                   14 worlds, 149 puzzles (09 heaps and 12 recursion full since H / L2)
    l10n/content_tr.json          U1: Turkish world titles, concept words, puzzle titles / stories / hints
    puzzles/world_01/             warm_readings, highest_tide + ms1_contract_probe, ms3_editor_probe, l1_list_probe, l1_tree_probe, ms13_stress_probe (unlisted dev probes)
    puzzles/world_02 … world_14/  the campaign puzzles (list: "Content backlog and coverage")
  content/                        offline only, NOT bundled
    references/<world>/<id>.json  reference solutions + spec + metrics + rejects
    capabilities.json             language capability audit: families and modes (MS12)
    coverage_targets.json         planning targets (~300 puzzles) per world, family, mode (MS12)
    coverage.json                 generated coverage matrix and gaps (MS12, committed)
    templates/                    authoring request + a worked candidate (MS12)
  packages/
    algorun_engine/               pure Dart, no Flutter
      lib/src/ast/                ir.dart (typed IR), lower.dart
      lib/src/blocks/             catalog, graph, typing, commands, chrome
      lib/src/blocks/narrowing.dart       Narrowing: where a value that may be empty is known to hold something (L1)
      lib/src/execution/          AlgorunEngine, DefaultEngine, Interpreter, results
      lib/src/puzzles/            parse.dart (THE schema), puzzle.dart, world.dart
      lib/src/puzzles/progression.dart    evaluateUnlocks: THE unlock rules (MS11 rules, moved here in MS12)
      lib/src/runner/             TestRunner, validator registry
      lib/src/runtime/            RuntimeValue, value_json.dart (fixture format), limits
      lib/src/types/              ValueType + parser
      lib/src/execution/performance.dart  BudgetOverrun, SuitePerformance (MS10)
      lib/src/runner/benchmark.dart       measureCase, benchmark, PerformanceReport (MS10)
      test/                       350 tests
    algorun_content/              offline content pipeline (MS12), CLI bin/validate.dart
      lib/src/content_validator.dart      orchestration, per-puzzle verdicts
      lib/src/reference_check.dart        levels 1–5 per reference (spec, capabilities, replay, runs, oracle, budgets)
      lib/src/editor_replay.dart          reference rebuilt with the editor's commands
      lib/src/content_spec.dart           spec, performance classes, capability audit
      lib/src/oracles/                    Oracle framework + one independent oracle per campaign puzzle
      lib/src/progression_check.dart      level 6: reachability, cycles, unlearnable prerequisites
      lib/src/redundancy.dart             level 7: fingerprints, near duplicates
      lib/src/coverage.dart               level 7: coverage matrix and gaps
      lib/src/difficulty.dart             level 7: difficulty signals and advice
      lib/src/content_issue.dart          ContentIssue, Level, PuzzleVerdict, ContentReport
      test/                       85 tests
  docs/                           architecture + per-milestone notes
  test/widget_test.dart           Flutter editor / picker / RUN tests
  test/real_puzzles_test.dart     the five real puzzles through the bundle and RUN
  test/hint_session_test.dart     hint session, the five puzzles' hints, hintsUsed through RUN
  test/hint_ui_test.dart          the hint interaction on the real puzzle screen
  test/performance_ui_test.dart   budget wording and the results screen (MS10)
  test/nullable_editor_test.dart  IS NOT NOTHING in the editor, the picker and RUN (L1)
  test/progress/                  save format, progression, best results, sessions (MS11, no widgets)
  test/progression_ui_test.dart   fresh install, locks, CONTINUE, restore, RUN completing a puzzle, settings (MS11)
  test/campaign_test.dart         the shipped campaign: every puzzle reachable, the unlock order (MS12)
  test/fixtures/ms11_worlds.json  the MS11 manifest, frozen: the MS11 rule tests run against it
  test/editor_actions_test.dart   select, move, copy, delete, folds, one undo step each (MS13)
  test/stress_probe_test.dart     the 82-block probe on a 360 × 800 phone (MS13)
  test/responsive_test.dart       the whole flow on 5 phone sizes × 2 font scales (MS13)
  test/campaign_regression_test.dart  all 119 puzzles: built by taps, saved, run, reported at 360 × 800 (MS13 harness; MS14 added the new puzzles to the same loop)
  test/screens_polish_test.dart   verdicts, next puzzle, world / puzzle wording (MS13)
  test/literal_sheets_test.dart   number pad, name sheet and TRUE / FALSE under the real theme (MS13, U1)
  test/localization_test.dart     U1: ARB parity, engine sentence coverage, Turkish content, block reference coverage
  test/localization_ui_test.dart  U1: language switch, reference in both languages, a Turkish puzzle, Turkish at ×1.6
  test/editor_variables_test.dart U1: puzzle variables declared on open; every reference restores with identical IR
  test/theme_test.dart            U2: both palettes' contrast rules, Light / Dark / System, saved, kept by reset
  test/web_test.dart              W1: readable widths on 1400 / 1920 px windows, phones unchanged, argument-less routes go home
  test/support/                   shared helpers: campaign from files, progress fixtures, phone sizes, UI replay, results rows
  lib/state/performance_text.dart player wording for budgets (MS10)
```

App `pubspec.yaml` path-depends on `packages/algorun_engine` only; beyond
Flutter and Riverpod it uses `path_provider` (MS11, to find the save
directory) and, since U1, `flutter_localizations` + `intl` (gen-l10n,
`l10n.yaml`).

## Important APIs

### Engine

```dart
abstract interface class AlgorunEngine {
  ValidationReport validate(BlockGraph graph, Puzzle puzzle);
  LowerResult lower(BlockGraph graph, Puzzle puzzle);          // never throws
  RunResult run(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
  SuiteResult runTests(Program program, Puzzle puzzle);
}
```

`DefaultEngine` is the shipping implementation: `lower` runs full `validate`
first, `run` is the MS5 interpreter, `runTests` is the MS6 runner.

### Typed ports (MS2) — do not change

- `PortKind` = `{statement, expression, elseClause}`.
- `GraphTyping.canConnect` is the snap/picker source of truth.
- `GraphTyping.compatiblePlacements` filters the hole picker.
- *(L1)* `GraphTyping` types a GET where it is (or is being dropped) through `Narrowing` — see "Values that may be empty".
- `GraphHistory` + reversible commands. Failed connects do not push undo.
- Top-level stack is `@main.body`.
- Variables live on `BlockGraph.variables`. GIVENS = `puzzle.io.inputs`. CREATE names come from `puzzle.variablePool` (chips only).
- Canvas `x` / `y` / `collapsed` are UI-only. Lowering ignores them.

### IR (MS4)

Closed, typed, JSON-serializable (`Program.toJson` / `fromJson`). No callbacks, no UI metadata.

| Node | Shape |
|---|---|
| `Program` | `entry` (`main`) + `functions` |
| `FnDecl` | name, params, optional return type, body, `srcBlockId` |
| `Stmt` | seq, if (optional else), while, forRange, forEach, break, continue, return, assign, inc, dec, expr |
| `Expr` | lit, var, binary, unary, call, index, field, null, new — each has `ValueType` + `srcBlockId` |
| `LValue` | var, index, field |

| Blocks | IR |
|---|---|
| `var.set` | `AssignStmt` + `VarLValue` |
| `var.inc` / `var.dec` | `IncStmt` / `DecStmt` |
| `ctrl.if` + optional `ctrl.else` | **one** `IfStmt` |
| `ctrl.while` / `ctrl.for_range` / `ctrl.foreach` | `WhileStmt` / `ForRangeStmt` / `ForEachStmt` |
| `ctrl.break` / `continue` / `return` | matching stmts |
| `arith.*` / `cmp.*` / `logic.*` | `BinaryExpr` / `UnaryExpr` (`arith.floor_div` → `BinaryOp.floorDiv`, MS7; `logic.is_nothing` / `logic.is_not_nothing` → `UnaryOp.isNothing` / `isNotNothing`, L1) |
| `arr.get` / `arr.set` | `IndexExpr` / `AssignStmt` + `IndexLValue` |
| `ll.*` / `tree.*` | `FieldExpr` / `FieldLValue` |
| other catalog ops (`arr.len`, `map.get`, mutators, …) | `CallExpr` / `ExprStmt` with the catalog id as callee |
| `fn.def` / `fn.call` | unsupported |

### Interpreter (MS5)

```dart
RunResult runProgram(Program program, Map<String, RuntimeValue> input, RunLimits limits, {TraceSink? trace});
```

Tree-walks the IR. Never sees a `BlockGraph`, never evals, no clock / random / I/O. Never throws.

- `ResultKind.correct` = ran to completion; verdicts are the runner's.
- Budgets are checked *before* a step: `maxOps` = one op per executed block (loop header once per iteration; `seq`, call wrappers and short-circuited operands free), `maxAlloc` = live collection cells, `maxDepth` = function frames (`ResultKind.depthLimit`).
- Deterministic: insertion-ordered maps and sets, `for each` iterates a snapshot, the `for range` counter is loop-owned, given values are deep-copied on entry.
- DIVIDE keeps whole results whole (`8 / 2` → `2`, `7 / 2` → `3.5`). FLOOR DIVIDE is below. Dividing by zero is a runtime error. List positions must be whole numbers inside the list.
- Equality is by value for number / text / yes-no / empty; containers, nodes and graphs are only equal to themselves.
- `RuntimeValue` is sealed: `Nil Num Bool Str Array Map Set Stack Queue Deque ListNode TreeNode Graph`. Adding one means updating `valuesEqual`, `value_json.dart` and the interpreter's copy.

Details: [`MILESTONE_5.md`](MILESTONE_5.md).

### Test runner (MS6)

```dart
final class TestRunner {
  SuiteResult run(Program program, Puzzle puzzle);                              // puzzle.allTests, visible first
  SuiteResult runCases(Program program, Puzzle puzzle, List<TestCase> cases);   // generator seam
}
```

- Cases arrive decoded and type-checked by the schema (`TestCase.input` / `output` are `RuntimeValue`s). The runner does no conversion of its own.
- Each case gets a fresh interpreter, which copies its input, so cases cannot see each other and fixtures never change.
- The runner invents one verdict, `wrongAnswer`; every other failure is the interpreter's own, with its message and `srcBlockId`.
- Metrics: worst `ops` / `peakAlloc` / `peakDepth` across cases, `blocks` = distinct `srcBlockId`s, `hintsUsed` = 0 until MS9.
- Hidden cases never enter `SuiteResult.visible`; only `HiddenSummary(passed, total)` leaves. `firstFailureCaseId` is set only for a visible failure.
- Visible `CaseResult.input` / `expected` / `actual` are canonical fixture JSON, so the results screen shows both sides in the author's format.

App side: `lib/state/run_puzzle.dart` holds the RUN path. Details: [`MILESTONE_6.md`](MILESTONE_6.md).

### Content contract (MS7)

**One schema.** `packages/algorun_engine/lib/src/puzzles/parse.dart` is the only definition of a puzzle. The game loads through it and the content validator calls it.

```dart
PuzzleRead readPuzzleJson(String source);   // never throws: puzzle or every issue with a JSON path
Puzzle parsePuzzleJson(String source);      // throws SchemaException(issues)
WorldsRead readWorldsJson(String source);
WorldsManifest parseWorldsJson(String source);
```

**One conversion path** for values (`lib/src/runtime/value_json.dart`):

```dart
RuntimeValue valueFromJson(Object? json, {ValueType? type, FixtureLimits limits});  // throws FixtureFormatException only
Object? valueToJson(RuntimeValue value, {FixtureLimits limits});                    // canonical JSON
String? fixtureTypeProblem(ValueType type);                                         // can this type be a fixture?
```

Schema rules, in short (full table in [`MILESTONE_7.md`](MILESTONE_7.md)):

- Closed at every level: unknown fields are errors. Behavior-shaped names (`generator`, `script`, `eval`, `predicate`, …) get a "data only" error. `meta` is the one open door: flat text / number / boolean, never read.
- Required: `id title world tier mode story io blocks limits fixtures`. Ids and world / chapter / concept names are `lower_snake_case`.
- `tier` 1–5; `mode` from the `PuzzleMode` enum; `limits.maxOps` 1–10,000,000, `maxDepth` 1–10,000, `maxAlloc` 1–1,000,000; `blocks.maxBlocks` 1–500.
- `blocks.allow` non-empty, known catalog ids, no repeats; `forbid` known and disjoint from `allow`.
- `io` types must parse and have a fixture form (not `void`, `heap`, `pair`; set items and map keys are num / str / bool).
- Fixtures: `visible` and `hidden` non-empty; case ids unique across both; `in` has exactly the declared inputs; `out` required. Every value is decoded against its declared type — nullability and element types included.
- `validators.output` is a registry name (default `equal`) and must fit `io.output`; `io.output.order: "any"` needs an order-free validator.

**Fixture format** — plain JSON for `null`, numbers, booleans, text and arrays; every object is tagged:

```json
{"type": "map", "entries": [["a", 1], ["b", 2]]}
{"type": "set", "items": [1, 2, 3]}
{"type": "stack", "items": [1, 2, 3]}
{"type": "queue", "items": [1, 2, 3]}
{"type": "deque", "items": [1, 2, 3]}
{"type": "listNode", "values": [1, 2, 3]}
{"type": "listNode", "values": [3, 2, 0, -4], "cycleTo": 1}
{"type": "treeNode", "value": 2, "left": {"type": "treeNode", "value": 1}, "right": null}
{"type": "graph", "nodes": [{"id": 0, "neighbors": [1]}, {"id": 1, "neighbors": [0]}], "visited": [0]}
```

Stacks are bottom → top, queues and deques front → back. An empty linked list is `null`. Graph neighbors must name existing nodes, keep their order, and may form cycles and self-loops; edges are directed. Limits: 10,000 values and 1,000 nesting levels per value.

**Validator registry** (`lib/src/runner/validators.dart`), closed:

| Validator | Output must be |
|---|---|
| `equal` | anything (strict, shape included) |
| `listEqualByValue` | array, stack, queue, deque, listNode |
| `unorderedArray` | array, set, stack, queue, deque, listNode |
| `setEqual` | array, set |
| `unorderedPairs` | array of arrays |
| `treeEqual` | treeNode |

### Integer division (MS7)

DIVIDE is unchanged. **FLOOR DIVIDE** (`arith.floor_div`, `num × num → num`,
MATH category) returns the largest whole number not above `left / right`:
`7 → 3`, `8 → 4`, `-7 → -4` (all ÷ 2), `7 ÷ -2 → -4`. Always whole, so it is a
valid list position (`nums[(lo + hi) FLOOR DIVIDE 2]`). Zero denominator is a
runtime error. Lowers to `BinaryOp.floorDiv`; one op.

### Content validator (MS7, MS8)

`packages/algorun_content`: `ContentValidator.validateContent(puzzles:, worldsSource:, references:)` → `ContentReport` of errors and warnings, each with file and JSON path, in a stable order.

Errors: every schema rule; an expected answer that fails its own validator; duplicate puzzle ids; a file not at `<world>/<id>.json`; a world listing a missing or invalid puzzle; a puzzle whose world is unknown or listed by another world; a malformed manifest; every reference rule above. Warnings: no hints; `fn.*` allowed; whole-catalog allowlist; a puzzle no world lists; a prerequisite no world teaches; a reference above 80 % of a budget; references not given.

### The five puzzles (MS8)

| Title | Id / world | Pattern | Mode, tier | What it turns away |
|---|---|---|---|---|
| Twin Beacons | `twin_beacons` / 03 | complement lookup, hash set | budget, 2 | all pairs (op budget); add before asking (hidden trap) |
| Quota Hours | `quota_hours` / 05 | variable sliding window | build, 3 | all runs (op budget); unconverted placeholder (hidden trap) |
| Relay Towers | `relay_towers` / 06 | monotonic stack | build, 3 | looking east (op budget); popping on equal heights (hidden trap) |
| The Smallest Cart | `smallest_cart` / 02 | binary search on the answer, FLOOR DIVIDE | build, 3 | one-unit steps (op budget); a DIVIDE midpoint |
| Fewest Rides | `fewest_rides` / 10 | BFS shortest path on a `graph` fixture | build, 3 | depth-first with a stack (hidden trap) |

Tree BFS was not chosen because at MS8 the language could not traverse a tree;
L1 closed that gap (see "Values that may be empty"). Per-puzzle rationale,
budgets and cases are in [`MILESTONE_8.md`](MILESTONE_8.md).

### Reference solutions (MS8)

A puzzle declares `"reference": {"strategy": "<lower_snake_case>"}`. Its
solution lives at `content/references/<world>/<id>.json`:

```json
{ "puzzle": "<id>", "notes": "…", "solution": { <BlockGraph JSON> },
  "rejects": [ { "name": "…", "expect": "operationLimit", "graph": { <BlockGraph JSON> } } ] }
```

`ReferenceChecker` (`packages/algorun_content/lib/src/reference_check.dart`)
proves the following for the solution:

- It uses only allowed blocks, stays within `maxBlocks` and is structurally
  sound (`engine.validate`).
- It is **buildable in the editor**: `replayInEditor` rebuilds it top-down with
  `AddBlockCommand` / `AttachStatementCommand` / `ConnectCommand`, starting from
  the givens and the pool and using only editor-settable literals.
- It lowers.
- It passes every visible and hidden case through `engine.runTests` within the
  puzzle's limits. The checker warns above 80 % of any budget.

Each reject must be buildable, pass every visible case, and end the suite in
exactly its declared `ResultKind`. That is how "correct but too slow" and
hidden traps are proven, not just claimed.

Rules: every puzzle a world lists must declare reference metadata, every
puzzle that declares it must have a passing reference file, and a reference
file with no puzzle is an error. Nothing is keyed to puzzle ids.

### Hints (MS9)

- Data: `Puzzle.hints`, a plain list of text in the author's order (idea →
  approach → stronger guidance). Every real puzzle has three. Nothing is
  generated or derived from the reference solution.
- UI: puzzle screen, directly under the BRIEF. **SHOW HINT n** reveals the next
  hint and becomes **NO MORE HINTS** (disabled) after the last. The
  **HINTS used/total** row opens and closes the revealed list. A puzzle without
  hints shows no hint row. Hints are never revealed automatically.
- `HintSession` (`lib/state/hint_session.dart`, pure Dart) is the only thing
  that counts. Only revealing a *new* hint counts; opening, closing, re-running
  or tapping the disabled button does not. The session lives as long as the
  puzzle screen; revealed hints are never persisted (only a run's hint count
  is kept as a metric since MS11).
- `hintsUsed`: RUN passes `HintSession.used` to `runPuzzle(..., hintsUsed:)`,
  which stamps it with `SuiteResult.withHintsUsed` (both the graded and the
  "cannot run yet" path). The `TestRunner` itself always reports 0 and grading
  never reads hints. The results screen shows it on the WHAT IT COST line.
  It is a metric only: no scoring, stars or penalties read it.
- The content validator warns when a hint quotes an internal block id or a
  hidden case id.

Details: [`MILESTONE_9.md`](MILESTONE_9.md).

### Performance (MS10)

**Operation model — unchanged since MS5, pinned by content.** Every executed
block costs 1 operation; a loop header costs 1 per iteration; `seq` and call
wrappers are free; a short-circuited AND / OR side is neither run nor charged;
a budget is checked *before* the step it pays for (a program needing exactly
`maxOps` passes, `maxOps + 1` fails). The five reference files record their
measured cost (`metrics`), and the content validator refuses any drift, so a
change to these rules can never slip in silently. If one is ever needed:
document it, re-record the metrics, and state the compatibility impact.

**Budgets.** `limits.maxOps` is the one authoritative operation budget, per
case. A fixture case may declare `"maxOps"` only *tighter* (a larger value is a
schema error). `limits.maxAlloc` (memory cells) and `limits.maxDepth` (frames)
stop a run as before; `blocks.maxBlocks` refuses the program before it runs.
No budget is wall-clock time.

**Correct but too slow.** A case over its operation budget is
`ResultKind.operationLimit`, exactly as in MS6 (same message, same
`SuiteResult.metrics`). The runner then re-runs that case once with room up to
`overrunCeiling(budget)` (5 budgets, at most +1,000,000 operations) purely to
measure it: `CaseResult.overrun` (visible cases) and `SuiteResult.performance`
(`SuitePerformance`: `opsBudget`, `worstOps`, `overBudgetCases`,
`overBudgetFinished`, `correctWhereFinished`, `worstOverrun`,
`correctButOverBudget`) — counts only, never a hidden case's name or data.

**Puzzle side.** `"performance": {"required": true, "baselineFactor": k}` —
closed data, no formulas. `required` makes the validator demand a
correct-but-slow baseline (a reject that passes the visible cases and expects
`operationLimit`); `baselineFactor` demands that baseline needs at least `k`
times a case budget, so every passing solution beats it by `k`. Twin Beacons
declares `required: true, baselineFactor: 10`.

**Reference performance.** The checker prints an INFO line per reference
(operations, memory, depth, blocks against the limits) and compares the
recorded `metrics` with a fresh measurement.

**Benchmark API** (content tooling / analytics, never the player UI — it names
hidden cases): `benchmark(program, puzzle, {cases})` → `PerformanceReport` of
`PerformanceSample` (`caseId`, `visible`, `inputSize`, `ops`, `peakAlloc`,
`peakDepth`, `finished`) and `BudgetCheck`s. `inputSize` = total size of the
collection inputs.

**No Big-O.** The engine never proves, estimates or displays a complexity
class and never infers one from sizes. Player text talks about operations and
budgets only; a complexity statement exists only if a content author writes
it into a story or hint.

**UI.** The results screen explains an operation limit ("The result is
correct, but this solution uses too many operations: 58 against a budget of
30." / "Every case that finished came out right, but … still running after
300,000 …" / "… and not every answer is right either."), shows the measured
operations on the WHAT IT COST line (`300,000+` when still running), and adds
a `Budget: … steps · … cells · depth … · … blocks` line.

Details: [`MILESTONE_10.md`](MILESTONE_10.md).

### Values that may be empty (L1)

**Model.** `ValueType.nullable` as it always was: `NEXT NODE` → `listNode?`,
`LEFT` / `RIGHT` → `treeNode?`, a map lookup → `V?`; givens and pool variables
may be declared `listNode?` / `treeNode?` / `num?` (fixture `null`). Storing
such a value in a variable that may be empty is fine. Putting it where a real
value is needed (a node or number hole, a plain variable, SWAP / COPY) is
refused by the editor and by lowering with *This value may be empty here.
Check that it is not empty first.* (code `may_be_empty`).

**Blocks.** `logic.is_nothing` IS NOTHING and `logic.is_not_nothing` IS NOT
NOTHING — LOGIC, `verbObject` layout (`[node] IS NOT NOTHING`), `T? → bool`.
Only a value that may be empty fits; a plain value / an already-checked
variable ("never empty here") and NOTHING itself are refused. There is no
unwrap / cast / force block, by design.

**Narrowing** (`lib/src/blocks/narrowing.dart`, the one implementation, read by
`GraphTyping` and the lowerer): a plain variable reads as its plain type in
THEN of `IF x IS NOT NOTHING`, ELSE of `IF x IS NOTHING`, the body of
`WHILE x IS NOT NOTHING`, and across AND (right side and branch). OR, NOT,
EQUAL NOTHING and checks on anything but a plain variable narrow nothing.
Branch-local: after the IF or loop the variable may be empty again. Any write
(SET, INCREMENT, DECREMENT, SWAP, COPY, a FOR counter) ends the narrowing for
the rest of that flow; a loop keeps an outer fact only if the loop never
writes that variable.

**IR / runtime.** Two appended `UnaryOp`s (old IR JSON reads unchanged); the
interpreter returns `BoolValue(value is NilValue)` (or its negation), never
errors, one operation per block as always. No narrowing metadata in the IR.

**Probes.** `l1_list_probe` (count a chain, `WHILE node IS NOT NOTHING … node =
NEXT NODE node`, 109 ops) and `l1_tree_probe` (LEFT of the root, IS NOTHING /
ELSE, 9 ops): unlisted, bundled, with reference files the validator replays,
lowers and runs.

Details: [`MILESTONE_L1.md`](MILESTONE_L1.md).

### Progression and local save (MS11)

**State.** `PlayerSave` (stored) = `puzzles` (per puzzle `PuzzleProgress`:
`puzzleVersion`, `completed`, `best`, `solution`, `draft`, `lastRun`,
`editedSinceRun`) + `settings` (`PlayerSettings.showBriefOnOpen`, `language` (U1), `theme` (U2)) + `session`
(`CurrentSession`: last world and puzzle). `CampaignProgress` (unlocked
worlds, mastered concepts, statuses, what a lock waits for, the current
puzzle) is **derived** by `evaluateCampaign(campaign, save)` every time and
never stored. `Campaign` = the worlds manifest + every puzzle a world lists;
the dev probes are not in it, are never recorded and never affect anything.

**Unlock rules** (data only — world `concepts` / `prerequisites`, puzzle
`prerequisites`; no id is special): a world opens when its prerequisites are
mastered or the player already solved one of its puzzles; it completes when
open and every listed puzzle is solved (a world with no puzzles completes as
it opens); a complete world masters its concepts; a puzzle opens when its
world is open and its own prerequisites are mastered or taught by its world.
Applied to a fixpoint. Since MS12 the rules are one pure engine function,
`evaluateUnlocks` (`packages/algorun_engine/lib/src/puzzles/progression.dart`),
which the app's `evaluateCampaign` and the content validator (level 6) both
call. Fresh install (MS12 campaign): Foundations is open; completing it opens
Arrays; Arrays opens Hash Maps, Two Pointers, Stack & Queue and Greedy; Two
Pointers opens Sliding Window; Stack & Queue → Linked Lists → Trees → Heaps
(empty) and Graphs; Greedy → Dynamic Programming; DP + Graphs → Advanced.
Backtracking waits for `recursion`, which nothing teaches.

**Completion rule.** A RUN completes its puzzle exactly when
`suite.kind == ResultKind.correct` — every case right within every budget.
Correct but over the operation budget (`operationLimit`) does not complete.
Hints never matter. Completion is never taken back.

**Best results.** Five independent minima over completing runs (`ops`,
`peakAlloc`, `peakDepth`, `blocks`, `hintsUsed`), each replaced only when
strictly better; no combined score. A failing run changes only `lastRun`.
`solution` = the program of the completing run with the fewest operations
(first wins a tie); the puzzle screen can load it back (undoable).

**Save format** (`save_codec.dart`, `saveVersion: 1`): deterministic JSON
(sorted keys); programs are `BlockGraph` JSON, never IR; only player state.
Reading never throws and never invents a completion: unusable text (not JSON,
no / bad / newer version) is kept aside and play starts fresh; a damaged
section (one puzzle entry, one program, the settings, the session) is dropped
on its own with a `SaveIssue`; a program must pass `GraphStructure.validate`
(unfinished holes are fine). Unknown fields are ignored and not written back.
Older versions go through a migration table (empty for v1). A puzzle with a
different `version` keeps `completed` and `draft`, and clears `best`,
`solution` and `lastRun` (the editor says the puzzle changed).

**Storage.** `FileProgressStore`: `algorun_save.json` in
`getApplicationSupportDirectory`, written to `.tmp` then renamed; an unusable
save is copied to `algorun_save.unreadable-<millis>.json`. `main.dart`
installs it; the provider default is `MemoryProgressStore`, so tests never
touch the device. On the web (W1) `platformProgressStore()` is a
`BrowserProgressStore`: the same JSON in the `algorun_save` local-storage
slot of the site, unreadable text copied to `algorun_save.unreadable-<millis>`
(`lib/progress/platform_store*.dart` picks the store per platform).

**Autosave** (`ProgressNotifier`): a new editor `BlockGraph` updates the draft
in memory and is written after 800 ms of quiet; opening a puzzle, RUN, a
settings change, leaving the puzzle and the app being hidden / paused /
detached (`AppLifecycleListener` in `AlgorunApp`) write at once. Writes never
overlap; nothing is recorded before the save has loaded; failures are
reported (`ProgressNotifier.issues`, debug log), never thrown.

**UI.** Home: PROGRESS card, CONTINUE (last puzzle) or ENTER on a fresh
install. Worlds / Puzzles: open, solved, locked (*Locked — learn arrays
first*), no puzzles yet, CURRENT. Puzzle: restores `draft` → `solution` →
empty; solved check; Load best solution; locked by route shows why. Results:
PROGRESS lines (*Puzzle solved.* / *New best: …* / *Now open: …*). Settings:
brief preference, Reset progress (confirmed).

Details: [`MILESTONE_11.md`](MILESTONE_11.md).

### Content pipeline (MS12)

Every candidate puzzle (hand-written or AI-drafted) is untrusted until
`bin/validate.dart` accepts it at all seven levels — **L1 schema** (closed
schema, manifest, reference file, `spec`), **L2 blocks** (allowlist, budget,
capability audit of family and mode), **L3 replay** (rebuilt through the
editor's commands, lowered), **L4 execution** (every case through the real
`TestRunner`; rejects in their verdicts; oracle ↔ every fixture; oracle ↔
reference on 40 seeded random inputs; hidden cases not copies of visible
ones), **L5 performance** (budgets, recorded metrics, baselines, performance
class), **L6 progression** (reachability under `evaluateUnlocks`, cycles,
unlearnable prerequisites, order), **L7 corpus** (near duplicates, difficulty
advice, coverage gaps). The CLI prints a level on every finding, `ACCEPTED` /
`REJECTED … at L# name` per puzzle and a `PIPELINE` summary line.

- **Spec** (in the reference file): `family`, `pattern`, `structure`,
  `secondary`, `performance` (`correctness | budget | optimization |
  restricted`, must match the puzzle), `traps`, `oracle`. Required for every
  listed puzzle.
- **Oracles** (`packages/algorun_content/lib/src/oracles/`, registry in
  `registry.dart`): Dart `solve(input JSON) → output JSON` + `sample(Random)`,
  deliberately not the reference's algorithm (brute force, Bellman-Ford,
  union-find, recursion, the fixture's own `cycleTo`). The validator never
  changes an expected answer.
- **Redundancy**: fingerprint = pattern, io signature, concepts, statement
  skeleton, block histogram. Near duplicate (error on the later puzzle):
  same io and (same pattern with same skeleton or ≥ 80 % similar, or same
  skeleton + concepts and ≥ 90 % similar under any pattern name). Related
  (info): same pattern or skeleton or ≥ 80 %.
- **Difficulty**: half-point signals (blocks, loop nesting, structures the
  program builds, state variables, concepts, a budget); warns only on a
  two-tier mismatch or a trivial tier 4–5.
- **Capability audit**: `content/capabilities.json` — families and modes as
  supported / partial / blocked, enforced at L2.
- **Coverage**: `--coverage content/coverage.json` writes the matrix
  (by world, tier, mode, structure, family, performance class, concept, and
  every puzzle's metadata) and gaps against `content/coverage_targets.json`;
  a test fails when the committed file is stale.

Authoring contract for people and AI sessions:
[`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md). Details:
[`MILESTONE_12.md`](MILESTONE_12.md).

### Editor (MS3, MS13) — do not regress

Scratch-style vertical stacks + typed holes, tap to place. No canvas, no
drag, no TextField (names are chips, numbers a pad). Labels via
`BlockChrome` (GREATER THAN, never `cmp.gt`). IF + ELSE draw as one card.

- **Typed insertion.** Picker = `allowlist ∩ GraphTyping.compatiblePlacements`
  (GET, INCREMENT and DECREMENT come one per variable the rules accept). The
  picker says where the piece goes (*For the condition of WHILE*) and closes
  with a button or back. Tapping a slot scrolls it above the sheet first; the
  new block is selected and scrolled into view, unfolding what hides it.
- **Selection** (tap or long-press; nothing is deleted by a gesture): the
  selection bar replaces the palette — UP / DOWN / OUT / IN / COPY / DELETE
  for instructions, REPLACE / DELETE for values. Each action is one undo step
  built from the engine's own commands (`_Batch` in the controller), so
  `GraphTyping` still decides. Delete removes the whole subtree; a placement
  is one step. Back first clears the selection.
- **Folds**: per C-block, fold all / unfold all in the menu, *Folded · n blocks
  inside* (tap to open). Saved in the draft (`BlockInstance.collapsed`), never
  an undo step, never "edited since run".
- **Layout** (phone): feedback line · one scroll (brief, hints, givens,
  PROGRAM) · selection bar or palette · RUN bar (UNDO, REDO, `n / max blocks`,
  saved / practice, RUN). Palette hidden below 560 dp height; a 280 dp side
  rail from 840 dp width. Instruction rows ≥ 48 dp, values 36 dp, empty slots
  40 × 64 dp. System font honoured to ×1.6.
- After *Invalid Program*, returning selects the block to fix and says why.
- **Names (U1).** The editor declares the puzzle's `variables.pool` and
  givens when it opens and when a draft is restored (type environment only —
  no block, no step). There is no CREATE VARIABLE in the UI; the engine's
  `DeclareVariableCommand` / `declareVariable` stay for future player-named
  variables. GIVENS and VARIABLES are chips above the program.
- **Numbers (U1).** The pad opens with the number selected (typing replaces
  it), ⌫ deletes the last digit, CLEAR empties it, +/− with a "negative" tag;
  no ±1 buttons; never the system keyboard.

Details: [`MILESTONE_13.md`](MILESTONE_13.md), [`MILESTONE_U1.md`](MILESTONE_U1.md), [`MILESTONE_U2.md`](MILESTONE_U2.md).

### Android shell (MS13)

Edge to edge on every version (`SystemUiMode.edgeToEdge`), system-bar icons
that read on the theme (dark on light, light on dark; U2), no navigation-bar
scrim, a window theme and launch background that follow the device's dark
mode (`android/app/src/main/res/values` light, `values-night` dark; U2). Every screen keeps its content inside the side
insets; the RUN bar and results buttons stay above the navigation bar.
Verified on the emulator: back, background autosave, process death and
restore, no keyboard ever.

### Languages (U1)

English (default) and Turkish, chosen in Settings and saved in
`settings.language` (reset progress keeps it). UI strings: ARB + gen-l10n
(`lib/l10n/`, run `flutter gen-l10n` after editing an ARB). Puzzle content
stays English in the puzzle JSON; Turkish lives in
`assets/l10n/content_tr.json` with a per-field English fallback. The engine
stays English; `lib/l10n/engine_text.dart` translates its sentences by exact
text (a test scans the engine and fails on an untranslated sentence). Block
names and the words inside blocks stay English in every language, also
inside Turkish stories and hints. Turkish capitals go through `l.upper()`.
The block reference (Blok Rehberi, `/guide`) opens from home, settings, the
puzzle app bar and the piece picker. Details:
[`MILESTONE_U1.md`](MILESTONE_U1.md).

## Test results at U1 closeout

| Suite | Result |
|---|---|
| `packages/algorun_engine` `dart analyze` | no issues |
| `packages/algorun_engine` `dart test` | **381 passed** (H) |
| `packages/algorun_content` `dart analyze` | no issues |
| `packages/algorun_content` `dart test` | **86 passed** (MS15) |
| Content validator (assets + worlds + references) | `PIPELINE 149 of 149 campaign puzzle(s) accepted, 5 probe(s) checked` · `OK 154 puzzle(s), 5 warning(s)` (H) |
| Flutter `analyze` | no issues |
| Flutter `test` | **517 passed** (H; 260 at MS14 review time of this table) |
| `flutter build apk --debug` | built |
| Emulator checklist (18 steps, MILESTONE_13.md) | passed on Android 15 emulator, 360 / 390 / 412 dp, landscape (MS13) |
| U1 emulator pass (MILESTONE_U1.md) | English and Turkish at 360 × 800 dp: home, reference, settings, worlds, puzzle, picker, pad, results |

Engine: MS4 lowering (86), MS5 interpreter (42), MS6 runner (26), MS7 codec
(40), schema (41), FLOOR DIVIDE (14), MS8 shipped puzzles (30), MS10
performance (17), L1 values that may be empty (44), MS12 unlock rules (6),
contract tests. Content: shipped set with references, every reference rule,
reference metrics and performance rules, hint leak warnings, CLI, the two L1
probes end to end; MS12 pipeline (36: every level's failure modes, the
shipped corpus accepted, coverage file up to date, one oracle per puzzle).
App: editor, picker, RUN, results, the MS8 puzzles, hints, budget wording, IS
NOT NOTHING in the editor; MS11 save format (22), progression and best
results (18), sessions and autosave (9), purity guards (2), progression UI
(10) — against the frozen MS11 manifest; the MS12 campaign (3); MS13:
editor actions (13), stress probe (6), responsive flows (11), all 38 puzzles
built by taps and run on a phone (77), screens (11), literal sheets under the
real theme (3). Engine +3 (INCREMENT / DECREMENT placements), content +3
(replay of an editor-saved ELSE). U1 (+25): localization (9), localization
UI (7), puzzle variables (4), number pad and TRUE / FALSE (+4), save
language (+1).

MS14 review (2026-09-25): engine 350, content **86** (+1: a puzzle whose
cases all expect one answer is refused), Flutter **364** (MS14 added the new
puzzles to the campaign loops, plus the move-reveal and playtest-unlock
tests), `flutter analyze` clean, validator 85 of 85 with the seven known
warnings. A scratch cross-check (story-based solvers against fixtures,
oracles and references, 14 596 runs) found no disagreement after the fixes.

The seven warnings are known and deliberate: Backtracking (world 12) requires
`recursion`, which no world teaches (the world has no puzzles; two warnings:
it never opens, and the prerequisite is untaught), and the five dev probes
are unlisted.

**Widget tests and the theme:** a test that opens sheets or buttons must use
`buildAppTheme(AppPalette.light or .dark)` (or `AlgorunApp`): the MS12
number-pad failure only showed under the real theme. The test device is
light, so `AlgorunApp` tests run the light theme; set
`tester.platformDispatcher.platformBrightnessTestValue` for dark.

**Widget tests and assets:** load the campaign from the repository files
(`test/support/campaign_files.dart`), never through `rootBundle` inside a
widget test — the bundle caches a pending load made in fake async and the next
test waits on it forever.

## Known limitations

### Open follow-ups

- **Narrowing is deliberately small (L1).** No narrowing through OR / NOT or after an IF whose THEN always returns (use IF / ELSE); assigning a real value does not narrow (check again); only plain variables narrow. The editor checks each drop where it is made, so an edit elsewhere can invalidate an earlier drop — lowering reports it before RUN. RETURN is still not checked against the puzzle's output type. Tree traversal beyond one path needs a queue or stack of nodes until recursion exists.
- **Hints are a metric only.** `hintsUsed` is shown and kept per run (`lastRun`, `best`) but never scored and never blocks anything; revealed hints are not persisted (MS9, MS11).
- **Progression is deliberately simple (MS11).** A world completes only when every listed puzzle is solved (no mastery threshold yet — worlds with 20–30 puzzles will want one); inconsistent content that would deadlock is caught by the validator since MS12 (level 6); an edit less than 800 ms before a kill without a lifecycle event is lost; one save slot, no export, no per-puzzle reset; the campaign loads every listed puzzle at start-up; unreadable-save copies are never cleaned up; on the web the save belongs to one browser at one address (another port or browser starts fresh).
- **Performance is counted, not scored.** No stars or scores read the budgets yet. A hopeless solution is only known to be "still running" at the measurement ceiling; its correctness beyond it is not claimed. Memory and depth have no overrun measurement. There is no fixture generator: size profiles are explicit fixtures with optional per-case `maxOps` (MS10).
- **Reference authoring has no tool.** References are hand-authored JSON checked by the validator; saving an editor graph as a reference would make authoring scale. MS12 authoring used scratch scripts outside the repository.
- **Random inputs are for checking only (MS12).** Oracles sample small inputs to compare with the reference; nothing generates shipped fixtures. A future generator must produce plain `TestCase` data for `TestRunner.runCases`, deterministic and within `FixtureLimits`, never executable content.
- **Content pipeline limits (MS12).** Redundancy relies on an honest `pattern` plus program structure — a differently programmed restatement can pass as "related". Oracles are hand-written per puzzle and only as independent as their author made them; sampled inputs are small. Coverage targets are a plan; difficulty advice is a heuristic.
- **Modes without a UI.** complete, repair, trace, predict, structure and ops need a starter program or an answer input the schema and editor do not have; every shipped puzzle is build-style in its mode (build, budget, optimize, restricted, edge).
- **World size (MS14).** Completion still needs every listed puzzle: Arrays is 9 puzzles before four worlds open, Graphs 13. Decide on a mastery threshold after the playtest.
- **World prerequisites.** Backtracking (world 12) requires `recursion`, which no world teaches (warning). Dynamic Programming now requires `greedy` (MS12; its puzzles are iterative).

### Other

- Graph nodes carry no values (the runtime graph has none). `pair` has no fixture form, runtime values or blocks; `heap` (H) has values and blocks but no fixture form, so no puzzle takes or returns one.
- A graph whose program marked a node it does not have cannot be written as canonical JSON; the results screen falls back to the display form.
- `constraints.n` is recorded but not checked against fixture sizes.
- `hintsUsed` is 0 until hints ship (MS9). The suite runs every case even after a failure.
- The `PuzzleScreen` → `ResultsScreen` navigation is not pumped in a test; `runPuzzle` covers the logic.
- The two MS1/MS3 probes stay bundled (tests, the editor seed, the screen's default route) but no world lists them; neither do the two L1 probes.
- Graph fixtures do not enforce "stations are numbered 0 to n-1"; `fewest_rides` states it and its fixtures follow it.
- `maxDepth` stays at 1 until player-defined functions ship; `fn.def` / `fn.call` remain unsupported and hidden.
- Allocation has no collector: an unreachable container keeps its cells for the rest of the run.
- Generic unification is per-block, not Hindley–Milner. The web version runs locally (`tool/web.sh`); it is not hosted anywhere.
- **Editor (MS13).** No drag and drop: blocks move one step at a time (UP / DOWN / OUT / IN). A move is typed by `GraphTyping`, but narrowing that changes with the new position is reported by lowering at RUN. The picker has no search. Landscape phones lose the palette (the picker remains). The stress probe opens from Settings in debug builds only.
- **Device testing (MS13).** Emulator only (software rendering, three-button navigation); no physical phone, no TalkBack pass, no frame timing on real hardware yet.
- **Languages (U1).** English and Turkish only. Engine sentences are matched by their English text, so changing one needs its ARB entry (the scan test says which). Fixture values on the results screen are JSON in both languages. Puzzle input and variable names stay English (they are the program's identifiers).
- `ARCHITECTURE.md` spells the validator command `dart run algorun_content:validate`; use the command below.

## Exact commands

From the **repository root**. Requires Flutter 3.47+ / Dart 3.13+ (app pubspec: `sdk: ^3.13.0`). SDK at MS13 closeout: Flutter 3.47.2, Dart 3.13.2.

```bash
flutter pub get

# Engine (no Flutter)
cd packages/algorun_engine && dart analyze && dart test && cd ../..

# Content
cd packages/algorun_content && dart analyze && dart test && cd ../..
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references --coverage content/coverage.json

# App
flutter gen-l10n     # after editing lib/l10n/app_*.arb (generated code is committed)
flutter analyze
flutter test
flutter run          # Android device/emulator
flutter build apk --debug
```

Emulator used for MS13 (see MILESTONE_13.md): AVD `algorun_phone`, Pixel 7
profile, `system-images;android-35;default;x86_64`; phone sizes via
`adb shell wm size 720x1600` + `wm density 320` (360 × 800 dp),
`1170x2532` + `480` (390 × 844), `wm size reset` (412 × 915).

Every new or edited puzzle must pass the content validator — with the
references directory — before it is committed under `assets/puzzles`. A new
playable puzzle needs a reference file with a `spec` in `content/references/`,
an oracle registered in `packages/algorun_content/lib/src/oracles/registry.dart`
and a world listing it; its folder must be in `pubspec.yaml` to ship. Commit
`content/coverage.json` regenerated (`--coverage`). Full procedure:
[`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md).

Do not add a TypeScript app. Do not eval generated source. Do not start one milestone from another milestone's request.

## Roadmap

| Order | Milestone | Status |
|---|---|---|
| 1–10 | skeleton → typed blocks → editor → lowering → interpreter → test runner → schema → five puzzles → hints → performance metrics | complete |
| L1 | Language: values that may be empty, IS NOTHING / IS NOT NOTHING, narrowing | complete |
| 11 | Progression + local save | complete |
| 12 | Content pipeline (oracles, reachability, coverage, redundancy) + 33 new puzzles | complete |
| 13 | Mobile UX polish and usability (emulator-verified) | complete |
| U1 | English / Turkish, block reference, number entry, no CREATE VARIABLE | complete |
| 14 | Content batch 2: 47 puzzles (85 in the campaign) | complete |
| 15 | Content batch 3: Foundations 2 → 12, +24 across ten worlds (119 in the campaign) | complete |
| L2 | Player functions and recursion; world 12 Recursion & Backtracking with 15 puzzles (134 in the campaign) | complete |
| **H** | Heaps of numbers; world 09 Heaps with 15 puzzles (149 in the campaign) | **complete** |
| later | Language: starter programs for complete / repair modes, pairs, text | planned, each unblocks content; do not start until playtest |

## Content backlog and coverage (after H)

Accepted: **149 campaign puzzles** (+ 5 unlisted probes) against a planning
target of ~300 (`content/coverage_targets.json`). That target is paused.
Source of truth: `content/coverage.json`.

| World | Have / target | MS14 / MS15 added |
|---|---|---|
| 01 Foundations | 12 / 12 | MS15: museum tickets, stair lights, party tables, doubling jar, digit wheels, three planks, lighthouse and bell, longest dry spell, hill tops, lift trips |
| 02 Arrays | 13 / 30 | first descent, second highest, even prefixes, nested distinct, loudest pair; MS15: last sighting, till totals, balance point, landslide |
| 03 Hash Maps | 10 / 25 | pair tickets, same-value span, shared values; MS15: second scan, matching bags, lonely numbers |
| 04 Two Pointers | 8 / 20 | exact gaps, pairs under a limit, sorted union, closest gap; MS15: sorted shelf, recipe steps |
| 05 Sliding Window | 9 / 20 | windows at least, one dropout, peak windows; MS15: calm stretches, window variety |
| 06 Stack & Queue | 10 / 25 | counter sum, josephus line, ticket minutes, stack sorted; MS15: plate minimum, snowball clash |
| 07 Linked Lists | 11 / 20 | tail lamp, cold cars, named car, end gap, rising links; MS15: from the back, no repeats |
| 08 Trees | 12 / 30 | left vine, right marks, lone tree, node census, leaf census, lowest leaf; MS15: mirror tree, catalogue range |
| 09 Heaps | 15 / 15 | H: top scores, halving piles, ticket order, rope joining, last stone, seat desk, meeting rooms, podium place, deadline jobs, bricks and ladders, print shop, factory codes, running median, fuel stops, cheapest crossing |
| 10 Graphs | 15 / 30 | platform doors, direct hop, silent stops, scout reach, scout last, biggest patch, source radius, last layer; MS15: ring road, ride limit |
| 11 Greedy | 8 / 20 | cookie gifts, dock overlap, leap reach; MS15: every rise, one room, medals in a row |
| 12 Recursion & Backtracking | 15 / 15 | L2: stack of coins, tree total, exact weight, even branches, change ways, watchtowers; batch 2: digit root, lucky picks, lantern rows, catalogue check, island size, power steps, rabbit months, maze paths, seating plan |
| 13 Dynamic Programming | 10 / 30 | plank ways, step toll, aisle cost, open lanes, diagonal haul, pack bins; MS15: best stretch, rising line |
| 14 Advanced | 1 / 8 | — |

By tier: 1: 2 · 2: 30 · 3: 32 · 4: 19 · 5: 2. By mode: build 53 · budget 10 ·
edge 14 · optimize 5 · restricted 3. By performance class: correctness 58 ·
budget 19 · optimization 5 · restricted 3. Worlds 09 and 12 are unchanged.

The batch is tier-2 entries for linked lists, trees, graphs and DP, plus
iterative DFS, grid DP, a queue simulation and a deque-style window, and new
optimize / restricted / edge puzzles. Details and titles:
[`MILESTONE_14.md`](MILESTONE_14.md).

**Still blocked, and not faked:** building new list or tree nodes, strings,
built-in sorting, bit manipulation, pairs / tuples, edge weights on graphs
(weighted shortest paths use a grid of costs since H). Product modes that
need a starter program stay blocked.

**Next content decision waits on playtest.** Do not add another batch, and do
not start the language milestone, until the player has tried this one.

## Milestone 14 (this batch — done)

Content only. The MS12 seven-level pipeline is unchanged. No puzzle that was
already shipped was edited, so no `version` bump. Unlock rules are unchanged.
47 new puzzles, each with an independent oracle (not the reference), a
reference built with the same editor commands the phone uses, one reject that
passes the visible cases and ends in its declared verdict, and Turkish
title / story / hints. Block names stay English.

Authoring helpers under `packages/algorun_content/tool/` are offline. The app
does not import them. `ms14_emit.dart` wrote the first draft; the review then
replaced the visible cases, strengthened hidden ones, rewrote twenty oracles
and fixed four stories — **do not re-run it**, it would overwrite that work.
Each world now lists its puzzles by tier.

## Milestone docs

| File | Status |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | locked |
| [`MILESTONE_1.md`](MILESTONE_1.md) | complete — skeleton + contracts |
| [`MILESTONE_2.md`](MILESTONE_2.md) | complete — typed ports + undo |
| [`MILESTONE_3.md`](MILESTONE_3.md) | complete — visual editor |
| [`MILESTONE_4.md`](MILESTONE_4.md) | complete — lowering |
| [`MILESTONE_5.md`](MILESTONE_5.md) | complete — interpreter |
| [`MILESTONE_6.md`](MILESTONE_6.md) | complete — test runner |
| [`MILESTONE_7.md`](MILESTONE_7.md) | complete — puzzle schema hardening |
| [`MILESTONE_8.md`](MILESTONE_8.md) | complete — five real puzzles + reference solutions |
| [`MILESTONE_9.md`](MILESTONE_9.md) | complete — hint system |
| [`MILESTONE_10.md`](MILESTONE_10.md) | complete — deterministic performance metrics |
| [`MILESTONE_L1.md`](MILESTONE_L1.md) | complete — values that may be empty and narrowing |
| [`MILESTONE_11.md`](MILESTONE_11.md) | complete — progression and local persistence |
| [`MILESTONE_12.md`](MILESTONE_12.md) | complete — content pipeline and first expansion batch |
| [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) | the authoring contract (people and AI sessions) |
| [`MILESTONE_13.md`](MILESTONE_13.md) | complete — mobile UX polish, emulator verification |
| [`MILESTONE_U1.md`](MILESTONE_U1.md) | complete — Turkish, block reference, number entry, puzzle variables |
| [`MILESTONE_14.md`](MILESTONE_14.md) | complete — second content batch (47 puzzles); playtest next |
| [`MILESTONE_U2.md`](MILESTONE_U2.md) | complete — light mode (Light / Dark / System) |
| [`MILESTONE_W1.md`](MILESTONE_W1.md) | complete — the web version on a computer (browser save, wide windows) |
| [`MILESTONE_15.md`](MILESTONE_15.md) | complete — content batch 3 (Foundations 2 → 12, +24 across ten worlds) |
| [`MILESTONE_L2.md`](MILESTONE_L2.md) | complete — player functions and recursion; world 12 opens |
| this file | MS14 handoff |

