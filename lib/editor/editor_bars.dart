import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'hole_picker.dart';

/// Feedback from the last edit ("Removed WHILE and 6 blocks inside…"), or a
/// notice. Stays until dismissed or the next successful edit.
final class FlashBanner extends StatelessWidget {
  const FlashBanner({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final notice = controller.flash;
    if (notice == null) return const SizedBox.shrink();
    final l = context.l10n;
    final text = notice.render(l);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: context.palette.subtle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: context.palette.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(text, style: TextStyle(color: context.palette.fg, height: 1.35)),
                ),
              ),
              IconButton(
                tooltip: l.dismiss,
                onPressed: controller.dismissFlash,
                icon: Icon(Icons.close, size: 18, color: context.palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What can be done to the selected block. Instructions move, copy and
/// delete; a value can be replaced or taken out of its slot. Every action is
/// one undo step.
final class BlockActionsBar extends StatelessWidget {
  const BlockActionsBar({super.key, required this.controller, required this.info});
  final EditorController controller;
  final SelectionInfo info;

  void _replace(BuildContext context) {
    final at = controller.graph.parentOf(info.blockId);
    if (at == null) return;
    final hole = PortRef(at.blockId, at.port);
    if (!controller.deleteTree(info.blockId)) return;
    controller.dismissFlash();
    controller.selectHole(hole);
    HolePicker.show(context, controller, hole);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = info.size;
    final title = size > 1 ? l.selectionTitle(info.label, blocksText(size, l)) : info.label;
    final actions = <Widget>[
      if (info.isStatement) ...[
        _BarAction(
          icon: Icons.arrow_upward,
          label: l.actionUp,
          tooltip: l.moveUp,
          onPressed: info.moves.contains(MoveDirection.up) ? () => controller.moveSelected(MoveDirection.up) : null,
        ),
        _BarAction(
          icon: Icons.arrow_downward,
          label: l.actionDown,
          tooltip: l.moveDown,
          onPressed:
              info.moves.contains(MoveDirection.down) ? () => controller.moveSelected(MoveDirection.down) : null,
        ),
        _BarAction(
          icon: Icons.format_indent_decrease,
          label: l.actionOut,
          tooltip: l.moveOut,
          onPressed: info.moves.contains(MoveDirection.out) ? () => controller.moveSelected(MoveDirection.out) : null,
        ),
        _BarAction(
          icon: Icons.format_indent_increase,
          label: l.actionIn,
          tooltip: l.moveIn,
          onPressed:
              info.moves.contains(MoveDirection.into) ? () => controller.moveSelected(MoveDirection.into) : null,
        ),
        _BarAction(
          icon: Icons.content_copy,
          label: l.actionCopy,
          tooltip: l.duplicate,
          onPressed: info.canDuplicate ? controller.duplicateSelected : null,
        ),
      ] else
        _BarAction(
          icon: Icons.swap_horiz,
          label: l.actionReplace,
          tooltip: l.replaceValue,
          onPressed: () => _replace(context),
        ),
      _BarAction(
        icon: Icons.delete_outline,
        label: l.actionDelete,
        tooltip: size > 1 ? l.deleteWithInside(blocksText(size - 1, l)) : l.delete,
        onPressed: info.canDelete
            ? () {
                HapticFeedback.mediumImpact();
                controller.deleteSelected();
              }
            : null,
      ),
    ];
    return Material(
      color: context.palette.elevated,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.borderStrong))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l.selected, style: AppText.label(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: l.done,
                    onPressed: controller.clearSelection,
                    icon: Icon(Icons.close, color: context.palette.muted),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? context.palette.fg : context.palette.faint.withValues(alpha: 0.55);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: color, fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Undo, redo, the block count against the budget, whether the program is
/// saved, and RUN. Always at the bottom, above the system bar.
final class RunBar extends StatelessWidget {
  const RunBar({
    super.key,
    required this.controller,
    required this.onRun,
    required this.running,
    required this.saved,
  });

  final EditorController controller;
  final VoidCallback onRun;
  final bool running;

  /// Whether this puzzle keeps its program on the device (campaign puzzles).
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final count = controller.blockCount;
    final max = controller.puzzle.blocks.maxBlocks;
    final over = max != null && count > max;
    return Material(
      color: context.palette.bg,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: l.undo,
                  onPressed: controller.canUndo ? controller.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: l.redo,
                  onPressed: controller.canRedo ? controller.redo : null,
                  icon: const Icon(Icons.redo),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    label: max == null
                        ? blocksText(count, l)
                        : '${l.blockCountSemantics(count, max)}${over ? l.overBudgetSuffix : ''}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (over) ...[
                              Icon(Icons.warning_amber_rounded, size: 16, color: context.palette.warn),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                max == null ? blocksText(count, l) : l.blockCountWithMax(count, max),
                                key: const Key('block-count'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: over ? context.palette.warn : context.palette.fg,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          saved ? l.savedOnDevice : l.practiceNotSaved,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                  onPressed: running ? null : onRun,
                  icon: running
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.muted),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(running ? l.running : l.run),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
