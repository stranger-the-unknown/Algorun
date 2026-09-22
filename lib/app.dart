import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/puzzle/puzzle_list_screen.dart';
import 'screens/puzzle/puzzle_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/world_select/world_select_screen.dart';
import 'shared/theme/app_theme.dart';

final class AlgorunApp extends StatelessWidget {
  const AlgorunApp({super.key});

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
