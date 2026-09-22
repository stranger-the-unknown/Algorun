# Milestone 1

## Files

- `packages/algorun_engine` — pure Dart contracts, IR, puzzle JSON parser, allowlist validation, named validators
- `packages/algorun_content` — offline content validator CLI (not imported by the app)
- `lib/` — Flutter shell: home, worlds, puzzle brief, results, settings
- `assets/puzzles/world_01/ms1_contract_probe.json` — data fixture, not a campaign puzzle
- `docs/ARCHITECTURE.md` — locked decisions

## What works

- App launches and navigates
- Worlds load from JSON
- Probe puzzle loads; palette is the allowlist, not the full catalog
- RUN calls `UnimplementedEngine.validate` + `runTests` and shows `Invalid Program` with a milestone message
- Engine tests run with `dart test` (no Flutter)
- Content validator rejects unknown block ids and missing hidden tests

## How to run

From `algorun/`:

```
flutter pub get
flutter test
cd packages/algorun_engine && dart test
cd packages/algorun_content && dart test
dart run algorun_content:validate ../../assets/puzzles ../../assets/worlds.json
flutter run          # Android device/emulator
```

## Tests added

- ValueType compatibility and type parser
- Puzzle JSON parse + empty allowlist / hidden-test rejection
- Engine allowlist, empty canvas, block budget
- Named unordered-array comparator
- Content validator
- Flutter asset load + home widget

## Known limitations

- No interpreter (MS5), no editor (MS3), no lowering (MS4)
- Worlds 2–14 are titles only
- No persistence (MS11)
- Probe puzzle is not interview difficulty; that starts at MS8

## Next

Milestone 2: block data model and typed connection system (ports, snap legality, command stack for undo).
