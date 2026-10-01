import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart' show readWorldsJson;
import 'package:test/test.dart';

/// The shipped oracles plus one for the test puzzle below (`return LENGTH OF nums`).
const _validator = ContentValidator(checker: ReferenceChecker(oracles: {...oracleRegistry, 'count_items': _countOracle}));

const _countOracle = Oracle(id: 'count_items', solve: _countItems, sample: _countSample);

Object? _countItems(Map<String, Object?> input) => (input['nums']! as List).length;

Map<String, Object?> _countSample(Random r) => {'nums': [for (var i = r.nextInt(6); i > 0; i--) r.nextInt(9)]};

/// A campaign puzzle's spec, as the test reference files carry it.
const _spec = {
  'family': 'array_scan',
  'pattern': 'count_items',
  'structure': 'array',
  'secondary': <String>[],
  'performance': 'correctness',
  'traps': ['an empty list'],
  'oracle': 'count_items',
};

String _puzzle({
  String id = 'p1',
  String world = 'world_01',
  String allow = '["ctrl.return", "arr.len", "var.get"]',
  String hints = '["Count them."]',
  String visibleIn = '{ "nums": [1, 2, 3] }',
  String extra = '',
}) =>
    '''
{
  "id": "$id",
  "title": "Probe",
  "world": "$world",
  "tier": 1,
  "mode": "build",
  "story": "Count the numbers.",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": $allow },
  "limits": { "maxOps": 1000 },
  "hints": $hints,
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": $visibleIn, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }$extra
}
''';

String _worlds(Map<String, List<String>> puzzles) => jsonEncode({
      'worlds': [
        for (final (i, entry) in puzzles.entries.indexed)
          {
            'id': entry.key,
            'title': entry.key,
            'index': i + 1,
            'concepts': ['c${i + 1}'],
            'puzzles': entry.value,
          },
      ],
    });

List<ContentFile> _files(String dir) {
  final root = Directory(dir);
  return [
    for (final f in root.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.json'))
        ContentFile(
          f.absolute.uri.path.substring(root.absolute.uri.path.length),
          f.readAsStringSync(),
        ),
  ];
}

/// A playable one-puzzle content set — `return LENGTH OF nums` — listed by a
/// world, with a reference file built from [solution] and [rejects].
ContentReport _referenced({
  String allow = '["ctrl.return", "arr.len", "var.get", "lit.num", "var.set"]',
  String limits = '{ "maxOps": 1000 }',
  String maxBlocks = '',
  String pool = '',
  Map<String, Object?>? solution,
  List<Object?>? rejects,
  Map<String, Object?>? reference,
  String? referenceSource,
  bool withMetadata = true,
  List<ContentFile> extraReferences = const [],
  String hidden = '[{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]',
  String extra = '',
}) {
  final metadata = withMetadata ? ',\n  "reference": { "strategy": "count_items" }' : '';
  final budget = maxBlocks.isEmpty ? '' : ', "maxBlocks": $maxBlocks';
  final variables = pool.isEmpty ? '' : ',\n  "variables": { "pool": $pool }';
  final source = '''
{
  "id": "p1", "title": "Probe", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Count the numbers.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": $allow$budget },
  "limits": $limits,
  "hints": ["Count them."],
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": $hidden
  }$metadata$variables$extra
}
''';
  final file = referenceSource ??
      jsonEncode(reference ??
          {
            'puzzle': 'p1',
            'notes': 'Count the list.',
            'spec': _spec,
            'solution': solution ?? _lengthGraph(),
            'rejects': ?rejects,
          });
  return _validator.validateContent(
    puzzles: [ContentFile('world_01/p1.json', source)],
    worldsSource: _worlds({
      'world_01': ['p1'],
    }),
    references: withMetadata
        ? [ContentFile('world_01/p1.json', file), ...extraReferences]
        : extraReferences,
  );
}

Map<String, Object?> _block(
  String id,
  String catalogId, {
  Map<String, String> slots = const {},
  Map<String, Object?> literals = const {},
}) =>
    {
      'id': id,
      'catalogId': catalogId,
      'slots': {for (final e in slots.entries) e.key: {'ref': e.value}},
      'literals': literals,
    };

/// `return LENGTH OF nums`, as the editor would save it.
Map<String, Object?> _lengthGraph({Map<String, Object?> lenLiterals = const {}}) => {
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'len'}),
        'len': _block('len', 'arr.len', slots: {'array': 'nums'}, literals: lenLiterals),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
      },
    };

