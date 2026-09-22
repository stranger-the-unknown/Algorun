import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_controller.dart';
import '../../editor/givens_bar.dart';
import '../../editor/palette_tray.dart';
import '../../editor/script_view.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/providers.dart';
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
        return _PuzzleEditor(puzzle: snap.data!);
      },
    );
  }
}

class _PuzzleEditor extends ConsumerStatefulWidget {
  const _PuzzleEditor({required this.puzzle});
  final Puzzle puzzle;

  @override
  ConsumerState<_PuzzleEditor> createState() => _PuzzleEditorState();
}

class _PuzzleEditorState extends ConsumerState<_PuzzleEditor> {
  late final EditorController _controller;
  bool _briefOpen = false;

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
    final engine = ref.read(engineProvider);
    final report = engine.validate(_controller.graph, widget.puzzle);
    final suite = engine.runTests(Program.empty, widget.puzzle);
    Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsArgs(
        puzzle: widget.puzzle,
        validation: report,
        suite: suite,
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
