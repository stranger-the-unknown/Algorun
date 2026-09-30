import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../l10n/content_text.dart';
import '../../l10n/engine_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/terms.dart';
import '../../progress/progress_ledger.dart';
import '../../progress/save_data.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/content_width.dart';
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
    this.text = ContentText.english,
  });

  final Puzzle puzzle;

  /// Puzzle content (world titles) in the player's language.
  final ContentText text;
  final ValidationReport validation;
  final SuiteResult suite;

  /// What the run changed in saved progress; null for an unsaved puzzle.
  final RunRecordOutcome? progress;

  /// Offered after a solve, when an open puzzle is left to play.
  final NextPuzzle? next;
}

/// Player words for what a RUN changed in their progress; empty when nothing
/// did.
List<String> progressLines(
  RunRecordOutcome? outcome, [
  AppLocalizations? strings,
  ContentText text = ContentText.english,
]) {
  if (outcome == null) return const [];
  final l = strings ?? englishStrings;
  return [
    if (outcome.firstCompletion) l.progressSolved,
    if (outcome.improved.isNotEmpty)
      l.progressNewBest([
        for (final m in BestMetric.values)
          if (outcome.improved.contains(m)) _metricWords(m, l),
      ].join(', ')),
    if (outcome.opened.isNotEmpty) l.progressNowOpen(outcome.opened.map(text.worldTitle).join(', ')),
  ];
}

String _metricWords(BestMetric metric, AppLocalizations l) => switch (metric) {
      BestMetric.ops => l.bestSteps,
      BestMetric.peakAlloc => l.bestMemory,
      BestMetric.peakDepth => l.bestDepth,
      BestMetric.blocks => l.bestBlocks,
      BestMetric.hintsUsed => l.bestHints,
    };

/// How each verdict looks: an icon and a sentence, so nothing depends on
/// colour alone. [palette] gives the colour; [strings] sets the sentence's
/// language (English if none).
({IconData icon, Color color, String meaning}) verdictStyle(
  ResultKind kind,
  AppPalette palette, [
  AppLocalizations? strings,
]) {
  final meaning = verdictMeaning(kind, strings ?? englishStrings);
  return switch (kind) {
      ResultKind.correct => (
          icon: Icons.check_circle,
          color: palette.ok,
          meaning: meaning,
        ),
      ResultKind.wrongAnswer => (
          icon: Icons.cancel_outlined,
          color: palette.danger,
          meaning: meaning,
        ),
      ResultKind.runtimeError => (
          icon: Icons.error_outline,
          color: palette.danger,
          meaning: meaning,
        ),
      ResultKind.operationLimit => (
          icon: Icons.speed,
          color: palette.warn,
          meaning: meaning,
        ),
      ResultKind.timeLimit => (
          icon: Icons.hourglass_bottom,
          color: palette.warn,
          meaning: meaning,
        ),
      ResultKind.memoryLimit => (
          icon: Icons.memory,
          color: palette.warn,
          meaning: meaning,
        ),
      ResultKind.depthLimit => (
          icon: Icons.layers_outlined,
          color: palette.warn,
          meaning: meaning,
        ),
      ResultKind.invalidProgram => (
          icon: Icons.build_outlined,
          color: palette.warn,
          meaning: meaning,
        ),
    };
}

