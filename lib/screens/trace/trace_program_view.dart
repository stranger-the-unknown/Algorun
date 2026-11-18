import 'dart:math' as math;

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../editor/editor_theme.dart';
import '../../editor/statement_tile.dart' show BlockLabel, BlockWord;
import '../../l10n/l10n.dart';
import '../../shared/theme/app_theme.dart';

/// The player's program, read only, with the block of the step on show
/// marked (T1).
///
/// It draws the same shapes and words as the editor — instruction cards with
/// a category strip, C-blocks with THEN / DO / ELSE lists, value pills — from
/// the same `BlockChrome` and `BlockDefinition`, but none of the editor's
/// controls: nothing here can be tapped, added, moved or folded. A block this
/// file has never heard of (a later language addition) draws through the
/// general case: its label and its slots.
///
/// [currentId] is the block that just ran. An instruction gets an outline
/// and an arrow; a value block inside an instruction (where a failure
/// points) gets the outline and its instruction the arrow. The view keeps
/// that instruction on screen.
final class TraceProgramView extends StatefulWidget {
  const TraceProgramView({
    super.key,
    required this.graph,
    this.currentId,
    this.failed = false,
    this.badge,
  });

  final BlockGraph graph;
  final String? currentId;

  /// The step is the failure that stopped the run.
  final bool failed;

  /// A word to put on the marked instruction: what its condition came to.
  final String? badge;

  @override
  State<TraceProgramView> createState() => _TraceProgramViewState();
}

