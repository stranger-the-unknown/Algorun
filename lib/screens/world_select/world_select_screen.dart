import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../state/providers.dart';

final class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = ref.watch(worldsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Worlds')),
      body: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Text('$e', style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (manifest) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s3, AppSpace.s4, AppSpace.s7),
            itemCount: manifest.worlds.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
            itemBuilder: (context, i) {
              final world = manifest.worlds[i];
              final locked = world.puzzleIds.isEmpty;
              return _WorldCard(world: world, locked: locked);
            },
          );
        },
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world, required this.locked});

  final WorldDef world;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: locked
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/puzzles',
                  arguments: world.id,
                ),
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
                    Text(
                      world.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: locked ? AppColors.faint : AppColors.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locked
                          ? 'Locked — content in later milestones'
                          : '${world.puzzleIds.length} ${world.puzzleIds.length == 1 ? 'probe' : 'probes'}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: AppColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
