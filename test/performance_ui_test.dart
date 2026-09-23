import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/state/performance_text.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/results_finders.dart';

/// Count the ones in a list. The budget is 30 operations per case.
Puzzle _puzzle({String hiddenNums = '[5]', int hiddenOut = 1, String maxBlocks = ', "maxBlocks": 20'}) =>
    parsePuzzleJson('''
{
  "id": "perf_ui", "title": "Count", "world": "world_01", "tier": 1, "mode": "optimize",
  "story": "Count the items.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.return", "arr.len", "var.get", "var.set", "lit.num", "ctrl.for_range", "arith.add"]
    $maxBlocks
  },
  "limits": { "maxOps": 30, "maxAlloc": 50, "maxDepth": 8 },
  "variables": { "pool": [{ "name": "c", "type": "num" }, { "name": "i", "type": "num" }] },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] }, "out": 10 }],
    "hidden": [{ "id": "h1", "in": { "nums": $hiddenNums }, "out": $hiddenOut }]
  }
}
''');

Map<String, Object?> _block(String id, String catalogId,
        {Map<String, Object?> slots = const {}, Map<String, Object?> literals = const {}}) =>
    {'id': id, 'catalogId': catalogId, 'slots': slots, 'literals': literals};

/// `c = 0; for i in 0..LENGTH: c = c + 1; return c` — correct, 2 + 4 + 5n + 2
/// operations.
BlockGraph _counting() => BlockGraph.fromJson({
      'variables': {'nums': 'array<num>', 'c': 'num', 'i': 'num'},
      'entryIds': ['start', 'loop', 'ret'],
      'blocks': {
        'start': _block('start', 'var.set', slots: {'value': {'ref': 'zero'}}, literals: {'name': 'c'}),
        'zero': _block('zero', 'lit.num', literals: {'value': 0}),
        'loop': _block('loop', 'ctrl.for_range', literals: {
          'name': 'i',
        }, slots: {
          'start': {'ref': 'from'},
          'end': {'ref': 'len'},
          'body': {
            'list': ['step'],
          },
        }),
        'from': _block('from', 'lit.num', literals: {'value': 0}),
        'len': _block('len', 'arr.len', slots: {'array': {'ref': 'nums'}}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
        'step': _block('step', 'var.set', slots: {'value': {'ref': 'add'}}, literals: {'name': 'c'}),
        'add': _block('add', 'arith.add', slots: {'left': {'ref': 'c1'}, 'right': {'ref': 'one'}}),
        'c1': _block('c1', 'var.get', literals: {'name': 'c'}),
        'one': _block('one', 'lit.num', literals: {'value': 1}),
        'ret': _block('ret', 'ctrl.return', slots: {'value': {'ref': 'c2'}}),
        'c2': _block('c2', 'var.get', literals: {'name': 'c'}),
      },
    });

/// `return LENGTH OF nums` — correct in 3 operations.
BlockGraph _length() => BlockGraph.fromJson({
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': {'ref': 'len'}}),
        'len': _block('len', 'arr.len', slots: {'array': {'ref': 'nums'}}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
      },
    });

Future<void> _showResults(WidgetTester tester, Puzzle puzzle, RunOutcome outcome) async {
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/results',
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(
          name: '/results',
          arguments: ResultsArgs(puzzle: puzzle, validation: outcome.validation, suite: outcome.suite),
        ),
        builder: (_) => const ResultsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const engine = DefaultEngine();

  group('wording', () {
    test('counts get thousands separators', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1,000');
      expect(formatCount(28008), '28,008');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount(-5000), '-5,000');
    });

    test('the budget line lists what the puzzle allows', () {
      expect(budgetLine(_puzzle()), 'Budget: 30 steps · 50 cells · depth 8 · 20 blocks');
      expect(budgetLine(_puzzle(maxBlocks: '')), 'Budget: 30 steps · 50 cells · depth 8');
    });

    test('within budget: the plain verdict stands and the cost is exact', () {
      final suite = runPuzzle(engine, _length(), _puzzle(), hintsUsed: 1).suite;
      expect(suite.kind, ResultKind.correct);
      expect(performanceMessage(suite), isNull);
      expect(costLine(suite), '3 steps · 0 cells · depth 1 · 3 blocks · 1 hint');
    });

    test('correct but too many operations is said plainly, with the numbers', () {
      final suite = runPuzzle(engine, _counting(), _puzzle()).suite;
      expect(suite.kind, ResultKind.operationLimit);
      expect(
        performanceMessage(suite),
        'The result is correct, but this solution uses too many operations: '
        '58 against a budget of 30.',
      );
      expect(costLine(suite), startsWith('58 steps · '));
    });

    test('far over budget: right where it finished, still running at the ceiling', () {
      final big = '[${List.filled(200, 1).join(', ')}]';
      final suite = runPuzzle(engine, _counting(), _puzzle(hiddenNums: big, hiddenOut: 200)).suite;
      expect(
        performanceMessage(suite),
        'Every case that finished came out right, but this solution uses too many '
        'operations: it was still running after 150, and the budget is 30.',
      );
      expect(costLine(suite), startsWith('150+ steps · '));
    });

    test('slow and wrong is not called correct', () {
      // The hidden answer is deliberately wrong for a counting program.
      final suite = runPuzzle(engine, _counting(), _puzzle(hiddenNums: '[1, 1, 1, 1, 1, 1, 1]', hiddenOut: 99)).suite;
      expect(performanceMessage(suite), contains('not every answer is right either'));
      expect(performanceMessage(suite), isNot(contains('The result is correct')));
    });

    test('no sentence ever claims a complexity class', () {
      for (final suite in [
        runPuzzle(engine, _counting(), _puzzle()).suite,
        runPuzzle(engine, _counting(), _puzzle(hiddenNums: '[${List.filled(200, 1).join(', ')}]', hiddenOut: 200)).suite,
      ]) {
        final text = performanceMessage(suite)!;
        for (final word in ['O(', 'Big-O', 'linear', 'quadratic', 'complexity']) {
          expect(text, isNot(contains(word)));
        }
      }
    });
  });

  testWidgets('the results screen shows a correct but slow run with its budget', (tester) async {
    final puzzle = _puzzle();
    final outcome = runPuzzle(engine, _counting(), puzzle, hintsUsed: 2);
    await _showResults(tester, puzzle, outcome);

    expect(find.text('OPERATION LIMIT'), findsOneWidget);
    expect(
      find.text('The result is correct, but this solution uses too many operations: 58 against a budget of 30.'),
      findsOneWidget,
    );
    // WHAT IT COST: what the run used against each budget.
    expect(costRow(tester, 'steps'), ['Steps', '58', '30']);
    expect(find.descendant(of: find.byKey(const Key('cost-steps')), matching: find.byIcon(Icons.warning_amber_rounded)),
        findsOneWidget, reason: 'over budget is said with an icon, not colour alone');
    expect(costRow(tester, 'memory'), ['Memory cells', '0', '50']);
    expect(costRow(tester, 'depth'), ['Depth', '1', '8']);
    expect(costRow(tester, 'blocks').last, '20');
    expect(costRow(tester, 'hints'), ['Hints', '2 hints', '—']);
    expect(find.textContaining('h1'), findsNothing);
  });

  testWidgets('an optimized solution passes and shows how far under budget it is', (tester) async {
    final puzzle = _puzzle();
    final outcome = runPuzzle(engine, _length(), puzzle);
    await _showResults(tester, puzzle, outcome);

    expect(find.text('CORRECT'), findsOneWidget);
    expect(costRow(tester, 'steps'), ['Steps', '3', '30']);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(costRow(tester, 'memory'), ['Memory cells', '0', '50']);
  });
}
