import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dev/stress_probe.dart';
import '../../editor/editor_bars.dart';
import '../../editor/editor_controller.dart';
import '../../editor/givens_bar.dart';
import '../../editor/palette_tray.dart';
import '../../editor/script_view.dart';
import '../../l10n/content_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/terms.dart';
import '../../progress/campaign.dart';
import '../../progress/progress_ledger.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/hint_session.dart';
import '../../state/l10n_providers.dart';
import '../../state/progress_providers.dart';
import '../../state/providers.dart';
import '../../state/run_puzzle.dart';
import '../guide/guide_screen.dart';
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
    final l = context.l10n;
    return FutureBuilder<_Opening>(
      future: _opening,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(l.puzzleFallbackTitle)),
            body: Padding(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger),
                  const SizedBox(height: AppSpace.s3),
                  Text(l.puzzleCouldNotOpen, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpace.s2),
                  Text('${snap.error}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        final opening = snap.data;
        if (opening == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpace.s3),
                  Text(l.puzzleOpening, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          );
        }
        if (opening.locked case final missing?) {
          return _LockedPuzzle(puzzle: opening.puzzle, missing: missing);
        }
        return PuzzleEditor(
          puzzle: opening.puzzle,
          initialGraph: opening.opened?.graph,
          save: opening.save,
          briefOpen: opening.briefOpen,
          notice: (opening.opened?.puzzleChanged ?? false) ? EditorNotice((l) => l.puzzleChangedNotice) : null,
        );
      },
    );
  }
}

class _LockedPuzzle extends ConsumerWidget {
  const _LockedPuzzle({required this.puzzle, required this.missing});

