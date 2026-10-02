import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/campaign.dart';
import '../../progress/save_data.dart';
import '../../l10n/content_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/terms.dart';
import '../../shared/load_failed.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/content_width.dart';
import '../../state/l10n_providers.dart';
import '../../state/progress_providers.dart';
import '../../state/progress_text.dart';

final class PuzzleListScreen extends ConsumerWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ModalRoute.of(context)?.settings.arguments as String? ?? 'world_01';
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    final view = ref.watch(campaignViewProvider);
    final world = view.valueOrNull?.campaign.manifest.byId(worldId);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          world == null ? l.puzzlesTitle : l.worldHeading(world.index.toString().padLeft(2, '0'), text.worldTitle(world)),
        ),
      ),
      body: ContentWidth(child: SafeArea(top: false, child: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: LoadFailed(onRetry: () => retryCampaign(ref)),
          ),
        ),
        data: (view) {
          final world = view.campaign.manifest.byId(worldId);
          if (world == null) {
            return Center(child: Text(l.unknownWorld));
          }
          if (!view.progress.isWorldOpen(world.id)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s5),
                child: Text(
                  lockedText(view.progress.missingFor(world.id), l, text),
                  style: TextStyle(color: context.palette.muted),
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
                    l.puzzleListHeader(solved, world.puzzleIds.length, text.concepts(world.concepts)),
                    style: TextStyle(color: context.palette.muted, fontSize: 13),
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
                text: text,
              );
            },
          );
        },
      ))),
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
    required this.text,
  });

  final String worldId;
  final Puzzle puzzle;
  final PuzzleStatus status;
  final PuzzleProgress? saved;
  final List<String> missing;
  final bool current;
  final ContentText text;

  @override
  Widget build(BuildContext context) {
    final locked = status == PuzzleStatus.locked;
    final l = context.l10n;
    return Material(
      color: context.palette.elevated,
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
                color: status == PuzzleStatus.completed ? context.palette.ok : context.palette.muted,
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
                            text.puzzleTitle(puzzle),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: locked ? context.palette.muted : context.palette.fg,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: AppSpace.s2),
                          Text(
                            l.tagCurrent,
                            style: TextStyle(
                              color: context.palette.accent,
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
                      puzzleStatusText(status, saved, missing, l, text),
                      style: TextStyle(
                        color: status == PuzzleStatus.completed ? context.palette.fg : context.palette.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      puzzle.mode == PuzzleMode.build
                          ? l.tierLabel(puzzle.tier.index + 1)
                          : l.tierWithMode(puzzle.tier.index + 1, modeText(puzzle.mode, l)),
                      style: TextStyle(color: context.palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!locked) Icon(Icons.chevron_right, color: context.palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
