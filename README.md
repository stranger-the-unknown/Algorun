# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 11 complete, on top of language milestone L1. Five real algorithm puzzles are playable end to end, each proven solvable by a reference solution, with progressive hints, deterministic performance budgets (operation counts, never a Big-O claim) and IS NOTHING / IS NOT NOTHING for values that may be empty. Progress is now saved on the device: solving a puzzle unlocks what its concepts lead to, CONTINUE reopens the last puzzle with its program, and best results survive restarts — no account, no backend. MS12 (large original content) is next. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

Validate content before committing it:

```bash
dart run packages/algorun_content/bin/validate.dart assets/puzzles assets/worlds.json content/references
```

Reference solutions live in `content/references/` and are never bundled with the app.

## Run

```bash
flutter pub get
flutter test
cd packages/algorun_engine && dart test
flutter run
```

Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
