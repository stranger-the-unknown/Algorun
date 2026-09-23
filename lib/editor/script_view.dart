import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'hole_picker.dart';
import 'statement_tile.dart';

/// The program: one vertical list of instructions, nested C-blocks inside.
///
/// [header] scrolls with the program (the brief, hints and givens on a
/// phone), so the program gets the screen once the player scrolls down.
/// Top-level instructions are built lazily; the scroll position survives
/// every edit.
final class ScriptView extends StatelessWidget {
  const ScriptView({super.key, required this.controller, this.header = const []});
  final EditorController controller;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final ids = controller.graph.entryIds;
    return CustomScrollView(
      key: const PageStorageKey('script'),
      slivers: [
        if (header.isNotEmpty) SliverList.list(children: header),
        if (ids.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            sliver: SliverToBoxAdapter(
              child: Builder(
                builder: (context) => _EmptyProgram(
                  active: controller.activeHole == PortRef.mainBody,
                  onTap: () => HolePicker.open(context, controller, PortRef.mainBody),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverList.builder(
              itemCount: ids.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StatementTile(
                  key: ValueKey(ids[i]),
                  controller: controller,
                  blockId: ids[i],
                ),
              ),
            ),
          ),
          SliverPadding(
            // Room past the end, so the last slots can scroll up above the
            // picker sheet.
            padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.sizeOf(context).height * 0.35),
            sliver: SliverToBoxAdapter(
              child: Builder(
                builder: (context) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: controller.activeHole == PortRef.mainBody
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                  ),
                  child: AddStepButton(
                    key: const ValueKey('add-step:main'),
                    onTap: () => HolePicker.open(context, controller, PortRef.mainBody),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// An empty program is one big "add step": the first thing to tap.
class _EmptyProgram extends StatelessWidget {
  const _EmptyProgram({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'add step',
      excludeSemantics: true,
      child: Material(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: active ? AppColors.accent : AppColors.holeOutline),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 20, color: AppColors.fg),
                    SizedBox(width: 8),
                    Text('add step', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Your program is empty. Tap to place the first instruction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
