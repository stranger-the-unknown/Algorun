import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Keeps a screen's content to a readable width on a wide window (a desktop
/// browser, a tablet), centred. Phones are narrower and see no change; the
/// child keeps the full height, so scrolling and pinned bars behave as before.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, this.maxWidth = readable, required this.child});

  /// Lists, settings, the guide, results.
  static const readable = 720.0;

  /// The puzzle editor: the side palette plus a program column.
  static const editor = 1200.0;

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
        return Padding(padding: EdgeInsets.symmetric(horizontal: side), child: child);
      },
    );
  }
}
