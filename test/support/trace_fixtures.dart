import 'dart:convert';
import 'dart:io';

import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/screens/trace/trace_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Programs and harnesses for the step-through tests (T1).

Map<String, Object?> _block(String id, String catalogId,
        {Map<String, Object?> slots = const {}, Map<String, Object?> literals = const {}}) =>
    {'id': id, 'catalogId': catalogId, 'slots': slots, 'literals': literals};

/// Add up a list. One visible case and one hidden case whose numbers appear
/// nowhere else, so a test can look for them on screen.
Puzzle sumPuzzle({int maxOps = 400}) => parsePuzzleJson('''
{
  "id": "trace_sum", "title": "Sum", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Add them up.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.return", "arr.len", "arr.get", "var.get", "var.set", "lit.num", "ctrl.for_range", "ctrl.while",
              "arith.add", "cmp.lt", "lit.bool"]
  },
  "limits": { "maxOps": $maxOps, "maxAlloc": 50, "maxDepth": 8 },
  "variables": { "pool": [{ "name": "total", "type": "num" }, { "name": "i", "type": "num" }] },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [4, 2] }, "out": 6 }],
    "hidden": [{ "id": "h1", "in": { "nums": [7001, 7002, 7003] }, "out": 21006 }]
  }
}
''');

/// `total = [first]; for i in 0..LENGTH: total = total + nums[i]; return
/// total`. With [first] 0 it is right; the default starts at 1 and is one
/// too high on every case.
BlockGraph sumProgram({int first = 1}) => BlockGraph.fromJson({
      'variables': {'nums': 'array<num>', 'total': 'num', 'i': 'num'},
      'entryIds': ['start', 'loop', 'ret'],
      'blocks': {
        'start': _block('start', 'var.set', slots: {'value': {'ref': 'zero'}}, literals: {'name': 'total'}),
        'zero': _block('zero', 'lit.num', literals: {'value': first}),
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
        'step': _block('step', 'var.set', slots: {'value': {'ref': 'add'}}, literals: {'name': 'total'}),
        'add': _block('add', 'arith.add', slots: {'left': {'ref': 't1'}, 'right': {'ref': 'at'}}),
        't1': _block('t1', 'var.get', literals: {'name': 'total'}),
        'at': _block('at', 'arr.get', slots: {'array': {'ref': 'nums2'}, 'index': {'ref': 'i1'}}),
        'nums2': _block('nums2', 'var.get', literals: {'name': 'nums'}),
        'i1': _block('i1', 'var.get', literals: {'name': 'i'}),
        'ret': _block('ret', 'ctrl.return', slots: {'value': {'ref': 't2'}}),
        't2': _block('t2', 'var.get', literals: {'name': 'total'}),
      },
    });

/// `total = 0; while TRUE: total = total + 1` — never ends on its own.
BlockGraph spinProgram() => BlockGraph.fromJson({
      'variables': {'nums': 'array<num>', 'total': 'num', 'i': 'num'},
      'entryIds': ['start', 'spin'],
      'blocks': {
        'start': _block('start', 'var.set', slots: {'value': {'ref': 'zero'}}, literals: {'name': 'total'}),
        'zero': _block('zero', 'lit.num', literals: {'value': 0}),
        'spin': _block('spin', 'ctrl.while', slots: {
          'condition': {'ref': 'yes'},
          'body': {
            'list': ['step'],
          },
        }),
        'yes': _block('yes', 'lit.bool', literals: {'value': true}),
        'step': _block('step', 'var.set', slots: {'value': {'ref': 'add'}}, literals: {'name': 'total'}),
        'add': _block('add', 'arith.add', slots: {'left': {'ref': 't1'}, 'right': {'ref': 'one'}}),
        't1': _block('t1', 'var.get', literals: {'name': 'total'}),
        'one': _block('one', 'lit.num', literals: {'value': 1}),
      },
    });

Puzzle shippedPuzzleFile(String world, String id) =>
    parsePuzzleJson(File('assets/puzzles/$world/$id.json').readAsStringSync());

/// A reference solution with literals of some blocks replaced: a small,
/// plausible mistake. `{blockId: {literal: value}}`.
BlockGraph brokenReference(String world, String id, Map<String, Map<String, Object?>> literals) {
  final file = jsonDecode(File('content/references/$world/$id.json').readAsStringSync()) as Map<String, Object?>;
  final graph = jsonDecode(jsonEncode(file['solution'])) as Map<String, Object?>;
  final blocks = graph['blocks']! as Map<String, Object?>;
  for (final change in literals.entries) {
    final block = blocks[change.key]! as Map<String, Object?>;
    block['literals'] = {...(block['literals'] as Map<String, Object?>? ?? const {}), ...change.value};
  }
  return BlockGraph.fromJson(graph);
}

/// The graded visible case [caseId] of [graph] on [puzzle].
CaseResult gradedCase(Puzzle puzzle, BlockGraph graph, [String caseId = 'v1']) =>
    runPuzzle(const DefaultEngine(), graph, puzzle).suite.visible.singleWhere((c) => c.id == caseId);

/// The step-through screen for one case, under the app's real theme.
Future<void> openTrace(
  WidgetTester tester,
  Puzzle puzzle,
  BlockGraph graph, {
  String caseId = 'v1',
  CaseResult? caseResult,
  AppPalette palette = AppPalette.light,
  String language = 'en',
  TraceLimits limits = TraceLimits.standard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(palette),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: maxTextScale, child: child!),
        home: TraceScreen(
          args: TraceArgs(
            puzzle: puzzle,
            graph: graph,
            caseResult: caseResult ?? gradedCase(puzzle, graph, caseId),
            limits: limits,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// The id of the instruction that carries the "just ran" arrow, or null.
String? currentBlock(WidgetTester tester) {
  final mark = find.byKey(const Key('trace-current'));
  if (mark.evaluate().isEmpty) return null;
  final tiles = find.ancestor(
    of: mark,
    matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('trace-block:')),
  );
  // The innermost one: a marked instruction inside a C-block is inside that
  // block's tile too.
  return (tester.widget(tiles.first).key! as ValueKey<String>).value.substring('trace-block:'.length);
}

/// The texts inside one name's row of VALUES, in order.
List<String> variableTexts(WidgetTester tester, String name) => [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: find.byKey(Key('trace-var:$name')), matching: find.byType(Text)),
      ))
        t.data ?? '',
    ];

/// The tag on a name (`new`, `changed`), or null.
String? tagOf(WidgetTester tester, String name) {
  final tag = find.descendant(of: find.byKey(Key('trace-changed:$name')), matching: find.byType(Text));
  return tag.evaluate().isEmpty ? null : tester.widget<Text>(tag).data;
}
