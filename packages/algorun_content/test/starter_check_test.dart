import 'dart:convert';
import 'dart:math';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart' show BlockGraph;
import 'package:test/test.dart';

/// M1: what the content pipeline demands of a starter program — one puzzle
/// (the total of a list) played as complete, repair and predict.

const _validator =
    ContentValidator(checker: ReferenceChecker(oracles: {...oracleRegistry, 'list_total': _totalOracle}));

const _totalOracle = Oracle(id: 'list_total', solve: _total, sample: _sample);

Object? _total(Map<String, Object?> input) => (input['nums']! as List).cast<int>().fold<int>(0, (a, b) => a + b);

Map<String, Object?> _sample(Random r) => {'nums': [for (var i = r.nextInt(6); i > 0; i--) r.nextInt(9)]};

const _puzzleFile = 'world_01/p1.json';
const _referenceFile = 'references/world_01/p1.json';

Map<String, Object?> _block(String id, String catalogId,
        {Map<String, Object?> slots = const {}, Map<String, Object?> literals = const {}}) =>
    {'id': id, 'catalogId': catalogId, 'slots': slots, 'literals': literals};

Map<String, Object?> _ref(String id) => {'ref': id};

/// ```
/// total = 0
/// FOR EACH x IN nums: total = total + x
/// RETURN total
/// ```
Map<String, Object?> _totalGraph() => {
      'variables': {'nums': 'array<num>', 'total': 'num', 'x': 'num'},
      'entryIds': ['start', 'loop', 'ret'],
      'blocks': {
        'start': _block('start', 'var.set', slots: {'value': _ref('zero')}, literals: {'name': 'total'}),
        'zero': _block('zero', 'lit.num', literals: {'value': 0}),
        'loop': _block('loop', 'ctrl.foreach', literals: {
          'name': 'x'
        }, slots: {
          'collection': _ref('nums'),
          'body': {
            'list': ['add'],
          },
        }),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
        'add': _block('add', 'var.set', slots: {'value': _ref('plus')}, literals: {'name': 'total'}),
        'plus': _block('plus', 'arith.add', slots: {'left': _ref('t1'), 'right': _ref('x1')}),
        't1': _block('t1', 'var.get', literals: {'name': 'total'}),
        'x1': _block('x1', 'var.get', literals: {'name': 'x'}),
        'ret': _block('ret', 'ctrl.return', slots: {'value': _ref('t2')}),
        't2': _block('t2', 'var.get', literals: {'name': 'total'}),
      },
    };

Map<String, Object?> _edit(void Function(Map<String, dynamic> graph, Map<String, dynamic> blocks) change) {
  final graph = jsonDecode(jsonEncode(_totalGraph())) as Map<String, dynamic>;
  change(graph, graph['blocks'] as Map<String, dynamic>);
  return graph;
}

/// The loop is there, its body is not: the player adds `total = total + x`.
Map<String, Object?> _halfGraph() => _edit((graph, blocks) {
      for (final id in ['add', 'plus', 't1', 'x1']) {
        blocks.remove(id);
      }
      ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
    });

/// `total = …` with nothing plugged in: not a program that can run.
Map<String, Object?> _holeGraph() => _edit((graph, blocks) {
      blocks.remove('zero');
      (blocks['start'] as Map)['slots'] = <String, Object?>{};
    });

/// Starts counting from 1: one wrong number.
Map<String, Object?> _buggyGraph() => _edit((graph, blocks) => ((blocks['zero'] as Map)['literals'] as Map)['value'] = 1);

