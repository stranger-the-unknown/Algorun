import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dev/stress_probe.dart';
import '../../l10n/l10n.dart';
import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/progress_providers.dart';
import '../guide/guide_screen.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final save = ref.watch(progressProvider).valueOrNull;
    final settings = save?.settings ?? PlayerSettings.defaults;
    void update(PlayerSettings next) => ref.read(progressProvider.notifier).updateSettings(next);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(top: false, child: ListView(
        padding: const EdgeInsets.all(AppSpace.s5),
        children: [
          Semantics(header: true, child: Text(l.languageSection, style: AppText.label)),
          const SizedBox(height: AppSpace.s2),
          for (final (code, name) in [('en', l.languageEnglish), ('tr', l.languageTurkish)])
            _LanguageOption(
              key: Key('settings-language-$code'),
              name: name,
              selected: settings.language == code,
              selectedWord: l.languageSelected,
              onTap: save == null || settings.language == code
                  ? null
                  : () => update(settings.copyWith(language: code)),
            ),
          const SizedBox(height: AppSpace.s2),
          Text(l.languageNote, style: const TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: AppSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('settings-guide'),
              onPressed: () => Navigator.pushNamed(
                context,
                '/guide',
                arguments: const GuideArgs(tab: GuideTab.blocks),
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(l.homeGuide),
            ),
          ),
          const SizedBox(height: AppSpace.s5),
          SwitchListTile(
            key: const Key('settings-brief'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.showBriefSetting),
            value: settings.showBriefOnOpen,
            onChanged: save == null ? null : (value) => update(settings.copyWith(showBriefOnOpen: value)),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(l.privacyNote, style: const TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: AppSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('settings-reset'),
              onPressed: save == null ? null : () => _confirmReset(context, ref),
              child: Text(l.resetProgress),
            ),
          ),
          const SizedBox(height: AppSpace.s5),
          Text(l.platformNote, style: const TextStyle(color: AppColors.muted, height: 1.5)),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpace.s5),
            Text(l.developerSection, style: AppText.label),
            const SizedBox(height: AppSpace.s2),
            Text(l.developerNote, style: const TextStyle(color: AppColors.muted, height: 1.5)),
            const SizedBox(height: AppSpace.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('settings-stress-probe'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/puzzle',
                  arguments: {'worldId': 'world_01', 'puzzleId': stressProbeId},
                ),
                child: Text(l.openStressProbe),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s5),
          Text(
            l.versionLine('0.1.0  ·  Milestone 13 · U1'),
            style: const TextStyle(
              color: AppColors.muted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      )),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.resetConfirmTitle),
        content: Text(l.resetConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(
            key: const Key('settings-reset-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.reset),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(progressProvider.notifier).reset();
  }
}

/// One language to choose. The chosen one says so in words and with a
/// filled mark, not by colour alone.
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    super.key,
    required this.name,
    required this.selected,
    required this.selectedWord,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final String selectedWord;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: Material(
          color: selected ? AppColors.subtle : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            // The chosen language stays enabled-looking; tapping it again
            // simply does nothing.
            onTap: onTap ?? () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? AppColors.fg : AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.fg,
                          fontSize: 16,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      Text(
                        selectedWord,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
