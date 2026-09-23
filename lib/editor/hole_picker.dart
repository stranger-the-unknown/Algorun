import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'literal_sheet.dart';

/// The typed picker: only what `GraphTyping.compatiblePlacements` accepts for
/// the slot, within the puzzle's allowlist. It never type-checks on its own.
abstract final class HolePicker {
  /// Selects [hole], scrolls it above the sheet's reach, then opens the
  /// picker. What the player tapped stays in view while they choose.
  static Future<void> open(
    BuildContext context,
    EditorController controller,
    PortRef hole,
  ) async {
    controller.selectHole(hole);
    await _keepAboveSheet(context);
    if (!context.mounted) return;
    await show(context, controller, hole);
  }

  static Future<void> show(
    BuildContext context,
    EditorController controller,
    PortRef hole,
  ) {
    final placements = controller.placementsFor(hole);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      builder: (context) {
        return _PickerBody(
          controller: controller,
          hole: hole,
          placements: placements,
        );
      },
    );
  }

  /// The sheet covers up to the lower half of the screen: a slot below 40 %
  /// of the height is scrolled up to 20 % first.
  static Future<void> _keepAboveSheet(BuildContext context) async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final screen = MediaQuery.sizeOf(context).height;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom <= screen * 0.4) return;
    if (Scrollable.maybeOf(context) == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

/// Where a pick will go, in player words: `the condition of WHILE`.
String describeHole(BlockGraph graph, PortRef hole) {
  if (hole.blockId == BlockGraph.mainId) return 'the program';
  final block = graph.blocks[hole.blockId];
  if (block == null) return 'this slot';
  if (block.catalogId == BlockIds.ctrlElse) return 'ELSE';
  final label = BlockChrome.labelOf(block.catalogId);
  return switch (hole.port) {
    'then' => 'THEN of $label',
    'body' => 'DO of $label',
    'else' => 'ELSE of $label',
    final port => 'the ${BlockChrome.holeCaption(port)} of $label',
  };
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
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose a piece',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${describeHole(controller.graph, hole)}. Only pieces that fit this slot are listed.',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (placements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing in this puzzle fits here.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 12),
                  children: [
                    for (final entry in groups.entries) ...[
                      Text(BlockChrome.categoryLabel(entry.key), style: AppText.label),
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
    if (id == null) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
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
    final name = placement.literals['name'];
    final label = switch (placement.catalogId) {
      BlockIds.varGet => '$name',
      _ when name is String => '${chrome.label} $name',
      _ => chrome.label,
    };
    return Material(
      color: AppColors.subtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: EditorTheme.strip(chrome.category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
