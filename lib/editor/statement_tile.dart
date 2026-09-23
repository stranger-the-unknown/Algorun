import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'hole_picker.dart';
import 'hole_widget.dart';
import 'literal_sheet.dart';

/// One instruction. Tap or long-press selects it (the selection bar then
/// offers move, duplicate and delete); nothing is ever deleted by a gesture
/// alone. A C-block (IF, WHILE, FOR) folds to one line.
final class StatementTile extends StatelessWidget {
  const StatementTile({
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
    revealWhenBuilt(context, controller, blockId);
    if (chrome.layout == BlockLayout.cBlock) {
      return _CBlock(
        controller: controller,
        block: block,
        def: def,
        chrome: chrome,
      );
    }
    return _Hat(
      controller: controller,
      block: block,
      def: def,
      chrome: chrome,
    );
  }
}

/// Scrolls this tile into view the first time it is built after the
/// controller asked for it (a placement, a move, a copy).
void revealWhenBuilt(BuildContext context, EditorController controller, String blockId) {
  if (controller.revealId != blockId) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !controller.takeReveal(blockId)) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.3,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  });
}

void _select(EditorController controller, String id) {
  HapticFeedback.selectionClick();
  controller.selectBlock(id);
}

bool _named(String catalogId) =>
    catalogId == BlockIds.varSet ||
    catalogId == BlockIds.varInc ||
    catalogId == BlockIds.varDec;

class _Hat extends StatelessWidget {
  const _Hat({
    required this.controller,
    required this.block,
    required this.def,
    required this.chrome,
  });

