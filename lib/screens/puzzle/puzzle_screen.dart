import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_controller.dart';
import '../../editor/givens_bar.dart';
import '../../editor/palette_tray.dart';
import '../../editor/script_view.dart';
import '../../progress/campaign.dart';
import '../../progress/progress_ledger.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/hint_session.dart';
import '../../state/progress_providers.dart';
import '../../state/providers.dart';
import '../../state/run_puzzle.dart';
import '../results/results_screen.dart';

/// Route `/puzzle`, arguments `{'worldId': …, 'puzzleId': …}`.
///
/// A campaign puzzle opens only when progression has unlocked it; it restores
/// the saved program and saves as the player works. A puzzle no world lists
/// (a dev probe) opens as before and is never saved.
final class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

final class _Opening {
  const _Opening(this.puzzle, {this.locked, this.opened, this.save, this.briefOpen = true});

  final Puzzle puzzle;

  /// Concepts still needed, when the puzzle is locked.
  final List<String>? locked;
  final OpenedPuzzle? opened;
  final PuzzleSaveHooks? save;
  final bool briefOpen;
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  Future<_Opening>? _opening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _opening ??= _open(
      args?['worldId'] as String? ?? 'world_01',
      args?['puzzleId'] as String? ?? 'ms3_editor_probe',
    );
  }

  Future<_Opening> _open(String worldId, String puzzleId) async {
    final campaign = await ref.read(campaignProvider.future);
    final save = await ref.read(progressProvider.future);
    final puzzle = campaign.puzzles[puzzleId];
    if (puzzle == null) {
      return _Opening(await ref.read(puzzleRepositoryProvider).loadPuzzle(worldId, puzzleId));
    }
    final progress = evaluateCampaign(campaign, save);
    if (!progress.isPuzzleOpen(puzzleId)) {
      return _Opening(puzzle, locked: progress.missingFor(puzzleId));
    }
    final notifier = ref.read(progressProvider.notifier);
    return _Opening(
      puzzle,
      opened: notifier.openPuzzle(campaign, puzzle),
      save: _SavedPuzzle(notifier, campaign, puzzle),
      briefOpen: save.settings.showBriefOnOpen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Opening>(
      future: _opening,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                '${snap.error}',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          );
        }
        final opening = snap.data;
        if (opening == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (opening.locked case final missing?) {
          return _LockedPuzzle(puzzle: opening.puzzle, missing: missing);
        }
        return PuzzleEditor(
          puzzle: opening.puzzle,
          initialGraph: opening.opened?.graph,
          save: opening.save,
          briefOpen: opening.briefOpen,
          notice: (opening.opened?.puzzleChanged ?? false)
              ? 'This puzzle changed since you last played it. Your program was kept; RUN shows what to update.'
              : null,
        );
      },
    );
  }
}

class _LockedPuzzle extends StatelessWidget {
  const _LockedPuzzle({required this.puzzle, required this.missing});

