import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/campaign.dart';
import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/progress_providers.dart';
import '../../state/progress_text.dart';

final class PuzzleListScreen extends ConsumerWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ModalRoute.of(context)?.settings.arguments as String? ?? 'world_01';
    final view = ref.watch(campaignViewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzles')),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (view) {
          final world = view.campaign.manifest.byId(worldId);
          if (world == null) {
            return const Center(child: Text('Unknown world.'));
          }
          if (!view.progress.isWorldOpen(world.id)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s5),
                child: Text(
                  lockedText(view.progress.missingFor(world.id)),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            itemCount: world.puzzleIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final id = world.puzzleIds[i];
              return _PuzzleRow(
                worldId: world.id,
                puzzle: view.campaign.puzzles[id]!,
                status: view.progress.puzzleStatus(id),
                saved: view.save[id],
                missing: view.progress.missingFor(id),
                current: view.progress.currentPuzzleId == id,
              );
            },
          );
        },
      ),
    );
  }
}

class _PuzzleRow extends StatelessWidget {
  const _PuzzleRow({
    required this.worldId,
    required this.puzzle,
    required this.status,
    required this.saved,
    required this.missing,
    required this.current,
  });

  final String worldId;
  final Puzzle puzzle;
  final PuzzleStatus status;
  final PuzzleProgress? saved;
  final List<String> missing;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final locked = status == PuzzleStatus.locked;
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: Key('puzzle-${puzzle.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: locked
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/puzzle',
                  arguments: {'worldId': worldId, 'puzzleId': puzzle.id},
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                switch (status) {
                  PuzzleStatus.locked => Icons.lock_outline,
                  PuzzleStatus.open => Icons.radio_button_unchecked,
                  PuzzleStatus.inProgress => Icons.edit_outlined,
                  PuzzleStatus.completed => Icons.check_circle,
                },
                size: 20,
                color: status == PuzzleStatus.completed ? AppColors.ok : AppColors.faint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            puzzle.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: locked ? AppColors.faint : AppColors.fg,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: AppSpace.s2),
                          const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      puzzleStatusText(status, saved, missing),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!locked) const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
