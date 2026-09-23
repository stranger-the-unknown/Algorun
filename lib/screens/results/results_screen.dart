import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../progress/progress_ledger.dart';
import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/performance_text.dart';

/// A puzzle to go on to after a solve.
final class NextPuzzle {
  const NextPuzzle({
    required this.worldId,
    required this.puzzleId,
    required this.title,
    required this.worldTitle,
  });

  final String worldId;
  final String puzzleId;
  final String title;
  final String worldTitle;
}

/// What the results screen hands back to the puzzle.
enum ResultsAction { back, next }

final class ResultsArgs {
  const ResultsArgs({
    required this.puzzle,
    required this.validation,
    required this.suite,
    this.progress,
    this.next,
  });

  final Puzzle puzzle;
  final ValidationReport validation;
  final SuiteResult suite;

  /// What the run changed in saved progress; null for an unsaved puzzle.
  final RunRecordOutcome? progress;

  /// Offered after a solve, when an open puzzle is left to play.
  final NextPuzzle? next;
}

/// Player words for what a RUN changed in their progress; empty when nothing
/// did.
List<String> progressLines(RunRecordOutcome? outcome) {
  if (outcome == null) return const [];
  return [
    if (outcome.firstCompletion) 'Puzzle solved.',
    if (outcome.improved.isNotEmpty)
      'New best: ${[for (final m in BestMetric.values) if (outcome.improved.contains(m)) _metricWords(m)].join(', ')}.',
    if (outcome.opened.isNotEmpty) 'Now open: ${outcome.opened.map((w) => w.title).join(', ')}.',
  ];
}

String _metricWords(BestMetric metric) => switch (metric) {
      BestMetric.ops => 'fewest steps',
      BestMetric.peakAlloc => 'least memory',
      BestMetric.peakDepth => 'least depth',
      BestMetric.blocks => 'fewest blocks',
      BestMetric.hintsUsed => 'fewest hints',
    };

/// How each verdict looks: an icon and a sentence, so nothing depends on
/// colour alone.
({IconData icon, Color color, String meaning}) verdictStyle(ResultKind kind) => switch (kind) {
      ResultKind.correct => (
          icon: Icons.check_circle,
          color: AppColors.ok,
          meaning: 'Every case came out right, within every budget.',
        ),
      ResultKind.wrongAnswer => (
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
          meaning: 'The program finished, but at least one answer is not the expected one.',
        ),
      ResultKind.runtimeError => (
          icon: Icons.error_outline,
          color: AppColors.danger,
          meaning: 'The program stopped on an instruction it could not carry out.',
        ),
      ResultKind.operationLimit => (
          icon: Icons.speed,
          color: AppColors.warn,
          meaning: 'The program needed more steps than the budget allows.',
        ),
      ResultKind.timeLimit => (
          icon: Icons.hourglass_bottom,
          color: AppColors.warn,
          meaning: 'The program ran out of time.',
        ),
      ResultKind.memoryLimit => (
          icon: Icons.memory,
          color: AppColors.warn,
          meaning: 'The program kept more values in its lists and maps than the budget allows.',
        ),
      ResultKind.depthLimit => (
          icon: Icons.layers_outlined,
          color: AppColors.warn,
          meaning: 'The program went deeper than the budget allows.',
        ),
      ResultKind.invalidProgram => (
          icon: Icons.build_outlined,
          color: AppColors.warn,
          meaning: 'The program cannot run yet. Fix what is listed below.',
        ),
    };

