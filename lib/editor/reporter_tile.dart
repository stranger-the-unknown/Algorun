import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'hole_widget.dart';
import 'literal_sheet.dart';

final class ReporterTile extends StatelessWidget {
  const ReporterTile({
    super.key,
    required this.controller,
    required this.blockId,
  });

  final EditorController controller;
  final String blockId;

  @override
  Widget build(BuildContext context) {
    final block = controller.graph.blocks[blockId];
    if (block == null) return const SizedBox.shrink();
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) return const SizedBox.shrink();
    final chrome = BlockChrome.of(block.catalogId);
    final selected = controller.selectedBlockId == blockId;
    final isBool = def.outputOfKind(PortKind.expression)?.type.atom ==
        TypeAtom.boolean;
    final radius = isBool ? AppRadius.sm : 20.0;

    return Material(
      color: EditorTheme.surface(BlockRole.expression),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () {
          controller.selectBlock(blockId);
          _maybeOpenLiteral(context, block);
        },
        onLongPress: () {
          controller.selectBlock(blockId);
          controller.apply(DisconnectCommand(blockId));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: _body(context, block, def, chrome),
        ),
      ),
    );
  }

  void _maybeOpenLiteral(BuildContext context, BlockInstance block) {
    if (block.catalogId == BlockIds.litNum) {
      LiteralSheet.showNumber(context, controller, block.id);
    } else if (block.catalogId == BlockIds.litBool) {
      LiteralSheet.showBool(context, controller, block.id);
    } else if (block.catalogId == BlockIds.varGet) {
      LiteralSheet.showVariable(
        context,
        controller,
        blockId: block.id,
        key: 'name',
        names: controller.graph.variables.keys.toList(),
      );
    }
  }

  Widget _body(
    BuildContext context,
    BlockInstance block,
    BlockDefinition def,
    BlockChrome chrome,
  ) {
    final exprIns = def.inputs.where((p) => p.isExpr).toList();
    if (block.catalogId == BlockIds.varGet) {
      final name = block.literals['name'] as String? ?? 'value';
      return Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
    }
    if (block.catalogId == BlockIds.litNum) {
      return Text(
        '${block.literals['value'] ?? 0}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }
    if (block.catalogId == BlockIds.litBool) {
      final v = block.literals['value'] == true;
      return Text(
        v ? 'TRUE' : 'FALSE',
        style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.6),
      );
    }
    if (block.catalogId == BlockIds.litNull) {
      return const Text('NOTHING', style: TextStyle(fontWeight: FontWeight.w600));
    }

    Widget hole(PortDefinition port) => HoleWidget(
          controller: controller,
          parentId: block.id,
          port: port.name,
        );

    final label = Text(
      chrome.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: EditorTheme.strip(chrome.category),
      ),
    );

    return switch (chrome.layout) {
      BlockLayout.infixBinary when exprIns.length >= 2 => Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [hole(exprIns[0]), label, hole(exprIns[1])],
        ),
      BlockLayout.prefix => Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [label, for (final p in exprIns) hole(p)],
        ),
      BlockLayout.verbObject when exprIns.isNotEmpty => Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            hole(exprIns.first),
            label,
            for (final p in exprIns.skip(1)) hole(p),
          ],
        ),
      _ => Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [label, for (final p in exprIns) hole(p)],
        ),
    };
  }
}
