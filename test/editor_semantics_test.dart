import 'dart:io';

import 'package:algorun/dev/stress_probe.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/editor_harness.dart';

/// E1: the editor's own buttons hide their children from a screen reader
/// (one node, one label). Such a node must offer the tap itself, or the
/// button can be read but not pressed. Found on the emulator's accessibility
/// dump, where "add step", the slots and the selection bar's actions were
/// labelled but not clickable.
final _stress = parsePuzzleJson(File('assets/puzzles/world_01/$stressProbeId.json').readAsStringSync());

void main() {
  testWidgets('add step, an empty slot, a name and the selection bar can be pressed by a screen reader',
      (tester) async {
    await openEditor(tester, _stress);
    final c = editorOf(tester);

    Future<void> press(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(finder);
      expect(node, isSemantics(isButton: true, hasTapAction: true), reason: '$finder');
      tester.semantics.tap(find.semantics.byPredicate((n) => n.id == node.id));
      await tester.pumpAndSettle();
    }

    // A name chip opens the name sheet.
    await press(find.bySemanticsLabel('Variable counts, change'));
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    // The selection bar: move the selected instruction down, then back up.
    final first = c.graph.entryIds.first;
    expect(c.selectedBlockId, first);
    await press(find.bySemanticsLabel('Move down'));
    expect(c.graph.entryIds[1], first);
    await press(find.bySemanticsLabel('Move up'));
    expect(c.graph.entryIds.first, first);
    final blocked = tester.getSemantics(find.bySemanticsLabel('Move up'));
    expect(blocked, isSemantics(isButton: true, hasEnabledState: true, isEnabled: false, hasTapAction: false),
        reason: 'the first instruction cannot go up, and says so');
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();

    // "add step" opens the picker for its list.
    c.scrollToEnd();
    await tester.pumpAndSettle();
    await press(find.byKey(const ValueKey('add-step:main')));
    expect(find.text('For the program. Only pieces that fit this slot are listed.'), findsOneWidget);
    expect(c.activeHole, PortRef.mainBody);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // An empty slot opens the picker for that slot.
    final loop = c.place(const Placement(catalogId: BlockIds.ctrlWhile), to: PortRef.mainBody)!;
    await tester.pumpAndSettle();
    await press(find.bySemanticsLabel('Empty condition slot'));
    expect(c.activeHole, PortRef(loop, 'condition'));
    expect(find.byType(BottomSheet), findsOneWidget);
  }, semanticsEnabled: true);

  testWidgets('PASTE and an outline line can be pressed by a screen reader', (tester) async {
    await openEditor(tester, _stress);
    final c = editorOf(tester);
    c.copyTree(c.graph.entryIds.first);
    c.scrollToEnd();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-step:main')));
    await tester.pumpAndSettle();
    final paste = tester.getSemantics(find.byKey(const Key('picker-paste')));
    expect(paste, isSemantics(label: 'PASTE SET counts · 2 blocks', isButton: true, hasTapAction: true));
    tester.semantics.tap(find.semantics.byPredicate((n) => n.id == paste.id));
    await tester.pumpAndSettle();
    expect(c.blockCount, 84);
    expect(find.byType(BottomSheet), findsNothing);

    c.clearSelection();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Program outline'));
    await tester.pumpAndSettle();
    final line = tester.getSemantics(find.byKey(const ValueKey('outline-line:3')));
    expect(line, isSemantics(label: 'Line 3: SET odds TO NEW LIST', isButton: true, hasTapAction: true));
    tester.semantics.tap(find.semantics.byPredicate((n) => n.id == line.id));
    await tester.pumpAndSettle();
    expect(c.selectedBlockId, c.graph.entryIds[2]);
  }, semanticsEnabled: true);
}
