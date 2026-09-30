import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'progress/platform_store.dart';
import 'progress/playtest_flags.dart';
import 'state/progress_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  // Playtest: every campaign puzzle is open in every build, release included,
  // until the campaign locks are switched on (PlaytestFlags.campaignLocks).
  // Completions are recorded as usual, so nothing is lost when they are.
  PlaytestFlags.unlockAllPuzzles = !PlaytestFlags.campaignLocks;
  // Draw behind the status and navigation bars on every Android version (it
  // is enforced from Android 15); every screen keeps its content inside the
  // safe area.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(ProviderScope(
    overrides: [progressStoreProvider.overrideWithValue(platformProgressStore())],
    child: const AlgorunApp(),
  ));
}