final class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = ModalRoute.of(context)?.settings.arguments as ResultsArgs?;
    if (args == null) {
      return Scaffold(body: Center(child: Text(l.noResult)));
    }
    final suite = args.suite;
    final kind = suite.kind;
    final style = verdictStyle(kind, context.palette, l);
    final progress = progressLines(args.progress, l, args.text);
    final engineDetail = suite.message ?? (args.validation.ok ? null : args.validation.messages.first.message);
    final detail = performanceMessage(suite, l) ?? (engineDetail == null ? null : engineText(engineDetail, l));
    final next = kind == ResultKind.correct ? args.next : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.resultTitle)),
      body: ContentWidth(child: SafeArea(
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
                      color: context.palette.elevated,
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
                                verdictText(kind, l),
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
                        Text(style.meaning, style: TextStyle(color: context.palette.fg, height: 1.45)),
                        if (detail != null && detail != style.meaning) ...[
                          const SizedBox(height: AppSpace.s2),
                          Text(detail, style: TextStyle(color: context.palette.muted, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                  ),
                  if (progress.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    _SectionLabel(l.progressSection),
                    for (final line in progress)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.arrow_forward, size: 16, color: context.palette.ok),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Expanded(child: Text(line, style: TextStyle(color: context.palette.fg))),
                          ],
                        ),
                      ),
                  ],
                  if (args.validation.messages.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    _SectionLabel(l.whatToFix),
                    for (final m in args.validation.messages)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Text(
                          engineText(m.message, l),
                          style: TextStyle(color: context.palette.fg, height: 1.4),
                        ),
                      ),
                  ],
                  if (suite.visible.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s5),
                    _SectionLabel(l.cases),
                    for (final result in suite.visible)
                      _CaseRow(result: result),
                  ],
                  if (suite.hiddenSummary != null) ...[
                    const SizedBox(height: AppSpace.s5),
                    _SectionLabel(l.hidden),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        l.hiddenPassed(suite.hiddenSummary!.passed, suite.hiddenSummary!.total),
                        style: TextStyle(color: context.palette.fg),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s5),
                  _SectionLabel(l.whatItCost),
                  const SizedBox(height: AppSpace.s2),
                  _CostTable(suite: suite, puzzle: args.puzzle),
                  if (!suite.ok && suite.firstFailureOpIndex != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        l.stoppedAfterStep(suite.firstFailureOpIndex!),
                        style: TextStyle(color: context.palette.muted),
                      ),
                    ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    l.hiddenNotShown,
                    style: TextStyle(color: context.palette.muted, fontSize: 13),
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
                      child: Text(l.nextPuzzle(l.upper(next.title)), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, ResultsAction.back),
                      child: Text(l.backToPuzzle),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => Navigator.pop(context, ResultsAction.back),
                      child: Text(l.backToPuzzle),
                    ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label(context));
}

/// What the run used against what the puzzle allows, one row per budget.
/// Over-budget rows say so in words and with an icon.
class _CostTable extends StatelessWidget {
  const _CostTable({required this.suite, required this.puzzle});
  final SuiteResult suite;
  final Puzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String count(int n) => formatCount(n, l.localeName);
    final m = suite.metrics;
    final perf = suite.performance;
    final ops = perf == null ? count(m.ops) : '${count(perf.worstOps)}${perf.overBudgetFinished ? '' : '+'}';
    final opsOver = suite.kind == ResultKind.operationLimit;
    final limits = puzzle.limits;
    final maxBlocks = puzzle.blocks.maxBlocks;
    final hints = m.hintsUsed;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
      child: Column(
        children: [
          _CostRow(label: '', used: l.costUsed, budget: l.costBudget, header: true),
          _CostRow(
            key: const Key('cost-steps'),
            label: l.costSteps,
            used: ops,
            budget: count(limits.maxOps),
            over: opsOver,
          ),
          _CostRow(
            key: const Key('cost-memory'),
            label: l.costMemory,
            used: count(m.peakAlloc),
            budget: count(limits.maxAlloc),
            over: suite.kind == ResultKind.memoryLimit,
          ),
          _CostRow(
            key: const Key('cost-depth'),
            label: l.costDepth,
            used: '${m.peakDepth}',
            budget: '${limits.maxDepth}',
            over: suite.kind == ResultKind.depthLimit,
          ),
          _CostRow(
            key: const Key('cost-blocks'),
            label: l.costBlocks,
            used: '${m.blocks}',
            budget: maxBlocks == null ? '—' : '$maxBlocks',
          ),
          _CostRow(
            key: const Key('cost-hints'),
            label: l.costHints,
            used: l.hintsCount(hints),
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
        ? AppText.label(context)
        : TextStyle(
            color: over ? context.palette.warn : context.palette.fg,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          );
    return Semantics(
      label: header ? null : '${context.l10n.costRowSemantics(label, used, budget)}${over ? context.l10n.overBudgetSuffix : ''}',
      excludeSemantics: !header,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(label, style: TextStyle(color: context.palette.muted)),
            ),
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (over) ...[
                    Icon(Icons.warning_amber_rounded, size: 16, color: context.palette.warn),
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
                style: header ? AppText.label(context) : TextStyle(color: context.palette.muted),
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
    final l = context.l10n;
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
                color: ok ? context.palette.ok : context.palette.danger,
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                result.id,
                style: TextStyle(
                  color: context.palette.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Flexible(
                child: Text(
                  ok ? l.casePassed : kindText(result.run.kind, l),
                  style: TextStyle(
                    color: ok ? context.palette.muted : context.palette.warn,
                  ),
                ),
              ),
            ],
          ),
          if (!ok) ...[
            _detail(context, l.caseGiven, result.input),
            _detail(context, l.caseExpected, result.expected),
            _detail(context, l.caseYouGave, result.actual),
          ],
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, Object? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Text(
        '$label: ${jsonEncode(value)}',
        style: TextStyle(color: context.palette.muted, fontSize: 13, height: 1.4),
      ),
    );
  }
}
