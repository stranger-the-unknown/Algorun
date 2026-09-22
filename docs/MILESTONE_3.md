# Milestone 3

Scratch-style vertical editor on the MS2 typed-port graph. No IR, no interpreter.

## Files

Engine (`packages/algorun_engine`):

- `lib/src/blocks/chrome.dart` — player-facing labels, category, layout
- `lib/src/blocks/typing.dart` — `Placement`, `GraphTyping.compatiblePlacements`
- `lib/src/blocks/commands.dart` — `DeclareVariableCommand`, `SetLiteralsCommand`, `markBaseline` / `forgetRedo`
- `lib/src/puzzles/puzzle.dart` — `variablePool`
- `test/placements_test.dart`, `test/chrome_test.dart`

App:

- `lib/editor/editor_controller.dart`
- `lib/editor/script_view.dart`
- `lib/editor/statement_tile.dart`
- `lib/editor/reporter_tile.dart`
- `lib/editor/hole_widget.dart`
- `lib/editor/hole_picker.dart`
- `lib/editor/palette_tray.dart`
- `lib/editor/literal_sheet.dart`
- `lib/editor/givens_bar.dart`
- `lib/editor/editor_theme.dart`
- `lib/screens/puzzle/puzzle_screen.dart` — editor shell
- `lib/screens/puzzle/puzzle_list_screen.dart`
- `assets/puzzles/world_01/ms3_editor_probe.json`
- `test/widget_test.dart` — picker invariants, seeded labels, no TextField

## Engine APIs added

- `GraphTyping.compatiblePlacements(graph, to:, allow:)` — picker filter; each candidate is trial-connected through `canConnect`
- `BlockChrome` — labels such as GREATER THAN, never `cmp.gt`
- `DeclareVariableCommand` / `SetLiteralsCommand`
- Puzzle `variables.pool` (closed names + types)

Typed ports, `canConnect` rules, and catalog ids are unchanged.

## Picker filtering

`allowlist ∩ GraphTyping.compatiblePlacements`. Incompatible blocks are omitted, not disabled. GET expands to one row per typed-compatible variable.

## Mobile layout

Phone: GIVENS + vertical `ScriptView` + bottom `PaletteTray`. Width ≥ 840: palette as a left rail. C-block bodies wrap; IF+ELSE draw as one card. Insert-in-place; no 2D canvas.

## Undo / redo

AppBar calls `GraphHistory` through `EditorController`. Failed connects do not push history. Seeded example is a baseline (`markBaseline`).

## Tests

Engine placements + chrome; Flutter picker invariants and seeded labels.

## Known limitations

- No interpreter (MS5); RUN still reports unimplemented
- `fn.def` / `fn.call` hidden
- No paletted drag; tap-to-place only
- Probe puzzle is not interview difficulty
