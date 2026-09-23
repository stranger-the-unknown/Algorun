import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../state/progress_providers.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing waits on the save here: ENTER is always there, CONTINUE appears
    // once the save says where the player was.
    final view = ref.watch(campaignViewProvider).valueOrNull;
    final currentId = view?.progress.currentPuzzleId;
    final current = currentId == null ? null : view!.campaign.puzzles[currentId];
    final currentWorld = currentId == null ? null : view!.campaign.worldOf(currentId);
    return Scaffold(
      body: SafeArea(
        // Tall phones keep the buttons at the bottom; short screens
        // (landscape, large fonts) scroll instead of overflowing.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s6, AppSpace.s5, AppSpace.s5),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpace.s6 - AppSpace.s5).clamp(0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'ALGORUN',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6,
                              color: AppColors.fg,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    const Text(
                      'Construct the algorithm.\nNever type it.',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpace.s5),
                    if (view != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PROGRESS', style: AppText.label),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              '${view.progress.solvedCount} of ${view.progress.puzzleCount} puzzles solved',
                              style: const TextStyle(color: AppColors.fg),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            // The words above already say it.
                            ExcludeSemantics(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: view.progress.puzzleCount == 0
                                      ? 0
                                      : view.progress.solvedCount / view.progress.puzzleCount,
                                ),
                              ),
                            ),
                            if (current != null && currentWorld != null) ...[
                              const SizedBox(height: AppSpace.s3),
                              Text(
                                'Last played: ${current.title} · ${currentWorld.title}',
                                style: const TextStyle(color: AppColors.muted, height: 1.45),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpace.s5),
                    if (current != null && currentWorld != null) ...[
                      FilledButton(
                        key: const Key('home-continue'),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/puzzle',
                          arguments: {'worldId': currentWorld.id, 'puzzleId': current.id},
                        ),
                        child: const Text('CONTINUE'),
                      ),
                      const SizedBox(height: AppSpace.s3),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/worlds'),
                        child: const Text('WORLDS'),
                      ),
                    ] else
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, '/worlds'),
                        child: const Text('ENTER'),
                      ),
                    const SizedBox(height: AppSpace.s3),
                    OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      child: const Text('Settings'),
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
