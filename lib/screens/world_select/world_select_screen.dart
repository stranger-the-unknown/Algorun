import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/campaign.dart';
import '../../l10n/content_text.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/content_width.dart';
import '../../state/l10n_providers.dart';
import '../../state/progress_providers.dart';
import '../../state/progress_text.dart';

final class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    final view = ref.watch(campaignViewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.worldsTitle)),
      body: ContentWidth(child: SafeArea(top: false, child: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Text('$e', style: TextStyle(color: context.palette.danger)),
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
                subtitle: worldStatusText(world, view.progress.worldStatus(world.id), view.progress, l, text),
                text: text,
                current: world.id == currentWorld,
                solved: world.puzzleIds
                    .where((id) => view.progress.puzzleStatus(id) == PuzzleStatus.completed)
                    .length,
              );
            },
          );
        },
      ))),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.status,
    required this.subtitle,
    required this.current,
    required this.solved,
    required this.text,
  });

  final WorldDef world;
  final WorldStatus status;
  final String subtitle;
  final bool current;
  final int solved;
  final ContentText text;
  int get total => world.puzzleIds.length;

  bool get _playable => status == WorldStatus.open || status == WorldStatus.completed;

  @override
  Widget build(BuildContext context) {
    final dim = !_playable;
    final l = context.l10n;
    return Material(
      color: context.palette.elevated,
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
                  style: TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: context.palette.muted,
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
                            text.worldTitle(world),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: dim ? context.palette.muted : context.palette.fg,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: AppSpace.s2),
                          _Tag(l.tagCurrent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: status == WorldStatus.locked ? context.palette.muted : context.palette.fg,
                        fontSize: 13,
                      ),
                    ),
                    if (world.concepts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.worldTeaches(text.concepts(world.concepts)),
                        style: TextStyle(color: context.palette.muted, fontSize: 12),
                      ),
                    ],
                    if (status == WorldStatus.open && total > 0) ...[
                      const SizedBox(height: AppSpace.s2),
                      // The words above already say it.
                      ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(minHeight: 3, value: solved / total),
                        ),
                      ),
                    ],
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
                color: status == WorldStatus.completed ? context.palette.ok : context.palette.muted,
                semanticLabel: switch (status) {
                  WorldStatus.locked => l.locked,
                  WorldStatus.completed => l.stateCompleted,
                  WorldStatus.empty => l.worldNoPuzzles,
                  WorldStatus.open => l.stateOpen,
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
        border: Border.all(color: context.palette.borderStrong),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.palette.accent, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
  }
}
