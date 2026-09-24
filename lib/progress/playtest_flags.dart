/// Playtest-only switches for device QA.
///
/// These never change how completions are recorded. Unlock-all only remaps
/// locked → open in [evaluateCampaign] while the flag is on.
abstract final class PlaytestFlags {
  /// When true, every campaign world/puzzle reports as open for playtesting.
  /// Default is false (safe for unit tests and release). [main] turns it on
  /// inside an `assert`, which is stripped from release builds.
  static bool unlockAllPuzzles = false;
}
