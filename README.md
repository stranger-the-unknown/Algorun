# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status (2026-11-18):** 204 campaign puzzles in 15 worlds. Five milestones were merged together: a step-by-step trace of a visible case (T1), editor comfort — block search, copy / paste, folds, drag, an outline (E1), puzzles that open with a program — complete, repair and predict (M1), text, deque, SORT and pair blocks with world 15 (L3), and a fourth content batch of 36 puzzles (MS16). Every listed puzzle passes the seven-level content pipeline with an independent oracle; the game plays in English or Turkish. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing; it points to each milestone's document.

Play in the browser: https://stranger-the-unknown.github.io/algorun-play/ (built web files only; publish an update with `tool/publish_web.sh`).

Android APK: https://github.com/stranger-the-unknown/Algorun/releases/latest/download/Algorun.apk (every release: https://github.com/stranger-the-unknown/Algorun/releases; publish one with `tool/publish_apk.sh <notes.md>`).

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
