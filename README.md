# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** L2 is in: players write functions with blocks and CALL them, recursion included, and world 12 (Recursion & Backtracking) has 14 puzzles — 133 campaign puzzles in all. Every listed puzzle passes the seven-level content pipeline with an independent oracle; the game plays in English or Turkish. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing, and [`docs/MILESTONE_L2.md`](docs/MILESTONE_L2.md) for the latest milestone.

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
