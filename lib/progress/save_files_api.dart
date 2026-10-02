/// Moving the save out of the app as a file and back in. Only the browser
/// version does it: there the save lives in the site's storage, which the
/// browser may clear (user request, 2026-10-02).
abstract interface class SaveFiles {
  /// Whether this platform can download and pick files.
  bool get supported;

  /// Offers [text] to the player as a file called [fileName].
  void download(String fileName, String text);

  /// Lets the player choose a file and gives its text, or null when they
  /// chose nothing.
  Future<String?> pick();
}
