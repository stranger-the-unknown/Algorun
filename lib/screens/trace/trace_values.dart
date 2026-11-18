import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_theme.dart';

/// How the step-through screen shows values (T1): a name's value at one
/// step, laid out by what it is — a row of numbered cells for a list, a chain
/// for linked nodes, an outline for a tree — with whatever the step just
/// changed pointed out in colour **and** in words.
///
/// Everything is bounded: a long list shows its first cells and says how many
/// more there are, so a big value can never make the screen slow or tall
/// without end. A kind of value this file does not know is shown as text.

/// Cells of one list, entries of one map, nodes of one chain or tree.
const _maxShown = 48;

/// [value] on one line, short: for a sentence, or a value inside a value.
String traceValueText(
  TraceRecording recording,
  TraceValue value,
  int step,
  AppLocalizations l, {
  int maxItems = 6,
  int depth = 2,
}) {
  String joined(List<TraceValue> values) => [
    for (final v in values.take(maxItems))
      traceValueText(recording, v, step, l, maxItems: 3, depth: depth - 1),
    if (values.length > maxItems) '…',
  ].join(', ');

  switch (value) {
    case TraceNothing():
      return 'NOTHING';
    case TraceNumber(:final value):
      return '$value';
    case TraceBool(:final value):
      return value ? 'TRUE' : 'FALSE';
    case TraceText(:final value):
      return '"$value"';
    case TraceUnknown(:final text):
      return text.length > 60 ? '${text.substring(0, 60)}…' : text;
    case TraceRef(:final id):
      final object = recording.objectAt(id, step);
      if (object == null || depth <= 0) return '…';
      switch (object) {
        case TraceSequence(:final shape, :final items):
          return shape == TraceShape.set
              ? '{${joined(items)}}'
              : '[${joined(items)}]';
        case TraceMap(:final entries):
          final shown = [
            for (final e in entries.take(maxItems))
              '${traceValueText(recording, e.key, step, l, depth: 1)}: '
                  '${traceValueText(recording, e.value, step, l, maxItems: 3, depth: depth - 1)}',
            if (entries.length > maxItems) '…',
          ];
          return '{${shown.join(', ')}}';
        case TraceListNode():
          final chain = traceChain(recording, id, step, max: maxItems);
          return [
            for (final node in chain.nodes) '${node.value}',
            if (chain.loopsBack) '↻' else if (chain.more) '…',
          ].join(' → ');
        case TraceTreeNode(:final value, :final left, :final right):
          if (left is TraceNothing && right is TraceNothing) return '($value)';
          return '($value: ${joined([left, right])})';
        case TraceGraph(:final adjacency):
          return '${l.captionGraph} (${adjacency.length})';
      }
  }
}

/// One linked node in a chain, with the id it is known by.
typedef ChainNode = ({int id, num value});

/// The nodes from [headId] on, up to [max]; [loopsBack] when the chain comes
/// back to a node already listed, [more] when it was cut at [max].
({List<ChainNode> nodes, bool loopsBack, bool more}) traceChain(
  TraceRecording recording,
  int headId,
  int step, {
  int max = _maxShown,
}) {
  final nodes = <ChainNode>[];
  final seen = <int>{};
  int? id = headId;
  while (id != null) {
    if (!seen.add(id)) return (nodes: nodes, loopsBack: true, more: false);
    final node = recording.objectAt(id, step);
    if (node is! TraceListNode) break;
    if (nodes.length >= max) {
      return (nodes: nodes, loopsBack: false, more: true);
    }
    nodes.add((id: id, value: node.value));
    final next = node.next;
    id = next is TraceRef ? next.id : null;
  }
  return (nodes: nodes, loopsBack: false, more: false);
}

