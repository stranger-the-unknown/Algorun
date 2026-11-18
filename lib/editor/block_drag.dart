import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';

/// Long press, then drag, to move an instruction (E1).
///
/// The layer sits over the program's scroll view. While a block is dragged
/// it shows a small tag under the finger and a line where the block would
/// land: the gap between two instructions nearest to the finger. The line is
/// in the accent colour where `EditorController.checkMove` accepts the drop
/// and in the danger colour, with the reason on the tag, where it does not.
/// Near the top or bottom edge the program scrolls by itself. Lifting the
/// finger makes one `EditorController.moveTo`: one undo step, or nothing.
///
/// Pointer moves never go through the controller: only the start and the end
/// of a drag notify it.
final class BlockDragLayer extends StatefulWidget {
  const BlockDragLayer({super.key, required this.controller, required this.child});

  final EditorController controller;
  final Widget child;

  /// The layer above [context], if the program is shown inside one.
  static BlockDragLayerState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DragScope>()?.layer;

  @override
  State<BlockDragLayer> createState() => BlockDragLayerState();
}

/// A place a dragged block can be dropped: before position [index] of the
/// list [to].
@immutable
final class DropTarget {
  const DropTarget(this.to, this.index);
  final PortRef to;
  final int index;

  @override
  bool operator ==(Object other) => other is DropTarget && other.to == to && other.index == index;

  @override
  int get hashCode => Object.hash(to, index);

  @override
  String toString() => 'DropTarget(${to.blockId}.${to.port} @ $index)';
}

class _Gap {
  _Gap(this.target, this.y, this.left, this.width);
  final DropTarget target;

  /// Global coordinates of the insertion line.
  final double y;
  final double left;
  final double width;
}

/// What the layer paints during a drag, in its own coordinates.
@immutable
class _DragView {
  const _DragView({
    required this.pointer,
    required this.label,
    required this.size,
    this.line,
    this.check,
  });

  final Offset pointer;
  final String label;
  final int size;

  /// The insertion line, when the finger is near a place other than the
  /// block's own.
  final Rect? line;
  final DropCheck? check;
}

final class BlockDragLayerState extends State<BlockDragLayer> with SingleTickerProviderStateMixin {
  /// A plain long press selects; the drag starts once the finger has moved
  /// this far.
  static const double startSlop = 8;

  /// The band at the top and bottom of the program where a drag scrolls it.
  static const double scrollBand = 72;

  /// Scroll speed at the very edge, in logical pixels per second.
  static const double scrollSpeed = 900;

  final Map<String, BuildContext> _tiles = {};
  final Map<PortRef, BuildContext> _listEnds = {};
  final ValueNotifier<_DragView?> _view = ValueNotifier(null);
  late final Ticker _ticker = createTicker(_tick);

  String? _pressedId;
  Offset? _pressedAt;
  Offset? _pointer;
  bool _dragging = false;
  DropTarget? _target;
  DropCheck? _check;
  ScrollPosition? _scroll;
  Duration _lastTick = Duration.zero;

  EditorController get _controller => widget.controller;

  /// The place the block would be dropped now, if any (tests).
  @visibleForTesting
  DropTarget? get target => _target;

  /// Whether the current [target] accepts the drop (tests).
  @visibleForTesting
  bool get targetAllowed => _check?.allowed ?? false;

  bool get isDragging => _dragging;

  // ---- the places ----------------------------------------------------------

  void registerTile(String blockId, BuildContext context) => _tiles[blockId] = context;

  void unregisterTile(String blockId, BuildContext context) {
    if (identical(_tiles[blockId], context)) _tiles.remove(blockId);
  }

  void registerListEnd(PortRef list, BuildContext context) => _listEnds[list] = context;

  void unregisterListEnd(PortRef list, BuildContext context) {
    if (identical(_listEnds[list], context)) _listEnds.remove(list);
  }