/// `return <value>`: right on the visible case when value is 3.
Map<String, Object?> _constantGraph(int value) => {
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'n'}),
        'n': _block('n', 'lit.num', literals: {'value': value}),
      },
    };

/// `c = 0; for i in 0..LENGTH: c = c + 1; return c` — right, but 2 + 4 + 5n + 2
/// operations instead of 3. Needs "c" and "i" from the pool.
Map<String, Object?> _countingGraph() => {
      'variables': {'nums': 'array<num>', 'c': 'num', 'i': 'num'},
      'entryIds': ['start', 'loop', 'ret'],
      'blocks': {
        'start': _block('start', 'var.set', slots: {'value': 'zero'}, literals: {'name': 'c'}),
        'zero': _block('zero', 'lit.num', literals: {'value': 0}),
        'loop': {
          'id': 'loop',
          'catalogId': 'ctrl.for_range',
          'literals': {'name': 'i'},
          'slots': {
            'start': {'ref': 'from'},
            'end': {'ref': 'len'},
            'body': {
              'list': ['step'],
            },
          },
        },
        'from': _block('from', 'lit.num', literals: {'value': 0}),
        'len': _block('len', 'arr.len', slots: {'array': 'nums'}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
        'step': _block('step', 'var.set', slots: {'value': 'add'}, literals: {'name': 'c'}),
        'add': _block('add', 'arith.add', slots: {'left': 'c1', 'right': 'one'}),
        'c1': _block('c1', 'var.get', literals: {'name': 'c'}),
        'one': _block('one', 'lit.num', literals: {'value': 1}),
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'c2'}),
        'c2': _block('c2', 'var.get', literals: {'name': 'c'}),
      },
    };

/// `x = LENGTH OF nums; return x`: needs "x" from the variable pool.
Map<String, Object?> _namedGraph() => {
      'variables': {'nums': 'array<num>', 'x': 'num'},
      'entryIds': ['set', 'ret'],
      'blocks': {
        'set': _block('set', 'var.set', slots: {'value': 'len'}, literals: {'name': 'x'}),
        'len': _block('len', 'arr.len', slots: {'array': 'nums'}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'x'}),
        'x': _block('x', 'var.get', literals: {'name': 'x'}),
      },
    };

bool _has(ContentReport report, Severity severity, String file, String path, String fragment) {
  return report.issues.any((i) =>
      i.severity == severity &&
      i.file == file &&
      i.path == path &&
      i.message.contains(fragment));
}

