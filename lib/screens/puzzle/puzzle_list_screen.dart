import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../state/providers.dart';

final class PuzzleListScreen extends ConsumerWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ModalRoute.of(context)?.settings.arguments as String? ??
        'world_01';
    final worlds = ref.watch(worldsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzles')),
      body: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (manifest) {
          final matches = manifest.worlds.where((w) => w.id == worldId);
          if (matches.isEmpty) {
            return const Center(child: Text('Unknown world.'));
          }
          final world = matches.first;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            itemCount: world.puzzleIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final id = world.puzzleIds[i];
              return _PuzzleRow(worldId: world.id, puzzleId: id);
            },
          );
        },
      ),
    );
  }
}

class _PuzzleRow extends ConsumerWidget {
  const _PuzzleRow({required this.worldId, required this.puzzleId});
  final String worldId;
  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Puzzle>(
      future: ref.read(puzzleRepositoryProvider).loadPuzzle(worldId, puzzleId),
      builder: (context, snap) {
        final title = snap.data?.title ?? puzzleId;
        return Material(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => Navigator.pushNamed(
              context,
              '/puzzle',
              arguments: {'worldId': worldId, 'puzzleId': puzzleId},
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.faint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