  static Rect? _rectOf(BuildContext context) {
    if (!context.mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Every gap between instructions that is on screen, except the ones
  /// inside the dragged block.
  List<_Gap> _gaps(String dragged, Rect viewport) {
    final graph = _controller.graph;
    final inside = _controller.subtreeOf(dragged).toSet();
    final gaps = <DropTarget, _Gap>{};
    void add(DropTarget target, double y, Rect rect) {
      if (y < viewport.top - 1 || y > viewport.bottom + 1) return;
      gaps[target] = _Gap(target, y, rect.left, rect.width);
    }

    // An empty list, or the end of a list: its "add step" row.
    _listEnds.forEach((list, context) {
      if (inside.contains(list.blockId)) return;
      final rect = _rectOf(context);
      if (rect == null) return;
      add(DropTarget(list, graph.slotList(list.blockId, list.port).length), rect.top + 2, rect);
    });
    _tiles.forEach((id, context) {
      if (inside.contains(id)) return;
      final at = graph.parentOf(id);
      final rect = _rectOf(context);
      if (at == null || rect == null) return;
      final list = PortRef(at.blockId, at.port);
      add(DropTarget(list, at.index), rect.top - 3, rect);
      // Below the last instruction of a list (this wins over the "add step"
      // row under it: the line is drawn right under the instruction).
      if (at.index == graph.slotList(at.blockId, at.port).length - 1) {
        add(DropTarget(list, at.index + 1), rect.bottom + 3, rect);
      }
    });
    return gaps.values.toList();
  }

  // ---- the gesture ---------------------------------------------------------

  /// A long press landed on [blockId]: it is selected; a drag may follow.
  void press(String blockId, Offset globalPosition) {
    _cancel();
    HapticFeedback.selectionClick();
    _controller.selectBlock(blockId);
    if (!_controller.canDrag(blockId)) return;
    _pressedId = blockId;
    _pressedAt = globalPosition;
    _pointer = globalPosition;
  }

  void move(Offset globalPosition) {
    final id = _pressedId;
    if (id == null) return;
    _pointer = globalPosition;
    if (!_dragging) {
      if ((globalPosition - _pressedAt!).distance < startSlop) return;
      if (!_controller.canDrag(id)) return _cancel();
      _dragging = true;
      final tile = _tiles[id];
      _scroll = tile != null && tile.mounted ? Scrollable.maybeOf(tile)?.position : null;
      _controller.beginDrag(id);
      _lastTick = Duration.zero;
      if (!_ticker.isActive) _ticker.start();
    }
    _retarget();
  }

  /// The finger lifted: move the block to the place shown, or say why not.
  void release() {
    final id = _pressedId;
    final target = _target;
    final check = _check;
    final dragged = _dragging;
    _reset();
    if (id == null || !dragged) return;
    _controller.endDrag();
    if (target == null || check == null || check.stays) return;
    if (check.allowed) {
      if (_controller.moveTo(id, target.to, target.index)) HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
      final reason = check.reason;
      if (reason != null) _controller.showFlash(reason);
    }
  }

  /// The gesture was taken away: nothing moves.
  void cancel() => _cancel();

  void _cancel() {
    final dragged = _dragging;
    _reset();
    if (dragged) _controller.endDrag();
  }

  void _reset() {
    if (_ticker.isActive) _ticker.stop();
    _pressedId = null;
    _pressedAt = null;
    _pointer = null;
    _dragging = false;
    _target = null;
    _check = null;
    _scroll = null;
    _view.value = null;
  }

  void _retarget() {
    final id = _pressedId;
    final pointer = _pointer;
    final box = context.findRenderObject();
    if (id == null || pointer == null || !_dragging || box is! RenderBox || !box.hasSize) return;
    final block = _controller.graph.blocks[id];
    if (block == null) return _cancel();
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    _Gap? nearest;
    for (final gap in _gaps(id, viewport)) {
      if (nearest == null || (gap.y - pointer.dy).abs() < (nearest.y - pointer.dy).abs()) nearest = gap;
    }
    final check = nearest == null ? null : _controller.checkMove(id, nearest.target.to, nearest.target.index);
    final shown = nearest != null && check != null && !check.stays;
    _target = shown ? nearest.target : null;
    _check = shown ? check : null;
    final info = _controller.selection;
    _view.value = _DragView(
      pointer: box.globalToLocal(pointer),
      label: info?.label ?? BlockChrome.labelOf(block.catalogId),
      size: info?.size ?? 1,
      line: shown
          ? Rect.fromLTWH(nearest.left - viewport.left, nearest.y - viewport.top - 2, nearest.width, 4)
          : null,
      check: _check,
    );
  }

  /// Scrolls the program while the finger rests near its top or bottom edge.
  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final scroll = _scroll;
    final pointer = _pointer;
    final box = context.findRenderObject();
    if (!_dragging || scroll == null || pointer == null || box is! RenderBox || !box.hasSize || dt <= 0) return;
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    final band = scrollBand < viewport.height / 3 ? scrollBand : viewport.height / 3;
    var pull = 0.0;
    if (pointer.dy < viewport.top + band) {
      pull = -((viewport.top + band - pointer.dy) / band).clamp(0.0, 1.0);
    } else if (pointer.dy > viewport.bottom - band) {
      pull = ((pointer.dy - (viewport.bottom - band)) / band).clamp(0.0, 1.0);
    }
    if (pull == 0) return;
    final next = (scroll.pixels + pull * scrollSpeed * dt).clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
    if (next == scroll.pixels) return;
    scroll.jumpTo(next);
    // The places moved under a resting finger: look again after the layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retarget();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DragScope(
      layer: this,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<_DragView?>(
                valueListenable: _view,
                builder: (context, view, _) => view == null ? const SizedBox.shrink() : _DragPaint(view: view),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragScope extends InheritedWidget {
  const _DragScope({required this.layer, required super.child});
  final BlockDragLayerState layer;

  @override
  bool updateShouldNotify(_DragScope oldWidget) => !identical(oldWidget.layer, layer);
}

/// The insertion line and the tag under the finger.
class _DragPaint extends StatelessWidget {
  const _DragPaint({required this.view});
  final _DragView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final refused = view.check != null && !view.check!.allowed;
    final colour = refused ? palette.danger : palette.accent;
    final line = view.line;
    final reason = refused ? view.check!.reason?.render(l) : null;
    final what = view.size > 1 ? l.selectionTitle(view.label, blocksText(view.size, l)) : view.label;
    return LayoutBuilder(
      builder: (context, constraints) {
        const tagWidth = 240.0;
        final left = (view.pointer.dx + 16).clamp(8.0, (constraints.maxWidth - tagWidth - 8).clamp(8.0, double.infinity));
        // Above the finger, so the hand does not cover it; below it at the
        // very top of the program.
        final above = view.pointer.dy > 96;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (line != null)
              Positioned(
                key: const Key('drop-line'),
                left: line.left,
                top: line.top,
                width: line.width,
                height: line.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            Positioned(
              left: left,
              top: above ? null : view.pointer.dy + 28,
              bottom: above ? constraints.maxHeight - view.pointer.dy + 20 : null,
              width: tagWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  key: const Key('drag-tag'),
                  color: palette.elevated,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: line == null ? palette.borderStrong : colour, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(refused ? Icons.block : Icons.open_with, size: 16, color: refused ? colour : palette.muted),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                what,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        if (reason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.fg, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tells the drag layer where an instruction, or the end of an instruction
/// list, is on screen. Without a layer above it does nothing.
final class DropAnchor extends StatefulWidget {
  /// The instruction [blockId].
  const DropAnchor.tile({super.key, required String this.blockId, required this.child}) : list = null;

  /// The end of the instruction list [list]: its "add step" row.
  const DropAnchor.listEnd({super.key, required PortRef this.list, required this.child}) : blockId = null;

  final String? blockId;
  final PortRef? list;
  final Widget child;

  @override
  State<DropAnchor> createState() => _DropAnchorState();
}

class _DropAnchorState extends State<DropAnchor> {
  BlockDragLayerState? _layer;

  void _register(DropAnchor of) {
    final layer = _layer;
    if (layer == null) return;
    if (of.blockId != null) layer.registerTile(of.blockId!, context);
    if (of.list != null) layer.registerListEnd(of.list!, context);
  }

  void _unregister(DropAnchor of) {
    final layer = _layer;
    if (layer == null) return;
    if (of.blockId != null) layer.unregisterTile(of.blockId!, context);
    if (of.list != null) layer.unregisterListEnd(of.list!, context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final layer = context.dependOnInheritedWidgetOfExactType<_DragScope>()?.layer;
    if (identical(layer, _layer)) return;
    _unregister(widget);
    _layer = layer;
    _register(widget);
  }

  @override
  void didUpdateWidget(DropAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockId != widget.blockId || oldWidget.list != widget.list) {
      _unregister(oldWidget);
      _register(widget);
    }
  }

  @override
  void dispose() {
    _unregister(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The long press of an instruction: it selects the block (as before E1)
/// and, when the finger then moves, drags it. A tap stays with [child].
final class BlockDragHandle extends StatefulWidget {
  const BlockDragHandle({super.key, required this.controller, required this.blockId, required this.child});

  final EditorController controller;
  final String blockId;
  final Widget child;

  @override
  State<BlockDragHandle> createState() => _BlockDragHandleState();
}

class _BlockDragHandleState extends State<BlockDragHandle> {
  BlockDragLayerState? _held;

  @override
  void dispose() {
    // The block left the screen (or the program) under the finger.
    _held?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        final layer = BlockDragLayer.maybeOf(context);
        if (layer == null) {
          HapticFeedback.selectionClick();
          widget.controller.selectBlock(widget.blockId);
          return;
        }
        _held = layer;
        layer.press(widget.blockId, details.globalPosition);
      },
      onLongPressMoveUpdate: (details) => _held?.move(details.globalPosition),
      onLongPressEnd: (_) {
        _held?.release();
        _held = null;
      },
      onLongPressCancel: () {
        _held?.cancel();
        _held = null;
      },
      child: widget.child,
    );
  }
}