void main() {
  group('shipped content', () {
    test('every current asset passes', () {
      final root = Directory('../../assets/puzzles');
      final files = [
        for (final f in root.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.json'))
            ContentFile(
              f.absolute.uri.path.substring(root.absolute.uri.path.length),
              f.readAsStringSync(),
            ),
      ];
      final report = _validator.validateContent(
        puzzles: files,
        worldsSource: File('../../assets/worlds.json').readAsStringSync(),
        references: _files('../../content/references'),
      );
      expect(report.errors, isEmpty, reason: report.issues.join('\n'));
      expect(report.puzzleCount, 130);
    });

    test('every playable puzzle has a reference file', () {
      final worlds = readWorldsJson(File('../../assets/worlds.json').readAsStringSync()).manifest!;
      final playable = [
        for (final w in worlds.worlds)
          for (final id in w.puzzleIds) '${w.id}/$id.json',
      ];
      expect(playable, hasLength(125));
      expect(_files('../../content/references').map((r) => r.path), containsAll(playable));
    });
  });

  group('one puzzle', () {
    test('accepts a well-formed puzzle', () {
      final report = _validator.validatePuzzleSource(_puzzle());
      expect(report.ok, isTrue);
      expect(report.issues, isEmpty);
      expect(report.puzzleCount, 1);
    });

    test('rejects an unknown block with where and why', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(allow: '["ctrl.return", "not.real"]'),
        file: 'world_01/p1.json',
      );
      expect(report.ok, isFalse);
      expect(_has(report, Severity.error, 'world_01/p1.json', 'blocks.allow[1]', 'Unknown block "not.real"'), isTrue);
    });

    test('missing hints is advice, not an error', () {
      final report = _validator.validatePuzzleSource(_puzzle(hints: '[]'));
      expect(report.ok, isTrue);
      expect(_has(report, Severity.warning, 'puzzle.json', 'hints', 'No hints'), isTrue);
    });

    test('hints that leak internals are flagged', () {
      final report = _validator.validatePuzzleSource(_puzzle(
        hints: '["Use arr.len on the list.", "Think about hidden_edge first."]',
      ).replaceFirst('"id": "h1"', '"id": "hidden_edge"'));
      expect(report.ok, isTrue, reason: 'advice, not an error');
      expect(_has(report, Severity.warning, 'puzzle.json', 'hints[0]', 'say LENGTH instead'), isTrue);
      expect(_has(report, Severity.warning, 'puzzle.json', 'hints[1]', 'hidden case "hidden_edge"'), isTrue);
    });

    test('unplayable function blocks are flagged', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(allow: '["ctrl.return", "fn.call"]'),
      );
      expect(report.ok, isTrue);
      expect(report.warnings.single.message, contains('fn.call'));
    });

    test('a malformed fixture fails with a path into the value', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(visibleIn: '{ "nums": [1, "two", 3] }'),
      );
      expect(report.ok, isFalse);
      expect(_has(report, Severity.error, 'puzzle.json', 'fixtures.visible[0].in.nums[1]', 'Expected num'), isTrue);
    });
  });

  group('the content set', () {
    test('duplicate puzzle ids', () {
      final report = _validator.validateContent(puzzles: [
        ContentFile('world_01/p1.json', _puzzle()),
        ContentFile('world_01/copy.json', _puzzle()),
      ]);
      expect(_has(report, Severity.error, 'world_01/p1.json', 'id', 'also used by world_01/copy.json'), isTrue);
    });

    test('a puzzle must sit where the game loads it from', () {
      final report = _validator.validateContent(puzzles: [
        ContentFile('world_02/p1.json', _puzzle()),
      ]);
      expect(_has(report, Severity.error, 'world_02/p1.json', '', 'loads this puzzle from world_01/p1.json'), isTrue);
    });

    test('a world that lists a missing puzzle', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({
          'world_01': ['p1', 'ghost'],
        }),
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[0].puzzles[1]', 'no valid puzzle has that id'), isTrue);
    });

    test('a puzzle whose world does not exist', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_09/p1.json', _puzzle(world: 'world_09'))],
        worldsSource: _worlds({'world_01': []}),
      );
      expect(_has(report, Severity.error, 'world_09/p1.json', 'world', 'not in the worlds manifest'), isTrue);
    });

    test('a puzzle listed by the wrong world', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({
          'world_01': [],
          'world_02': ['p1'],
        }),
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[1].puzzles[0]', 'belongs to world_01'), isTrue);
    });

    test('a puzzle no world lists is a warning', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({'world_01': []}),
      );
      expect(report.ok, isTrue);
      expect(_has(report, Severity.warning, 'world_01/p1.json', '', 'no player can reach it'), isTrue);
    });

    test('a malformed manifest', () {
      final report = _validator.validateContent(
        puzzles: const [],
        worldsSource: '{"worlds": [{"id": "world_01", "title": "A"}]}',
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[0].index', 'Required'), isTrue);
    });

    test('the report does not depend on file order', () {
      final files = [
        ContentFile('world_01/b.json', _puzzle(id: 'b', allow: '["nope.x"]')),
        ContentFile('world_01/a.json', _puzzle(id: 'a', hints: '[]')),
      ];
      final forward = _validator.validateContent(puzzles: files);
      final backward = _validator.validateContent(puzzles: files.reversed.toList());
      expect(
        forward.issues.map((i) => '$i').toList(),
        backward.issues.map((i) => '$i').toList(),
      );
    });
  });

  group('reference solutions', () {
    const file = 'references/world_01/p1.json';

    test('a correct, buildable reference passes', () {
      final report = _referenced();
      expect(report.errors, isEmpty, reason: report.issues.join('\n'));
    });

    test('a playable puzzle without reference metadata is refused', () {
      final report = _referenced(withMetadata: false);
      expect(
        _has(report, Severity.error, 'world_01/p1.json', 'reference', 'needs reference metadata'),
        isTrue,
      );
    });

    test('reference metadata without a reference file is refused', () {
      final report = _validator.validateContent(
        puzzles: [
          ContentFile(
            'world_01/p1.json',
            _puzzle(extra: ',\n  "reference": { "strategy": "count_items" }'),
          ),
        ],
        references: const [],
      );
      expect(
        _has(report, Severity.error, 'world_01/p1.json', 'reference',
            'No reference solution at references/world_01/p1.json'),
        isTrue,
      );
    });

    test('a reference with no puzzle is refused', () {
      final report = _referenced(extraReferences: [const ContentFile('world_09/ghost.json', '{}')]);
      expect(_has(report, Severity.error, 'references/world_09/ghost.json', '', 'No puzzle'), isTrue);
    });

    test('malformed reference files are refused', () {
      expect(
        _has(_referenced(referenceSource: '{"puzzle": '), Severity.error, file, '', 'Not valid JSON'),
        isTrue,
      );
      expect(
        _has(
          _referenced(reference: {
            'puzzle': 'p1',
            'solution': {'blocks': 5},
          }),
          Severity.error,
          file,
          'solution',
          'Not a block graph',
        ),
        isTrue,
      );
      expect(
        _has(
          _referenced(reference: {'puzzle': 'other', 'solution': _lengthGraph()}),
          Severity.error,
          file,
          'puzzle',
          'belongs to "p1"',
        ),
        isTrue,
      );
      expect(
        _has(
          _referenced(reference: {'puzzle': 'p1', 'solution': _lengthGraph(), 'source': 'x => x'}),
          Severity.error,
          file,
          'source',
          'Unknown field',
        ),
        isTrue,
      );
    });

    test('a reference that uses a block the puzzle does not allow', () {
      final report = _referenced(allow: '["ctrl.return", "lit.num", "var.get"]');
      expect(
        _has(report, Severity.error, file, 'solution.blocks.len', 'does not include that block'),
        isTrue,
      );
    });

    test('a reference over the block budget', () {
      final report = _referenced(maxBlocks: '2');
      expect(_has(report, Severity.error, file, 'solution', 'at most 2 blocks'), isTrue);
    });

    test('a reference over the operation budget', () {
      final report = _referenced(limits: '{ "maxOps": 2 }');
      expect(
        _has(report, Severity.error, file, 'solution',
            'The reference does not pass: Operation Limit on visible case "v1"'),
        isTrue,
      );
    });

    test('a reference that gives a wrong answer names the case', () {
      final report = _referenced(solution: _constantGraph(3));
      expect(_has(report, Severity.error, file, 'solution', 'Wrong Answer on hidden case "h1"'), isTrue);
    });

    test('a reference a player could not build', () {
      final unset = _referenced(solution: _lengthGraph(lenLiterals: {'of': 'num'}));
      expect(
        _has(unset, Severity.error, file, 'solution.blocks.len.literals.of', 'cannot set "of"'),
        isTrue,
      );
      final outsidePool = _referenced(solution: _namedGraph());
      expect(
        _has(outsidePool, Severity.error, file, 'solution.variables.x', "not in the puzzle's variable pool"),
        isTrue,
      );
      final inPool = _referenced(solution: _namedGraph(), pool: '[{ "name": "x", "type": "num" }]');
      expect(inPool.errors, isEmpty, reason: inPool.issues.join('\n'));
    });

    test('a reject must end the suite the way it says', () {
      final right = _referenced(rejects: [
        {'name': 'answer three', 'expect': 'wrongAnswer', 'graph': _constantGraph(3)},
      ]);
      expect(right.errors, isEmpty, reason: right.issues.join('\n'));

      final wrongKind = _referenced(rejects: [
        {'name': 'answer three', 'expect': 'operationLimit', 'graph': _constantGraph(3)},
      ]);
      expect(_has(wrongKind, Severity.error, file, 'rejects[0].expect', 'ended in Wrong Answer'), isTrue);
    });

    test('a reject has to look right on the visible cases', () {
      final report = _referenced(rejects: [
        {'name': 'answer zero', 'expect': 'wrongAnswer', 'graph': _constantGraph(0)},
      ]);
      expect(_has(report, Severity.error, file, 'rejects[0]', 'must pass every visible case'), isTrue);
    });

    test('a reject must name a real failure', () {
      final report = _referenced(rejects: [
        {'name': 'x', 'expect': 'correct', 'graph': _constantGraph(3)},
      ]);
      expect(_has(report, Severity.error, file, 'rejects[0].expect', 'Must be one of'), isTrue);
    });
  });

  group('reference performance (MS10)', () {
    const file = 'references/world_01/p1.json';
    const counting = '["ctrl.return", "arr.len", "var.get", "lit.num", "var.set", '
        '"ctrl.for_range", "arith.add"]';
    const pool = '[{ "name": "c", "type": "num" }, { "name": "i", "type": "num" }]';
    // Twenty ones: counting needs 2 + 4 + 100 + 2 = 108 operations, 3.6 × a
    // budget of 30, while the visible case (3 ones, 23 operations) fits.
    final twenty = '[{ "id": "h1", "in": { "nums": [${List.filled(20, 1).join(', ')}] }, "out": 20 }]';

    ContentReport perf(String performance, {List<Object?>? rejects}) => _referenced(
          allow: counting,
          pool: pool,
          limits: '{ "maxOps": 30 }',
          hidden: twenty,
          extra: ',\n  "performance": $performance',
          rejects: rejects,
        );

    final slowBaseline = {'name': 'count one by one', 'expect': 'operationLimit', 'graph': _countingGraph()};

    test('the checker records what the reference costs', () {
      final report = _referenced();
      expect(
        _has(report, Severity.info, file, 'solution',
            'Reference needs 3 of 1000 operations (0%), 0 of 10000 memory cells, depth 1 of 256, 3 blocks.'),
        isTrue,
        reason: report.issues.join('\n'),
      );
      expect(
        _has(report, Severity.warning, file, 'metrics',
            'not recorded. Measured: {"ops":3,"peakAlloc":0,"peakDepth":1,"blocks":3}'),
        isTrue,
      );
    });

    test('recorded metrics must match what is measured', () {
      Map<String, Object?> withMetrics(Map<String, Object?> metrics) => {
            'puzzle': 'p1',
            'spec': _spec,
            'metrics': metrics,
            'solution': _lengthGraph(),
          };
      final same = _referenced(reference: withMetrics({'ops': 3, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 3}));
      expect(same.errors, isEmpty, reason: same.issues.join('\n'));
      expect(same.warnings.where((w) => w.path == 'metrics'), isEmpty);

      final drifted = _referenced(reference: withMetrics({'ops': 4, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 3}));
      expect(_has(drifted, Severity.error, file, 'metrics.ops', 'Recorded 4, measured 3'), isTrue);

      final unknown = _referenced(
        reference: withMetrics({'ops': 3, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 3, 'millis': 12}),
      );
      expect(_has(unknown, Severity.error, file, 'metrics.millis', 'Unknown field'), isTrue);
    });

    test('performance.required needs a correct-but-slow baseline', () {
      final missing = perf('{ "required": true }');
      expect(_has(missing, Severity.error, file, 'rejects', 'performance.required'), isTrue);

      final proven = perf('{ "required": true }', rejects: [slowBaseline]);
      expect(proven.errors, isEmpty, reason: proven.issues.join('\n'));
    });

    test('baselineFactor is checked against the measured baseline', () {
      final met = perf('{ "required": true, "baselineFactor": 3 }', rejects: [slowBaseline]);
      expect(met.errors, isEmpty, reason: met.issues.join('\n'));

      final unmet = perf('{ "required": true, "baselineFactor": 5 }', rejects: [slowBaseline]);
      expect(
        _has(unmet, Severity.error, file, 'rejects[0].expect', 'needs at most 3.6x a case budget'),
        isTrue,
        reason: unmet.issues.join('\n'),
      );
    });

    test('a baseline that is not slow cannot stand in for one', () {
      final report = perf('{ "required": true }', rejects: [
        {'name': 'not slow at all', 'expect': 'operationLimit', 'graph': _lengthGraph()},
      ]);
      expect(_has(report, Severity.error, file, 'rejects[0].expect', 'ended in Correct'), isTrue);
      expect(_has(report, Severity.error, file, 'rejects', 'performance.required'), isTrue);
    });
  });

  group('command line', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('algorun_content_'));
    tearDown(() => temp.deleteSync(recursive: true));

    Future<ProcessResult> validate(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'bin/validate.dart', ...args],
        );

    test('the shipped assets and references pass', () async {
      final result = await validate([
        '../../assets/puzzles',
        '../../assets/worlds.json',
        '../../content/references',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect('${result.stdout}', contains('OK 130 puzzle(s)'));
      expect('${result.stdout}', isNot(contains('ERROR')));
    });

    test('leaving out the references is visible, not silent', () async {
      final result = await validate(['../../assets/puzzles', '../../assets/worlds.json']);
      expect(result.exitCode, 0);
      expect('${result.stdout}', contains('Reference solutions were not checked'));
    });

    test('malformed temporary fixtures fail with useful errors', () async {
      Directory('${temp.path}/world_01').createSync();
      File('${temp.path}/world_01/p1.json').writeAsStringSync(
        _puzzle(
          visibleIn: '{ "nums": "hello" }',
          extra: ',\n  "generator": "random(10)"',
        ),
      );
      File('${temp.path}/worlds.json').writeAsStringSync(_worlds({
        'world_01': ['p1'],
      }));
      final result = await validate([temp.path, '${temp.path}/worlds.json']);
      final out = '${result.stdout}';
      expect(result.exitCode, 1, reason: out);
      expect(out, contains('ERROR [L1 schema] world_01/p1.json fixtures.visible[0].in.nums: Expected array<num>, got the text "hello".'));
      expect(out, contains('ERROR [L1 schema] world_01/p1.json generator: Puzzle JSON is data only'));
      // The world now points at a puzzle that did not load, which is its own error.
      expect(out, contains('ERROR [L1 schema] worlds.json worlds[0].puzzles[0]: Lists "p1", but no valid puzzle has that id.'));
      expect(out, contains('REJECTED world_01/p1.json at L1 schema'));
      expect(out, contains('FAILED 3 error(s)'));
    });
  });
}
