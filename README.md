# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 15 content batch 3 is in progress: 107 campaign puzzles (Foundations now has 12). The user asked to keep growing the game until their subscription ends (~2026-10-10) and to playtest afterwards; see [`docs/MILESTONE_15.md`](docs/MILESTONE_15.md). Recursion and player functions are still deferred, so Heaps and Backtracking stay empty. Milestone 13 and U1 still stand: the game plays in English or Turkish, block names stay English, and every listed puzzle passes the seven-level content pipeline with an independent oracle. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing, and [`docs/MILESTONE_15.md`](docs/MILESTONE_15.md) for the current batch.

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

In a desktop browser (builds when the code changed, serves at
http://localhost:8080 and opens it; progress is kept by that browser for that
address):

```bash
tool/web.sh
```

Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
