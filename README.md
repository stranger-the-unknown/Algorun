# Algorun

Android-first algorithm puzzle game. Construct the algorithm with typed blocks. Never type syntax.

Engine is pure Dart (`packages/algorun_engine`). Content validation is a separate package (`packages/algorun_content`) and is not shipped as app UI logic.

**Status:** Milestone 5 complete (sandboxed interpreter over the IR). Next is Milestone 6 (test runner) — until then RUN in the app still reports unimplemented, because the puzzle screen calls `runTests`. See [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) before continuing.

Primary target: Android (`com.algorun`). Flutter web is the same Dart app, used only when a host cannot run an APK.

## Run

```bash
flutter pub get
flutter test
cd packages/algorun_engine && dart test
flutter run
```

Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
