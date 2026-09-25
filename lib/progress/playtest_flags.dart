/// Playtest-only switches for device QA.
///
/// These never change how completions are recorded. Unlock-all only remaps
/// locked → open in [evaluateCampaign] while the flag is on.
abstract final class PlaytestFlags {
  /// Whether the app applies the campaign locks. **Off for now:** every build,
  /// debug and release, opens every puzzle so a playtester never has to solve
  /// puzzles again to reach the ones under test. The lock rules stay in the
  /// code and in the tests. To play with the real locks, build with
  /// `--dart-define=ALGORUN_LOCKS=true`; when the campaign is ready for
  /// players, make `true` the default here.
  static const bool campaignLocks = bool.fromEnvironment('ALGORUN_LOCKS');

  /// When true, every campaign world/puzzle reports as open. Default is false
  /// so unit tests keep the real locks; [main] sets it from [campaignLocks].
  static bool unlockAllPuzzles = false;
}
