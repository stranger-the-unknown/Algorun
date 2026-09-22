import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';
import 'hole_picker.dart';
import 'reporter_tile.dart';

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          controller.selectHole(hole);
          HolePicker.show(context, controller, hole);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
          child: CustomPaint(
            painter: _DashedHolePainter(
              color: selected ? AppColors.accent : AppColors.borderStrong,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                caption,
                style: const TextStyle(
                  color: AppColors.faint,
                  fontSize: 12,
                  letterSpacing: 0.3,
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
  _DashedHolePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    const dash = 4.0;
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
      oldDelegate.color != color;
}
