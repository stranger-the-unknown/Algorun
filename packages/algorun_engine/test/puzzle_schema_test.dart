import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> _base() => {
      'id': 'schema_probe',
      'title': 'Schema probe',
      'world': 'world_01',
      'tier': 1,
      'mode': 'build',
      'story': 'Probe.',
      'io': {
        'inputs': [
          {'name': 'nums', 'type': 'array<num>'},
        ],
        'output': {'type': 'num'},
      },
      'blocks': {
        'allow': ['ctrl.return', 'arr.len', 'var.get'],
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
        ],
        'hidden': [
          {
            'id': 'h1',
            'in': {'nums': <Object?>[]},
            'out': 0,
          },
        ],
      },
    };

/// A deep copy of the base puzzle with [change] applied.
Map<String, dynamic> _with(void Function(Map<String, dynamic> m) change) {
  final copy = jsonDecode(jsonEncode(_base())) as Map<String, dynamic>;
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

Map<String, dynamic> _visible(Map<String, dynamic> m) =>
    ((m['fixtures'] as Map)['visible'] as List).first as Map<String, dynamic>;

void main() {
  group('valid content', () {
    test('a minimal puzzle loads with documented defaults', () {
      final read = readPuzzleJson(jsonEncode(_base()));
      expect(read.issues, isEmpty);
      final puzzle = read.puzzle!;
      expect(puzzle.outputValidator, ValidatorId.equal);
      expect(puzzle.limits.maxDepth, 256);
      expect(puzzle.limits.maxAlloc, 10000);
      expect(puzzle.verdictSource, VerdictSource.local);
      expect(puzzle.meta, isEmpty);
      final nums = puzzle.visibleTests.single.input['nums'] as ArrayValue;
      expect(nums.elementType, ValueType.number);
      expect(valueToJson(nums), [1, 2]);
      expect((puzzle.hiddenTests.single.output as NumValue).value, 0);
    });

    test('structured fixtures load as typed runtime values', () {
      final json = _with((m) {
        m['io'] = {
          'inputs': [
            {'name': 'root', 'type': 'treeNode'},
            {'name': 'g', 'type': 'graph'},
            {'name': 'seen', 'type': 'set<num>'},
            {'name': 'counts', 'type': 'map<str,num>'},
          ],
          'output': {'type': 'listNode?'},
        };
        m['validators'] = {'output': 'listEqualByValue'};
        final given = {
          'root': {
            'type': 'treeNode',
            'value': 2,
            'left': {'type': 'treeNode', 'value': 1},
          },
          'g': {
            'type': 'graph',
            'nodes': [
              {'id': 0, 'neighbors': [1]},
              {'id': 1, 'neighbors': [0]},
            ],
          },
          'seen': {'type': 'set', 'items': [4]},
          'counts': {
            'type': 'map',
            'entries': [
              ['a', 1],
            ],
          },
        };
        m['fixtures'] = {
          'visible': [
            {
              'id': 'v1',
              'in': given,
              'out': {'type': 'listNode', 'values': [1, 2]},
            },
          ],
          'hidden': [
            {'id': 'h1', 'in': given, 'out': null},
          ],
        };
      });
      final read = readPuzzleJson(jsonEncode(json));
      expect(read.issues, isEmpty, reason: read.issues.join('\n'));
      final input = read.puzzle!.visibleTests.single.input;
      expect(input['root'], isA<TreeNodeValue>());
      expect(input['g'], isA<GraphValue>());
      expect(input['seen'], isA<SetValue>());
      expect((input['counts'] as MapValue).keyType, ValueType.string);
      expect(read.puzzle!.visibleTests.single.output, isA<ListNodeValue>());
      expect(read.puzzle!.hiddenTests.single.output, isA<NilValue>());
    });

    test('reference metadata names the intended strategy', () {
      final read = readPuzzleJson(jsonEncode(_with((m) {
        m['reference'] = {'strategy': 'hash_set_complement'};
      })));
      expect(read.issues, isEmpty);
      expect(read.puzzle!.reference!.strategy, 'hash_set_complement');
      expect(readPuzzleJson(jsonEncode(_base())).puzzle!.reference, isNull);
    });

    test('meta holds flat data the engine never reads', () {
      final read = readPuzzleJson(jsonEncode(_with((m) {
        m['meta'] = {'author': 'grok', 'revision': 3, 'reviewed': true};
      })));
      expect(read.issues, isEmpty);
      expect(read.puzzle!.meta, {'author': 'grok', 'revision': 3, 'reviewed': true});
    });

    test('parsePuzzleJson throws every issue at once', () {
      final json = _with((m) {
        m.remove('story');
        m['tier'] = 9;
        m['mode'] = 'speedrun';
      });
      expect(
        () => parsePuzzleJson(jsonEncode(json)),
        throwsA(isA<SchemaException>().having((e) => e.issues.length, 'issues', 3)),
      );
    });
  });

  group('required fields and field types', () {
    test('missing required field', () {
      _rejects(_with((m) => m.remove('story')), 'story', 'Required');
      _rejects(_with((m) => m.remove('limits')), 'limits', 'Required');
      _rejects(_with((m) => m.remove('tier')), 'tier', 'Required');
    });

    test('wrong field type', () {
      _rejects(_with((m) => m['tier'] = '1'), 'tier', 'whole number');
      _rejects(_with((m) => m['title'] = 5), 'title', 'Must be text');
      _rejects(_with((m) => m['io'] = []), 'io', 'Must be an object');
      _rejects(_with((m) => m['hints'] = 'one'), 'hints', 'Must be a list');
    });

    test('identifiers follow one spelling', () {
      _rejects(_with((m) => m['id'] = 'Bad Id'), 'id', 'lower_snake_case');
      _rejects(_with((m) => m['chapter'] = 'Chapter 1'), 'chapter', 'lower_snake_case');
    });

    test('invalid mode', () {
      _rejects(_with((m) => m['mode'] = 'speedrun'), 'mode', 'Must be one of build');
    });

    test('invalid tier', () {
      _rejects(_with((m) => m['tier'] = 7), 'tier', 'from 1 to 5');
      _rejects(_with((m) => m['tier'] = 0), 'tier', 'from 1 to 5');
    });

    test('invalid limits', () {
      _rejects(_with((m) => m['limits'] = {'maxOps': 0}), 'limits.maxOps', 'from 1');
      _rejects(
        _with((m) => m['limits'] = {'maxOps': 20000000}),
        'limits.maxOps',
        'to 10000000',
      );
      _rejects(
        _with((m) => m['limits'] = {'maxOps': 10, 'maxDepth': 'deep'}),
        'limits.maxDepth',
        'whole number',
      );
      _rejects(
        _with((m) => m['limits'] = {'maxOps': 10.5}),
        'limits.maxOps',
        'whole number',
      );
    });

    test('constraints must be consistent', () {
      _rejects(
        _with((m) => m['constraints'] = {
              'n': {'min': 5, 'max': 1},
            }),
        'constraints.n',
        'larger than max',
      );
    });

    test('invalid JSON text', () {
      final read = readPuzzleJson('{"id": ');
      expect(read.ok, isFalse);
      expect(read.issues.single.message, contains('Not valid JSON'));
    });

    test('a puzzle is an object', () {
      expect(readPuzzleJson('[1, 2]').issues.single.message, contains('JSON object'));
    });
  });

  group('closed schema', () {
    test('unknown top-level field', () {
      _rejects(_with((m) => m['difficulty'] = 3), 'difficulty', 'Unknown field "difficulty"');
    });

    test('unknown nested field', () {
      _rejects(
        _with((m) => (m['limits'] as Map)['timeout'] = 5),
        'limits.timeout',
        'Unknown field',
      );
      _rejects(
        _with((m) => _visible(m)['note'] = 'x'),
        'fixtures.visible[0].note',
        'Unknown field',
      );
    });

    test('code-shaped fields are refused as code', () {
      _rejects(
        _with((m) => m['generator'] = 'random list of 10'),
        'generator',
        'data only',
      );
      _rejects(
        _with((m) => m['validators'] = {'output': 'equal', 'predicate': 'a == b'}),
        'validators.predicate',
        'data only',
      );
    });

    test('reference metadata is closed and never carries the solution', () {
      _rejects(_with((m) => m['reference'] = {'strategy': 'Two Sum'}), 'reference.strategy',
          'lower_snake_case');
      _rejects(_with((m) => m['reference'] = {}), 'reference.strategy', 'Required');
      _rejects(
        _with((m) => m['reference'] = {'strategy': 'bfs', 'solution': {'blocks': {}}}),
        'reference.solution',
        'Unknown field',
      );
    });

    test('meta holds only flat values', () {
      _rejects(
        _with((m) => m['meta'] = {
              'nested': {'a': 1},
            }),
        'meta.nested',
        'only text, numbers and true/false',
      );
    });
  });

  group('blocks', () {
    test('unknown block', () {
      _rejects(
        _with((m) => ((m['blocks'] as Map)['allow'] as List).add('arr.nope')),
        'blocks.allow[3]',
        'Unknown block "arr.nope"',
      );
    });

    test('malformed allowlist', () {
      _rejects(_with((m) => m['blocks'] = {'allow': 'arr.len'}), 'blocks.allow', 'Must be a list');
      _rejects(_with((m) => m['blocks'] = {'allow': []}), 'blocks.allow', 'at least one block');
      _rejects(
        _with((m) => m['blocks'] = {
              'allow': [1],
            }),
        'blocks.allow[0]',
        'non-empty text',
      );
      _rejects(
        _with((m) => m['blocks'] = {
              'allow': ['arr.len', 'arr.len'],
            }),
        'blocks.allow[1]',
        'listed twice',
      );
      _rejects(
        _with((m) => (m['blocks'] as Map)['forbid'] = ['arr.len']),
        'blocks.forbid[0]',
        'also in blocks.allow',
      );
      _rejects(
        _with((m) => (m['blocks'] as Map)['maxBlocks'] = 0),
        'blocks.maxBlocks',
        'from 1',
      );
    });

    test('FLOOR DIVIDE is a valid block to allow', () {
      final read = readPuzzleJson(jsonEncode(_with(
        (m) => ((m['blocks'] as Map)['allow'] as List).add('arith.floor_div'),
      )));
      expect(read.issues, isEmpty);
    });
  });

  group('io', () {
    test('types must parse and have a fixture form', () {
      _rejects(
        _with((m) => (((m['io'] as Map)['inputs'] as List).first as Map)['type'] = 'tensor'),
        'io.inputs[0].type',
        'Unknown type',
      );
      _rejects(
        _with((m) => (((m['io'] as Map)['inputs'] as List).first as Map)['type'] = 'heap<num>'),
        'io.inputs[0].type',
        'no fixture format',
      );
      _rejects(
        _with((m) => ((m['io'] as Map)['output'] as Map)['type'] = 'void'),
        'io.output.type',
        'void is not a value',
      );
    });

    test('input names are unique', () {
      _rejects(
        _with((m) => ((m['io'] as Map)['inputs'] as List).add({'name': 'nums', 'type': 'num'})),
        'io.inputs[1].name',
        'already used',
      );
    });

    test('variable pool cannot shadow an input or hold void', () {
      _rejects(
        _with((m) => m['variables'] = {
              'pool': [
                {'name': 'nums', 'type': 'num'},
              ],
            }),
        'variables.pool[0].name',
        'already an input',
      );
      _rejects(
        _with((m) => m['variables'] = {
              'pool': [
                {'name': 'x', 'type': 'void'},
              ],
            }),
        'variables.pool[0].type',
        'void',
      );
    });
  });

  group('fixtures', () {
    test('malformed fixture', () {
      _rejects(_with((m) => _visible(m).remove('out')), 'fixtures.visible[0].out', 'Required');
      _rejects(_with((m) => _visible(m)['in'] = [1]), 'fixtures.visible[0].in', 'Must be an object');
      _rejects(
        _with((m) => (m['fixtures'] as Map)['visible'] = []),
        'fixtures.visible',
        'at least one case',
      );
      _rejects(
        _with((m) => (((m['fixtures'] as Map)['hidden'] as List).first as Map)['id'] = 'v1'),
        'fixtures.hidden[0].id',
        'already used',
      );
    });

    test('fixture input type mismatch', () {
      _rejects(
        _with((m) => (_visible(m)['in'] as Map)['nums'] = 'hello'),
        'fixtures.visible[0].in.nums',
        'Expected array<num>, got the text "hello"',
      );
      _rejects(
        _with((m) => (_visible(m)['in'] as Map)['nums'] = [1, 'x']),
        'fixtures.visible[0].in.nums[1]',
        'Expected num',
      );
    });

    test('fixture inputs match the declared inputs exactly', () {
      _rejects(_with((m) => _visible(m)['in'] = {}), 'fixtures.visible[0].in.nums', 'Missing input');
      _rejects(
        _with((m) => (_visible(m)['in'] as Map)['k'] = 1),
        'fixtures.visible[0].in.k',
        'Not an input',
      );
    });

    test('output type mismatch', () {
      _rejects(_with((m) => _visible(m)['out'] = '2'), 'fixtures.visible[0].out', 'Expected num');
      _rejects(
        _with((m) => _visible(m)['out'] = null),
        'fixtures.visible[0].out',
        'Expected num, got null',
      );
    });

    test('invalid structured node', () {
      final json = _with((m) {
        m['io'] = {
          'inputs': [
            {'name': 'root', 'type': 'treeNode'},
          ],
          'output': {'type': 'num'},
        };
        _visible(m)['in'] = {
          'root': {'type': 'treeNode', 'value': 'x'},
        };
        (((m['fixtures'] as Map)['hidden'] as List).first as Map)['in'] = {
          'root': {'type': 'treeNode', 'value': 1},
        };
      });
      _rejects(json, 'fixtures.visible[0].in.root.value', 'Expected a number');
    });

    test('invalid graph reference', () {
      final json = _with((m) {
        m['io'] = {
          'inputs': [
            {'name': 'g', 'type': 'graph'},
          ],
          'output': {'type': 'num'},
        };
        _visible(m)['in'] = {
          'g': {
            'type': 'graph',
            'nodes': [
              {'id': 0, 'neighbors': [9]},
            ],
          },
        };
        (((m['fixtures'] as Map)['hidden'] as List).first as Map)['in'] = {
          'g': {
            'type': 'graph',
            'nodes': [
              {'id': 0},
            ],
          },
        };
      });
      _rejects(json, 'fixtures.visible[0].in.g.nodes[0].neighbors[0]', 'No node has id 9');
    });
  });

  group('validators', () {
    test('unknown validator', () {
      _rejects(
        _with((m) => m['validators'] = {'output': 'bogus'}),
        'validators.output',
        'Must be one of equal',
      );
    });

    test('a validator must fit the declared output', () {
      _rejects(
        _with((m) => m['validators'] = {'output': 'treeEqual'}),
        'validators.output',
        'needs a treeNode',
      );
      _rejects(
        _with((m) => m['validators'] = {'output': 'unorderedArray'}),
        'validators.output',
        'list-like output',
      );
      _rejects(
        _with((m) => m['validators'] = {'output': 'unorderedPairs'}),
        'validators.output',
        'array of arrays',
      );
    });

    test('order "any" needs an order-free validator', () {
      _rejects(
        _with((m) => ((m['io'] as Map)['output'] as Map)['order'] = 'any'),
        'io.output.order',
        'order-free validator',
      );
    });

    test('compatibility table', () {
      final numType = ValueType.number;
      final array = ValueType.array(ValueType.number);
      final pairs = ValueType.array(array);
      final set = ValueType.setOf(ValueType.number);
      expect(validatorAccepts(ValidatorId.equal, numType), isTrue);
      expect(validatorAccepts(ValidatorId.unorderedArray, array), isTrue);
      expect(validatorAccepts(ValidatorId.unorderedArray, set), isTrue);
      expect(validatorAccepts(ValidatorId.setEqual, set), isTrue);
      expect(validatorAccepts(ValidatorId.setEqual, ValueType.listNode), isFalse);
      expect(validatorAccepts(ValidatorId.unorderedPairs, pairs), isTrue);
      expect(validatorAccepts(ValidatorId.unorderedPairs, array), isFalse);
      expect(validatorAccepts(ValidatorId.listEqualByValue, ValueType.listNode.asNullable), isTrue);
      expect(validatorAccepts(ValidatorId.treeEqual, ValueType.treeNode), isTrue);
      expect(validatorAccepts(ValidatorId.treeEqual, array), isFalse);
    });
  });

  group('worlds manifest', () {
    const valid = '''
{"worlds": [
  {"id": "world_01", "title": "A", "index": 1, "concepts": ["arrays"], "puzzles": ["p1"]},
  {"id": "world_02", "title": "B", "index": 2, "prerequisites": ["arrays"], "puzzles": []}
]}
''';

    test('a valid manifest loads', () {
      final read = readWorldsJson(valid);
      expect(read.issues, isEmpty);
      expect(read.manifest!.byId('world_01')!.puzzleIds, ['p1']);
    });

    test('duplicate world id and index', () {
      final read = readWorldsJson('''
{"worlds": [
  {"id": "world_01", "title": "A", "index": 1},
  {"id": "world_01", "title": "B", "index": 1}
]}
''');
      expect(read.ok, isFalse);
      expect(read.issues.map((i) => i.path), containsAll(['worlds[1].id', 'worlds[1].index']));
    });

    test('a puzzle listed by two worlds', () {
      final read = readWorldsJson('''
{"worlds": [
  {"id": "world_01", "title": "A", "index": 1, "puzzles": ["p1"]},
  {"id": "world_02", "title": "B", "index": 2, "puzzles": ["p1"]}
]}
''');
      expect(read.issues.single.path, 'worlds[1].puzzles[0]');
    });

    test('unknown world field', () {
      final read = readWorldsJson('{"worlds": [{"id": "w", "title": "A", "index": 1, "color": "red"}]}');
      expect(read.issues.single.path, 'worlds[0].color');
    });
  });
}
