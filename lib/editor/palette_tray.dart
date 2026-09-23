import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'hole_picker.dart';

/// Every block the puzzle allows, by category. An instruction goes to the
/// selected list (or the end of the program); a value goes into the selected
/// slot. Rows grow with the system font size.
final class PaletteTray extends StatefulWidget {
  const PaletteTray({super.key, required this.controller, this.vertical = false});
  final EditorController controller;

  /// A side rail (wide screens): chips wrap downwards.
  final bool vertical;

  @override
  State<PaletteTray> createState() => _PaletteTrayState();
}

class _PaletteTrayState extends State<PaletteTray> {
  BlockCategory? _filter;

  void _add(String id) {
    if (EditorController.needsName(id)) {
      // INCREMENT / DECREMENT come one per variable: choose it in the picker.
      final well = widget.controller.activeWell;
      widget.controller.selectHole(well);
      HolePicker.show(context, widget.controller, well);
      return;
    }
    final before = widget.controller.blockCount;
    widget.controller.addFromPalette(id);
    if (widget.controller.blockCount > before) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.controller.paletteIds;
    final cats = <BlockCategory>{
      for (final id in ids) BlockChrome.of(id).category,
    };
    final shown = [
      for (final id in ids)
        if (_filter == null || BlockChrome.of(id).category == _filter) id,
    ];
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, maxTextScale);
    final filters = [
      _CatChip(
        label: 'ALL',
        selected: _filter == null,
        onTap: () => setState(() => _filter = null),
      ),
      for (final cat in BlockCategory.values)
        if (cats.contains(cat))
          _CatChip(
            label: BlockChrome.categoryLabel(cat),
            selected: _filter == cat,
            onTap: () => setState(() => _filter = cat),
          ),
    ];
    final chips = [
      for (final id in shown)
        _BlockChip(catalogId: id, onTap: () => _add(id), wraps: widget.vertical),
    ];
    if (widget.vertical) {
      return Material(
        color: AppColors.elevated,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('BLOCKS', style: AppText.label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: filters),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      );
    }
    return Material(
      color: AppColors.elevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48 * scale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Center(child: filters[i]),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48 * scale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => chips[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        color: selected ? AppColors.accentFg : AppColors.fg,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.6,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }
}

class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.catalogId, required this.onTap, this.wraps = false});
  final String catalogId;
  final VoidCallback onTap;

  /// In the side rail a long label wraps; in the phone row it scrolls.
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    final chrome = BlockChrome.of(catalogId);
    final label = Text(
      chrome.label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.4,
      ),
    );
    return Material(
      color: AppColors.subtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                color: EditorTheme.strip(chrome.category),
              ),
              const SizedBox(width: 8),
              if (wraps) Flexible(child: label) else label,
            ],
          ),
        ),
      ),
    );
  }
}
