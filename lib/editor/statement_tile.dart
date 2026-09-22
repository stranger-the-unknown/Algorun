import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'hole_picker.dart';
import 'hole_widget.dart';
import 'literal_sheet.dart';

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
    return Material(
      color: AppColors.elevated,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          controller.selectBlock(block.id);
          _onHatTap(context);
        },
        onLongPress: () {
          controller.selectBlock(block.id);
          controller.apply(RemoveBlockCommand(block.id));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: strip,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: _hatBody(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onHatTap(BuildContext context) {
    if (block.catalogId == BlockIds.varSet ||
        block.catalogId == BlockIds.varInc ||
        block.catalogId == BlockIds.varDec) {
      LiteralSheet.showVariable(
        context,
        controller,
        blockId: block.id,
        key: 'name',
        names: controller.graph.variables.keys.toList(),
        allowCreate: true,
      );
    }
  }

  Widget _hatBody(BuildContext context) {
    final exprIns = def.inputs.where((p) => p.isExpr).toList();
    final label = Text(
      chrome.label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        fontSize: 12,
      ),
    );
    final name = block.literals['name'] as String?;
    final children = <Widget>[label];
    if (name != null &&
        (block.catalogId == BlockIds.varSet ||
            block.catalogId == BlockIds.varInc ||
            block.catalogId == BlockIds.varDec)) {
      children.add(_NameChip(name: name));
    }
    if (block.catalogId == BlockIds.varSet) {
      children.add(const Text(
        'TO',
        style: TextStyle(color: AppColors.faint, fontSize: 11, letterSpacing: 0.8),
      ));
    }
    for (final p in exprIns) {
      children.add(HoleWidget(
        controller: controller,
        parentId: block.id,
        port: p.name,
      ));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            onTap: () => controller.selectBlock(block.id),
            onLongPress: () {
              controller.selectBlock(block.id);
              controller.apply(RemoveBlockCommand(block.id));
            },
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: strip,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: _hat(context),
                  ),
                ),
                IconButton(
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () => controller.toggleCollapsed(block.id),
                  icon: Icon(
                    collapsed
                        ? Icons.unfold_more
                        : Icons.unfold_less,
                    color: AppColors.faint,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (!collapsed) ...[
            _Well(
              controller: controller,
              parentId: block.id,
              port: def.port('then') != null ? 'then' : 'body',
              label: def.port('then') != null ? 'THEN' : 'DO',
            ),
            if (block.catalogId == BlockIds.ctrlIf)
              hasElse
                  ? _Well(
                      controller: controller,
                      parentId: elseBlock!.id,
                      port: 'body',
                      label: 'ELSE',
                    )
                  : _AddElse(controller: controller, ifId: block.id),
          ],
        ],
      ),
    );
  }

  Widget _hat(BuildContext context) {
    final exprIns = def.inputs.where((p) => p.isExpr).toList();
    final name = block.literals['name'] as String?;
    final children = <Widget>[
      Text(
        chrome.label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
    ];
    if (block.catalogId == BlockIds.ctrlForRange ||
        block.catalogId == BlockIds.ctrlForEach) {
      children.add(GestureDetector(
        onTap: () => LiteralSheet.showVariable(
          context,
          controller,
          blockId: block.id,
          key: 'name',
          names: controller.graph.variables.keys.toList(),
          allowCreate: true,
        ),
        child: _NameChip(name: name ?? 'item'),
      ));
    }
    if (block.catalogId == BlockIds.ctrlForRange) {
      for (final p in exprIns) {
        children.add(Text(
          switch (p.name) {
            'start' => 'FROM',
            'end' => 'TO',
            'step' => 'BY',
            _ => p.name.toUpperCase(),
          },
          style: const TextStyle(
            color: AppColors.faint,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ));
        children.add(HoleWidget(
          controller: controller,
          parentId: block.id,
          port: p.name,
        ));
      }
    } else if (block.catalogId == BlockIds.ctrlForEach) {
      children.add(const Text(
        'IN',
        style: TextStyle(color: AppColors.faint, fontSize: 11, letterSpacing: 0.8),
      ));
      for (final p in exprIns) {
        children.add(HoleWidget(
          controller: controller,
          parentId: block.id,
          port: p.name,
        ));
      }
    } else {
      for (final p in exprIns) {
        children.add(HoleWidget(
          controller: controller,
          parentId: block.id,
          port: p.name,
        ));
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _Well extends StatelessWidget {
  const _Well({
    required this.controller,
    required this.parentId,
    required this.port,
    required this.label,
  });

  final EditorController controller;
  final String parentId;
  final String port;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ids = controller.graph.slotList(parentId, port);
    final hole = PortRef(parentId, port);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.faint,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final id in ids) ...[
                  StatementTile(controller: controller, blockId: id),
                  const SizedBox(height: 8),
                ],
                _AddStep(
                  onTap: () {
                    controller.selectHole(hole);
                    HolePicker.show(context, controller, hole);
                  },
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
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: OutlinedButton(
        onPressed: () {
          final hole = PortRef(ifId, 'else');
          controller.selectHole(hole);
          HolePicker.show(context, controller, hole);
        },
        child: const Text('ADD ELSE'),
      ),
    );
  }
}

class _AddStep extends StatelessWidget {
  const _AddStep({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: const SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: AppColors.faint),
              SizedBox(width: 6),
              Text(
                'add step',
                style: TextStyle(
                  color: AppColors.faint,
                  letterSpacing: 0.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