final class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as ResultsArgs?;
    if (args == null) {
      return const Scaffold(body: Center(child: Text('No result.')));
    }
    final suite = args.suite;
    final kind = suite.kind;
    final style = verdictStyle(kind);
    final progress = progressLines(args.progress);
    final detail = performanceMessage(suite) ??
        suite.message ??
        (args.validation.ok ? null : args.validation.messages.first.message);
    final next = kind == ResultKind.correct ? args.next : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s4),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      border: Border(left: BorderSide(color: style.color, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(style.icon, color: style.color, size: 28),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Text(
                                kind.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: style.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(style.meaning, style: const TextStyle(color: AppColors.fg, height: 1.45)),
                        if (detail != null && detail != style.meaning) ...[
                          const SizedBox(height: AppSpace.s2),
                          Text(detail, style: const TextStyle(color: AppColors.muted, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                  ),
                  if (progress.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    const _SectionLabel('PROGRESS'),
                    for (final line in progress)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.arrow_forward, size: 16, color: AppColors.ok),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Expanded(child: Text(line, style: const TextStyle(color: AppColors.fg))),
                          ],
                        ),
                      ),
                  ],
                  if (args.validation.messages.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    const _SectionLabel('WHAT TO FIX'),
                    for (final m in args.validation.messages)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Text(
                          m.message,
                          style: const TextStyle(color: AppColors.fg, height: 1.4),
                        ),
                      ),
                  ],
                  if (suite.visible.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    const _SectionLabel('CASES'),
                    for (final result in suite.visible)
                      _CaseRow(result: result),
                  ],
                  if (suite.hiddenSummary != null) ...[
                    const SizedBox(height: AppSpace.s5),
                    const _SectionLabel('HIDDEN'),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        '${suite.hiddenSummary!.passed} of '
                        '${suite.hiddenSummary!.total} hidden cases passed.',
                        style: const TextStyle(color: AppColors.fg),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s5),
                  const _SectionLabel('WHAT IT COST'),
                  const SizedBox(height: AppSpace.s2),
                  _CostTable(suite: suite, puzzle: args.puzzle),
                  if (!suite.ok && suite.firstFailureOpIndex != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        'Stopped after step ${suite.firstFailureOpIndex}.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  const SizedBox(height: AppSpace.s4),
                  const Text(
                    'Hidden test inputs and answers are not shown.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (next != null) ...[
                    FilledButton(
                      key: const Key('results-next'),
                      onPressed: () => Navigator.pop(context, ResultsAction.next),
                      child: Text('NEXT: ${next.title.toUpperCase()}', overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, ResultsAction.back),
                      child: const Text('BACK TO PUZZLE'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => Navigator.pop(context, ResultsAction.back),
                      child: const Text('BACK TO PUZZLE'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label);
}

/// What the run used against what the puzzle allows, one row per budget.
/// Over-budget rows say so in words and with an icon.
class _CostTable extends StatelessWidget {
  const _CostTable({required this.suite, required this.puzzle});
  final SuiteResult suite;
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final m = suite.metrics;
    final perf = suite.performance;
    final ops = perf == null ? formatCount(m.ops) : '${formatCount(perf.worstOps)}${perf.overBudgetFinished ? '' : '+'}';
    final opsOver = suite.kind == ResultKind.operationLimit;
    final limits = puzzle.limits;
    final maxBlocks = puzzle.blocks.maxBlocks;
    final hints = m.hintsUsed;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
      child: Column(
        children: [
          const _CostRow(label: '', used: 'USED', budget: 'BUDGET', header: true),
          _CostRow(
            key: const Key('cost-steps'),
            label: 'Steps',
            used: ops,
            budget: formatCount(limits.maxOps),
            over: opsOver,
          ),
          _CostRow(
            key: const Key('cost-memory'),
            label: 'Memory cells',
            used: formatCount(m.peakAlloc),
            budget: formatCount(limits.maxAlloc),
            over: suite.kind == ResultKind.memoryLimit,
          ),
          _CostRow(
            key: const Key('cost-depth'),
            label: 'Depth',
            used: '${m.peakDepth}',
            budget: '${limits.maxDepth}',
            over: suite.kind == ResultKind.depthLimit,
          ),
          _CostRow(
            key: const Key('cost-blocks'),
            label: 'Blocks',
            used: '${m.blocks}',
            budget: maxBlocks == null ? '—' : '$maxBlocks',
          ),
          _CostRow(
            key: const Key('cost-hints'),
            label: 'Hints',
            used: hints == 1 ? '1 hint' : '$hints hints',
            budget: '—',
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    super.key,
    required this.label,
    required this.used,
    required this.budget,
    this.over = false,
    this.header = false,
  });

  final String label;
  final String used;
  final String budget;
  final bool over;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final valueStyle = header
        ? AppText.label
        : TextStyle(
            color: over ? AppColors.warn : AppColors.fg,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
    return Semantics(
      label: header ? null : '$label: $used used, budget $budget${over ? ', over the budget' : ''}',
      excludeSemantics: !header,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(label, style: const TextStyle(color: AppColors.muted)),
            ),
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (over) ...[
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warn),
                    const SizedBox(width: 4),
                  ],
                  Flexible(child: Text(used, textAlign: TextAlign.end, style: valueStyle)),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                budget,
                textAlign: TextAlign.end,
                style: header ? AppText.label : const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A visible case. Hidden cases never reach this widget.
class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.result});
  final CaseResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.ok;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 18,
                color: ok ? AppColors.ok : AppColors.danger,
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                result.id,
                style: const TextStyle(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Flexible(
                child: Text(
                  ok ? 'passed' : result.run.kind.label.toLowerCase(),
                  style: TextStyle(
                    color: ok ? AppColors.muted : AppColors.warn,
                  ),
                ),
              ),
            ],
          ),
          if (!ok) ...[
            _detail('given', result.input),
            _detail('expected', result.expected),
            _detail('you gave', result.actual),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, Object? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Text(
        '$label: ${jsonEncode(value)}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
      ),
    );
  }
}
