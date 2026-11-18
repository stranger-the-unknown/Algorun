import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// M1: the starter program in the puzzle schema, and predict grading.

Map<String, Object?> _block(String id, String catalogId,
        {Map<String, Object?> slots = const {}, Map<String, Object?> literals = const {}}) =>
    {'id': id, 'catalogId': catalogId, 'slots': slots, 'literals': literals};

/// `RETURN LENGTH nums`.
Map<String, Object?> _lengthGraph() => {
      'blocks': {
        'b1': _block('b1', 'var.get', literals: {'name': 'nums'}),
        'b2': _block('b2', 'arr.len', slots: {
          'array': {'ref': 'b1'},
        }),
        'b3': _block('b3', 'ctrl.return', slots: {
          'value': {'ref': 'b2'},
        }),
      },
      'entryIds': ['b3'],
      'variables': {'nums': 'array<num>'},
    };

Map<String, Object?> _base({String mode = 'complete'}) => {
      'id': 'starter_probe',
      'title': 'Starter probe',
      'world': 'world_01',
      'tier': 1,
      'mode': mode,
      'story': 'Probe.',
      'io': {
        'inputs': [
          {'name': 'nums', 'type': 'array<num>'},
        ],
        'output': {'type': 'num'},
      },
      'blocks': {
        'allow': ['ctrl.return', 'arr.len', 'var.get', 'lit.num'],
        'maxBlocks': 6,
      },
      'limits': {'maxOps': 1000},
      'fixtures': {
        'visible': [
          {
            'id': 'v1',
            'in': {
              'nums': [1, 2],
            },
            'out': 2,
          },
          {
            'id': 'v2',
            'in': {
              'nums': [5, 5, 5],
            },
            'out': 3,
          },
        ],
        'hidden': [
          {
            'id': 'h1',
            'in': {'nums': <Object?>[]},
            'out': 0,
          },
        ],
      },
      'starter': {'graph': _lengthGraph()},
    };

Map<String, dynamic> _with(void Function(Map<String, dynamic> m) change, {String mode = 'complete'}) {
  final copy = jsonDecode(jsonEncode(_base(mode: mode))) as Map<String, dynamic>;
  change(copy);
  return copy;
}

List<SchemaIssue> _issues(Object? json) => readPuzzleJson(jsonEncode(json)).issues;

void _rejects(Object? json, String path, String fragment) {
  final issues = _issues(json);
  expect(
    issues.any((i) => i.path == path && i.message.contains(fragment)),
    isTrue,
    reason: 'wanted "$fragment" at $path, got:\n${issues.join('\n')}',
  );
}

