import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'progress_store.dart';
import 'save_codec.dart';
import 'save_data.dart';

/// The save as one JSON file in the app's private support directory
/// (`getApplicationSupportDirectory`; on Android the app's internal files,
/// removed with the app, no permission needed).
///
/// Writes go to `algorun_save.json.tmp` and are then renamed over
/// `algorun_save.json`, so a crash mid-write leaves the previous save intact.
/// A save that cannot be used is copied to
/// `algorun_save.unreadable-<millis>.json` before play continues, so nothing
/// the player had is ever silently deleted.
final class FileProgressStore implements ProgressStore {
  FileProgressStore(this._directory);

  FileProgressStore.appSupport() : this(getApplicationSupportDirectory);

  static const fileName = 'algorun_save.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}${Platform.pathSeparator}$fileName');

  @override
  Future<StoreLoad> load() async {
    File? file;
    try {
      file = await _file();
      if (!await file.exists()) return const StoreLoad(PlayerSave.fresh);
      final read = decodeSave(await file.readAsString());
      if (!read.usable) await _keepAside(file);
      return StoreLoad(read.save, read.issues);
    } on Object catch (e) {
      // Unreadable bytes or a storage failure: keep what is there aside
      // before anything can overwrite it.
      if (file != null) await _keepAside(file);
      return StoreLoad(PlayerSave.fresh, [SaveIssue('', 'The save could not be read ($e).')]);
    }
  }

  Future<void> _keepAside(File file) async {
    try {
      if (!await file.exists()) return;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.copy(file.path.replaceFirst(RegExp(r'\.json$'), '.unreadable-$stamp.json'));
    } on Object {
      // Nothing more can be done; play continues from a fresh save.
    }
  }

  @override
  Future<void> save(PlayerSave save) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encodeSave(save), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
