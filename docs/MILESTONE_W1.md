# W1 — The web version on a computer

**W1 COMPLETE.** The user wants to play Algorun in a desktop browser as well
(2026-09-30). The web version is the same Dart app built with Flutter web —
no second implementation, no change to the engine, the puzzles, the budgets or
the architecture (locked decisions 1 and 8 stand; `ARCHITECTURE.md` already
calls the web build "the same Dart app, not a separate product").

Previous commit: U2 `fb64cba`.

Before W1 the web build ran (checked on 2026-09-30 at 1400 px) but was only a
preview: progress lived in memory, so a reload lost everything while the
editor said "Saved on this device"; home and the lists stretched across the
whole window; and a reload on a puzzle address opened the developer's editor
probe.

## What changed

| Piece | Where | What |
|---|---|---|
| Browser save | `lib/progress/browser_progress_store.dart` | `BrowserProgressStore` over `TextSlots` (local storage in the browser, a map in tests). The same JSON text as the Android file, in the `algorun_save` slot; one write replaces it whole; an unusable save is copied to `algorun_save.unreadable-<millis>` first; a blocked storage starts play fresh and a failed write reaches the notifier, which reports it and keeps playing from memory (as with the file). |
| Store per platform | `lib/progress/platform_store.dart` (+ `_io`, `_web`) | A conditional export: the file store on Android / iOS, local storage (`package:web`, new dependency) on the web. `main` installs `platformProgressStore()`; tests still use `MemoryProgressStore`. |
| Wide windows | `lib/shared/content_width.dart` | `ContentWidth` centres a screen's content: 720 px for home, worlds, puzzles, settings, the guide and results; 1200 px for the puzzle editor (its 840 px side-palette layout is unchanged). It pads rather than loosening constraints, so phones and every pinned bar behave exactly as before. |
| Addresses | `lib/app.dart` | The app always opens at home (`onGenerateInitialRoutes`), whatever the address says; home's CONTINUE leads back to the puzzle. `/puzzles`, `/puzzle` and `/results` opened without their arguments (the browser's forward button) go home instead of guessing. |
| Settings | web only | A line under the privacy note: progress is kept by that browser for that address; clearing the site's data or another browser starts fresh. |
| Running it | `tool/web.sh`, README | Builds (`flutter build web --release`) when `lib`, `assets`, `web`, the engine or `pubspec.yaml` changed since the last build, serves `build/web` at http://localhost:8080 (local only) and opens the browser. The port is fixed on purpose: local storage belongs to one address. |

## Tests

`test/web_test.dart` (new): on a 1400 px window home's buttons and the
worlds and settings rows stay inside a centred 720 px column; a 390 px phone
is unchanged; on a 1920 px window the editor's script and RUN stay inside
1200 px with the palette rail on the left; a reload on `/puzzle` opens home
and CONTINUE leads back; `/puzzle`, `/puzzles` and `/results` without
arguments go home. `save_codec_test` (browser store group): the JSON matches
the file store's and survives a reload; unreadable text is kept aside; blocked
storage starts fresh and a failed write throws to the caller; clear. The
storage-boundary test now also keeps `package:web` inside the web store.

`flutter test`: 385 passed. Engine `dart test`: 350 passed.

## Browser pass

Release build served locally, 1400 × 850: home, worlds and the puzzle list
centred; the editor with the side palette; a FOR EACH placed, the page
reloaded on `#/puzzle` → home with CONTINUE, the program restored; with the
browser in dark mode the app opens dark; Light chosen in Settings is saved and
wins over the dark browser after a reload; the web storage line shows in
Settings. `tool/web.sh` built, served and asked the desktop to open the
address; a second run skipped the build.

## Not done

- **Not hosted.** It runs on the computer it is built on. The repository is
  private; publishing it (GitHub Pages needs a paid plan for a private
  repository, or another host) is the user's decision.
- No keyboard entry for numbers (the number pad is clicked) and no mouse drag
  to scroll; the mouse wheel scrolls.
- The theme loads with the save, so a player whose choice differs from the
  browser's sees the browser's for the first moment.
