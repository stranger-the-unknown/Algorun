import 'package:web/web.dart' as web;

import 'browser_progress_store.dart';
import 'progress_store.dart';

/// This site's local storage in this browser.
ProgressStore platformProgressStore() => BrowserProgressStore(_LocalStorage());

final class _LocalStorage implements TextSlots {
  web.Storage get _storage => web.window.localStorage;

  @override
  String? read(String key) => _storage.getItem(key);

  @override
  void write(String key, String value) => _storage.setItem(key, value);

  @override
  void remove(String key) => _storage.removeItem(key);
}