  final Puzzle puzzle;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(puzzle.title)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.faint),
            const SizedBox(height: AppSpace.s3),
            Text(
              missing.isEmpty
                  ? 'This puzzle is locked.'
                  : 'This puzzle is locked. It opens once you have learned ${missing.map(conceptWords).join(', ')}.',
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a puzzle screen talks to saved progress. A puzzle without it (a probe,
/// or a test) plays exactly the same and saves nothing.
abstract interface class PuzzleSaveHooks {
  /// The program changed (autosave; written after a short pause).
  void graphChanged(BlockGraph graph);

  /// A RUN finished. Returns what it changed in the player's progress.
  RunRecordOutcome runFinished(BlockGraph graph, SuiteResult suite);

  /// The player is leaving the puzzle: write now.
  void leaving();

  /// The saved best solution, if the puzzle has been solved.
  BlockGraph? bestSolution();

  bool get solved;
}

final class _SavedPuzzle implements PuzzleSaveHooks {
  _SavedPuzzle(this.notifier, this.campaign, this.puzzle);

  final ProgressNotifier notifier;
  final Campaign campaign;
  final Puzzle puzzle;

  @override
  void graphChanged(BlockGraph graph) => notifier.saveDraft(campaign, puzzle, graph);

  @override
  RunRecordOutcome runFinished(BlockGraph graph, SuiteResult suite) =>
      notifier.recordRun(campaign, puzzle, graph, suite);

  @override
  void leaving() => notifier.flush();

  @override
  BlockGraph? bestSolution() => notifier.progressOf(puzzle.id)?.solution;

  @override
  bool get solved => notifier.progressOf(puzzle.id)?.completed ?? false;
}

/// One puzzle being played: brief, hints, editor and RUN.
final class PuzzleEditor extends ConsumerStatefulWidget {
  const PuzzleEditor({
    super.key,
    required this.puzzle,
    this.initialGraph,
    this.save,
    this.briefOpen = true,
    this.notice,
  });

  final Puzzle puzzle;

  /// A saved program to restore.
  final BlockGraph? initialGraph;
  final PuzzleSaveHooks? save;
  final bool briefOpen;

  /// Shown once above the brief.
  final String? notice;

  @override
  ConsumerState<PuzzleEditor> createState() => _PuzzleEditorState();
}

class _PuzzleEditorState extends ConsumerState<PuzzleEditor> {
  late final EditorController _controller;
  late final HintSession _hints = HintSession(widget.puzzle.hints);
  late bool _briefOpen = widget.briefOpen;
  bool _hintsOpen = false;
  late BlockGraph _saved;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      puzzle: widget.puzzle,
      seedExample: widget.puzzle.id == 'ms3_editor_probe',
      initialGraph: widget.initialGraph,
    );
    _controller.flash = widget.notice;
    _saved = _controller.graph;
    _controller.addListener(_autosave);
  }

  /// Only a new program counts as a change: selection, the picker and the
  /// hint panel never write.
  void _autosave() {
    if (identical(_controller.graph, _saved)) return;
    _saved = _controller.graph;
    widget.save?.graphChanged(_saved);
  }

  @override
  void dispose() {
    _controller.removeListener(_autosave);
    widget.save?.leaving();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final outcome = runPuzzle(
      ref.read(engineProvider),
      _controller.graph,
      widget.puzzle,
      hintsUsed: _hints.used,
    );
    final progress = widget.save?.runFinished(_controller.graph, outcome.suite);
    await Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsArgs(
        puzzle: widget.puzzle,
        validation: outcome.validation,
        suite: outcome.suite,
        progress: progress,
      ),
    );
    if (mounted) setState(() {});
  }

  void _loadBest() {
    final best = widget.save?.bestSolution();
    if (best == null) return;
    _controller.replaceGraph(best);
    _controller.showFlash('Your best solution is loaded. UNDO brings back the program you had.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 840;
        final solved = widget.save?.solved ?? false;
        final best = widget.save?.bestSolution();
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(widget.puzzle.title, overflow: TextOverflow.ellipsis)),
                if (solved) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, size: 18, color: AppColors.ok, semanticLabel: 'Solved'),
                ],
              ],
            ),
            actions: [
              if (best != null)
                IconButton(
                  tooltip: 'Load best solution',
                  onPressed: _loadBest,
                  icon: const Icon(Icons.emoji_events_outlined),
                ),
              IconButton(
                tooltip: 'Undo',
                onPressed: _controller.canUndo ? _controller.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: _controller.canRedo ? _controller.redo : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: 'Remove block',
                onPressed: _controller.selectedBlockId == null
                    ? null
                    : _controller.detachSelected,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_controller.flash != null)
                Material(
                  color: AppColors.subtle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.warn),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _controller.flash!,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _Brief(
                puzzle: widget.puzzle,
                open: _briefOpen,
                onToggle: () => setState(() => _briefOpen = !_briefOpen),
              ),
              _HintBar(
                hints: _hints,
                open: _hintsOpen,
                onToggle: () => setState(() => _hintsOpen = !_hintsOpen),
                onReveal: () => setState(() {
                  _hints.revealNext();
                  _hintsOpen = true;
                }),
              ),
              GivensBar(controller: _controller),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: PaletteTray(controller: _controller),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: ScriptView(controller: _controller)),
                        ],
                      )
                    : ScriptView(controller: _controller),
              ),
              if (!wide) PaletteTray(controller: _controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _run,
                  child: const Text('RUN'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Brief extends StatelessWidget {
  const _Brief({
    required this.puzzle,
    required this.open,
    required this.onToggle,
  });

  final Puzzle puzzle;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'BRIEF',
                  style: TextStyle(
                    color: AppColors.faint,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.faint,
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 6),
              Text(
                puzzle.story,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progressive hints, in the author's order. Opening or closing the list only
/// shows what is already revealed; SHOW HINT is the only thing that counts.
/// Hints are puzzle text — no solution, no hidden case ever reaches here.
class _HintBar extends StatelessWidget {
  const _HintBar({
    required this.hints,
    required this.open,
    required this.onToggle,
    required this.onReveal,
  });

  final HintSession hints;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    if (hints.total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('hints-toggle'),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          'HINTS',
                          style: TextStyle(
                            color: AppColors.faint,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${hints.used}/${hints.total}',
                          style: const TextStyle(color: AppColors.faint, fontSize: 12),
                        ),
                        const Spacer(),
                        Icon(
                          open ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: AppColors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('hints-reveal'),
                onPressed: hints.hasMore ? onReveal : null,
                icon: const Icon(Icons.lightbulb_outline, size: 16),
                label: Text(
                  hints.hasMore ? 'SHOW HINT ${hints.used + 1}' : 'NO MORE HINTS',
                  style: const TextStyle(fontSize: 12, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          if (open)
            for (final (i, hint) in hints.revealed.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 8),
                child: Text(
                  '${i + 1}. $hint',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
          if (open && hints.used == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                'Hints go from the idea to the approach, one at a time.',
                style: TextStyle(color: AppColors.faint, height: 1.45),
              ),
            ),
        ],
      ),
    );
  }
}
