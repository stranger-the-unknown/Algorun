import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// JSON → value → JSON → value, and every step agrees.
void _roundTrip(Object? json, {Object? canonical, ValueType? type}) {
  final expected = canonical ?? json;
  final first = valueFromJson(json, type: type);
  final written = valueToJson(first);
  expect(written, expected, reason: 'canonical form');
  final second = valueFromJson(written, type: type);
  expect(valuesEqual(first, second), isTrue, reason: 'value survives');
  expect(valueToJson(second), written, reason: 'second trip is stable');
}

Matcher _fails(String path, String fragment) => throwsA(
      isA<FixtureFormatException>()
          .having((e) => e.path, 'path', path)
          .having((e) => e.message, 'message', contains(fragment)),
    );

void main() {
  group('round trips', () {
    test('num', () {
      _roundTrip(3);
      _roundTrip(-2.5);
      _roundTrip(0, type: ValueType.number);
      expect(valueFromJson(3), isA<NumValue>());
    });

    test('bool', () {
      _roundTrip(true);
      _roundTrip(false, type: ValueType.boolean);
    });

    test('str', () {
      _roundTrip('hello');
      _roundTrip('', type: ValueType.string);
    });

    test('null', () {
      _roundTrip(null);
      _roundTrip(null, type: ValueType.number.asNullable);
      expect(valueFromJson(null), isA<NilValue>());
    });

    test('array, nested', () {
      _roundTrip([1, 2, 3]);
      _roundTrip([
        [1, 2],
        [],
        [3],
      ], type: ValueType.array(ValueType.array(ValueType.number)));
      final typed = valueFromJson([1], type: ValueType.array(ValueType.number));
      expect((typed as ArrayValue).elementType, ValueType.number);
    });

    test('map keeps entry order and key types', () {
      final json = {
        'type': 'map',
        'entries': [
          ['b', 2],
          ['a', 1],
        ],
      };
      _roundTrip(json, type: ValueType.mapOf(ValueType.string, ValueType.number));
      final numeric = {
        'type': 'map',
        'entries': [
          [3, true],
          [1, false],
        ],
      };
      _roundTrip(numeric);
      final value = valueFromJson(numeric) as MapValue;
      expect(value.entries.keys, [3, 1]);
    });

    test('set', () {
      _roundTrip({
        'type': 'set',
        'items': [3, 1, 2],
      }, type: ValueType.setOf(ValueType.number));
      _roundTrip({'type': 'set', 'items': <Object?>[]});
    });

    test('stack, queue, deque', () {
      for (final tag in ['stack', 'queue', 'deque']) {
        _roundTrip({
          'type': tag,
          'items': [1, 2, 3],
        });
      }
      final stack = valueFromJson({
        'type': 'stack',
        'items': [1, 2, 3],
      }) as StackValue;
      expect((stack.items.last as NumValue).value, 3, reason: 'last item is the top');
    });

    test('linked list', () {
      _roundTrip({
        'type': 'listNode',
        'values': [1, 2, 3],
      }, type: ValueType.listNode);
      final head = valueFromJson({
        'type': 'listNode',
        'values': [1, 2],
      }) as ListNodeValue;
      expect(head.value, 1);
      expect(head.next!.value, 2);
      expect(head.next!.next, isNull);
    });

    test('linked list with a cycle', () {
      final json = {
        'type': 'listNode',
        'values': [3, 2, 0, -4],
        'cycleTo': 1,
      };
      _roundTrip(json);
      final head = valueFromJson(json) as ListNodeValue;
      final tail = head.next!.next!.next!;
      expect(identical(tail.next, head.next), isTrue);
    });

    test('tree, and omitted children written back as null', () {
      final written = {
        'type': 'treeNode',
        'value': 2,
        'left': {'type': 'treeNode', 'value': 1, 'left': null, 'right': null},
        'right': {'type': 'treeNode', 'value': 3, 'left': null, 'right': null},
      };
      _roundTrip(written, type: ValueType.treeNode);
      final shorthand = {
        'type': 'treeNode',
        'value': 2,
        'left': {'type': 'treeNode', 'value': 1},
        'right': {'type': 'treeNode', 'value': 3},
      };
      _roundTrip(shorthand, canonical: written);
    });

    test('graph with a cycle and a self-loop', () {
      _roundTrip({
        'type': 'graph',
        'nodes': [
          {'id': 0, 'neighbors': [1]},
          {'id': 1, 'neighbors': [2]},
          {'id': 2, 'neighbors': [0, 2]},
        ],
      }, type: ValueType.graph);
    });

    test('graph visited marks, written sorted', () {
      _roundTrip({
        'type': 'graph',
        'nodes': [
          {'id': 0, 'neighbors': <Object?>[]},
          {'id': 1, 'neighbors': <Object?>[]},
        ],
        'visited': [1, 0],
      }, canonical: {
        'type': 'graph',
        'nodes': [
          {'id': 0, 'neighbors': <Object?>[]},
          {'id': 1, 'neighbors': <Object?>[]},
        ],
        'visited': [0, 1],
      });
    });

    test('graph node without neighbors is written with an empty list', () {
      _roundTrip({
        'type': 'graph',
        'nodes': [
          {'id': 7},
        ],
      }, canonical: {
        'type': 'graph',
        'nodes': [
          {'id': 7, 'neighbors': <Object?>[]},
        ],
      });
    });

    test('structures nest inside each other', () {
      _roundTrip([
        {'type': 'listNode', 'values': [1]},
        null,
        {
          'type': 'map',
          'entries': [
            ['k', {'type': 'set', 'items': [1]}],
          ],
        },
      ]);
    });

    test('runtime-built values encode the same way', () {
      final a = ListNodeValue(1, next: ListNodeValue(2));
      expect(valueToJson(a), {'type': 'listNode', 'values': [1, 2]});
      final graph = GraphValue({1: [2], 2: []}, visited: {2, 1});
      expect(valueToJson(graph), {
        'type': 'graph',
        'nodes': [
          {'id': 1, 'neighbors': [2]},
          {'id': 2, 'neighbors': <Object?>[]},
        ],
        'visited': [1, 2],
      });
    });
  });

  group('format errors fail cleanly', () {
    test('an untagged object is not a map', () {
      expect(() => valueFromJson({'a': 1}), _fails(r'$', 'must name its "type"'));
    });

    test('unknown tag', () {
      expect(
        () => valueFromJson({'type': 'heap', 'items': []}),
        _fails(r'$.type', 'Unknown type "heap"'),
      );
    });

    test('unknown field on a tagged value', () {
      expect(
        () => valueFromJson({'type': 'set', 'items': [], 'size': 0}),
        _fails(r'$.size', 'Unknown field "size"'),
      );
    });

    test('wrong field types', () {
      expect(
        () => valueFromJson({'type': 'stack', 'items': 'abc'}),
        _fails(r'$.items', 'must be a list'),
      );
      expect(
        () => valueFromJson({'type': 'treeNode', 'value': 'x'}),
        _fails(r'$.value', 'Expected a number'),
      );
    });

    test('duplicate set item and duplicate map key', () {
      expect(
        () => valueFromJson({'type': 'set', 'items': [1, 1]}),
        _fails(r'$.items[1]', 'Duplicate set item'),
      );
      expect(
        () => valueFromJson({
          'type': 'map',
          'entries': [
            ['a', 1],
            ['a', 2],
          ],
        }),
        _fails(r'$.entries[1][0]', 'Duplicate key'),
      );
    });

    test('map entries are pairs with simple keys', () {
      expect(
        () => valueFromJson({
          'type': 'map',
          'entries': [
            ['a'],
          ],
        }),
        _fails(r'$.entries[0]', '[key, value] pair'),
      );
      expect(
        () => valueFromJson({
          'type': 'map',
          'entries': [
            [
              [1],
              2,
            ],
          ],
        }),
        _fails(r'$.entries[0][0]', 'must be a number, text or true/false'),
      );
    });

    test('linked list: empty, bad cycle', () {
      expect(
        () => valueFromJson({'type': 'listNode', 'values': []}),
        _fails(r'$.values', 'An empty list is null'),
      );
      expect(
        () => valueFromJson({'type': 'listNode', 'values': [1, 2], 'cycleTo': 2}),
        _fails(r'$.cycleTo', 'from 0 to 1'),
      );
    });

    test('tree child must be a tree', () {
      expect(
        () => valueFromJson({
          'type': 'treeNode',
          'value': 1,
          'left': {'type': 'listNode', 'values': [1]},
        }),
        _fails(r'$.left', 'Expected treeNode, got a listNode'),
      );
      expect(
        () => valueFromJson({'type': 'treeNode'}),
        _fails(r'$.value', 'needs a value'),
      );
    });

    test('graph: duplicate id, missing reference, bad visited', () {
      expect(
        () => valueFromJson({
          'type': 'graph',
          'nodes': [
            {'id': 0},
            {'id': 0},
          ],
        }),
        _fails(r'$.nodes[1].id', 'Duplicate node id 0'),
      );
      expect(
        () => valueFromJson({
          'type': 'graph',
          'nodes': [
            {'id': 0, 'neighbors': [5]},
          ],
        }),
        _fails(r'$.nodes[0].neighbors[0]', 'No node has id 5'),
      );
      expect(
        () => valueFromJson({
          'type': 'graph',
          'nodes': [
            {'id': 0},
          ],
          'visited': [9],
        }),
        _fails(r'$.visited[0]', 'No node has id 9'),
      );
      expect(
        () => valueFromJson({
          'type': 'graph',
          'nodes': [
            {'id': 0},
          ],
          'visited': [0, 0],
        }),
        _fails(r'$.visited[1]', 'marked twice'),
      );
    });

    test('numbers must be finite', () {
      expect(() => valueFromJson(double.infinity), _fails(r'$', 'finite'));
    });

    test('something that is not JSON', () {
      expect(() => valueFromJson(DateTime(2026)), _fails(r'$', 'Not a JSON value'));
    });
  });

  group('typed decoding', () {
    test('a value must match its declared type', () {
      expect(
        () => valueFromJson('hello', type: ValueType.number),
        _fails(r'$', 'Expected num, got the text "hello"'),
      );
      expect(
        () => valueFromJson([1, 'x'], type: ValueType.array(ValueType.number)),
        _fails(r'$[1]', 'Expected num'),
      );
    });

    test('nullability is checked', () {
      expect(
        () => valueFromJson(null, type: ValueType.listNode),
        _fails(r'$', 'Expected listNode, got null'),
      );
      expect(valueFromJson(null, type: ValueType.listNode.asNullable), isA<NilValue>());
    });

    test('a set is never guessed from a plain array', () {
      expect(
        () => valueFromJson([1, 2], type: ValueType.setOf(ValueType.number)),
        _fails(r'$', 'Expected set<num>, got a list'),
      );
    });

    test('tags must match the declared type', () {
      expect(
        () => valueFromJson({'type': 'queue', 'items': []},
            type: ValueType.stackOf(ValueType.number)),
        _fails(r'$', 'Expected stack<num>, got a queue'),
      );
    });

    test('map keys and values are typed', () {
      expect(
        () => valueFromJson({
          'type': 'map',
          'entries': [
            [1, 2],
          ],
        }, type: ValueType.mapOf(ValueType.string, ValueType.number)),
        _fails(r'$.entries[0][0]', 'Expected str'),
      );
    });
  });

  group('limits', () {
    test('too many values', () {
      expect(
        () => valueFromJson(
          List.filled(20, 0),
          limits: const FixtureLimits(maxValues: 10),
        ),
        _fails(r'$[9]', 'More than 10 values'),
      );
    });

    test('too deep', () {
      Object? nested = 1;
      for (var i = 0; i < 20; i++) {
        nested = [nested];
      }
      expect(
        () => valueFromJson(nested, limits: const FixtureLimits(maxDepth: 5)),
        throwsA(isA<FixtureFormatException>()
            .having((e) => e.message, 'message', contains('deeper than 5'))),
      );
    });

    test('a long linked list counts every node', () {
      expect(
        () => valueFromJson(
          {'type': 'listNode', 'values': List.filled(50, 1)},
          limits: const FixtureLimits(maxValues: 10),
        ),
        throwsA(isA<FixtureFormatException>()),
      );
    });

    test('the standard limits admit a skewed tree hundreds deep', () {
      Object? tree;
      for (var i = 0; i < 400; i++) {
        tree = {'type': 'treeNode', 'value': i, 'left': tree};
      }
      final value = valueFromJson(tree);
      expect(value, isA<TreeNodeValue>());
    });
  });

  group('encoding refuses what the format cannot hold', () {
    test('a tree that contains itself', () {
      final root = TreeNodeValue(1);
      root.left = root;
      expect(() => valueToJson(root), _fails(r'$.left', 'cannot contain itself'));
    });

    test('a graph that marked a node it does not have', () {
      final graph = GraphValue({0: []}, visited: {7});
      expect(() => valueToJson(graph), _fails(r'$.visited', 'not in the graph'));
    });
  });

  group('fixture types', () {
    test('io types that have a fixture form', () {
      for (final spec in [
        'num',
        'bool',
        'str',
        'array<num>',
        'array<array<str>>',
        'map<str,num>',
        'set<num>',
        'stack<num>',
        'queue<bool>',
        'deque<num>',
        'listNode?',
        'treeNode',
        'graph',
      ]) {
        expect(fixtureTypeProblem(parseValueType(spec)), isNull, reason: spec);
      }
    });

    test('io types that do not', () {
      expect(fixtureTypeProblem(parseValueType('void')), contains('void'));
      expect(fixtureTypeProblem(parseValueType('heap<num>')), contains('no fixture format'));
      expect(fixtureTypeProblem(parseValueType('set<array<num>>')), contains('Set items'));
      expect(fixtureTypeProblem(parseValueType('map<num?,num>')), contains('Map keys'));
    });
  });
}
