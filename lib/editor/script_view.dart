import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'hole_picker.dart';
import 'statement_tile.dart';

final class ScriptView extends StatelessWidget {
  const ScriptView({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final ids = controller.graph.entryIds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'The canvas is empty.\nTap add step to place an instruction.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ),
        for (final id in ids) ...[
          StatementTile(controller: controller, blockId: id),
          const SizedBox(height: 10),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              controller.selectHole(PortRef.mainBody);
              HolePicker.show(context, controller, PortRef.mainBody);
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: const SizedBox(
              height: 48,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
