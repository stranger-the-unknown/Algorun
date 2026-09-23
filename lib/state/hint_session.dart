/// The hints a player has revealed during one visit to a puzzle.
///
/// Hints are the puzzle's own declarative data (`Puzzle.hints`), shown in the
/// order the author wrote them — from the idea, to the approach, to stronger
/// guidance — and never skipped. Only revealing a *new* hint counts; looking
/// at hints already shown, or opening and closing the hint panel, does not.
///
/// The session lives exactly as long as the puzzle screen. Nothing is saved.
final class HintSession {
  HintSession(List<String> hints) : hints = List.unmodifiable(hints);

  final List<String> hints;
  int _used = 0;

  /// How many hints have been revealed. This is `hintsUsed`.
  int get used => _used;

  int get total => hints.length;

  bool get hasMore => _used < hints.length;

  /// The hints revealed so far, in order.
  List<String> get revealed => hints.sublist(0, _used);

  /// Reveal the next hint and return it, or null when every hint is showing.
  String? revealNext() {
    if (!hasMore) return null;
    return hints[_used++];
  }
}