/// Whether anything [value] reaches changed at [step] (bounded walk).
bool traceContentChanged(
  TraceRecording recording,
  TraceStep step,
  TraceValue value,
) {
  if (value is! TraceRef || step.changedObjects.isEmpty) return false;
  final seen = <int>{};
  final queue = <int>[value.id];
  while (queue.isNotEmpty && seen.length < 400) {
    final id = queue.removeLast();
    if (!seen.add(id)) continue;
    if (step.changedObjects.contains(id)) return true;
    void follow(TraceValue v) {
      if (v is TraceRef) queue.add(v.id);
    }

    switch (recording.objectAt(id, step.index)) {
      case TraceSequence(:final items):
        items.take(_maxShown).forEach(follow);
      case TraceMap(:final entries):
        for (final e in entries.take(_maxShown)) {
          follow(e.value);
        }
      case TraceListNode(:final next):
        follow(next);
      case TraceTreeNode(:final left, :final right):
        follow(left);
        follow(right);
      case TraceGraph() || null:
        break;
    }
  }
  return false;
}

/// One name of a frame: `total = 9`, or the name over its list.
final class TraceVariableRow extends StatelessWidget {
  const TraceVariableRow({
    super.key,
    required this.recording,
    required this.step,
    required this.frame,
    required this.name,
    this.running = true,
  });

  final TraceRecording recording;
  final TraceStep step;
  final TraceFrameSnapshot frame;
  final String name;

  /// [frame] is the running frame: only its names can have just changed.
  final bool running;

  /// `new` when the name had no value one step earlier, `changed` when it
  /// had another; null when this step did not touch it.
  String? _tag(AppLocalizations l, TraceValue value) {
    if (!running) {
      return traceContentChanged(recording, step, value)
          ? l.traceChanged
          : null;
    }
    if (step.changed.contains(name)) {
      final before = recording.stepAt(step.index - 1);
      final depth = step.frames.length - 1;
      final same =
          before != null &&
              before.frames.length > depth &&
              before.frames[depth].serial == frame.serial
          ? before.frames[depth]
          : null;
      // No earlier look at this frame: it was just entered (or the window
      // starts here, and "changed" is the safe word).
      if (same == null) {
        return before == null && step.index > 0 ? l.traceChanged : l.traceNew;
      }
      return same.vars.containsKey(name) ? l.traceChanged : l.traceNew;
    }
    return traceContentChanged(recording, step, value) ? l.traceChanged : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = frame.vars[name]!;
    final tag = _tag(l, value);
    final changed = tag != null;
    final p = context.palette;
    final labels = <int, List<String>>{};
    for (final entry in frame.vars.entries) {
      final v = entry.value;
      if (v is TraceRef) (labels[v.id] ??= []).add(entry.key);
    }
    final simple = value is! TraceRef;
    final nameText = Text(
      name,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.fg),
    );
    final tagChip = changed
        ? Container(
            key: Key('trace-changed:$name'),
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: p.warn,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: p.bg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          )
        : null;
    final view = TraceValueView(
      recording: recording,
      step: step,
      value: value,
      labels: labels,
      emphasised: changed && simple,
    );
    // A bar down the left edge says "changed" before the word is read.
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            key: Key('trace-var:$name'),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: BoxDecoration(
              color: p.elevated,
              border: Border(
                left: BorderSide(
                  color: changed ? p.warn : p.borderStrong,
                  width: 3,
                ),
              ),
            ),
            child: simple
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      nameText,
                      Text('=', style: TextStyle(color: p.muted)),
                      view,
                      ?tagChip,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: nameText),
                          ?tagChip,
                        ],
                      ),
                      const SizedBox(height: 6),
                      view,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A value at one step, drawn by what it is.
final class TraceValueView extends StatelessWidget {
  const TraceValueView({
    super.key,
    required this.recording,
    required this.step,
    required this.value,
    this.labels = const {},
    this.emphasised = false,
  });

  final TraceRecording recording;
  final TraceStep step;
  final TraceValue value;

  /// The names that hold each node, to write under it in a chain or a tree.
  final Map<int, List<String>> labels;

