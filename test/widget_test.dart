import 'package:algorun/app.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/puzzles/asset_repository.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Puzzle _editorPuzzle() => parsePuzzleJson(r'''
{
  "id": "ms3_editor_probe",
  "title": "Editor Probe",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "Editor probe.",
  "io": {
    "inputs": [
      { "name": "nums", "type": "array<num>" },
      { "name": "target", "type": "num" }
    ],
    "output": { "type": "bool" }
  },
  "blocks": {
    "allow": [
      "ctrl.if", "ctrl.else", "ctrl.while", "ctrl.return",
      "var.set", "var.get", "lit.num", "lit.bool",
      "cmp.eq", "cmp.lt", "cmp.gt", "logic.and",
      "arith.add", "arr.get", "arr.append"
    ],
    "maxBlocks": 40
  },
  "limits": { "maxOps": 10000 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1], "target": 1 }, "out": true }],
    "hidden": [{ "id": "h1", "in": { "nums": [0], "target": 1 }, "out": false }]
  },
  "variables": {
    "pool": [
      { "name": "i", "type": "num" },
      { "name": "found", "type": "bool" }
    ]
  }
}
''');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shows wordmark and enter', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AlgorunApp()));
    expect(find.text('ALGORUN'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
  });

  test('loads worlds and the probe puzzle from assets', () async {
    const repo = AssetPuzzleRepository();
    final worlds = await repo.loadWorlds();
    expect(worlds.worlds, isNotEmpty);
    expect(worlds.worlds.first.id, 'world_01');
    final puzzle = await repo.loadPuzzle('world_01', 'ms1_contract_probe');
    expect(puzzle.blocks.allow, isNotEmpty);
    expect(puzzle.hiddenTests, isNotEmpty);
    final editor = await repo.loadPuzzle('world_01', 'ms3_editor_probe');
    expect(editor.blocks.allow, contains('ctrl.if'));
    expect(editor.variablePool, isNotEmpty);
  });

  test('picker hides NUMBER from IF condition', () {
    final c = EditorController(puzzle: _editorPuzzle());
    final ifId = c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    )!;
    final labels = c
        .placementsFor(PortRef(ifId, 'condition'))
        .map((p) => BlockChrome.labelOf(p.catalogId))
        .toSet();
    expect(labels, contains('GREATER THAN'));
    expect(labels, contains('EQUAL'));
    expect(labels, isNot(contains('NUMBER')));
    expect(labels, isNot(contains('PLUS')));
  });

  test('picker hides BOOL producers from numeric operand', () {
    final c = EditorController(puzzle: _editorPuzzle());
    final ifId = c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    )!;
    final gt = c.place(
      const Placement(catalogId: BlockIds.cmpGt),
      to: PortRef(ifId, 'condition'),
    )!;
    final labels = c
        .placementsFor(PortRef(gt, 'left'))
        .map((p) => BlockChrome.labelOf(p.catalogId))
        .toSet();
    expect(labels, contains('NUMBER'));
    expect(labels, contains('GET ELEMENT'));
    expect(labels, isNot(contains('BOOLEAN')));
    expect(labels, isNot(contains('GREATER THAN')));
    expect(labels, isNot(contains('AND')));
  });

  test('variable picker is type-filtered', () {
    final c = EditorController(puzzle: _editorPuzzle());
    c.declareVariable('i', ValueType.number);
    c.declareVariable('found', ValueType.boolean);
    final ifId = c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    )!;
    final gt = c.place(
      const Placement(catalogId: BlockIds.cmpGt),
      to: PortRef(ifId, 'condition'),
    )!;
    final get = c.place(
      const Placement(catalogId: BlockIds.arrGet),
      to: PortRef(gt, 'left'),
    )!;
    final names = [
      for (final p in c.placementsFor(PortRef(get, 'index')))
        if (p.catalogId == BlockIds.varGet) p.literals['name'],
    ];
    expect(names, contains('i'));
    expect(names, contains('target'));
    expect(names, isNot(contains('found')));
    expect(names, isNot(contains('nums')));
  });

  test('ELSE placements only on the IF else port', () {
    final c = EditorController(puzzle: _editorPuzzle());
    final ifId = c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    )!;
    expect(
      c.placementsFor(PortRef(ifId, 'else')).map((p) => p.catalogId),
      contains(BlockIds.ctrlElse),
    );
    expect(
      c.placementsFor(PortRef(ifId, 'then')).map((p) => p.catalogId),
      isNot(contains(BlockIds.ctrlElse)),
    );
  });

  test('undo restores after a placement', () {
    final c = EditorController(puzzle: _editorPuzzle());
    c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    );
    expect(c.graph.entryIds, isNotEmpty);
    c.undo();
    expect(c.graph.entryIds, isEmpty);
    c.redo();
    expect(c.graph.entryIds, isNotEmpty);
  });

  testWidgets('seeded example renders semantic labels, not catalog ids',
      (tester) async {
    final c = EditorController(puzzle: _editorPuzzle(), seedExample: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: c,
          builder: (_, _) => Scaffold(body: ScriptView(controller: c)),
        ),
      ),
    );
    expect(find.text('IF'), findsWidgets);
    expect(find.text('GREATER THAN'), findsOneWidget);
    expect(find.text('GET ELEMENT'), findsOneWidget);
    expect(find.text('WHILE'), findsOneWidget);
    expect(find.text('ELSE'), findsOneWidget);
    expect(find.text('SET'), findsWidgets);
    expect(find.text('PLUS'), findsOneWidget);
    expect(find.text('cmp.gt'), findsNothing);
    expect(find.text('arr.get'), findsNothing);
    expect(find.text('var.get'), findsNothing);
    expect(find.text('ctrl.if'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('condition hole picker does not list NUMBER', (tester) async {
    final c = EditorController(puzzle: _editorPuzzle());
    c.place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: c,
          builder: (_, _) => Scaffold(body: ScriptView(controller: c)),
        ),
      ),
    );
    await tester.tap(find.text('condition'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('GREATER THAN'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('NUMBER'),
      ),
      findsNothing,
    );
  });

  test('RUN solves the shipped contract probe through the hardened schema',
      () async {
    const repo = AssetPuzzleRepository();
    final puzzle = await repo.loadPuzzle('world_01', 'ms1_contract_probe');
    final controller = EditorController(puzzle: puzzle);
    final ret = controller.place(
      const Placement(catalogId: BlockIds.ctrlReturn),
      to: PortRef.mainBody,
    )!;
    final len = controller.place(
      const Placement(catalogId: BlockIds.arrLen),
      to: PortRef(ret, 'value'),
    )!;
    controller.place(
      const Placement(catalogId: BlockIds.varGet, literals: {'name': 'nums'}),
      to: PortRef(len, 'array'),
    );
    final outcome = runPuzzle(const DefaultEngine(), controller.graph, puzzle);
    expect(outcome.suite.kind, ResultKind.correct, reason: outcome.suite.message);
    expect(outcome.suite.visible.single.input, {'nums': [1, 2, 3]});
    expect(outcome.suite.hiddenSummary!.passed, 1);
  });

  test('RUN grades the real fixtures instead of a placeholder', () {
    final suite = _solvedLengthRun().suite;
    expect(suite.kind, ResultKind.correct);
    expect(suite.message, 'Every case passed.');
    expect(suite.message, isNot(contains('not implemented')));
    expect(suite.visible.single.id, 'v1');
    expect(suite.visible.single.actual, 3);
    expect(suite.hiddenSummary!.passed, 1);
    expect(suite.metrics.blocks, 3);
  });

  test('RUN on an unfinished program says what to fix', () {
    final puzzle = _lengthPuzzle();
    // An empty canvas: nothing to lower, nothing to run.
    final controller = EditorController(puzzle: puzzle);
    final outcome = runPuzzle(const DefaultEngine(), controller.graph, puzzle);
    expect(outcome.suite.kind, ResultKind.invalidProgram);
    expect(outcome.validation.ok, isFalse);
    expect(outcome.suite.message, isNot(contains('not implemented')));
    expect(outcome.suite.message, isNot(contains('Milestone')));
    expect(outcome.suite.visible, isEmpty);
  });

  testWidgets('results show visible cases and only a hidden count',
      (tester) async {
    final outcome = _solvedLengthRun();
    final args = ResultsArgs(
      puzzle: _lengthPuzzle(),
      validation: outcome.validation,
      suite: outcome.suite,
    );
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/results',
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(name: '/results', arguments: args),
          builder: (_) => const ResultsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(find.textContaining('1 of 1 hidden cases passed'), findsOneWidget);
    // The hidden fixture's id and payload never reach the screen.
    expect(find.textContaining('h1'), findsNothing);
    expect(find.textContaining('[9]'), findsNothing);
  });

  testWidgets('a wrong visible case shows both sides, hidden stays a count',
      (tester) async {
    final puzzle = _lengthPuzzle();
    final controller = EditorController(puzzle: puzzle);
    final ret = controller.place(
      const Placement(catalogId: BlockIds.ctrlReturn),
      to: PortRef.mainBody,
    )!;
    controller.place(
      const Placement(catalogId: BlockIds.litNum, literals: {'value': 7}),
      to: PortRef(ret, 'value'),
    );
    final outcome = runPuzzle(const DefaultEngine(), controller.graph, puzzle);
    expect(outcome.suite.kind, ResultKind.wrongAnswer);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/results',
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(
            name: '/results',
            arguments: ResultsArgs(
              puzzle: puzzle,
              validation: outcome.validation,
              suite: outcome.suite,
            ),
          ),
          builder: (_) => const ResultsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WRONG ANSWER'), findsOneWidget);
    expect(find.textContaining('expected: 3'), findsOneWidget);
    expect(find.textContaining('you gave: 7'), findsOneWidget);
    expect(find.textContaining('h1'), findsNothing);
  });
}

/// `return LENGTH OF nums`, built through the editor and run the way the RUN
/// button runs it.
RunOutcome _solvedLengthRun() {
  final puzzle = _lengthPuzzle();
  final controller = EditorController(puzzle: puzzle);
  final ret = controller.place(
    const Placement(catalogId: BlockIds.ctrlReturn),
    to: PortRef.mainBody,
  )!;
  final len = controller.place(
    const Placement(catalogId: BlockIds.arrLen),
    to: PortRef(ret, 'value'),
  )!;
  controller.place(
    const Placement(catalogId: BlockIds.varGet, literals: {'name': 'nums'}),
    to: PortRef(len, 'array'),
  );
  return runPuzzle(const DefaultEngine(), controller.graph, puzzle);
}

Puzzle _lengthPuzzle() => parsePuzzleJson(r'''
{
  "id": "ms1_contract_probe",
  "title": "Contract Probe",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "Engine probe.",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "blocks": {
    "allow": ["var.set", "var.get", "ctrl.return", "arr.len", "lit.num"],
    "maxBlocks": 8
  },
  "limits": { "maxOps": 10000, "maxDepth": 32, "maxAlloc": 1000 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }
}
''');
