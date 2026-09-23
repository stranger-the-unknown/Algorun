import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_controller.dart';
import '../../editor/givens_bar.dart';
import '../../editor/palette_tray.dart';
import '../../editor/script_view.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/hint_session.dart';
import '../../state/providers.dart';
import '../../state/run_puzzle.dart';
import '../results/results_screen.dart';

final class PuzzleScreen extends ConsumerWidget {
  const PuzzleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final worldId = args?['worldId'] as String? ?? 'world_01';
    final puzzleId = args?['puzzleId'] as String? ?? 'ms3_editor_probe';
    return FutureBuilder<Puzzle>(
      future: ref.read(puzzleRepositoryProvider).loadPuzzle(worldId, puzzleId),
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
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return PuzzleEditor(puzzle: snap.data!);
      },
    );
  }
}

/// One puzzle being played: brief, hints, editor and RUN.
final class PuzzleEditor extends ConsumerStatefulWidget {
  const PuzzleEditor({super.key, required this.puzzle});
  final Puzzle puzzle;

  @override
  ConsumerState<PuzzleEditor> createState() => _PuzzleEditorState();
}

class _PuzzleEditorState extends ConsumerState<PuzzleEditor> {
  late final EditorController _controller;
  late final HintSession _hints = HintSession(widget.puzzle.hints);
  bool _briefOpen = true;
  bool _hintsOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      puzzle: widget.puzzle,
      seedExample: widget.puzzle.id == 'ms3_editor_probe',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    final outcome = runPuzzle(
      ref.read(engineProvider),
      _controller.graph,
      widget.puzzle,
      hintsUsed: _hints.used,
    );
    Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsArgs(
        puzzle: widget.puzzle,
        validation: outcome.validation,
        suite: outcome.suite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 840;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.puzzle.title),
            actions: [
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
