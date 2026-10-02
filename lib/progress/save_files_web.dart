import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'save_files_api.dart';

/// The browser's download and file picker.
SaveFiles platformSaveFiles() => const _BrowserSaveFiles();

final class _BrowserSaveFiles implements SaveFiles {
  const _BrowserSaveFiles();

  @override
  bool get supported => true;

  @override
  void download(String fileName, String text) {
    final blob = web.Blob(<JSAny>[text.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(link);
    link.click();
    link.remove();
    // Give the browser a moment to start the download before letting go.
    Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  }

  @override
  Future<String?> pick() {
    final done = Completer<String?>();
    void finish(String? text) {
      if (!done.isCompleted) done.complete(text);
    }

    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    void changed(web.Event _) {
      final file = input.files?.item(0);
      if (file == null) return finish(null);
      file.text().toDart.then((text) => finish(text.toDart), onError: (Object _) => finish(null));
    }

    input.addEventListener('change', changed.toJS);
    input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
    input.click();
    return done.future;
  }
}
