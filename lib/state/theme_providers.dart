import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'progress_providers.dart';

/// Light, dark or the device's choice, from the saved settings; the device's
/// until the save has loaded.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(progressProvider).valueOrNull?.settings.theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});
