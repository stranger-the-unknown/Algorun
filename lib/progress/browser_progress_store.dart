import 'progress_store.dart';
import 'save_codec.dart';
import 'save_data.dart';

/// Named text slots that outlive the page: the browser's `localStorage` on
/// the web, a map in tests.
abstract interface class TextSlots {
  String? read(String key);

  /// May throw (storage full, storage blocked).
  void write(String key, String value);

  void remove(String key);
}

/// The save in the browser (Flutter web): the same JSON text as the Android
/// file, in the `algorun_save` slot of this site's local storage. It stays
/// until the player resets progress or clears the site's data; another
/// browser, or the same one at another address, has its own.
///
/// One `write` replaces the slot whole, so a closed tab never leaves half a
/// save. A save that cannot be used is copied to
/// `algorun_save.unreadable-<millis>` before play continues, as on Android.
final class BrowserProgressStore implements ProgressStore {
  BrowserProgressStore(this._slots);

  static const key = 'algorun_save';

  final TextSlots _slots;

  @override
  Future<StoreLoad> load() async {
    String? text;
    try {
      text = _slots.read(key);
      if (text == null) return const StoreLoad(PlayerSave.fresh);
      final read = decodeSave(text);
      if (!read.usable) _keepAside(text);
      return StoreLoad(read.save, read.issues);
    } on Object catch (e) {
      if (text != null) _keepAside(text);
      return StoreLoad(PlayerSave.fresh, [SaveIssue('', 'The save could not be read ($e).')]);
    }
  }

  void _keepAside(String text) {
    try {
      _slots.write('$key.unreadable-${DateTime.now().millisecondsSinceEpoch}', text);
    } on Object {
      // Nothing more can be done; play continues from a fresh save.
    }
  }

  @override
  Future<void> save(PlayerSave save) async => _slots.write(key, encodeSave(save));

  @override
  Future<void> clear() async => _slots.remove(key);
}
