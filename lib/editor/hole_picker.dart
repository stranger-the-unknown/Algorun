import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import '../screens/guide/guide_screen.dart';
import '../shared/theme/app_theme.dart';
import 'block_search.dart';
import 'block_search_field.dart';
import 'editor_controller.dart';
import 'editor_theme.dart';
import 'literal_sheet.dart';

/// The typed picker: only what `GraphTyping.compatiblePlacements` accepts for
/// the slot, within the puzzle's allowlist. It never type-checks on its own.
abstract final class HolePicker {
  /// Selects [hole], scrolls it above the sheet's reach, then opens the
  /// picker. What the player tapped stays in view while they choose.
  static Future<void> open(
    BuildContext context,
    EditorController controller,
    PortRef hole,
  ) async {
    controller.selectHole(hole);
    await _keepAboveSheet(context);
    if (!context.mounted) return;
    await show(context, controller, hole);
  }

  static Future<void> show(
    BuildContext context,
    EditorController controller,
    PortRef hole,
  ) {
    final placements = controller.placementsFor(hole);
    final screen = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.paddingOf(context).top;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.elevated,
      // The sheet sizes itself (E1): the same 9/16 of the screen as before,
      // but lifted above the keyboard while the player searches.
      isScrollControlled: true,
      builder: (context) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final room = screen - top - keyboard - 8;
        final height = screen * 9 / 16;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height < room ? height : room),
            child: _PickerBody(
              controller: controller,
              hole: hole,
              placements: placements,
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Closing the sheet, by the close button, back, or a drag, is a
      // cancel. A piece that was chosen already cleared this hole in place().
      if (controller.activeHole == hole) controller.selectHole(null);
    });
  }

  /// The sheet covers up to the lower half of the screen: a slot below 40 %
  /// of the height is scrolled up to 20 % first.
  static Future<void> _keepAboveSheet(BuildContext context) async {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final screen = MediaQuery.sizeOf(context).height;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom <= screen * 0.4) return;
    if (Scrollable.maybeOf(context) == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}

