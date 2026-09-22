import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';

final class PaletteTray extends StatefulWidget {
  const PaletteTray({super.key, required this.controller});
  final EditorController controller;

  @override
  State<PaletteTray> createState() => _PaletteTrayState();
}

class _PaletteTrayState extends State<PaletteTray> {
  BlockCategory? _filter;

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
    return Material(
      color: AppColors.elevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final id in shown)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BlockChip(
                          catalogId: id,
                          onTap: () =>
                              widget.controller.addFromPalette(id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.catalogId, required this.onTap});
  final String catalogId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = BlockChrome.of(catalogId);
    return Material(
      color: AppColors.subtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                color: EditorTheme.strip(chrome.category),
              ),
              const SizedBox(width: 8),
              Text(
                chrome.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
