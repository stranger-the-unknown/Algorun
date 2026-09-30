import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';

/// The names the puzzle provides: its GIVENS (inputs) and its VARIABLES
/// (the working names of `variables.pool`, declared from the start). With a
/// value slot selected, tapping a name plugs it in. There is nothing to
/// create: players never invent names.
final class GivensBar extends StatelessWidget {
  const GivensBar({super.key, required this.controller});
  final EditorController controller;

  void _place(String name) {
    final hole = controller.activeHole;
    if (hole == null) {
      controller.showFlash(EditorNotice((l) => l.tapSlotThenName));
      return;
    }
    final hit = controller.placementsFor(hole).where(
          (p) => p.catalogId == BlockIds.varGet && p.literals['name'] == name,
        );
    if (hit.isEmpty) {
      controller.showFlash(EditorNotice((l) => l.nameDoesNotFit));
      return;
    }
    if (controller.place(hit.first, to: hole) != null) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final givens = controller.givens;
    final pool = controller.poolVariables;
    if (givens.isEmpty && pool.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (givens.isNotEmpty) ...[
            Text(l.givens, style: AppText.label(context)),
            const SizedBox(height: 8),
            _Names(names: givens, onTap: _place),
          ],
          if (pool.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.variables, style: AppText.label(context)),
            const SizedBox(height: 8),
            _Names(names: pool, onTap: _place),
          ],
        ],
      ),
    );
  }
}

class _Names extends StatelessWidget {
  const _Names({required this.names, required this.onTap});
  final List<IoBinding> names;
  final void Function(String name) onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in names)
          Tooltip(
            message: typeText(n.type, l),
            child: ActionChip(
              label: Text(n.name),
              onPressed: () => onTap(n.name),
            ),
          ),
      ],
    );
  }
}