/// Where a pick will go, in player words: `the condition of WHILE`.
String describeHole(BlockGraph graph, PortRef hole, [AppLocalizations? strings]) {
  final l = strings ?? englishStrings;
  if (hole.blockId == BlockGraph.mainId) return l.targetProgram;
  final block = graph.blocks[hole.blockId];
  if (block == null) return l.targetSlot;
  if (block.catalogId == BlockIds.ctrlElse) return l.targetElse;
  final label = BlockChrome.labelOf(block.catalogId);
  return switch (hole.port) {
    'then' => l.targetThenOf(label),
    'body' => l.targetDoOf(label),
    'else' => l.targetElseOf(label),
    final port => l.targetCaptionOf(holeCaptionText(port, l), label),
  };
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({
    required this.controller,
    required this.hole,
    required this.placements,
  });

  final EditorController controller;
  final PortRef hole;
  final List<Placement> placements;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  /// The search box is only built once asked for (E1): no text field, and so
  /// no keyboard, unless the player wants one.
  bool _searching = false;
  String _query = '';

  /// Whether the clipboard fits this slot (E1), asked once: the engine
  /// rebuilds the copy here to decide, like PASTE itself.
  late final bool _canPaste = controller.canPaste(hole);

  EditorController get controller => widget.controller;
  PortRef get hole => widget.hole;
  List<Placement> get placements => widget.placements;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = <BlockCategory, List<Placement>>{};
    for (final p in placements) {
      if (BlockChrome.hiddenFromEditor(p.catalogId)) continue;
      if (!BlockSearch.matches(p.catalogId, _query, literals: p.literals)) continue;
      final cat = BlockChrome.of(p.catalogId).category;
      groups.putIfAbsent(cat, () => []).add(p);
    }
    final muted = TextStyle(color: context.palette.muted);
    final clip = _canPaste ? controller.clipboard : null;
    final showPaste = clip != null &&
        (BlockSearch.words(_query).isEmpty ||
            BlockSearch.words(_query).every(BlockSearch.fold('${l.pasteHere} ${clip.label}').contains));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l.chooseAPiece,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                if (placements.isNotEmpty && !_searching)
                  IconButton(
                    key: const Key('picker-search'),
                    tooltip: l.searchBlocks,
                    onPressed: () => setState(() => _searching = true),
                    icon: Icon(Icons.search, color: context.palette.muted),
                  ),
                IconButton(
                  tooltip: l.openGuide,
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.pushNamed(
                      '/guide',
                      arguments: GuideArgs(allow: controller.paletteIds, tab: GuideTab.blocks),
                    );
                  },
                  icon: Icon(Icons.menu_book_outlined, color: context.palette.muted),
                ),
                IconButton(
                  tooltip: l.close,
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.palette.muted),
                ),
              ],
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12, bottom: 12),
                child: BlockSearchField(
                  onChanged: (text) => setState(() => _query = text),
                  onClose: () => setState(() {
                    _searching = false;
                    _query = '';
                  }),
                ),
              ),
            // Everything under the title scrolls (E1): where the piece goes,
            // then the pieces. Only the title row and the search box keep
            // their height, so the sheet fits a short screen at any font size.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(right: 12),
                children: [
                  // While searching, the room goes to the results: the
                  // keyboard already takes half the screen.
                  if (!_searching) ...[
                    Text(
                      l.pickerFor(describeHole(controller.graph, hole, l)),
                      style: TextStyle(color: context.palette.muted, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showPaste) ...[
                    Text(l.clipboard, style: AppText.label(context)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PasteChip(clip: clip, onTap: () => _paste(context)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (placements.isEmpty && !_canPaste)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.nothingFits, style: muted),
                    )
                  else if (groups.isEmpty && !showPaste && placements.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.noBlockMatches(_query.trim()), style: muted),
                    ),
                  for (final entry in groups.entries) ...[
                    Text(categoryText(entry.key, l), style: AppText.label(context)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in entry.value)
                          _PlacementChip(
                            placement: p,
                            onTap: () => _pick(context, p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _paste(BuildContext context) {
    Navigator.pop(context);
    if (controller.paste(hole) == null) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pick(BuildContext context, Placement placement) async {
    Navigator.pop(context);
    final id = controller.place(placement, to: hole);
    if (id == null) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
    if (placement.catalogId == BlockIds.litNum) {
      if (context.mounted) {
        await LiteralSheet.showNumber(context, controller, id);
      }
    } else if (placement.catalogId == BlockIds.varSet ||
        placement.catalogId == BlockIds.varInc ||
        placement.catalogId == BlockIds.varDec) {
      if (placement.literals['name'] == null && context.mounted) {
        await LiteralSheet.showVariable(
          context,
          controller,
          blockId: id,
          key: 'name',
          names: controller.graph.variables.keys.toList(),
        );
      }
    }
  }
}

class _PlacementChip extends StatelessWidget {
  const _PlacementChip({required this.placement, required this.onTap});
  final Placement placement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = BlockChrome.of(placement.catalogId);
    final name = placement.literals['name'];
    final label = switch (placement.catalogId) {
      BlockIds.varGet => '$name',
      _ when name is String => '${chrome.label} $name',
      _ => chrome.label,
    };
    return Material(
      color: context.palette.subtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: context.palette.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: EditorTheme.strip(context, chrome.category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PASTE, first in the picker when the copied block fits this slot (E1).
class _PasteChip extends StatelessWidget {
  const _PasteChip({required this.clip, required this.onTap});
  final BlockClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final what = clip.size > 1 ? l.selectionTitle(clip.label, blocksText(clip.size, l)) : clip.label;
    return Semantics(
      container: true,
      button: true,
      label: '${l.pasteHere} $what',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: const Key('picker-paste'),
        color: context.palette.subtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.palette.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.content_paste, size: 18, color: context.palette.fg),
                const SizedBox(width: 8),
                Text(
                  l.pasteHere,
                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    what,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
