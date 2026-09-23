import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home/home_screen.dart';
import 'screens/puzzle/puzzle_list_screen.dart';
import 'screens/puzzle/puzzle_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/world_select/world_select_screen.dart';
import 'shared/theme/app_theme.dart';
import 'state/progress_providers.dart';

final class AlgorunApp extends ConsumerStatefulWidget {
  const AlgorunApp({super.key});

  @override
  ConsumerState<AlgorunApp> createState() => _AlgorunAppState();
}

class _AlgorunAppState extends ConsumerState<AlgorunApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Going to the background may be the last chance to write: flush the
    // debounced autosave now.
    void flush() => ref.read(progressProvider.notifier).flush();
    _lifecycle = AppLifecycleListener(onHide: flush, onPause: flush, onDetach: flush);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Algorun',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/worlds': (_) => const WorldSelectScreen(),
        '/puzzles': (_) => const PuzzleListScreen(),
        '/puzzle': (_) => const PuzzleScreen(),
        '/results': (_) => const ResultsScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