  /// A plain value that this step just set.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final v = value;
    if (v is! TraceRef) {
      return Text(
        traceValueText(recording, v, step.index, l),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: p.fg,
          fontSize: 15,
          fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    final object = recording.objectAt(v.id, step.index);
    final before = recording.objectBefore(v.id, step.index);
    return switch (object) {
      null => Text('…', style: TextStyle(color: p.muted)),
      final TraceSequence o => _sequence(
        context,
        o,
        before is TraceSequence ? before : null,
      ),
      final TraceMap o => _map(context, o, before is TraceMap ? before : null),
      TraceListNode() => _chain(context, v.id),
      TraceTreeNode() => _tree(context, v.id),
      final TraceGraph o => _graph(
        context,
        o,
        before is TraceGraph ? before : null,
      ),
    };
  }

  String _text(TraceValue v, AppLocalizations l) =>
      traceValueText(recording, v, step.index, l, maxItems: 4);

  Widget _more(BuildContext context, int hidden) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      context.l10n.traceMore(hidden),
      style: TextStyle(color: context.palette.muted, fontSize: 12),
    ),
  );

  Widget _empty(BuildContext context) => Text(
    context.l10n.traceEmpty,
    style: TextStyle(color: context.palette.muted, fontStyle: FontStyle.italic),
  );

  Widget _sequence(
    BuildContext context,
    TraceSequence o,
    TraceSequence? before,
  ) {
    final l = context.l10n;
    if (o.items.isEmpty) return _empty(context);
    final changed = before == null
        ? const <int>{}
        : changedPositions(before, o);
    final indexed = o.shape == TraceShape.array;
    // Which end to name: a stack's top is its last item, a queue's front and
    // a heap's top its first.
    final endLabel = switch (o.shape) {
      TraceShape.stack => (o.items.length - 1, l.traceTop),
      TraceShape.queue || TraceShape.deque => (0, l.traceFront),
      TraceShape.minHeap || TraceShape.maxHeap => (0, l.traceTop),
      _ => null,
    };
    // A long stack keeps its top in view: show the last cells, not the first.
    final fromEnd = o.shape == TraceShape.stack && o.items.length > _maxShown;
    final start = fromEnd ? o.items.length - _maxShown : 0;
    final end = fromEnd
        ? o.items.length
        : (o.items.length > _maxShown ? _maxShown : o.items.length);
    final hiddenChanged = changed.where((i) => i < start || i >= end).length;
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: [
        if (fromEnd) _more(context, start),
        for (var i = start; i < end; i++)
          _Cell(
            text: _text(o.items[i], l),
            above: indexed
                ? '$i'
                : (endLabel != null && endLabel.$1 == i ? endLabel.$2 : ''),
            changed: changed.contains(i),
            strong: endLabel != null && endLabel.$1 == i,
          ),
        if (!fromEnd && o.items.length > end)
          _more(context, o.items.length - end),
        if (hiddenChanged > 0)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              l.traceChangedBeyond,
              style: TextStyle(color: context.palette.warn, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _map(BuildContext context, TraceMap o, TraceMap? before) {
    final l = context.l10n;
    if (o.entries.isEmpty) return _empty(context);
    final changed = before == null ? const <int>{} : changedEntries(before, o);
    final shown = o.entries.length > _maxShown ? _maxShown : o.entries.length;
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: [
        for (var i = 0; i < shown; i++)
          _Cell(
            text:
                '${_text(o.entries[i].key, l)} → ${_text(o.entries[i].value, l)}',
            changed: changed.contains(i),
          ),
        if (o.entries.length > shown) _more(context, o.entries.length - shown),
      ],
    );
  }

  Widget _chain(BuildContext context, int headId) {
    final l = context.l10n;
    final p = context.palette;
    final chain = traceChain(recording, headId, step.index);
    final arrow = Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Icon(Icons.arrow_right_alt, size: 16, color: p.muted),
    );
    return Wrap(
      spacing: 2,
      runSpacing: 6,
      children: [
        for (final node in chain.nodes) ...[
          _Cell(
            text: '${node.value}',
            above: '',
            below: labels[node.id]?.join(', '),
            changed: step.changedObjects.contains(node.id),
          ),
          arrow,
        ],
        Padding(
          padding: const EdgeInsets.only(top: 18, left: 2),
          child: Text(
            chain.loopsBack
                ? '↻ ${l.traceLoopsBack}'
                : (chain.more ? '…' : 'NOTHING'),
            style: TextStyle(
              color: chain.loopsBack ? p.warn : p.muted,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tree(BuildContext context, int rootId) {
    final p = context.palette;
    final rows = <Widget>[];
    final seen = <int>{};
    var cut = false;
    // Root first, then left before right, each child one step in.
    void walk(TraceValue ref, int depth, String side) {
      if (ref is! TraceRef) return;
      if (rows.length >= _maxShown) {
        cut = true;
        return;
      }
      final node = recording.objectAt(ref.id, step.index);
      if (node is! TraceTreeNode) return;
      final again = !seen.add(ref.id);
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 18.0, bottom: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (side.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    side,
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              _Cell(
                text: again ? '↻ ${node.value}' : '${node.value}',
                changed: step.changedObjects.contains(ref.id),
              ),
              if (labels[ref.id] case final names?)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      names.join(', '),
                      style: TextStyle(color: p.muted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      if (again) return;
      walk(node.left, depth + 1, 'LEFT');
      walk(node.right, depth + 1, 'RIGHT');
    }

    walk(TraceRef(rootId), 0, '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...rows,
        if (cut) Text('…', style: TextStyle(color: p.muted)),
      ],
    );
  }

  Widget _graph(BuildContext context, TraceGraph o, TraceGraph? before) {
    final l = context.l10n;
    final p = context.palette;
    if (o.adjacency.isEmpty) return _empty(context);
    final visited = o.visited.toSet();
    final was = before?.visited.toSet();
    final nodes = o.adjacency.keys.take(_maxShown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final node in nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                _Cell(
                  text: '$node',
                  changed:
                      was != null &&
                      visited.contains(node) &&
                      !was.contains(node),
                  icon: visited.contains(node) ? Icons.check : null,
                  iconLabel: l.traceVisited,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_right_alt, size: 16, color: p.muted),
                ),
                Expanded(
                  child: Text(
                    o.adjacency[node]!.isEmpty
                        ? '—'
                        : o.adjacency[node]!.join(', '),
                    style: TextStyle(
                      color: p.fg,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (o.adjacency.length > nodes.length)
          Text(
            l.traceMore(o.adjacency.length - nodes.length),
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
        if (visited.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.check, size: 14, color: p.ok),
                const SizedBox(width: 4),
                Text(
                  l.traceVisited,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One value in a box, with an optional small caption above (a position, or
/// which end this is) and below (the names that hold it).
class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    this.above,
    this.below,
    this.changed = false,
    this.strong = false,
    this.icon,
    this.iconLabel,
  });

  final String text;

  /// Null leaves no room for a caption; empty keeps the room so cells with
  /// and without one line up.
  final String? above;
  final String? below;
  final bool changed;
  final bool strong;
  final IconData? icon;
  final String? iconLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final caption = TextStyle(color: p.faint, fontSize: 11, height: 1.2);
    final box = Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: changed
            ? Color.alphaBlend(p.warn.withValues(alpha: 0.22), p.subtle)
            : p.subtle,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: changed ? p.warn : (strong ? p.accent : p.borderStrong),
          width: changed ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                icon,
                size: 13,
                color: p.ok,
                semanticLabel: iconLabel,
              ),
            ),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.fg,
                fontSize: 13,
                fontWeight: changed ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
    final cell = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: box,
    );
    if (above == null && below == null) {
      return Semantics(
        label: changed ? '$text, ${context.l10n.traceChanged}' : null,
        child: cell,
      );
    }
    return Semantics(
      label: changed ? '$text, ${context.l10n.traceChanged}' : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (above != null)
            // Room for one caption line at the player's font size.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(11) * 1.3,
              child: Text(above!, style: caption),
            ),
          cell,
          if (below != null && below!.isNotEmpty)
            Text(below!, style: caption.copyWith(color: p.muted)),
        ],
      ),
    );
  }
}
