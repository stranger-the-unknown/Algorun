import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../shared/theme/app_theme.dart';
import 'block_text.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';

/// One line of the program outline (E1): an instruction, numbered from the
/// top of the program, or the ELSE of an IF (which has no number of its own).
@immutable
final class OutlineLine {
  const OutlineLine({
    required this.number,
    required this.blockId,
    required this.depth,
    required this.text,
    required this.category,
  });

  /// 1 for the first instruction of the program; null for an ELSE row.
  final int? number;

  /// The block a tap goes to: the instruction itself, or the IF of an ELSE.
  final String blockId;

  /// How many blocks hold this line.
  final int depth;

  /// The instruction in words (`WHILE i LESS THAN (nums LENGTH)`).
  final String text;
  final BlockCategory category;
}

/// The whole program as numbered lines, top to bottom, bodies indented.
/// Folds do not matter here: the outline always shows every instruction.
List<OutlineLine> programOutline(BlockGraph graph) {
  final lines = <OutlineLine>[];
  var number = 0;
  void visit(String id, int depth) {
    final block = graph.blocks[id];
    final def = block == null ? null : BlockCatalog.of(block.catalogId);
    if (block == null || def == null) return;
    lines.add(OutlineLine(
      number: ++number,
      blockId: id,
      depth: depth,
      text: BlockText.line(graph, id),
      category: BlockChrome.of(block.catalogId).category,
    ));
    for (final port in def.inputs) {
      if (port.kind == PortKind.statement) {
        for (final child in graph.slotList(id, port.name)) {
          visit(child, depth + 1);
        }
      } else if (port.kind == PortKind.elseClause) {
        for (final clause in graph.slotList(id, port.name)) {
          final clauseBlock = graph.blocks[clause];
          final clauseDef = clauseBlock == null ? null : BlockCatalog.of(clauseBlock.catalogId);
          if (clauseBlock == null || clauseDef == null) continue;
          lines.add(OutlineLine(
            number: null,
            blockId: id,
            depth: depth,
            text: BlockChrome.labelOf(clauseBlock.catalogId),
            category: BlockChrome.of(clauseBlock.catalogId).category,
          ));
          for (final inner in clauseDef.inputs) {
            if (inner.kind != PortKind.statement) continue;
            for (final child in graph.slotList(clause, inner.name)) {
              visit(child, depth + 1);
            }
          }
        }
      }
    }
  }

  for (final id in graph.entryIds) {
    visit(id, 0);
  }
  return lines;
}

/// The outline as a sheet: START and END, then every instruction on one
/// line. A tap goes there: the block is selected and scrolled into view,
/// whatever was folded around it opens.
abstract final class ProgramOutline {
  static const double _row = 44;

  static Future<void> show(BuildContext context, EditorController controller) {
    final screen = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.elevated,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen * 0.75),
        child: _OutlineBody(controller: controller),
      ),
    );
  }
}

class _OutlineBody extends StatefulWidget {
  const _OutlineBody({required this.controller});
  final EditorController controller;

  @override
  State<_OutlineBody> createState() => _OutlineBodyState();
}

class _OutlineBodyState extends State<_OutlineBody> {
  late final List<OutlineLine> _lines = programOutline(widget.controller.graph);
  ScrollController? _scroll;

  double _rowHeight(BuildContext context) =>
      ProgramOutline._row * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, maxTextScale);

  /// The list opens on the selected block's line, a few rows down.
  ScrollController _controllerFor(BuildContext context) {
    final selected = widget.controller.selectedBlockId;
    final index = selected == null ? -1 : _lines.indexWhere((line) => line.number != null && line.blockId == selected);
    final offset = index <= 2 ? 0.0 : (index - 2) * _rowHeight(context);
    return _scroll ??= ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _go(void Function() action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = widget.controller;
    final entries = controller.graph.entryIds;
    final height = _rowHeight(context);
    final digits = '${_lines.where((line) => line.number != null).length}'.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.programOutline,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.palette.muted),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: l.goToStart,
                      child: OutlinedButton.icon(
                        key: const Key('outline-start'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: entries.isEmpty ? null : () => _go(() => controller.scrollTo(entries.first)),
                        icon: const Icon(Icons.vertical_align_top, size: 18),
                        label: Text(l.outlineStart),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: l.goToEnd,
                      child: OutlinedButton.icon(
                        key: const Key('outline-end'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: entries.isEmpty ? null : () => _go(controller.scrollToEnd),
                        icon: const Icon(Icons.vertical_align_bottom, size: 18),
                        label: Text(l.outlineEnd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 16),
                child: Text(l.outlineEmpty, style: TextStyle(color: context.palette.muted)),
              )
            else
              Flexible(
                child: ListView.builder(
                  controller: _controllerFor(context),
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 12),
                  itemExtent: height,
                  itemCount: _lines.length,
                  itemBuilder: (context, i) => _OutlineRow(
                    line: _lines[i],
                    digits: digits,
                    selected: _lines[i].number != null && _lines[i].blockId == controller.selectedBlockId,
                    onTap: () => _go(() => controller.jumpTo(_lines[i].blockId)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({required this.line, required this.digits, required this.selected, required this.onTap});

  final OutlineLine line;

  /// How wide the widest line number is, in digits.
  final int digits;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final number = line.number;
    // Deep nesting stops indenting: the text keeps most of a phone's width.
    final indent = (line.depth > 6 ? 6 : line.depth) * 12.0;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: number == null ? line.text : l.outlineLine(number, line.text),
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.subtle : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          key: number == null ? null : ValueKey('outline-line:$number'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  // Room for the widest number at the player's font size.
                  width: MediaQuery.textScalerOf(context).scale(12) * 0.75 * digits + 6,
                  child: Text(
                    number == null ? '' : '$number',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(width: 8 + indent),
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: EditorTheme.strip(context, line.category),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 13,
                      fontWeight: line.depth == 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
