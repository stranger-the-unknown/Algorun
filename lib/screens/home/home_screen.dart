import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/content_width.dart';
import '../../state/l10n_providers.dart';
import '../../state/progress_providers.dart';
import '../guide/guide_screen.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing waits on the save here: ENTER is always there, CONTINUE appears
    // once the save says where the player was.
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    final view = ref.watch(campaignViewProvider).valueOrNull;
    final currentId = view?.progress.currentPuzzleId;
    final current = currentId == null ? null : view!.campaign.puzzles[currentId];
    final currentWorld = currentId == null ? null : view!.campaign.worldOf(currentId);
    return Scaffold(
      body: ContentWidth(child: SafeArea(
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
                              color: context.palette.fg,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      l.homeTagline,
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.45,
                        fontSize: 16,
                      ),
                    ),
                    if (view != null && view.progress.solvedCount == 0) ...[
                      const SizedBox(height: AppSpace.s3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('home-how-to-play'),
                          onPressed: () => Navigator.pushNamed(context, '/guide', arguments: const GuideArgs()),
                          icon: const Icon(Icons.help_outline, size: 18),
                          label: Text(l.homeHowToPlay),
                        ),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: AppSpace.s5),
                    if (view != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        decoration: BoxDecoration(
                          color: context.palette.elevated,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.homeProgress, style: AppText.label(context)),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              l.homeSolvedCount(view.progress.solvedCount, view.progress.puzzleCount),
                              style: TextStyle(color: context.palette.fg),
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
                                l.homeLastPlayed(text.puzzleTitle(current), text.worldTitle(currentWorld)),
                                style: TextStyle(color: context.palette.muted, height: 1.45),
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
                        child: Text(l.homeContinue),
                      ),
                      const SizedBox(height: AppSpace.s3),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/worlds'),
                        child: Text(l.homeWorlds),
                      ),
                    ] else
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, '/worlds'),
                        child: Text(l.homeEnter),
                      ),
                    const SizedBox(height: AppSpace.s3),
                    OutlinedButton.icon(
                      key: const Key('home-guide'),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/guide',
                        arguments: const GuideArgs(tab: GuideTab.blocks),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(l.homeGuide),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      child: Text(l.homeSettings),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )),
    );
  }
}