  final Puzzle puzzle;
  final List<String> missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    return Scaffold(
      appBar: AppBar(title: Text(text.puzzleTitle(puzzle))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: AppColors.muted, size: 28, semanticLabel: l.locked),
              const SizedBox(height: AppSpace.s3),
              Text(
                missing.isEmpty ? l.puzzleLocked : l.puzzleLockedLearn(text.concepts(missing)),
                style: const TextStyle(color: AppColors.fg, height: 1.45),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(l.puzzleLockedHow, style: const TextStyle(color: AppColors.muted, height: 1.45)),
              const SizedBox(height: AppSpace.s5),
              OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                child: Text(l.back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a puzzle screen talks to saved progress. A puzzle without it (a probe,
/// or a test) plays exactly the same and saves nothing.
abstract interface class PuzzleSaveHooks {
  /// The program changed (autosave; written after a short pause). [edited]
  /// is false when only its layout (a fold) changed.
  void graphChanged(BlockGraph graph, {bool edited = true});

  /// A RUN finished. Returns what it changed in the player's progress.
  RunRecordOutcome runFinished(BlockGraph graph, SuiteResult suite);

  /// The player is leaving the puzzle: write now.
  void leaving();

  /// The saved best solution, if the puzzle has been solved.
  BlockGraph? bestSolution();

  bool get solved;

  /// The puzzle to offer next, as of now, titled in [text]'s language.
  NextPuzzle? next(ContentText text);
}

final class _SavedPuzzle implements PuzzleSaveHooks {
  _SavedPuzzle(this.notifier, this.campaign, this.puzzle);

  final ProgressNotifier notifier;
  final Campaign campaign;
  final Puzzle puzzle;

  @override
  void graphChanged(BlockGraph graph, {bool edited = true}) =>
      notifier.saveDraft(campaign, puzzle, graph, edited: edited);

  @override
  RunRecordOutcome runFinished(BlockGraph graph, SuiteResult suite) =>
      notifier.recordRun(campaign, puzzle, graph, suite);

  @override
  void leaving() => notifier.flush();

  @override
  BlockGraph? bestSolution() => notifier.progressOf(puzzle.id)?.solution;

  @override
  bool get solved => notifier.progressOf(puzzle.id)?.completed ?? false;

  @override
  NextPuzzle? next(ContentText text) {
    final id = nextPuzzle(campaign, evaluateCampaign(campaign, notifier.current), puzzle.id);
    final world = id == null ? null : campaign.worldOf(id);
    if (id == null || world == null) return null;
    return NextPuzzle(
      worldId: world.id,
      puzzleId: id,
      title: text.puzzleTitle(campaign.puzzles[id]!),
      worldTitle: text.worldTitle(world),
    );
  }
}

/// One puzzle being played: brief, hints, editor and RUN.
///
/// Phone layout, top to bottom: the edit feedback line; the brief, hints,
/// givens and program in one scroll; the selection bar (a block is
/// selected) or the block palette; undo / redo, the block count and RUN.
/// Wide screens (≥ 840) put the palette in a side rail.
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

  /// Shown once above the program.
  final EditorNotice? notice;

  @override
  ConsumerState<PuzzleEditor> createState() => _PuzzleEditorState();
}

class _PuzzleEditorState extends ConsumerState<PuzzleEditor> {
  late final EditorController _controller;
  late final HintSession _hints = HintSession(widget.puzzle.hints);
  late bool _briefOpen = widget.briefOpen;
  bool _hintsOpen = false;
  bool _running = false;
  late BlockGraph _saved;
  late int _savedFolds;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      puzzle: widget.puzzle,
      seedExample: widget.puzzle.id == 'ms3_editor_probe',
      initialGraph: widget.initialGraph,
    );
    if (widget.puzzle.id == stressProbeId && widget.initialGraph == null) {
      buildStressProgram(_controller);
      _controller.markBaseline();
    }
    _controller.flash = widget.notice;
    _saved = _controller.graph;
    _savedFolds = _controller.foldsVersion;
    _controller.addListener(_autosave);
  }

  /// Only the program (and its folds) counts as a change: selection, the
  /// picker and the hint panel never write.
  void _autosave() {
    final graphChanged = !identical(_controller.graph, _saved);
    final foldsChanged = _controller.foldsVersion != _savedFolds;
    if (!graphChanged && !foldsChanged) return;
    _saved = _controller.graph;
    _savedFolds = _controller.foldsVersion;
    widget.save?.graphChanged(_controller.graphForSave, edited: graphChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_autosave);
    widget.save?.leaving();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    _controller.clearSelection();
    setState(() => _running = true);
    // Let RUNNING reach the screen before the cases run.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    final graph = _controller.graphForSave;
    final outcome = runPuzzle(ref.read(engineProvider), _controller.graph, widget.puzzle, hintsUsed: _hints.used);
    final progress = widget.save?.runFinished(graph, outcome.suite);
    final solved = outcome.suite.kind == ResultKind.correct;
    final next = solved ? widget.save?.next(ref.read(contentTextProvider)) : null;
    setState(() => _running = false);
    final action = await Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsArgs(
        puzzle: widget.puzzle,
        validation: outcome.validation,
        suite: outcome.suite,
        progress: progress,
        next: next,
        text: ref.read(contentTextProvider),
      ),
    );
    if (!mounted) return;
    if (action == ResultsAction.next && next != null) {
      await Navigator.pushReplacementNamed(
        context,
        '/puzzle',
        arguments: {'worldId': next.worldId, 'puzzleId': next.puzzleId},
      );
      return;
    }
    // A program that could not run points at the block to fix.
    final problem = outcome.suite.firstFailureBlockId;
    if (outcome.suite.kind == ResultKind.invalidProgram && problem != null) {
      final message = outcome.suite.message;
      _controller.showProblem(
        problem,
        message == null ? EditorNotice((l) => l.blockNeedsAttention) : EditorNotice.engine(message),
      );
    }
    setState(() {});
  }

  void _loadBest() {
    final best = widget.save?.bestSolution();
    if (best == null) return;
    _controller.replaceGraph(best);
    _controller.showFlash(EditorNotice((l) => l.bestLoaded));
  }

  void _clearProgram() {
    if (_controller.graph.blocks.isEmpty) return;
    _controller.replaceGraph(BlockGraph(blocks: const {}, variables: _controller.graph.variables));
    _controller.showFlash(EditorNotice((l) => l.programCleared));
  }

  void _openGuide() => Navigator.pushNamed(
        context,
        '/guide',
        arguments: GuideArgs(allow: _controller.paletteIds, tab: GuideTab.blocks),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final wide = size.width >= 840;
        final short = size.height < 560;
        final solved = widget.save?.solved ?? false;
        final best = widget.save?.bestSolution();
        final selection = _controller.selection;
        final header = <Widget>[
          if (solved) _SolvedLine(onLoadBest: best == null ? null : _loadBest),
          _Brief(
            puzzle: widget.puzzle,
            story: text.story(widget.puzzle),
            open: _briefOpen,
            onToggle: () => setState(() => _briefOpen = !_briefOpen),
          ),
          _HintBar(
            hints: _hints,
            texts: text.hints(widget.puzzle),
            open: _hintsOpen,
            onToggle: () => setState(() => _hintsOpen = !_hintsOpen),
            onReveal: () => setState(() {
              _hints.revealNext();
              _hintsOpen = true;
            }),
          ),
          GivensBar(controller: _controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(l.program, style: AppText.label),
          ),
        ];
        final script = ScriptView(controller: _controller, header: header);
        return PopScope(
          // Back first lets go of a selection, then leaves (the program is
          // already saved).
          canPop: selection == null && _controller.activeHole == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.clearSelection();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(text.puzzleTitle(widget.puzzle), overflow: TextOverflow.ellipsis)),
                  if (solved) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 18, color: AppColors.ok, semanticLabel: l.solved),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('open-guide'),
                  tooltip: l.openGuide,
                  onPressed: _openGuide,
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: l.programOptions,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => switch (value) {
                    'fold' => _controller.collapseAll(),
                    'unfold' => _controller.expandAll(),
                    'clear' => _clearProgram(),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'fold',
                      enabled: _controller.cBlockIds.isNotEmpty,
                      child: Text(l.foldAll),
                    ),
                    PopupMenuItem(
                      value: 'unfold',
                      enabled: _controller.collapsedIds.isNotEmpty,
                      child: Text(l.unfoldAll),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      enabled: _controller.graph.blocks.isNotEmpty,
                      child: Text(l.clearProgram),
                    ),
                  ],
                ),
              ],
            ),
            // Side insets (landscape system bars, cutouts); the RUN bar keeps
            // clear of the bottom one itself.
            body: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  FlashBanner(controller: _controller),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              SizedBox(width: 280, child: PaletteTray(controller: _controller, vertical: true)),
                              const VerticalDivider(width: 1),
                              Expanded(child: script),
                            ],
                          )
                        : script,
                  ),
                  if (selection != null)
                    BlockActionsBar(controller: _controller, info: selection)
                  else if (!wide && !short)
                    DecoratedBox(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      child: PaletteTray(controller: _controller),
                    ),
                  RunBar(controller: _controller, onRun: _run, running: _running, saved: widget.save != null),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A solved puzzle says so, and offers its best program back.
