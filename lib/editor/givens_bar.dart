import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';

final class GivensBar extends StatelessWidget {
  const GivensBar({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final givens = controller.givens;
    if (givens.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('GIVENS', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in givens)
                ActionChip(
                  label: Text(g.name),
                  onPressed: () {
                    final hole = controller.activeHole;
                    if (hole == null) {
                      controller.showFlash('Tap a value slot, then a given.');
                      return;
                    }
                    final hit = controller.placementsFor(hole).where(
                          (p) =>
                              p.catalogId == BlockIds.varGet &&
                              p.literals['name'] == g.name,
                        );
                    if (hit.isEmpty) {
                      controller.showFlash('This given does not fit that slot.');
                      return;
                    }
                    if (controller.place(hit.first, to: hole) != null) {
                      HapticFeedback.selectionClick();
                    }
                  },
                ),
              if (controller.unusedPool.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('CREATE VARIABLE'),
                  onPressed: () => _create(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final pool = controller.unusedPool;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in pool)
                  ActionChip(
                    label: Text(v.name),
                    onPressed: () {
                      controller.declareVariable(v.name, v.type);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
