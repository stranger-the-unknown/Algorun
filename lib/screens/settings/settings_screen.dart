import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/progress_providers.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = ref.watch(progressProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s5),
        children: [
          SwitchListTile(
            key: const Key('settings-brief'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show the brief when a puzzle opens'),
            value: save?.settings.showBriefOnOpen ?? PlayerSettings.defaults.showBriefOnOpen,
            onChanged: save == null
                ? null
                : (value) => ref
                    .read(progressProvider.notifier)
                    .updateSettings(PlayerSettings(showBriefOnOpen: value)),
          ),
          const SizedBox(height: AppSpace.s4),
          const Text(
            'Progress, your programs and your best results are saved on this device only. There is no account and nothing is uploaded.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: AppSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('settings-reset'),
              onPressed: save == null ? null : () => _confirmReset(context, ref),
              child: const Text('Reset progress'),
            ),
          ),
          const SizedBox(height: AppSpace.s5),
          const Text(
            'Android is the primary target. Engine code is pure Dart and does not import Flutter.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: AppSpace.s5),
          const Text(
            'Version 0.1.0  ·  Milestone 11',
            style: TextStyle(
              color: AppColors.faint,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'Every solved puzzle, saved program and best result on this device is deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            key: const Key('settings-reset-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(progressProvider.notifier).reset();
  }
}