  final EditorController controller;
  final BlockInstance block;
  final BlockDefinition def;
  final BlockChrome chrome;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedBlockId == block.id;
    final strip = EditorTheme.strip(chrome.category);
    return Semantics(
      container: true,
      selected: selected,
      child: Material(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _select(controller, block.id),
          onLongPress: () => _select(controller, block.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: strip,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _hatBody(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hatBody(BuildContext context) {
    final exprIns = def.inputs.where((p) => p.isExpr).toList();
    final name = block.literals['name'] as String?;
    final children = <Widget>[BlockLabel(chrome.label)];
    if (_named(block.catalogId)) {
      // INCREMENT / DECREMENT only take numbers; SET takes any variable.
      final numbersOnly = block.catalogId != BlockIds.varSet;
      children.add(NameChip(
        name: name ?? 'name',
        onTap: () {
          controller.selectBlock(block.id);
          LiteralSheet.showVariable(
            context,
            controller,
            blockId: block.id,
            key: 'name',
            names: [
              for (final e in controller.graph.variables.entries)
                if (!numbersOnly || e.value.atom == TypeAtom.number) e.key,
            ],
            allowCreate: !numbersOnly,
          );
        },
      ));
    }
    if (block.catalogId == BlockIds.varSet) {
      children.add(const BlockWord('TO'));
    }
    for (final p in exprIns) {
      children.add(HoleWidget(
        controller: controller,
        parentId: block.id,
        port: p.name,
      ));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _CBlock extends StatelessWidget {
  const _CBlock({
    required this.controller,
    required this.block,
    required this.def,
    required this.chrome,
  });

  final EditorController controller;
  final BlockInstance block;
  final BlockDefinition def;
  final BlockChrome chrome;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedBlockId == block.id;
    final collapsed = controller.isCollapsed(block.id);
    final strip = EditorTheme.strip(chrome.category);
    final elseIds = controller.graph.slotList(block.id, 'else');
    final elseBlock = elseIds.isEmpty
        ? null
        : controller.graph.blocks[elseIds.first];
    final hasElse = elseBlock?.catalogId == BlockIds.ctrlElse;
    final body = def.port('then') != null ? 'then' : 'body';

    return Semantics(
      container: true,
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
              onTap: () => _select(controller, block.id),
              onLongPress: () => _select(controller, block.id),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color: strip,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _hat(context),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: IconButton(
                        tooltip: collapsed ? 'Expand' : 'Collapse',
                        onPressed: () => controller.toggleCollapsed(block.id),
                        icon: Icon(
                          collapsed ? Icons.unfold_more : Icons.unfold_less,
                          color: AppColors.muted,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (collapsed)
              _FoldedSummary(
                count: controller.subtreeOf(block.id).length - 1,
                onOpen: () => controller.toggleCollapsed(block.id),
              )
            else ...[
              _Well(
                controller: controller,
                parentId: block.id,
                port: body,
                label: body == 'then' ? 'THEN' : 'DO',
                rail: strip,
              ),
              if (block.catalogId == BlockIds.ctrlIf)
                hasElse
                    ? _Well(
                        controller: controller,
                        parentId: elseBlock!.id,
                        port: 'body',
                        label: 'ELSE',
                        rail: strip,
                        onRemove: () => controller.deleteTree(elseBlock.id),
                      )
                    : _AddElse(controller: controller, ifId: block.id),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _hat(BuildContext context) {
    final exprIns = def.inputs.where((p) => p.isExpr).toList();
    final name = block.literals['name'] as String?;
    final children = <Widget>[BlockLabel(chrome.label)];
    if (block.catalogId == BlockIds.ctrlForRange ||
        block.catalogId == BlockIds.ctrlForEach) {
      children.add(NameChip(
        name: name ?? 'item',
        onTap: () {
          controller.selectBlock(block.id);
          LiteralSheet.showVariable(
            context,
            controller,
            blockId: block.id,
            key: 'name',
            names: controller.graph.variables.keys.toList(),
            allowCreate: true,
          );
        },
      ));
    }
    if (block.catalogId == BlockIds.ctrlForRange) {
      for (final p in exprIns) {
        children.add(BlockWord(switch (p.name) {
          'start' => 'FROM',
          'end' => 'TO',
          'step' => 'BY',
          _ => p.name.toUpperCase(),
        }));
        children.add(HoleWidget(
          controller: controller,
          parentId: block.id,
          port: p.name,
        ));
      }
    } else {
      if (block.catalogId == BlockIds.ctrlForEach) {
        children.add(const BlockWord('IN'));
      }
      for (final p in exprIns) {
        children.add(HoleWidget(
          controller: controller,
          parentId: block.id,
          port: p.name,
        ));
      }
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// A folded C-block says what it hides and opens with one tap.
class _FoldedSummary extends StatelessWidget {
  const _FoldedSummary({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = count == 0 ? 'Folded · empty' : 'Folded · ${blocksWord(count)} inside';
    return InkWell(
      onTap: onOpen,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An instruction list inside a C-block: a rail in the block's colour marks
/// what belongs to it, however deep the nesting.
class _Well extends StatelessWidget {
  const _Well({
    required this.controller,
    required this.parentId,
    required this.port,
    required this.label,
    required this.rail,
    this.onRemove,
  });

  final EditorController controller;
  final String parentId;
  final String port;
  final String label;
  final Color rail;

  /// Removes this list (ELSE only).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ids = controller.graph.slotList(parentId, port);
    final hole = PortRef(parentId, port);
    final active = controller.activeHole == hole;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 6, bottom: 4),
                child: Text(label, style: AppText.label),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove ELSE',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: active ? AppColors.accent : rail, width: 2),
              ),
            ),
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final id in ids) ...[
                  StatementTile(controller: controller, blockId: id),
                  const SizedBox(height: 6),
                ],
                AddStepButton(
                  key: ValueKey('add-step:$parentId.$port'),
                  compact: ids.isNotEmpty,
                  onTap: () => HolePicker.open(context, controller, hole),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddElse extends StatelessWidget {
  const _AddElse({required this.controller, required this.ifId});
  final EditorController controller;
  final String ifId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => HolePicker.open(context, controller, PortRef(ifId, 'else')),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('ADD ELSE'),
        ),
      ),
    );
  }
}

/// "add step": opens the picker for an instruction list.
final class AddStepButton extends StatelessWidget {
  const AddStepButton({super.key, required this.onTap, this.compact = false});
  final VoidCallback onTap;

  /// Under existing instructions: left-aligned and quieter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'add step',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, size: 18, color: AppColors.muted),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'add step',
                    style: TextStyle(
                      color: AppColors.muted,
                      letterSpacing: 0.6,
                      fontSize: 13,
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

/// A block's own name (`WHILE`, `SET`).
final class BlockLabel extends StatelessWidget {
  const BlockLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        fontSize: 13,
      ),
    );
  }
}

/// A joining word inside a block (`TO`, `IN`, `FROM`).
final class BlockWord extends StatelessWidget {
  const BlockWord(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.8),
    );
  }
}

/// A variable name on an instruction; tapping it chooses another. Squared
/// and marked with ▾ so it never reads as a value.
final class NameChip extends StatelessWidget {
  const NameChip({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Variable $name, change',
      excludeSemantics: true,
      child: Material(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.7), width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
