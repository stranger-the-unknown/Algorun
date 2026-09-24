# U1 — Turkish, the block reference, number entry, puzzle variables

**U1 COMPLETE.** A UX and localization round on top of MS13: the whole game
in English or Turkish, a block reference (Blok Rehberi) open from anywhere,
a number pad that replaces and corrects numbers easily, and no more CREATE
VARIABLE step. No new language feature, no new puzzle, no change to any
puzzle, budget, validator rule or interpreter behaviour, no architecture
change.

Previous commit: MS13 `10f6ec4`.

## Localization architecture

| Piece | Where | What |
|---|---|---|
| UI strings | `lib/l10n/app_en.arb` (template), `lib/l10n/app_tr.arb`; `l10n.yaml` | 367 keys, Flutter `gen-l10n` (`flutter_localizations` + `intl`). Generated code in `lib/l10n/gen/` is committed; run `flutter gen-l10n` after editing an ARB file. |
| Access | `lib/l10n/l10n.dart` | `context.l10n` (English when a bare test harness has no delegate), `stringsFor('tr')`, `englishStrings`, `l.upper(text)` for Turkish capitals (`i → İ`; Dart's `toUpperCase` gives `I`). |
| Game words | `lib/l10n/terms.dart` | verdicts, result kinds and their meanings, type words (`sayı listesi`), palette categories, modes, slot captions. |
| Engine messages | `lib/l10n/engine_text.dart` | The engine stays English (pure Dart, shared with the validator). The app translates its sentences by exact text (74) and three patterns (block limit, missing value, failed case). An unknown sentence is shown in English rather than not at all. |
| Puzzle content | `assets/l10n/content_tr.json`, `lib/l10n/content_text.dart` | The puzzle JSON stays English and the source of truth. The Turkish file holds world titles, concept words and every campaign puzzle's title, story and hints. `ContentText` falls back to English per field; hints are replaced whole or not at all. Loaded only when Turkish is chosen. |
| Setting | `PlayerSettings.language` (`en` default, `tr`) | Saved in `settings.language`. A save from before U1 reads as English without an issue; an unknown language reads as English with an issue. **Reset progress keeps the language.** |
| App | `lib/app.dart`, `lib/state/l10n_providers.dart` | `MaterialApp.locale` follows `languageProvider`; switching rebuilds every open screen at once. Counts use the locale's grouping (`3.000` in Turkish). |

**What stays English in every language:** block names and the words inside
blocks (IF, WHILE, RETURN, SET … TO, FOR … FROM … TO … BY, IN, THEN, DO,
ELSE, NOTHING, TRUE / FALSE), the same words inside Turkish stories and hints
(a test checks every one), puzzle input and variable names (`readings`,
`count`: they are the program's identifiers), save-file diagnostics (debug
log only) and the unlisted developer probes.

**What is in Turkish:** home, worlds, puzzle lists, locks and statuses, the
puzzle screen (brief, INPUTS / RETURNS with type words, hints, GIVENS /
VARIABLES, PROGRAM, palette categories, the piece picker and where it puts a
piece, name / number / TRUE-FALSE sheets, the selection bar, the RUN bar,
every notice), results (verdict, meaning, engine explanation, cases, hidden
summary, cost table, progress lines, NEXT), settings, the block reference,
and every engine message a player can see.

## Block reference (Blok Rehberi)

`lib/guide/guide_data.dart` (73 blocks, 12 concepts) and
`lib/screens/guide/guide_screen.dart`. Three tabs: **How to play**,
**Concepts**, **Blocks**. Each card: the English name as the editor shows it,
the Turkish name (`IF — EĞER / KOŞUL`), what it does in the player's
language first and then in the other one, and a small example written in the
editor's layout (parentheses show a block inside another block's slot).
Concepts: Variable / Değişken, Value / Değer, **Index / Position / Konum —
a variable holding a position is not the value there** (worked example),
List, Condition, Loop, Map, Set, Stack / Queue, Node, NOTHING, steps and
budget.

Opens from:

- **Home** — *Block reference* button; on a fresh install also *New here?
  See how to play* (How to play tab).