ContentReport _check({
  required String mode,
  Map<String, Object?>? starter,
  List<String> locked = const [],
  Map<String, Object?>? solution,
  bool withMetadata = true,
  String visible = '''[
      { "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 6 },
      { "id": "v2", "in": { "nums": [4, 4] }, "out": 8 }
    ]''',
}) {
  final puzzle = jsonEncode({
    'id': 'p1',
    'title': 'Probe',
    'world': 'world_01',
    'tier': 1,
    'mode': mode,
    'story': 'Add the numbers up.',
    'io': {
      'inputs': [
        {'name': 'nums', 'type': 'array<num>'},
      ],
      'output': {'type': 'num'},
    },
    'blocks': {
      'allow': ['ctrl.return', 'ctrl.foreach', 'var.get', 'var.set', 'lit.num', 'arith.add', 'arr.len'],
    },
    'limits': {'maxOps': 1000},
    'hints': ['Keep a running total.'],
    'fixtures': {
      'visible': jsonDecode(visible),
      'hidden': [
        {
          'id': 'h1',
          'in': {'nums': <Object?>[]},
          'out': 0,
        },
        {
          'id': 'h2',
          'in': {
            'nums': [7],
          },
          'out': 7,
        },
        {
          'id': 'h3',
          'in': {
            'nums': [1, 1, 1, 1, 1],
          },
          'out': 5,
        },
        {
          'id': 'h4',
          'in': {
            'nums': [9, 0, 2],
          },
          'out': 11,
        },
      ],
    },
    'variables': {
      'pool': [
        {'name': 'total', 'type': 'num'},
        {'name': 'x', 'type': 'num'},
      ],
    },
    if (withMetadata) 'reference': {'strategy': 'list_total'},
    if (starter != null) 'starter': {'graph': starter, if (locked.isNotEmpty) 'locked': locked},
  });
  final reference = jsonEncode({
    'puzzle': 'p1',
    'notes': 'A running total.',
    'spec': {
      'family': 'array_scan',
      'pattern': 'list_total',
      'structure': 'array',
      'secondary': <String>[],
      'performance': 'correctness',
      'traps': ['an empty list'],
      'oracle': 'list_total',
    },
    'solution': solution ?? _totalGraph(),
  });
  return _validator.validateContent(
    puzzles: [ContentFile(_puzzleFile, puzzle)],
    worldsSource: jsonEncode({
      'worlds': [
        {
          'id': 'world_01',
          'title': 'One',
          'index': 1,
          'concepts': ['c1'],
          'puzzles': ['p1'],
        },
      ],
    }),
    references: withMetadata ? [ContentFile('world_01/p1.json', reference)] : const [],
  );
}

Iterable<ContentIssue> _errors(ContentReport report) => report.issues.where((i) => i.isError);

void _accepted(ContentReport report) {
  expect(_errors(report), isEmpty, reason: _errors(report).join('\n'));
  expect(report.verdicts.single.accepted, isTrue);
}

void _refused(ContentReport report, String path, String fragment, {int? level, String file = _puzzleFile}) {
  final hit = _errors(report).where((i) => i.file == file && i.path == path && i.message.contains(fragment));
  expect(hit, isNotEmpty, reason: 'wanted "$fragment" at $path, got:\n${_errors(report).join('\n')}');
  if (level != null) expect(hit.first.level, level);
  expect(report.verdicts.single.accepted, isFalse);
}

