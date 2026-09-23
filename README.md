# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Language milestone L1 complete, on top of Milestone 10. Five real algorithm puzzles are playable end to end, each proven solvable by a reference solution, with progressive hints and deterministic performance budgets (operation counts, never a Big-O claim). L1 adds IS NOTHING / IS NOT NOTHING: a value that may be empty (a linked list's NEXT NODE, a tree's LEFT / RIGHT, a map lookup) can be checked, and inside the checked branch it is used as a real value — so linked lists can be walked, tree children read and maps counted, with no force-unwrap and no unsafe access reaching RUN. MS11 (progression + local save) is next. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

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
