# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 13 complete, on top of language milestone L1. 38 original algorithm puzzles in 12 worlds (tiers 1–5: arrays, hash maps, two pointers, sliding windows, stacks, linked lists, trees, graphs, greedy, iterative DP) are playable end to end on an Android phone: a tap-to-place block editor with typed pickers, move / copy / delete and folding for long programs, progressive hints, deterministic performance budgets (operation counts, never a Big-O claim) and progress saved on the device — no account, no backend. Every puzzle passes a seven-level content pipeline with an independent oracle. MS13 was verified on an Android 15 emulator at 360, 390 and 412 dp (no physical device yet). See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing, and [`docs/CONTENT_AUTHORING.md`](docs/CONTENT_AUTHORING.md) before adding content.

Validate content before committing it:

```bash
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references --coverage content/coverage.json
```

Reference solutions, the language capability audit and the coverage matrix live in `content/` and are never bundled with the app.

## Run

```bash
flutter pub get
flutter test
cd packages/algorun_engine && dart test
flutter run
```

Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