void main() {
  group('complete', () {
    test('half a program the reference only adds to is accepted', () {
      _accepted(_check(mode: 'complete', starter: _halfGraph()));
    });

    test('a starter that already passes leaves nothing to complete', () {
      _refused(_check(mode: 'complete', starter: _totalGraph()), 'starter.graph', 'already passes every case',
          level: Level.execution);
    });

    test('a starter that is the whole reference adds nothing', () {
      _refused(_check(mode: 'complete', starter: _totalGraph()), 'starter.graph', 'adds nothing', level: Level.replay);
    });

    test('a starter block the reference does not have is refused', () {
      final starter = _edit((graph, blocks) {
        blocks['extra'] = _block('extra', 'var.set', literals: {'name': 'x'});
        (graph['entryIds'] as List).insert(1, 'extra');
        for (final id in ['add', 'plus', 't1', 'x1']) {
          blocks.remove(id);
        }
        ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
      });
      _refused(_check(mode: 'complete', starter: starter), 'starter.graph.blocks.extra', 'Not in the reference',
          level: Level.replay);
    });

    test('a starter block the reference changes is refused', () {
      final starter = _edit((graph, blocks) {
        ((blocks['zero'] as Map)['literals'] as Map)['value'] = 5;
        for (final id in ['add', 'plus', 't1', 'x1']) {
          blocks.remove(id);
        }
        ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
      });
      _refused(_check(mode: 'complete', starter: starter), 'starter.graph.blocks.zero', 'changes this block');
    });

    test('a starter in another order than the reference is refused', () {
      final starter = _edit((graph, blocks) {
        graph['entryIds'] = ['loop', 'start', 'ret'];
        for (final id in ['add', 'plus', 't1', 'x1']) {
          blocks.remove(id);
        }
        ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
      });
      _refused(_check(mode: 'complete', starter: starter), 'starter.graph.entryIds', 'rearranges');
    });

    test('a starter with a piece where it does not fit is refused at replay', () {
      // RETURN handed the list where the reference returns the total.
      final starter = _edit((graph, blocks) {
        for (final id in ['add', 'x1']) {
          blocks.remove(id);
        }
        ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
        ((blocks['plus'] as Map)['slots'] as Map)
          ..remove('right')
          ..['left'] = _ref('nums2');
        blocks.remove('t1');
        blocks['nums2'] = _block('nums2', 'var.get', literals: {'name': 'nums'});
        (graph['entryIds'] as List).add('orphan');
        blocks['orphan'] = _block('orphan', 'var.set', slots: {'value': _ref('plus')}, literals: {'name': 'total'});
      });
      final report = _check(mode: 'complete', starter: starter);
      final hit = _errors(report).where((i) => i.path.startsWith('starter.graph.blocks.') && i.level == Level.replay);
      expect(hit, isNotEmpty, reason: _errors(report).join('\n'));
    });

    test('a starter mode needs reference metadata', () {
      _refused(_check(mode: 'complete', starter: _halfGraph(), withMetadata: false), 'reference',
          'checked against its reference solution');
    });
  });

  group('repair', () {
    test('one wrong number is accepted, and the report says how it fails', () {
      final report = _check(mode: 'repair', starter: _buggyGraph());
      _accepted(report);
      final info = report.issues.where((i) => i.severity == Severity.info && i.path == 'starter.graph');
      expect(info.single.message, contains('fails 6 of 6 case(s), 2 of them visible'));
      expect(info.single.message, contains('Wrong Answer'));
    });

    test('a starter that already passes has nothing to repair', () {
      _refused(_check(mode: 'repair', starter: _totalGraph()), 'starter.graph', 'already passes every case',
          level: Level.execution);
      _refused(_check(mode: 'repair', starter: _totalGraph()), 'starter.graph', 'is the reference solution',
          level: Level.replay);
    });

    test('half a program is not a repair: the starter must run', () {
      _refused(_check(mode: 'repair', starter: _holeGraph()), 'starter.graph.blocks.start', 'whole program that runs');
    });

    test('a starter far from the reference is another program, not a bug', () {
      // Counts the items instead: five blocks differ.
      final starter = _edit((graph, blocks) {
        ((blocks['zero'] as Map)['literals'] as Map)['value'] = 1;
        ((blocks['x1'] as Map)['literals'] as Map)['name'] = 'total';
        ((blocks['t1'] as Map)['literals'] as Map)['name'] = 'x';
        ((blocks['t2'] as Map)['literals'] as Map)['name'] = 'x';
        ((blocks['start'] as Map)['literals'] as Map)['name'] = 'x';
      });
      _refused(_check(mode: 'repair', starter: starter), 'starter.graph', 'differs from the reference solution in 5 blocks',
          level: Level.replay);
    });

    test('changedBlocks names what differs', () {
      BlockGraph graph(Map<String, Object?> json) => BlockGraph.fromJson(Map<String, dynamic>.from(json));
      expect(changedBlocks(graph(_totalGraph()), graph(_totalGraph())), isEmpty);
      expect(changedBlocks(graph(_buggyGraph()), graph(_totalGraph())), ['zero']);
      // A missing instruction: its blocks, and the list it belongs in.
      expect(changedBlocks(graph(_halfGraph()), graph(_totalGraph())), ['add', 'loop', 'plus', 't1', 'x1']);
      final swapped = _edit((graph, blocks) => graph['entryIds'] = ['loop', 'start', 'ret']);
      expect(changedBlocks(graph(swapped), graph(_totalGraph())), ['@main']);
    });
  });

  group('predict', () {
    test('the reference shown as the starter is accepted', () {
      _accepted(_check(mode: 'predict', starter: _totalGraph()));
    });

    test('a shown program that is not the reference is refused', () {
      // The same answers by another route: LENGTH is never asked, but the
      // player would be reading a program the pipeline did not prove.
      final starter = _edit((graph, blocks) {
        ((blocks['plus'] as Map)['slots'] as Map)
          ..['left'] = _ref('x1')
          ..['right'] = _ref('t1');
      });
      _refused(_check(mode: 'predict', starter: starter), 'starter.graph', 'must be the same program',
          level: Level.replay);
    });

    test('an expected answer the program does not return is refused', () {
      final report = _check(
        mode: 'predict',
        starter: _buggyGraph(),
        solution: _buggyGraph(),
      );
      _refused(report, 'starter.graph', 'does not return the expected answer of visible case "v1"',
          level: Level.execution);
      // The reference is the same wrong program: the oracle says so too.
      expect(_errors(report).any((i) => i.file == _referenceFile), isTrue);
    });

    test('half a program cannot be predicted', () {
      _refused(_check(mode: 'predict', starter: _holeGraph()), 'starter.graph.blocks.start', 'whole program that runs');
    });

    test('one visible case is one question: too few', () {
      _refused(
        _check(
          mode: 'predict',
          starter: _totalGraph(),
          visible: '[{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 6 }]',
        ),
        'fixtures.visible',
        'at least 2',
      );
    });
  });

  group('locked blocks', () {
    test('locks the reference keeps are accepted', () {
      _accepted(_check(mode: 'complete', starter: _halfGraph(), locked: ['start', 'zero', 'loop', 'ret']));
    });

    test('a lock the reference changes is refused', () {
      final solution = _edit((graph, blocks) => ((blocks['ret'] as Map)['literals'] as Map)['note'] = 'x');
      final report = _check(mode: 'repair', starter: _buggyGraph(), locked: ['ret'], solution: solution);
      expect(_errors(report).any((i) => i.path == 'starter.locked' && i.message.contains('changes the locked block "ret"')),
          isTrue,
          reason: _errors(report).join('\n'));
    });

    test('a lock the reference drops or moves is refused', () {
      // The reference returns from inside nothing: `ret` renamed.
      final renamed = _edit((graph, blocks) {
        blocks['ret9'] = _block('ret9', 'ctrl.return', slots: {'value': _ref('t2')});
        blocks.remove('ret');
        graph['entryIds'] = ['start', 'loop', 'ret9'];
      });
      final dropped = _check(mode: 'repair', starter: _buggyGraph(), locked: ['ret'], solution: renamed);
      expect(_errors(dropped).any((i) => i.path == 'starter.locked' && i.message.contains('no block "ret"')), isTrue,
          reason: _errors(dropped).join('\n'));

      // The starter updates the total after the loop; the reference inside it.
      final starter = _edit((graph, blocks) {
        ((blocks['loop'] as Map)['slots'] as Map)['body'] = {'list': <String>[]};
        graph['entryIds'] = ['start', 'loop', 'add', 'ret'];
      });
      final moved = _check(mode: 'repair', starter: starter, locked: ['add']);
      expect(_errors(moved).any((i) => i.path == 'starter.locked' && i.message.contains('moves the locked block "add"')),
          isTrue,
          reason: _errors(moved).join('\n'));
    });
  });

  test('a build puzzle with a starter is only checked for being buildable', () {
    _accepted(_check(mode: 'build', starter: _halfGraph()));
  });
}
