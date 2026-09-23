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
    final world = view.valueOrNull?.campaign.manifest.byId(worldId);
    return Scaffold(
      appBar: AppBar(
        title: Text(world == null ? 'Puzzles' : '${world.index.toString().padLeft(2, '0')} · ${world.title}'),
      ),
      body: SafeArea(top: false, child: view.when(
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
          final solved = world.puzzleIds
              .where((id) => view.progress.puzzleStatus(id) == PuzzleStatus.completed)
              .length;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            itemCount: world.puzzleIds.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '$solved of ${world.puzzleIds.length} solved · teaches ${world.concepts.map(conceptWords).join(', ')}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                );
              }
              final id = world.puzzleIds[i - 1];
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
      )),
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
                size: 22,
                color: status == PuzzleStatus.completed ? AppColors.ok : AppColors.muted,
                // The status line below says it in words.
                semanticLabel: null,
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
                              color: locked ? AppColors.muted : AppColors.fg,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: AppSpace.s2),
                          const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
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
                      style: TextStyle(
                        color: status == PuzzleStatus.completed ? AppColors.fg : AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tier ${puzzle.tier.index + 1}${puzzle.mode == PuzzleMode.build ? '' : ' · ${puzzle.mode.name}'}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!locked) const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
