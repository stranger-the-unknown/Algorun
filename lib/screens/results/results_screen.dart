import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../progress/progress_ledger.dart';
import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/performance_text.dart';

final class ResultsArgs {
  const ResultsArgs({
    required this.puzzle,
    required this.validation,
    required this.suite,
    this.progress,
  });

  final Puzzle puzzle;
  final ValidationReport validation;
  final SuiteResult suite;

  /// What the run changed in saved progress; null for an unsaved puzzle.
  final RunRecordOutcome? progress;
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
    final progress = progressLines(args.progress);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: kind == ResultKind.correct
                            ? AppColors.ok
                            : AppColors.warn,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      performanceMessage(suite) ??
                          suite.message ??
                          (args.validation.ok
                              ? 'No message.'
                              : args.validation.messages.first.message),
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    if (progress.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s4),
                      const _SectionLabel('PROGRESS'),
                      for (final line in progress)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s2),
                          child: Text(line, style: const TextStyle(color: AppColors.ok)),
                        ),
                    ],
                    if (args.validation.messages.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s4),
                      const _SectionLabel('WHAT TO FIX'),
                      for (final m in args.validation.messages)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s2),
                          child: Text(
                            m.message,
                            style: const TextStyle(color: AppColors.fg),
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
                      const SizedBox(height: AppSpace.s4),
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
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        costLine(suite),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        budgetLine(args.puzzle),
                        style: const TextStyle(color: AppColors.faint, fontSize: 13),
                      ),
                    ),
                    if (!suite.ok && suite.firstFailureOpIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Text(
                          'Stopped after step ${suite.firstFailureOpIndex}.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            const Text(
              'Hidden test inputs and answers are not shown.',
              style: TextStyle(color: AppColors.faint, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.s4),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK TO PUZZLE'),
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.faint,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
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
                size: 16,
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
              Text(
                ok ? 'passed' : result.run.kind.label.toLowerCase(),
                style: TextStyle(
                  color: ok ? AppColors.muted : AppColors.warn,
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
      padding: const EdgeInsets.only(left: 24, top: 2),
      child: Text(
        '$label: ${jsonEncode(value)}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
