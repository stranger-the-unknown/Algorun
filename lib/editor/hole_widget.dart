import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'hole_picker.dart';
import 'reporter_tile.dart';

/// A value slot. Empty, it is a dashed outline naming what it takes
/// (`condition`, `number`); tapping it opens the typed picker. Filled, it
/// shows the block plugged into it.
final class HoleWidget extends StatelessWidget {
  const HoleWidget({
    super.key,
    required this.controller,
    required this.parentId,
    required this.port,
  });

  final EditorController controller;
  final String parentId;
  final String port;

  @override
  Widget build(BuildContext context) {
    final graph = controller.graph;
    final filled = graph.slotList(parentId, port);
    final hole = PortRef(parentId, port);
    final selected = controller.activeHole == hole;
    final caption = BlockChrome.holeCaption(port);

    if (filled.isNotEmpty) {
      final childId = filled.first;
      final child = graph.blocks[childId];
      if (child != null) {
        return ReporterTile(controller: controller, blockId: childId);
      }
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Empty $caption slot',
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.subtle : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => HolePicker.open(context, controller, hole),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
            child: CustomPaint(
              painter: _DashedHolePainter(
                color: selected ? AppColors.accent : AppColors.holeOutline,
                width: selected ? 2 : 1.2,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        caption,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedHolePainter extends CustomPainter {
  _DashedHolePainter({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(20),
    );
    const dash = 5.0;
    const gap = 3.0;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedHolePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}