- **Settings** — under the language choice.
- **Puzzle screen** — the book icon in the app bar: Blocks tab with **IN THIS
  PUZZLE** (the puzzle's blocks) before ALL BLOCKS.
- **Piece picker** — the book icon next to close, same view.

Blocks no puzzle offers and that have nothing to plug in (SWAP, COPY, TEXT)
and the hidden function blocks are not listed. A test fails if a puzzle
offers a block the reference does not explain.

## CREATE VARIABLE — findings and decision

Findings:

- A puzzle's names were never free: the name sheet only offered
  `variables.pool`, and CREATE VARIABLE only declared one of those names.
- Declaring a name only puts its type in `graph.variables`, which lowering
  uses as a type environment. It creates no block, no IR, no step and no
  memory cell.
- So the step was pure friction: the player had to "create" a name the
  puzzle had already chosen before SET or INCREMENT could use it.

Decision: **removed from the editor, kept in the engine.**

- `EditorController` declares the whole pool (and the givens) when a puzzle
  opens and when a saved draft is restored. Declaring a name that exists is a
  no-op and never an undo step.
- The engine's `DeclareVariableCommand` and `EditorController.declareVariable`
  stay, for future player-named variables.
- The givens bar now shows **GIVENS** and **VARIABLES**; tapping a name puts
  it in the selected slot. The name sheet has no create button.
- Evidence (tests): every one of the 38 reference solutions, opened in the
  editor, lowers to byte-identical IR and runs with identical steps, memory
  and depth; a draft saved before U1 with only some names created restores
  with the whole pool and survives a save; every puzzle opens with exactly
  its pool and givens declared and nothing placed.
- Visible side effect: the picker offers INCREMENT / DECREMENT for every
  number variable from the start, not only after it was created.

## Number entry

The pad (`NumberPad` in `lib/editor/literal_sheet.dart`) keeps the MS13
rule: no system keyboard, ever.

| Before | After |
|---|---|
| Opened on the current digits; typing appended (`45` → `454`) | Opens with the number **selected** (highlight + "Typing replaces this number"): the first digit replaces it (`45` → `4` → `44`) |
| ⌫ | ⌫ deletes the last digit; on a selected number it clears it |
| — | **CLEAR** empties it in one tap; tapping the number selects it all again |
| ± key | **+/−** key; the sign shows as `−45` plus a "negative" tag, not by colour |
| One less / One more buttons | **Removed** |

Why the sign key stays: nine reference solutions use −1 (a "not found" or
"none yet" marker), and a system keyboard's minus key differs
between keyboards. Why ±1 went: typing the number is as fast, and two more
buttons next to DONE invited mis-taps.

The TRUE / FALSE sheet now marks the current value with a check, the word
"selected" and a stronger border (it always looked like TRUE before).

## UI consistency

- Targets ≥ 48 dp: language options 52, guide tabs 48, pad keys and CLEAR /
  DONE 52, picker chips 48.
- Selected states never by colour alone: language (filled radio + "selected"),
  TRUE / FALSE (check + "selected"), guide tab (bold + underline), pad
  selection (highlight + sentence), negative (tag).
- Dark theme tokens only; safe areas on the new screens; long Turkish labels
  shortened where they were cut at 360 dp (hint button, "saved" label).
- Turkish at 360 × 800 and 800 × 360 dp with a ×1.6 font: home, settings,
  worlds, puzzle list, guide, puzzle, results — no overflow (test).

## Tests

| File | Tests | What |
|---|---|---|
| `test/localization_test.dart` | 9 (new) | ARB parity and placeholders; Turkish differs where it should; every player-visible engine sentence (scanned from the engine source) has Turkish, English passes through, unknown stays English; Turkish content for every world, concept and puzzle with the same number of hints; block names kept in Turkish stories and hints; fallback; the reference covers every offered block; the concepts |
| `test/localization_ui_test.dart` | 7 (new) | English by default; switching to Türkçe in settings changes the open screen and home / worlds at once, is saved and switches back; the language survives a reset; the reference in English and in Turkish (both meanings, order, examples, concepts); a Turkish puzzle: title, story, hints, IN THIS PUZZLE, RUN, verdict, NEXT with Turkish capitals, block names English; Turkish at 360 × 800 and 800 × 360, ×1.6 |
| `test/editor_variables_test.dart` | 4 (new) | pool and givens declared on open; re-declaring is a no-op; all 38 references restore with identical IR and metrics; a pre-U1 draft restores and survives a save |
| `test/literal_sheets_test.dart` | 3 → 7 | replace-on-open (`45` → `44`), ⌫ on a wrong last digit, CLEAR, ⌫ on a selected number, tap to reselect, negative on and off with the tag, sign kept on reopen, no One more / One less, TRUE / FALSE marking, INCREMENT offered from the start, no *Create variable* |
| `test/progress/save_codec_test.dart` | 22 → 23 | `settings.language` round trip; old saves; unknown language |
| `test/editor_actions_test.dart`, `test/stress_probe_test.dart` | changed | notices are `EditorNotice` (rendered in the player's language) |

## Emulator check

Android 15 emulator (`algorun_phone`), 360 × 800 dp, debug build: English
home, block reference (Blocks, Concepts), settings, switch to Türkçe,
worlds, puzzle, picker, name sheet, number pad (select-and-replace,
negative), reference from the puzzle, results. Found and fixed on the way:
the selected guide tab looked dimmer than the others; the Index example
wrapped mid-column; "önce değişkenler öğren" (wrong case) → "önce öğren:
…"; two Turkish labels cut at 360 dp; the picker's target line started in
lower case; the empty name chip said "name" / "item" in Turkish; Turkish
capitals (`GELGIT` → `GELGİT`).

## Known limitations

- Two languages. Adding one: a `app_<xx>.arb`, an entry in
  `PlayerSettings.languages`, `assets/l10n/content_<xx>.json`, and the
  guide's texts (the guide holds exactly English and Turkish).
- Engine messages are matched by their English text: changing a sentence in
  the engine needs the ARB entry updated (the scan test fails until it is).
- Fixture values on the results screen are JSON (`{"readings":[18,25]}`) in
  both languages.
- No TalkBack pass; emulator only, as in MS13.