class _TraceProgramViewState extends State<TraceProgramView> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  late Map<String, String> _owner;
  String? _shown;

  @override
  void initState() {
    super.initState();
    _owner = _owners(widget.graph);
  }

  @override
  void didUpdateWidget(TraceProgramView old) {
    super.didUpdateWidget(old);
    if (!identical(old.graph, widget.graph)) {
      _owner = _owners(widget.graph);
      _keys.clear();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Every block → the instruction it is part of (an instruction is its own).
  static Map<String, String> _owners(BlockGraph graph) {
    final out = <String, String>{};
    void value(String id, String owner) {
      final block = graph.blocks[id];
      if (block == null || out.containsKey(id)) return;
      out[id] = owner;
      for (final slot in block.slots.keys) {
        for (final child in graph.slotList(id, slot)) {
          value(child, owner);
        }
      }
    }

    void statement(String id) {
      final block = graph.blocks[id];
      if (block == null || out.containsKey(id)) return;
      out[id] = id;
      final def = BlockCatalog.of(block.catalogId);
      for (final slot in block.slots.keys) {
        final isValue = def?.port(slot)?.isExpr ?? false;
        for (final child in graph.slotList(id, slot)) {
          isValue ? value(child, id) : statement(child);
        }
      }
    }

    graph.entryIds.forEach(statement);
    return out;
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'trace-block:$id'));

  /// Bring the marked instruction on screen, if it is not already.
  void _follow(String? statementId) {
    if (statementId == null || statementId == _shown) return;
    _shown = statementId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[statementId]?.currentContext;
      if (target == null) return;
      final box = target.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !_scroll.hasClients) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final position = _scroll.position;
      // The scroll offsets that put its top at the top of the view and its
      // bottom at the bottom: it is in view when the view sits between them.
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final bottom = viewport.getOffsetToReveal(box, 1).offset;
      if (top >= position.pixels && bottom <= position.pixels) return;
      // Move as little as it takes, and leave a line of what comes next (or
      // came before) in view. A block taller than the view shows its top.
      final margin = position.viewportDimension * 0.15;
      final double wanted;
      if (top < bottom) {
        wanted = top;
      } else if (top < position.pixels) {
        // Above the view: down to it, but never so far that its end leaves.
        wanted = math.max(top - margin, bottom);
      } else {
        // Below the view: up to it, but never so far that its start leaves.
        wanted = math.min(bottom + margin, top);
      }
      _scroll.jumpTo(wanted.clamp(position.minScrollExtent, position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    final current = widget.currentId;
    final statementId = current == null ? null : _owner[current];
    _follow(statementId);
    final mark = _Mark(
      blockId: current,
      statementId: statementId,
      failed: widget.failed,
      badge: widget.badge,
    );
    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        key: const Key('trace-program'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in graph.entryIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _Statement(graph: graph, blockId: id, mark: mark, keyFor: _keyFor),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to point out in the program.
final class _Mark {
  const _Mark({this.blockId, this.statementId, this.failed = false, this.badge});
  final String? blockId;
  final String? statementId;
  final bool failed;
  final String? badge;

  Color color(BuildContext context) => failed ? context.palette.danger : context.palette.accent;
}

class _Statement extends StatelessWidget {
  const _Statement({required this.graph, required this.blockId, required this.mark, required this.keyFor});

  final BlockGraph graph;
  final String blockId;
  final _Mark mark;
  final GlobalKey Function(String id) keyFor;

  @override
  Widget build(BuildContext context) {
    final block = graph.blocks[blockId];
    if (block == null) return const SizedBox.shrink();
    final def = BlockCatalog.of(block.catalogId);
    final chrome = BlockChrome.of(block.catalogId);
    final current = mark.statementId == blockId;
    final strip = EditorTheme.strip(context, chrome.category);
    final isC = chrome.layout == BlockLayout.cBlock;
    final markColor = mark.color(context);

    // The header carries the scroll key: a C-block's own line is what must be
    // in view, not the whole block with everything inside it.
    final header = IntrinsicHeight(
      key: keyFor(blockId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              color: strip,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.sm),
                bottomLeft: Radius.circular(isC ? 0 : AppRadius.sm),
              ),
            ),
          ),
          if (current)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                mark.failed ? Icons.error_outline : Icons.play_arrow,
                key: const Key('trace-current'),
                size: 18,
                color: markColor,
                semanticLabel: context.l10n.traceCurrentBlock,
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(current ? 4 : 10, 4, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._headerParts(context, block, def, chrome),
                    if (current && mark.badge != null)
                      Container(
                        key: const Key('trace-badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: markColor,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          mark.badge!,
                          style: TextStyle(
                            color: context.palette.accentFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget body = header;
    if (isC) {
      final bodyPort = def?.port('then') != null ? 'then' : 'body';
      final elseIds = graph.slotList(blockId, 'else');
      final elseBlock = elseIds.isEmpty ? null : graph.blocks[elseIds.first];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          _Well(graph: graph, label: bodyPort == 'then' ? 'THEN' : 'DO', ids: graph.slotList(blockId, bodyPort), rail: strip, mark: mark, keyFor: keyFor),
          if (elseBlock != null && elseBlock.catalogId == BlockIds.ctrlElse)
            _Well(graph: graph, label: 'ELSE', ids: graph.slotList(elseBlock.id, 'body'), rail: strip, mark: mark, keyFor: keyFor),
          const SizedBox(height: 4),
        ],
      );
    }

    return Semantics(
      container: true,
      selected: current,
      child: Container(
        key: ValueKey('trace-block:$blockId'),
        decoration: BoxDecoration(
          color: current ? context.palette.subtle : context.palette.elevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: current ? markColor : context.palette.border,
            width: current ? 2 : 1,
          ),
        ),
        child: body,
      ),
    );
  }

  List<Widget> _headerParts(BuildContext context, BlockInstance block, BlockDefinition? def, BlockChrome chrome) {
    final holes = [
      for (final p in def?.inputs ?? const <PortDefinition>[])
        if (p.isExpr) p,
    ];
    Widget? hole(PortDefinition port) {
      final filled = graph.slotList(block.id, port.name);
      if (filled.isEmpty) return null;
      return _Value(graph: graph, blockId: filled.first, mark: mark);
    }

    final name = block.literals['name'];
    final parts = <Widget>[BlockLabel(chrome.label)];
    final signature = FunctionSignature.of(block);
    if (signature != null) {
      parts.add(Text(signature.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      parts.add(BlockWord('(${signature.params.map((p) => p.name).join(', ')})'));
      return parts;
    }
    final named = block.catalogId == BlockIds.varSet ||
        block.catalogId == BlockIds.varInc ||
        block.catalogId == BlockIds.varDec ||
        block.catalogId == BlockIds.ctrlForRange ||
        block.catalogId == BlockIds.ctrlForEach;
    if (named && name is String) parts.add(_Name(name));
    if (block.catalogId == BlockIds.varSet) parts.add(const BlockWord('TO'));
    if (block.catalogId == BlockIds.ctrlForEach) parts.add(const BlockWord('IN'));
    for (final port in holes) {
      final value = hole(port);
      if (value == null) continue;
      if (block.catalogId == BlockIds.ctrlForRange) {
        parts.add(BlockWord(switch (port.name) {
          'start' => 'FROM',
          'end' => 'TO',
          'step' => 'BY',
          _ => port.name.toUpperCase(),
        }));
      }
      parts.add(value);
    }
    return parts;
  }
}

/// An instruction list inside a C-block.
class _Well extends StatelessWidget {
  const _Well({
    required this.graph,
    required this.label,
    required this.ids,
    required this.rail,
    required this.mark,
    required this.keyFor,
  });

  final BlockGraph graph;
  final String label;
  final List<String> ids;
  final Color rail;
  final _Mark mark;
  final GlobalKey Function(String id) keyFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Text(label, style: AppText.label(context)),
          ),
          Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: rail, width: 2))),
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('—', style: TextStyle(color: context.palette.faint)),
                  ),
                for (final id in ids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _Statement(graph: graph, blockId: id, mark: mark, keyFor: keyFor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A variable name on an instruction.
class _Name extends StatelessWidget {
  const _Name(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.palette.subtle,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border(bottom: BorderSide(color: context.palette.accent.withValues(alpha: 0.7), width: 2)),
      ),
      child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

/// A value block: a pill holding its own slots.
class _Value extends StatelessWidget {
  const _Value({required this.graph, required this.blockId, required this.mark});

  final BlockGraph graph;
  final String blockId;
  final _Mark mark;

  @override
  Widget build(BuildContext context) {
    final block = graph.blocks[blockId];
    if (block == null) return const SizedBox.shrink();
    final def = BlockCatalog.of(block.catalogId);
    final chrome = BlockChrome.of(block.catalogId);
    // Only a failure points at a value block; an instruction that ran marks
    // itself.
    final current = mark.blockId == blockId && mark.statementId != blockId;
    final isBool = def?.outputOfKind(PortKind.expression)?.type.atom == TypeAtom.boolean;
    final radius = isBool ? AppRadius.xs : 14.0;
    return Container(
      key: ValueKey('trace-block:$blockId'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EditorTheme.surface(context, BlockRole.expression),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: current ? mark.color(context) : context.palette.borderStrong,
          width: current ? 2 : 1,
        ),
      ),
      child: _body(context, block, def, chrome),
    );
  }

  Widget _body(BuildContext context, BlockInstance block, BlockDefinition? def, BlockChrome chrome) {
    const strong = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
    final id = block.catalogId;
    if (id == BlockIds.varGet) return Text('${block.literals['name'] ?? ''}', style: strong);
    if (id == BlockIds.litNum) {
      return Text(
        '${block.literals['value'] ?? 0}',
        style: strong.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }
    if (id == BlockIds.litBool) return Text(block.literals['value'] == true ? 'TRUE' : 'FALSE', style: strong);
    if (id == BlockIds.litNull) return const Text('NOTHING', style: strong);
    if (id == BlockIds.litStr) return Text('"${block.literals['value'] ?? ''}"', style: strong);

    final holes = <Widget>[
      for (final p in def?.inputs ?? const <PortDefinition>[])
        if (p.isExpr)
          for (final child in graph.slotList(block.id, p.name).take(1)) _Value(graph: graph, blockId: child, mark: mark),
    ];
    final called = BlockIds.isCall(id) ? block.literals['name'] : null;
    final label = Text(
      called is String ? '${chrome.label} $called' : chrome.label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.palette.muted),
    );
    final leadsWithValue = holes.isNotEmpty &&
        ((chrome.layout == BlockLayout.infixBinary && holes.length >= 2) || chrome.layout == BlockLayout.verbObject);
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: leadsWithValue ? [holes.first, label, ...holes.skip(1)] : [label, ...holes],
    );
  }
}
