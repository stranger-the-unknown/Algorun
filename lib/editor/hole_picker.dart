import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'literal_sheet.dart';

abstract final class HolePicker {
  static Future<void> show(
    BuildContext context,
    EditorController controller,
    PortRef hole,
  ) {
    final placements = controller.placementsFor(hole);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return _PickerBody(
          controller: controller,
          hole: hole,
          placements: placements,
        );
      },
    );
  }
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({
    required this.controller,
    required this.hole,
    required this.placements,
  });

  final EditorController controller;
  final PortRef hole;
  final List<Placement> placements;

  @override
  Widget build(BuildContext context) {
    final groups = <BlockCategory, List<Placement>>{};
    for (final p in placements) {
      if (BlockChrome.hiddenFromEditor(p.catalogId)) continue;
      final cat = BlockChrome.of(p.catalogId).category;
      groups.putIfAbsent(cat, () => []).add(p);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a piece',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only pieces that fit this slot are listed.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (placements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing in this puzzle fits here.',
                  style: TextStyle(color: AppColors.faint),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in groups.entries) ...[
                      Text(
                        BlockChrome.categoryLabel(entry.key),
                        style: const TextStyle(
                          color: AppColors.faint,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in entry.value)
                            _PlacementChip(
                              placement: p,
                              onTap: () => _pick(context, p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, Placement placement) async {
    Navigator.pop(context);
    final id = controller.place(placement, to: hole);
    if (id == null) return;
    if (placement.catalogId == BlockIds.litNum) {
      if (context.mounted) {
        await LiteralSheet.showNumber(context, controller, id);
      }
    } else if (placement.catalogId == BlockIds.varSet ||
        placement.catalogId == BlockIds.varInc ||
        placement.catalogId == BlockIds.varDec) {
      if (placement.literals['name'] == null && context.mounted) {
        await LiteralSheet.showVariable(
          context,
          controller,
          blockId: id,
          key: 'name',
          names: controller.graph.variables.keys.toList(),
          allowCreate: true,
        );
      }
    }
  }
}

class _PlacementChip extends StatelessWidget {
  const _PlacementChip({required this.placement, required this.onTap});
  final Placement placement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = BlockChrome.of(placement.catalogId);
    final isGet = placement.catalogId == BlockIds.varGet;
    final label = isGet
        ? '${placement.literals['name']}'
        : chrome.label;
    return Material(
      color: AppColors.subtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: EditorTheme.strip(chrome.category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
