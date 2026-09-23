import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/campaign.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/progress_providers.dart';
import '../../state/progress_text.dart';

final class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(campaignViewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Worlds')),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Text('$e', style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (view) {
          final worlds = view.campaign.manifest.worlds;
          final currentWorld = switch (view.progress.currentPuzzleId) {
            final id? => view.campaign.worldOf(id)?.id,
            null => null,
          };
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s3, AppSpace.s4, AppSpace.s7),
            itemCount: worlds.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
            itemBuilder: (context, i) {
              final world = worlds[i];
              return _WorldCard(
                world: world,
                status: view.progress.worldStatus(world.id),
                subtitle: worldStatusText(world, view.progress.worldStatus(world.id), view.progress),
                current: world.id == currentWorld,
              );
            },
          );
        },
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.status,
    required this.subtitle,
    required this.current,
  });

  final WorldDef world;
  final WorldStatus status;
  final String subtitle;
  final bool current;

  bool get _playable => status == WorldStatus.open || status == WorldStatus.completed;

  @override
  Widget build(BuildContext context) {
    final dim = !_playable;
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: Key('world-${world.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: _playable
            ? () => Navigator.pushNamed(
                  context,
                  '/puzzles',
                  arguments: world.id,
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  world.index.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: AppColors.faint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            world.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: dim ? AppColors.faint : AppColors.fg,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: AppSpace.s2),
                          const _Tag('CURRENT'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                switch (status) {
                  WorldStatus.locked => Icons.lock_outline,
                  WorldStatus.completed => Icons.check_circle,
                  WorldStatus.empty => Icons.hourglass_empty,
                  WorldStatus.open => Icons.chevron_right,
                },
                color: status == WorldStatus.completed ? AppColors.ok : AppColors.faint,
                semanticLabel: switch (status) {
                  WorldStatus.locked => 'Locked',
                  WorldStatus.completed => 'Completed',
                  WorldStatus.empty => 'No puzzles yet',
                  WorldStatus.open => 'Open',
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small label, e.g. CURRENT.
final class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.accent, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
  }
}
