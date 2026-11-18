import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/engine_text.dart';
import '../../l10n/l10n.dart';
import '../../shared/content_width.dart';
import '../../shared/theme/app_theme.dart';
import '../../state/performance_text.dart';
import '../../state/providers.dart';
import '../../state/trace_session.dart';
import 'trace_program_view.dart';
import 'trace_values.dart';

/// What the step-through screen needs: the program as the player built it
/// and one graded **visible** case. There is no way to hand it a hidden case:
/// [caseResult] comes from `SuiteResult.visible`, and the screen looks the
/// case up among the puzzle's visible fixtures only.
final class TraceArgs {
  const TraceArgs({required this.puzzle, required this.graph, required this.caseResult, this.limits = TraceLimits.standard});

  final Puzzle puzzle;
  final BlockGraph graph;
  final CaseResult caseResult;

  /// How much of a long run is held at once.
  final TraceLimits limits;
}

/// Route `/trace` (T1): one case of the last RUN, step by step.
///
/// Top to bottom on a phone: the case (what the puzzle expects, what the
/// program gave), the program with the block that just ran marked, what that
/// step did, the values as they stand, and the controls — back and forward
/// one step, play / pause with a speed, first and last, and a slider over the
/// whole run. A wide window puts the program and the values side by side.
final class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key, this.args});

  /// Given directly (tests); otherwise read from the route.
  final TraceArgs? args;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  TraceArgs? _args;
  TraceSession? _session;
  bool _opened = false;
  double? _drag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final args = widget.args ?? ModalRoute.of(context)?.settings.arguments as TraceArgs?;
    _args = args;
    if (args == null || !args.caseResult.visible) return;
    final program = ref.read(engineProvider).lower(args.graph, args.puzzle).program;
    if (program == null) return;
    _session = TraceSession.forCase(program, args.puzzle, args.caseResult.id, limits: args.limits);
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _help() {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s4, AppSpace.s5, AppSpace.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.traceHelpTitle, style: AppText.label(context)),
              const SizedBox(height: AppSpace.s3),
              for (final line in [l.traceHelpSteps, l.traceHelpValues, l.traceHelpCalls, l.traceHelpCost, l.traceHelpHidden])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s3),
                  child: Text(line, style: TextStyle(color: context.palette.fg, height: 1.45)),
                ),
              FilledButton(
                key: const Key('trace-help-close'),
                onPressed: () => Navigator.pop(context),
                child: Text(l.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = _args;
    final session = _session;
    if (args == null || session == null || session.total == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(l.traceTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Text(l.traceCannot, textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.traceTitle),
        actions: [
          IconButton(
            key: const Key('trace-help'),
            tooltip: l.traceHelp,
            onPressed: _help,
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.editor,
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) {
              final step = session.step!;
              final wide = MediaQuery.sizeOf(context).width >= 720;
              final program = TraceProgramView(
                graph: args.graph,
                currentId: step.blockId,
                failed: step.kind == TraceKinds.halt,
                badge: switch (step.value) {
                  TraceBool(:final value) when step.kind == TraceKinds.ifStep || step.kind == TraceKinds.whileStep =>
                    value ? 'TRUE' : 'FALSE',
                  _ => null,
                },
              );
              final status = _Status(session: session, args: args);
              final values = _Values(session: session);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CaseStrip(result: args.caseResult),
                  Divider(height: 1, color: context.palette.border),
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: program),
                              VerticalDivider(width: 1, color: context.palette.border),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [status, Divider(height: 1, color: context.palette.border), Expanded(child: values)],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: program),
                              Divider(height: 1, color: context.palette.border),
                              status,
                              Divider(height: 1, color: context.palette.border),
                              Expanded(flex: 4, child: values),
                            ],
                          ),
                  ),
                  Divider(height: 1, color: context.palette.border),
                  _Controls(
                    session: session,
                    drag: _drag,
                    onDrag: (value) => setState(() => _drag = value),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Which case this is, what the puzzle expects and what the program gave.
/// The given values are the names the trace starts with, so they are not
/// repeated here.
class _CaseStrip extends StatelessWidget {
  const _CaseStrip({required this.result});
  final CaseResult result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final ok = result.ok;
    final muted = TextStyle(color: p.muted, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, 0, AppSpace.s4, AppSpace.s2),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined, size: 18, color: ok ? p.ok : p.danger),
          const SizedBox(width: AppSpace.s2),
          Text(result.id, style: TextStyle(color: p.fg, fontWeight: FontWeight.w700)),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Text(
              [
                '${l.caseExpected}: ${jsonEncode(result.expected)}',
                if (result.actual != null) '${l.caseYouGave}: ${jsonEncode(result.actual)}',
              ].join('  ·  '),
              key: const Key('trace-case'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the step on show did, in a sentence, and what it has cost so far.
class _Status extends StatelessWidget {
  const _Status({required this.session, required this.args});
  final TraceSession session;
  final TraceArgs args;

  String _sentence(AppLocalizations l, TraceStep step) {
    final value = step.value;
    final shown = value == null ? null : traceValueText(session.recording, value, step.index, l);
    final truth = value is TraceBool ? value.value : null;
    // A SET, INCREMENT or DECREMENT of one name says what the name holds now.
    final written = step.kind == TraceKinds.assign || step.kind == TraceKinds.inc || step.kind == TraceKinds.dec;
    if (written && step.changed.length == 1 && step.frames.isNotEmpty) {
      final name = step.changed.single;
      final now = step.frames.last.vars[name];
      if (now != null) return l.traceNowIs(name, traceValueText(session.recording, now, step.index, l));
    }
    return switch (step.kind) {
      TraceKinds.start => l.traceStart,
      TraceKinds.call => l.traceCall(step.frames.isEmpty ? '' : step.frames.last.function),
      TraceKinds.ifStep => truth == true ? l.traceIfTrue : l.traceIfFalse,
      TraceKinds.whileStep => truth == true ? l.traceWhileTrue : l.traceWhileFalse,
      TraceKinds.forRange || TraceKinds.forEach => l.traceLoopNext,
      TraceKinds.loopEnd => l.traceLoopEnd,
      TraceKinds.breakStep => l.traceBreak,
      TraceKinds.continueStep => l.traceContinue,
      TraceKinds.returnStep =>
        step.depth <= 1 ? l.traceAnswer(shown ?? 'NOTHING') : l.traceReturn(shown ?? 'NOTHING'),
      TraceKinds.halt => l.traceHalt(engineText(step.message ?? '', l)),
      _ => value == null || value is TraceNothing ? l.traceRan : l.traceRanValue(shown!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final step = session.step!;
    final failed = step.kind == TraceKinds.halt;
    final limits = args.puzzle.limits;
    final budget = args.puzzle.opsBudgetFor(
      args.puzzle.visibleTests.firstWhere((c) => c.id == args.caseResult.id),
    );
    String count(int n) => formatCount(n, l.localeName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 1),
                  child: Icon(Icons.error_outline, size: 18, color: p.danger),
                ),
              Expanded(
                child: Text(
                  _sentence(l, step),
                  key: const Key('trace-sentence'),
                  style: TextStyle(color: failed ? p.danger : p.fg, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              l.traceOpsSoFar(count(step.opIndex), count(budget)),
              if (step.depth > 1) l.traceDepthNow(step.depth, limits.maxDepth),
            ].join('  ·  '),
            key: const Key('trace-cost'),
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
          if (session.windowed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.traceLongRun(count(session.total), count(session.windowSteps)),
                key: const Key('trace-long-run'),
                style: TextStyle(color: p.warn, fontSize: 12, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

/// The open calls (when there is more than one) and the names of the one on
/// show.
class _Values extends StatelessWidget {
  const _Values({required this.session});
  final TraceSession session;

  String _frameLabel(AppLocalizations l, TraceStep step, TraceFrameSnapshot frame) {
    if (frame.vars.isEmpty) return frame.function;
    // The first names are the parameters: enough to tell two calls of one
    // function apart.
    final first = frame.vars.entries.take(2).map(
          (e) => '${e.key}=${traceValueText(session.recording, e.value, step.index, l, maxItems: 2, depth: 1)}',
        );
    return '${frame.function}  ${first.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final step = session.step!;
    final frames = step.frames;
    final shownIndex = session.frameIndex;
    final frame = shownIndex >= 0 && shownIndex < frames.length ? frames[shownIndex] : null;
    final running = shownIndex == frames.length - 1;
    // The open calls stay put above the values: whatever the values list has
    // scrolled to, where the program is in its calls is always in view.
    final calls = frames.length <= 1
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s3, AppSpace.s2, AppSpace.s3, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(l.traceCalls(frames.length), key: const Key('trace-calls'), style: AppText.label(context)),
          ),
          SizedBox(
            height: 40,
            // Innermost first: the running call is always in view.
            child: ListView.separated(
              key: const Key('trace-frames'),
              scrollDirection: Axis.horizontal,
              itemCount: frames.length,
              separatorBuilder: (_, _) => Icon(Icons.chevron_left, size: 16, color: p.faint),
              itemBuilder: (context, i) {
                final index = frames.length - 1 - i;
                final selected = index == shownIndex;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: InkWell(
                    key: Key('trace-frame:$index'),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => session.selectFrame(index),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected ? p.subtle : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
                      ),
                      child: Text(
                        '${index + 1} · ${_frameLabel(l, step, frames[index])}',
                        maxLines: 1,
                        style: TextStyle(
                          color: p.fg,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          if (!running && frame != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpace.s2),
              child: Text(l.traceWaiting(frame.function), style: TextStyle(color: p.muted, fontSize: 12)),
            ),
                      ],
            ),
          );
    // Not a lazy list: every row is laid out, so the one that just changed
    // can bring itself into view. A frame has a handful of names and every
    // value is drawn within fixed limits.
    final values = SingleChildScrollView(
      key: const Key('trace-values'),
      padding: const EdgeInsets.fromLTRB(AppSpace.s3, AppSpace.s2, AppSpace.s3, AppSpace.s3),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(l.traceValues, style: AppText.label(context)),
        ),
        if (frame == null || frame.vars.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(l.traceNoValues, style: TextStyle(color: p.muted)),
          )
        else
          for (final name in frame.vars.keys)
            TraceVariableRow(
              recording: session.recording,
              step: step,
              frame: frame,
              name: name,
              running: running,
            ),
      ],
      ),
    );
    if (calls == null) return values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [calls, Expanded(child: values)],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.session, required this.drag, required this.onDrag});
  final TraceSession session;

  /// Where the slider is being dragged to, while it is.
  final double? drag;
  final ValueChanged<double?> onDrag;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final total = session.total;
    final shown = (drag?.round() ?? session.position) + 1;
    String count(int n) => formatCount(n, l.localeName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s2, 0, AppSpace.s2, AppSpace.s1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: const Key('trace-slider'),
                  value: (drag ?? session.position.toDouble()).clamp(0, (total - 1).toDouble()),
                  max: total > 1 ? (total - 1).toDouble() : 1,
                  onChanged: total > 1
                      ? (value) {
                          session.pause();
                          final index = value.round();
                          // Inside the window the program follows the thumb;
                          // outside, the window is recorded on release.
                          if (session.holds(index)) session.goTo(index);
                          onDrag(value);
                        }
                      : null,
                  onChangeEnd: (value) {
                    session.goTo(value.round());
                    onDrag(null);
                  },
                  semanticFormatterCallback: (value) => '${count(value.round() + 1)} / ${count(total)}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.s2),
                child: Text(
                  // The same in every language: no word, just where and how many.
                  '${count(shown)} / ${count(total)}',
                  key: const Key('trace-position'),
                  style: TextStyle(
                    color: p.fg,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                key: const Key('trace-first'),
                tooltip: l.traceFirst,
                onPressed: session.atStart ? null : () => (session..pause()).first(),
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                key: const Key('trace-prev'),
                tooltip: l.tracePrevious,
                onPressed: session.atStart ? null : () => (session..pause()).previous(),
                icon: const Icon(Icons.chevron_left, size: 30),
              ),
              IconButton.filled(
                key: const Key('trace-play'),
                tooltip: session.playing ? l.tracePause : l.tracePlay,
                onPressed: total > 1 ? session.togglePlay : null,
                // The app's icon-button theme paints icons in the text
                // colour; on the accent they need the accent's own.
                style: IconButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentFg),
                icon: Icon(session.playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                key: const Key('trace-next'),
                tooltip: l.traceNext,
                onPressed: session.atEnd ? null : () => (session..pause()).next(),
                icon: const Icon(Icons.chevron_right, size: 30),
              ),
              IconButton(
                key: const Key('trace-last'),
                tooltip: l.traceLast,
                onPressed: session.atEnd ? null : () => (session..pause()).last(),
                icon: const Icon(Icons.skip_next),
              ),
              Tooltip(
                message: l.traceSpeed,
                child: TextButton(
                  key: const Key('trace-speed'),
                  onPressed: session.cycleSpeed,
                  child: Text(
                    session.speedLabel,
                    style: TextStyle(color: p.fg, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
