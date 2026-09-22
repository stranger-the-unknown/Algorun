# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 6 complete. RUN is live end to end: block graph → validate → lower → interpreter → test runner → result, graded against the puzzle's visible and hidden fixtures. Next is Milestone 7 (puzzle schema hardening). See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

Primary target: Android (`com.algorun`). Flutter web is the same Dart app, used only when a host cannot run an APK.

## Run

```bash
flutter pub get
flutter test
cd packages/algorun_engine && dart test
flutter run
```

Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
