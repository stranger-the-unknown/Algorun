import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/progress_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  // Draw behind the status and navigation bars on every Android version (it
  // is enforced from Android 15); every screen keeps its content inside the
  // safe area.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(ProviderScope(
    overrides: [progressStoreProvider.overrideWithValue(platformProgressStore())],
    child: const AlgorunApp(),
  ));
}