class _SolvedLine extends StatelessWidget {
  const _SolvedLine({required this.onLoadBest});
  final VoidCallback? onLoadBest;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.task_alt, size: 18, color: AppColors.ok),
          const SizedBox(width: 8),
          Expanded(child: Text(l.solvedLine, style: const TextStyle(color: AppColors.fg))),
          if (onLoadBest != null)
            Tooltip(
              message: l.loadBest,
              child: TextButton.icon(
                onPressed: onLoadBest,
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: Text(l.bestButton),
              ),
            ),
        ],
      ),
    );
  }
}

class _Brief extends StatelessWidget {
  const _Brief({
    required this.puzzle,
    required this.story,
    required this.open,
    required this.onToggle,
  });

  final Puzzle puzzle;
  final String story;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tier = puzzle.tier.index + 1;
    final tag = puzzle.mode == PuzzleMode.build ? l.briefTier(tier) : l.briefTierMode(tier, modeText(puzzle.mode, l));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(l.brief, style: AppText.label),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tag,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.1),
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, size: 22, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
        if (open) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(story, style: const TextStyle(color: AppColors.fg, height: 1.5, fontSize: 15)),
          ),
          _InputsAndOutput(puzzle: puzzle),
        ],
      ],
    );
  }
}

/// What the puzzle gives and what the program returns, in words:
/// `readings — list of numbers`, `RETURNS number`.
class _InputsAndOutput extends StatelessWidget {
  const _InputsAndOutput({required this.puzzle});
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const name = TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600);
    const words = TextStyle(color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (puzzle.io.inputs.isNotEmpty) ...[
              Text(l.ioInputs, style: AppText.label),
              const SizedBox(height: 4),
              for (final input in puzzle.io.inputs)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: input.name, style: name),
                      TextSpan(text: ' — ${typeText(input.type, l)}', style: words),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            Text(l.ioReturns, style: AppText.label),
            const SizedBox(height: 4),
            Text(typeText(puzzle.io.output, l), style: words),
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
    required this.texts,
    required this.open,
    required this.onToggle,
    required this.onReveal,
  });

  final HintSession hints;

  /// The hints in the player's language (same order and count).
  final List<String> texts;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    if (hints.total == 0) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: open,
                  child: InkWell(
                    key: const Key('hints-toggle'),
                    onTap: onToggle,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          Text(l.hints, style: AppText.label),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${hints.used}/${hints.total}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ),
                          const Spacer(),
                          Icon(open ? Icons.expand_less : Icons.expand_more, size: 22, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: TextButton.icon(
                  key: const Key('hints-reveal'),
                  onPressed: hints.hasMore ? onReveal : null,
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(
                    hints.hasMore ? l.showHint(hints.used + 1) : l.noMoreHints,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
          if (open)
            for (var i = 0; i < hints.used; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      border: Border(left: BorderSide(color: AppColors.warn, width: 2)),
                    ),
                    child: Text('${i + 1}. ${texts[i]}', style: const TextStyle(color: AppColors.fg, height: 1.45)),
                  ),
                ),
              ),
          if (open && hints.used == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Text(l.hintsIntro, style: const TextStyle(color: AppColors.muted, height: 1.45)),
            ),
        ],
      ),
    );
  }
}
