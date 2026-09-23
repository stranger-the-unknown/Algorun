# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 10 complete. Five real algorithm puzzles are playable end to end, each proven solvable by a reference solution, with progressive hints and deterministic performance budgets: a solution can be correct and still fail on operations, and the results screen shows the counted operations against the budget (operation counts, never a Big-O claim). Next is language milestone L1 (nullable / NOTHING narrowing), which must land before tree or linked-list content, then Milestone 11. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

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
