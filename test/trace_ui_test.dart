import 'package:algorun/app.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/screens/trace/trace_screen.dart';
import 'package:algorun/screens/trace/trace_values.dart';
import 'package:algorun/shared/content_width.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/trace_fixtures.dart';

/// T1: the step-through screen. Stepping forward and back, the marked block,
/// the value that just changed, calls and their frames, long runs, both
/// themes and both languages on a phone and on a wide window — and that a
/// hidden case can never be opened.

Future<void> _showResults(WidgetTester tester, Puzzle puzzle, BlockGraph graph, {bool withGraph = true}) async {
  final outcome = runPuzzle(const DefaultEngine(), graph, puzzle);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(AppPalette.light),
        initialRoute: '/results',
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings.name == '/results'
              ? RouteSettings(
                  name: '/results',
                  arguments: ResultsArgs(
                    puzzle: puzzle,
                    validation: outcome.validation,
                    suite: outcome.suite,
                    graph: withGraph ? graph : null,
                  ),
                )
              : settings,
          builder: (_) => settings.name == '/trace' ? const TraceScreen() : const ResultsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('stepping', () {
    testWidgets('opens at the start: the given values, nothing marked, nowhere to go back to', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      expect(find.text('STEP BY STEP'), findsOneWidget);
      expect(textOf(tester, 'trace-position'), '1 / 8');
      expect(textOf(tester, 'trace-sentence'), 'Start. These are the given values.');
      expect(textOf(tester, 'trace-case'), 'expected: 6  ·  you gave: 7');
      expect(currentBlock(tester), isNull);
      // The list is drawn as numbered cells.
      expect(variableTexts(tester, 'nums'), ['nums', '0', '4', '1', '2']);
      expect(tagOf(tester, 'nums'), isNull);
      expect(find.byKey(const Key('trace-var:total')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const Key('trace-prev'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('trace-first'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('trace-next'))).onPressed, isNotNull);
    });

    testWidgets('forward marks the block that ran and the value it changed; back undoes it', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());

      await tapKey(tester, 'trace-next');
      expect(textOf(tester, 'trace-position'), '2 / 8');
      expect(currentBlock(tester), 'start');
      expect(variableTexts(tester, 'total'), ['total', '=', '1', 'new']);
      expect(tagOf(tester, 'nums'), isNull);
      expect(textOf(tester, 'trace-cost'), 'Steps used so far: 2 of 400');

      await tapKey(tester, 'trace-next');
      expect(currentBlock(tester), 'loop');
      expect(textOf(tester, 'trace-sentence'), 'The loop starts a pass.');
      expect(tagOf(tester, 'i'), 'new');
      expect(tagOf(tester, 'total'), isNull, reason: 'total was not touched by this step');

      await tapKey(tester, 'trace-next');
      expect(currentBlock(tester), 'step');
      expect(variableTexts(tester, 'total'), ['total', '=', '5', 'changed']);
      expect(tagOf(tester, 'i'), isNull);

      // Back: exactly the step before, with its own marks.
      await tapKey(tester, 'trace-prev');
      expect(textOf(tester, 'trace-position'), '3 / 8');
      expect(currentBlock(tester), 'loop');
      expect(variableTexts(tester, 'total'), ['total', '=', '1']);
      expect(tagOf(tester, 'i'), 'new');

      await tapKey(tester, 'trace-prev', times: 2);
      expect(textOf(tester, 'trace-position'), '1 / 8');
      expect(currentBlock(tester), isNull);
      expect(find.byKey(const Key('trace-var:total')), findsNothing);
    });

    testWidgets('the end shows the answer next to what the puzzle expected; first and last jump', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      await tapKey(tester, 'trace-last');
      expect(textOf(tester, 'trace-position'), '8 / 8');
      expect(currentBlock(tester), 'ret');
      expect(textOf(tester, 'trace-sentence'), 'The program’s answer: 7');
      expect(textOf(tester, 'trace-case'), contains('expected: 6'));
      expect(tester.widget<IconButton>(find.byKey(const Key('trace-next'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('trace-last'))).onPressed, isNull);

      await tapKey(tester, 'trace-prev');
      expect(textOf(tester, 'trace-sentence'), 'Nothing left: the loop ends.');
      expect(currentBlock(tester), 'loop');

      await tapKey(tester, 'trace-first');
      expect(textOf(tester, 'trace-position'), '1 / 8');
    });

    testWidgets('play runs on by itself at the chosen speed and stops at the end', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      expect(textOf(tester, 'trace-position'), '1 / 8');
      expect(find.descendant(of: find.byKey(const Key('trace-speed')), matching: find.text('1×')), findsOneWidget);

      await tester.tap(find.byKey(const Key('trace-play')));
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);
      // 1× is two steps a second.
      await tester.pump(const Duration(milliseconds: 500));
      expect(textOf(tester, 'trace-position'), '2 / 8');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(textOf(tester, 'trace-position'), '4 / 8');

      // Pause holds the place.
      await tester.tap(find.byKey(const Key('trace-play')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(textOf(tester, 'trace-position'), '4 / 8');
      expect(find.byIcon(Icons.pause), findsNothing);

      // Faster, then on to the end, where it stops by itself.
      await tapKey(tester, 'trace-speed');
      expect(find.descendant(of: find.byKey(const Key('trace-speed')), matching: find.text('2×')), findsOneWidget);
      await tester.tap(find.byKey(const Key('trace-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(textOf(tester, 'trace-position'), '5 / 8');
      await tester.pump(const Duration(seconds: 2));
      expect(textOf(tester, 'trace-position'), '8 / 8');
      expect(find.byIcon(Icons.pause), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      // Stepping by hand stops a run that is playing.
      await tapKey(tester, 'trace-first');
      await tester.tap(find.byKey(const Key('trace-play')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('trace-next')));
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(textOf(tester, 'trace-position'), '2 / 8');
    });

    testWidgets('the slider moves through the run', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      final slider = find.byKey(const Key('trace-slider'));
      final rect = tester.getRect(slider);
      await tester.tapAt(Offset(rect.right - 26, rect.center.dy));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'trace-position'), '8 / 8');
      expect(currentBlock(tester), 'ret');
      await tester.tapAt(Offset(rect.left + 26, rect.center.dy));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'trace-position'), '1 / 8');
    });

    testWidgets('help explains the screen and closes', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      await tapKey(tester, 'trace-help');
      expect(find.textContaining('Hidden cases stay hidden.'), findsOneWidget);
      expect(find.textContaining('“changed” or “new”'), findsOneWidget);
      await tapKey(tester, 'trace-help-close');
      expect(find.textContaining('Hidden cases stay hidden.'), findsNothing);
    });
  });

  group('hidden cases', () {
    testWidgets('results offer STEP THROUGH on every visible case and nowhere else', (tester) async {
      final puzzle = sumPuzzle();
      await _showResults(tester, puzzle, sumProgram());
      expect(find.text('WRONG ANSWER'), findsOneWidget);
      expect(find.byKey(const Key('trace-case:v1')), findsOneWidget);
      expect(find.text('STEP THROUGH'), findsNWidgets(puzzle.visibleTests.length));
      expect(find.byKey(const Key('trace-case:h1')), findsNothing);
      // The hidden case is still only a count.
      expect(find.text('0 of 1 hidden cases passed.'), findsOneWidget);
      for (final secret in ['7001', '7002', '7003', '21006', '21007']) {
        expect(find.textContaining(secret), findsNothing);
      }
    });

    testWidgets('a passing visible case can be stepped through too', (tester) async {
      await _showResults(tester, sumPuzzle(), sumProgram(first: 0));
      expect(find.text('CORRECT'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('trace-case:v1')));
      await tapKey(tester, 'trace-case:v1');
      expect(find.byType(TraceScreen), findsOneWidget);
      expect(textOf(tester, 'trace-case'), 'expected: 6  ·  you gave: 6');
    });

    testWidgets('without the program there is nothing to step through', (tester) async {
      await _showResults(tester, sumPuzzle(), sumProgram(), withGraph: false);
      expect(find.text('WRONG ANSWER'), findsOneWidget);
      expect(find.text('STEP THROUGH'), findsNothing);
    });

    testWidgets('STEP THROUGH opens the case; nothing of the hidden case is on the way', (tester) async {
      await _showResults(tester, sumPuzzle(), sumProgram());
      await tester.ensureVisible(find.byKey(const Key('trace-case:v1')));
      await tapKey(tester, 'trace-case:v1');
      expect(find.byType(TraceScreen), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        for (final secret in ['7001', '7002', '7003', '21006', '21007']) {
          expect(find.textContaining(secret), findsNothing);
        }
        if (i < 7) await tapKey(tester, 'trace-next');
      }
      expect(textOf(tester, 'trace-position'), '8 / 8');
      // Back leads to the results again.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TraceScreen), findsNothing);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.byKey(const Key('trace-case:v1')), findsOneWidget);
    });

    testWidgets('the screen refuses a hidden case, however it is asked', (tester) async {
      final puzzle = sumPuzzle();
      final run = runProgram(
        const DefaultEngine().lower(sumProgram(), puzzle).program!,
        puzzle.hiddenTests.single.input,
        RunLimits.standard,
      );
      for (final forged in [
        // As the runner reports a hidden case…
        CaseResult(id: 'h1', visible: false, run: run),
        // …and dressed up as a visible one.
        CaseResult(id: 'h1', visible: true, run: run, input: const {}, expected: 0),
      ]) {
        await openTrace(tester, puzzle, sumProgram(), caseResult: forged);
        expect(find.text('This case cannot be stepped through.'), findsOneWidget);
        expect(find.byKey(const Key('trace-next')), findsNothing);
        expect(find.byKey(const Key('trace-values')), findsNothing);
        for (final secret in ['7001', '7002', '7003', '21006']) {
          expect(find.textContaining(secret), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('functions', () {
    // Rabbit Months with the base case one month too late: pairs(0) is asked
    // for pairs(-1).
    final puzzle = shippedPuzzleFile('world_12', 'rabbit_months');
    final wrong = brokenReference('world_12', 'rabbit_months', {
      'b1': {'value': 1},
    });

    testWidgets('a call opens a frame: the stack is listed and each frame has its own values', (tester) async {
      final graded = gradedCase(puzzle, wrong);
      expect(graded.run.kind, ResultKind.wrongAnswer);
      await openTrace(tester, puzzle, wrong);
      expect(find.byKey(const Key('trace-calls')), findsNothing, reason: 'only main is open at the start');
      expect(variableTexts(tester, 'n'), ['n', '=', '6']);

      // SET book, then the RETURN's CALL enters pairs.
      await tapKey(tester, 'trace-next', times: 2);
      expect(textOf(tester, 'trace-sentence'), 'pairs starts, one level deeper.');
      expect(currentBlock(tester), 'fn_pairs');
      expect(textOf(tester, 'trace-calls'), 'CALLS · 2 OPEN');
      expect(textOf(tester, 'trace-cost'), contains('Depth 2 of 80'));
      expect(tagOf(tester, 'month'), 'new');
      expect(tagOf(tester, 'memo'), 'new');
      expect(find.byKey(const Key('trace-var:n')), findsNothing, reason: "main's names are not pairs's");

      // The IF inside pairs says what its condition came to.
      await tapKey(tester, 'trace-next');
      expect(textOf(tester, 'trace-sentence'), 'The condition is FALSE: THEN is skipped.');
      expect(find.descendant(of: find.byKey(const Key('trace-badge')), matching: find.text('FALSE')), findsOneWidget);

      // main is still there, waiting, with its own names. (The list of calls
      // scrolls sideways; the test font is wide enough to need it.)
      await tester.scrollUntilVisible(
        find.byKey(const Key('trace-frame:0')),
        80,
        scrollable: find.descendant(of: find.byKey(const Key('trace-frames')), matching: find.byType(Scrollable)),
      );
      await tester.ensureVisible(find.byKey(const Key('trace-frame:0')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'trace-frame:0');
      expect(find.text('main is waiting for the call it made to finish.'), findsOneWidget);
      expect(variableTexts(tester, 'n'), ['n', '=', '6']);
      expect(find.byKey(const Key('trace-var:book')), findsOneWidget);
      expect(find.byKey(const Key('trace-var:month')), findsNothing);

      // The next step shows the running call again.
      await tapKey(tester, 'trace-next');
      expect(find.byKey(const Key('trace-var:month')), findsOneWidget);
      expect(find.byKey(const Key('trace-var:n')), findsNothing);
    });

    testWidgets('deeper calls stack up, a RETURN gives its value back, the map fills in', (tester) async {
      await openTrace(tester, puzzle, wrong);
      var deepest = 0;
      var sawReturn = false;
      var sawMapChange = false;
      final total = int.parse(textOf(tester, 'trace-position').split(' / ').last);
      for (var i = 1; i < total; i++) {
        await tester.tap(find.byKey(const Key('trace-next')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final calls = find.byKey(const Key('trace-calls'));
        if (calls.evaluate().isNotEmpty) {
          final open = int.parse(RegExp(r'(\d+) OPEN').firstMatch(textOf(tester, 'trace-calls'))!.group(1)!);
          if (open > deepest) deepest = open;
        }
        final sentence = textOf(tester, 'trace-sentence');
        if (sentence.startsWith('RETURN gives back')) sawReturn = true;
        if (tagOf(tester, 'memo') == 'changed') sawMapChange = true;
      }
      expect(deepest, greaterThan(5));
      expect(sawReturn, isTrue);
      expect(sawMapChange, isTrue, reason: 'storing into the shared map marks it in the frame that did it');
      expect(textOf(tester, 'trace-sentence'), startsWith('The program’s answer: '));
      expect(textOf(tester, 'trace-case'), contains('expected: 8'));
    });

    testWidgets('a recursion that never stops ends on the failure, with the block and the reason', (tester) async {
      // Rabbit Months asking for the same month again: month - 0.
      final endless = brokenReference('world_12', 'rabbit_months', {
        'b17': {'value': 0},
      });
      expect(gradedCase(puzzle, endless).run.kind, ResultKind.depthLimit);
      await openTrace(tester, puzzle, endless);
      await tapKey(tester, 'trace-last');
      expect(textOf(tester, 'trace-sentence'), 'Stopped here. This program went too many levels deep.');
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(textOf(tester, 'trace-calls'), 'CALLS · 80 OPEN');
      expect(textOf(tester, 'trace-cost'), contains('Depth 80 of 80'));
      // The failure points at the FUNCTION that could not be entered again.
      expect(currentBlock(tester), 'fn_pairs');
      // Only the calls near the top are built: 80 frames cost a few widgets.
      expect(find.byKey(const Key('trace-frame:79')), findsOneWidget);
      expect(find.byKey(const Key('trace-frame:0')), findsNothing);
      // A few steps earlier the last call that fitted was being entered.
      await tapKey(tester, 'trace-prev', times: 4);
      expect(textOf(tester, 'trace-sentence'), 'pairs starts, one level deeper.');
    });
  });

  group('long runs', () {
    testWidgets('a run longer than one window says so and loads as the player moves', (tester) async {
      final puzzle = sumPuzzle(maxOps: 600);
      final graded = gradedCase(puzzle, spinProgram());
      expect(graded.run.kind, ResultKind.operationLimit);
      await openTrace(tester, puzzle, spinProgram(), limits: const TraceLimits(maxSteps: 20));
      final total = int.parse(textOf(tester, 'trace-position').split(' / ').last);
      expect(total, greaterThan(200));
      expect(
        textOf(tester, 'trace-long-run'),
        'A long run: $total instructions ran. They load 20 at a time as you move through it.',
      );

      // Past the first window: the next one is there without a word.
      await tapKey(tester, 'trace-next', times: 25);
      expect(textOf(tester, 'trace-position'), '26 / $total');
      expect(currentBlock(tester), anyOf('spin', 'step'));
      expect(find.byKey(const Key('trace-var:total')), findsOneWidget);

      // The end is the failure; back from it crosses a window again.
      await tapKey(tester, 'trace-last');
      expect(textOf(tester, 'trace-position'), '$total / $total');
      expect(textOf(tester, 'trace-sentence'), 'Stopped here. This program took too many steps.');
      await tapKey(tester, 'trace-prev', times: 30);
      expect(textOf(tester, 'trace-position'), '${total - 30} / $total');
      expect(tester.takeException(), isNull);

      await tapKey(tester, 'trace-first');
      expect(textOf(tester, 'trace-position'), '1 / $total');
      expect(textOf(tester, 'trace-sentence'), 'Start. These are the given values.');
    });

    testWidgets('a short run has no such notice', (tester) async {
      await openTrace(tester, sumPuzzle(), sumProgram());
      expect(find.byKey(const Key('trace-long-run')), findsNothing);
    });
  });

  group('values', () {
    Future<void> show(WidgetTester tester, TraceRecording r, {int? at}) async {
      final step = r.steps[at ?? r.steps.length - 1];
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(AppPalette.dark),
        home: Scaffold(
          body: ListView(children: [
            for (final name in step.frames.last.vars.keys)
              TraceVariableRow(recording: r, step: step, frame: step.frames.last, name: name),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    const num = ValueType.number;
    Expr get(String name, [ValueType type = num]) => VarExpr(name, type: type);
    Expr n(int v) => LitExpr(v, type: num);
    Stmt run(String callee, List<Expr> args) => ExprStmt(CallExpr(callee, args, type: ValueType.voidType));
    Stmt set(String name, Expr value) => AssignStmt(target: VarLValue(name), value: value);
    Program main(List<Stmt> body, [List<Param> params = const []]) =>
        Program(functions: [FnDecl(name: 'main', params: params, body: body)]);

    testWidgets('stack, queue, heap, set and map each read their own way', (tester) async {
      final r = recordTrace(
        main([
          set('st', NewExpr(CollKind.stack, type: ValueType.stackOf(num))),
          run(BlockIds.stackPush, [get('st'), n(11)]),
          run(BlockIds.stackPush, [get('st'), n(12)]),
          set('q', NewExpr(CollKind.queue, type: ValueType.queueOf(num))),
          run(BlockIds.queueEnq, [get('q'), n(21)]),
          run(BlockIds.queueEnq, [get('q'), n(22)]),
          set('h', NewExpr(CollKind.maxHeap, type: ValueType.heapOf(num))),
          run(BlockIds.heapInsert, [get('h'), n(31)]),
          run(BlockIds.heapInsert, [get('h'), n(39)]),
          set('s', NewExpr(CollKind.set, type: ValueType.setOf(num))),
          set('m', NewExpr(CollKind.map, type: ValueType.mapOf(num, num))),
          run(BlockIds.mapSet, [get('m'), n(41), n(42)]),
        ]),
        const {},
        RunLimits.standard,
      );
      await show(tester, r);
      // The stack's top is its last item, the queue's front its first, the
      // max heap's top its largest.
      expect(variableTexts(tester, 'st'), ['st', '', '11', 'top', '12']);
      expect(variableTexts(tester, 'q'), ['q', 'front', '21', '', '22']);
      expect(variableTexts(tester, 'h'), ['h', 'top', '39', '', '31']);
      expect(variableTexts(tester, 's'), ['s', 'empty']);
      expect(variableTexts(tester, 'm'), ['m', 'changed', '41 → 42']);
    });

    testWidgets('linked nodes are a chain with the names that hold each node; a tree is an outline', (tester) async {
      final head = ListNodeValue(1, next: ListNodeValue(2, next: ListNodeValue(3)));
      final tree = TreeNodeValue(5, left: TreeNodeValue(3), right: TreeNodeValue(8));
      final node = ValueType.listNode;
      final r = recordTrace(
        main(
          [set('cur', FieldExpr(get('head', node), 'next', type: node))],
          [Param('head', node), const Param('root', ValueType.treeNode)],
        ),
        {'head': head, 'root': tree},
        RunLimits.standard,
      );
      await show(tester, r);
      expect(variableTexts(tester, 'head'), ['head', '', '1', 'head', '', '2', 'cur', '', '3', 'NOTHING']);
      expect(variableTexts(tester, 'cur'), ['cur', 'new', '', '2', 'cur', '', '3', 'NOTHING']);
      expect(variableTexts(tester, 'root'), ['root', '5', 'root', 'LEFT', '3', 'RIGHT', '8']);
    });

    testWidgets('a graph lists who each node leads to and marks the visited ones', (tester) async {
      final r = recordTrace(
        main(
          [run(BlockIds.graphMark, [get('g', ValueType.graph), n(1)])],
          [const Param('g', ValueType.graph)],
        ),
        {
          'g': GraphValue({
            0: [1],
            1: [0, 2],
            2: [],
          }),
        },
        RunLimits.standard,
      );
      await show(tester, r);
      expect(variableTexts(tester, 'g'), ['g', 'changed', '0', '1', '1', '0, 2', '2', '—', 'visited']);
      expect(find.byIcon(Icons.check), findsNWidgets(2), reason: 'node 1 and the legend');
    });

    testWidgets('a long list shows its first cells and says how many more; a value kind it does not know is text',
        (tester) async {
      final r = recordTrace(
        main(const [], [Param('big', ValueType.array(num))]),
        {'big': valueFromJson([for (var i = 0; i < 500; i++) i])},
        RunLimits.standard,
      );
      await show(tester, r);
      final texts = variableTexts(tester, 'big');
      expect(texts.last, '+452 more');
      expect(texts.length, lessThan(110));

      final step = r.steps.last;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TraceValueView(recording: r, step: step, value: const TraceUnknown('{"first":1,"second":[2,3]}')),
        ),
      ));
      expect(find.text('{"first":1,"second":[2,3]}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    final cart = shippedPuzzleFile('world_02', 'smallest_cart');
    // The Smallest Cart counting trips from 0: one trip too few.
    final wrongCart = brokenReference('world_02', 'smallest_cart', {
      'num_24': {'value': 0},
    });

    for (final (palette, language, scale) in [
      (AppPalette.light, 'en', 1.0),
      (AppPalette.dark, 'tr', 1.0),
      (AppPalette.dark, 'en', 1.6),
      (AppPalette.light, 'tr', 1.6),
    ]) {
      testWidgets(
          'a 360 × 800 phone, ${palette.brightness.name}, $language, text ×$scale: '
          'every step fits and the marked block stays in view', (tester) async {
        usePhone(tester, 360, 800, textScale: scale);
        expect(gradedCase(cart, wrongCart).run.kind, ResultKind.wrongAnswer);
        await openTrace(tester, cart, wrongCart, palette: palette, language: language);
        expect(tester.takeException(), isNull);
        expect(find.text(language == 'tr' ? 'ADIM ADIM' : 'STEP BY STEP'), findsOneWidget);
        for (final key in ['trace-first', 'trace-prev', 'trace-play', 'trace-next', 'trace-last', 'trace-speed']) {
          expect(clearOfSystemBars(tester, find.byKey(Key(key))), isTrue, reason: key);
          expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48), reason: key);
        }
        final total = int.parse(textOf(tester, 'trace-position').split(' / ').last);
        expect(total, greaterThan(60));
        expect(tester.getRect(find.byKey(const Key('trace-program'))).height, greaterThan(120),
            reason: 'the program keeps real room');
        expect(tester.getRect(find.byKey(const Key('trace-values'))).height, greaterThan(100));
        for (var i = 1; i < total; i++) {
          await tester.tap(find.byKey(const Key('trace-next')));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
          final mark = find.byKey(const Key('trace-current'));
          expect(mark, findsOneWidget, reason: 'step ${i + 1}');
          // The program's room changes a little with the length of the
          // sentence under it.
          final program = tester.getRect(find.byKey(const Key('trace-program')));
          final at = tester.getRect(mark);
          // Its first line is always in view; all of it whenever it fits (at
          // ×1.6 one long instruction can be taller than the program's room).
          expect(at.top, greaterThanOrEqualTo(program.top - 1), reason: 'step ${i + 1}: the marked block is in view');
          expect(at.top, lessThan(program.bottom - 20), reason: 'step ${i + 1}');
          if (at.height <= program.height) {
            expect(at.bottom, lessThanOrEqualTo(program.bottom + 1), reason: 'step ${i + 1}');
          }
        }
        expect(textOf(tester, 'trace-position'), '$total / $total');
      });
    }

    testWidgets('a wide window puts the program and the values side by side, inside the editor width',
        (tester) async {
      usePhone(tester, 1600, 900, dpr: 1, top: 0, bottom: 0);
      await openTrace(tester, cart, wrongCart);
      await tapKey(tester, 'trace-next', times: 12);
      expect(tester.takeException(), isNull);
      final program = tester.getRect(find.byKey(const Key('trace-program')));
      final values = tester.getRect(find.byKey(const Key('trace-values')));
      expect(program.right, lessThanOrEqualTo(values.left));
      expect(program.left, greaterThanOrEqualTo((1600 - ContentWidth.editor) / 2 - 1));
      expect(values.right, lessThanOrEqualTo((1600 + ContentWidth.editor) / 2 + 1));
      expect(program.height, greaterThan(500));
      expect(values.top, greaterThan(program.top), reason: 'what the step did sits above the values');
    });
  });

  group('in the app', () {
    testWidgets('RUN a wrong program, open the failed case from the results, step, and come back', (tester) async {
      final campaign = ms11Campaign();
      final cart = campaign.puzzles['smallest_cart']!;
      final wrong = brokenReference('world_02', 'smallest_cart', {
        'num_24': {'value': 0},
      });
      final store = MemoryProgressStore(
        encodeSave(saveDraft(openPuzzle(PlayerSave.fresh, campaign, cart).$1, campaign, cart, wrong)),
      );
      usePhone(tester, 360, 800);
      await tester.pumpWidget(
        ProviderScope(overrides: campaignOverrides(store, campaign: campaign), child: const AlgorunApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RUN'));
      await tester.pumpAndSettle();
      expect(find.text('WRONG ANSWER'), findsOneWidget);

      final open = find.byKey(const Key('trace-case:v1'));
      await tester.scrollUntilVisible(open, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(TraceScreen), findsOneWidget);
      expect(textOf(tester, 'trace-case'), startsWith('expected: 8'));
      expect(variableTexts(tester, 'weights').take(5), ['weights', '0', '5', '1', '1']);
      await tapKey(tester, 'trace-next', times: 3);
      expect(currentBlock(tester), isNotNull);
      expect(tester.takeException(), isNull);

      // Back to the results, back to the puzzle: the program is as it was.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TraceScreen), findsNothing);
      expect(find.byType(ResultsScreen), findsOneWidget);
      await tester.tap(find.text('BACK TO PUZZLE'));
      await tester.pumpAndSettle();
      expect(find.text('RUN'), findsOneWidget);
    });
  });
}
