import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The progression model, the save format and the rules are pure Dart; only
/// the file store touches the device. Widgets reach storage through the
/// progress notifier, never directly.
void main() {
  test('lib/progress is pure Dart except the file store', () {
    final files = Directory('lib/progress').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      if (file.path.endsWith('file_progress_store.dart')) continue;
      final source = file.readAsStringSync();
      for (final banned in ['package:flutter', 'dart:io', 'package:path_provider', 'dart:ui']) {
        expect(source, isNot(contains(banned)), reason: '${file.path} imports $banned');
      }
    }
  });

  test('no screen or widget talks to storage directly', () {
    final files = [
      ...Directory('lib/screens').listSync(recursive: true),
      ...Directory('lib/editor').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final banned in ['file_progress_store', 'progress_store.dart', 'save_codec', 'dart:io', 'path_provider']) {
        expect(source, isNot(contains(banned)), reason: '${file.path} uses $banned');
      }
    }
  });
}