void main() {
  group('starter program schema', () {
    test('a starter program is read as a block graph with its locked blocks', () {
      final puzzle = parsePuzzleMap(_with((m) => (m['starter'] as Map)['locked'] = ['b3']));
      final starter = puzzle.starter!;
      expect(starter.graph.entryIds, ['b3']);
      expect(starter.graph.blocks.keys, ['b1', 'b2', 'b3']);
      expect(starter.locked, {'b3'});
      expect(puzzle.isPredict, isFalse);
    });

    test('a puzzle without a starter still reads, with none', () {
      final puzzle = parsePuzzleMap(_with((m) => m.remove('starter'), mode: 'build'));
      expect(puzzle.starter, isNull);
    });

    test('a build puzzle may carry a starter', () {
      expect(parsePuzzleMap(_base(mode: 'build')).starter, isNotNull);
    });

    for (final mode in ['complete', 'repair', 'predict']) {
      test('$mode needs a starter', () {
        _rejects(_with((m) => m.remove('starter'), mode: mode), 'starter', 'opens with a starter program');
      });
    }

    test('an unfinished starter is fine: empty holes are what the player fills', () {
      final puzzle = parsePuzzleMap(_with((m) {
        final blocks = ((m['starter'] as Map)['graph'] as Map)['blocks'] as Map;
        blocks.remove('b1');
        (blocks['b2'] as Map)['slots'] = <String, Object?>{};
      }));
      expect(puzzle.starter!.graph.blocks.length, 2);
    });

    test('unknown fields are refused', () {
      _rejects(_with((m) => (m['starter'] as Map)['hint'] = 'x'), 'starter.hint', 'Unknown field');
      _rejects(_with((m) => (m['starter'] as Map)['script'] = 'x'), 'starter.script', 'data only');
    });

    test('the graph is required and must be a block graph', () {
      _rejects(_with((m) => (m['starter'] as Map).remove('graph')), 'starter.graph', 'Required');
      _rejects(_with((m) => (m['starter'] as Map)['graph'] = {'entryIds': <Object?>[]}), 'starter.graph',
          'Not a block graph');
      _rejects(
        _with((m) => (((m['starter'] as Map)['graph'] as Map)['blocks'] as Map)['b1'] =
            _block('b1', 'made.up')),
        'starter.graph',
        'Not a block graph',
      );
    });

    test('an empty starter is refused', () {
      _rejects(
        _with((m) => (m['starter'] as Map)['graph'] = {'blocks': <String, Object?>{}, 'entryIds': <Object?>[]}),
        'starter.graph',
        'at least one block',
      );
    });

    test('a graph that is not put together soundly is refused', () {
      _rejects(
        _with((m) => (((m['starter'] as Map)['graph'] as Map)['blocks'] as Map).remove('b1')),
        'starter.graph.blocks.b2',
        'missing block',
      );
    });

    test('a block outside the allowlist is refused', () {
      _rejects(
        _with((m) => (m['blocks'] as Map)['allow'] = ['ctrl.return', 'var.get', 'lit.num']),
        'starter.graph.blocks.b2',
        'not in blocks.allow',
      );
    });

    test('a starter over the block budget is refused', () {
      _rejects(_with((m) => (m['blocks'] as Map)['maxBlocks'] = 2), 'starter.graph', 'blocks.maxBlocks is 2');
    });

    test('names must be the puzzle\'s, with its types', () {
      _rejects(
        _with((m) => (((m['starter'] as Map)['graph'] as Map)['variables'] as Map)['total'] = 'num'),
        'starter.graph.variables.total',
        'not an input or a variable',
      );
      _rejects(
        _with((m) => (((m['starter'] as Map)['graph'] as Map)['variables'] as Map)['nums'] = 'num'),
        'starter.graph.variables.nums',
        'array<num>',
      );
    });

    test('locked ids must name starter blocks', () {
      _rejects(_with((m) => (m['starter'] as Map)['locked'] = ['b9']), 'starter.locked[0]', 'No block "b9"');
      _rejects(_with((m) => (m['starter'] as Map)['locked'] = ['b1', 'b1']), 'starter.locked[1]', 'twice');
    });

    test('predict: nothing is locked and the answer is a number or yes / no', () {
      _rejects(
        _with((m) => (m['starter'] as Map)['locked'] = ['b3'], mode: 'predict'),
        'starter.locked',
        'read-only',
      );
      _rejects(
        _with((m) {
          ((m['io'] as Map)['output'] as Map)['type'] = 'array<num>';
          final fixtures = m['fixtures'] as Map;
          for (final list in ['visible', 'hidden']) {
            for (final c in fixtures[list] as List) {
              (c as Map)['out'] = <Object?>[];
            }
          }
        }, mode: 'predict'),
        'io.output.type',
        'num or bool',
      );
      expect(parsePuzzleMap(_base(mode: 'predict')).isPredict, isTrue);
    });
  });

  group('predict grading', () {
    final puzzle = parsePuzzleMap(_base(mode: 'predict'));
    const engine = DefaultEngine();
    final program = engine.lower(puzzle.starter!.graph, puzzle).program!;

    SuiteResult grade(Map<String, num> answers) => gradePredictions(
          program,
          puzzle,
          {for (final e in answers.entries) e.key: NumValue(e.value)},
        );

    test('the starter of the probe lowers', () {
      expect(engine.lower(puzzle.starter!.graph, puzzle).errors, isEmpty);
    });

    test('every answer right is correct', () {
      final suite = grade({'v1': 2, 'v2': 3});
      expect(suite.kind, ResultKind.correct);
      expect(suite.visible.map((c) => c.ok), [true, true]);
      expect(suite.visible.first.input, {
        'nums': [1, 2],
      });
      expect(suite.visible.first.actual, 2);
      expect(suite.visible.first.expected, 2);
      expect(suite.metrics.blocks, 3);
      expect(suite.hiddenSummary, isNull);
    });

    test('a wrong answer is a wrong answer and never carries the real one', () {
      final suite = grade({'v1': 2, 'v2': 4});
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible.map((c) => c.ok), [true, false]);
      expect(suite.firstFailureCaseId, 'v2');
      expect(suite.visible[1].actual, 4);
      expect(suite.visible[1].expected, isNull);
      expect(suite.message, contains('not what the program returns'));
    });

    test('a missing answer is wrong', () {
      final suite = grade({'v1': 2});
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible[1].actual, isNull);
      expect(suite.visible[1].expected, isNull);
    });

    test('answers are compared with what the program returns, not the fixture', () {
      // A fixture that claims 99 changes nothing: the interpreter decides.
      final lying = parsePuzzleMap(_with(
        (m) => (((m['fixtures'] as Map)['visible'] as List)[0] as Map)['out'] = 99,
        mode: 'predict',
      ));
      final suite = gradePredictions(program, lying, {'v1': const NumValue(2), 'v2': const NumValue(3)});
      expect(suite.kind, ResultKind.correct);
    });

    test('an answer of the wrong kind is wrong, not an error', () {
      final suite = gradePredictions(program, puzzle, {'v1': const BoolValue(true), 'v2': const NumValue(3)});
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible.first.ok, isFalse);
    });

    test('hidden cases take no part', () {
      final suite = grade({'v1': 2, 'v2': 3, 'h1': 7});
      expect(suite.kind, ResultKind.correct);
      expect(suite.visible.map((c) => c.id), ['v1', 'v2']);
    });
  });
}
