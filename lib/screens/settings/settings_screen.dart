import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s5),
        children: const [
          Text(
            'Algorun is local-first. Progress persistence arrives in Milestone 11. There is no account.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          SizedBox(height: AppSpace.s5),
          Text(
            'Android is the primary target. Engine code is pure Dart and does not import Flutter.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          SizedBox(height: AppSpace.s5),
          Text(
            'Version 0.1.0  ·  Milestone 1',
            style: TextStyle(
              color: AppColors.faint,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
