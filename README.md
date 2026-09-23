# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 9 complete. Five real algorithm puzzles (hash-set complement lookup, sliding window, monotonic stack, binary search on the answer, graph BFS) are playable end to end, each proven solvable by a reference solution the content validator runs through the real test runner, and each offers three progressive hints (under the brief; the count shows on the results screen). Next is Milestone 10 (performance metrics); the planned language milestone L1 (nullable narrowing) must come before tree or linked-list content. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

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
