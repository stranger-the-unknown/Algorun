import 'save_files_api.dart';

/// The phone keeps its save in the app's own files: no download, no picker.
SaveFiles platformSaveFiles() => const _NoSaveFiles();

final class _NoSaveFiles implements SaveFiles {
  const _NoSaveFiles();

  @override
  bool get supported => false;

  @override
  void download(String fileName, String text) => throw UnsupportedError('No save files on this platform.');

  @override
  Future<String?> pick() => throw UnsupportedError('No save files on this platform.');
}
