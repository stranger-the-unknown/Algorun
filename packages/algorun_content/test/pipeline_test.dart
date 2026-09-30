import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// MS12: the content pipeline, level by level, on small candidate sets.

// --- a test oracle: the length of a list -------------------------------------

Object? _length(Map<String, Object?> input) => (input['nums']! as List).length;

Map<String, Object?> _lengthSample(Random r) => {'nums': [for (var i = r.nextInt(7); i > 0; i--) r.nextInt(9)]};

const _oracles = {
  ...oracleRegistry,
  'test_length': Oracle(id: 'test_length', solve: _length, sample: _lengthSample),
};

const _validator = ContentValidator(checker: ReferenceChecker(oracles: _oracles));

final _capabilities = File('../../content/capabilities.json').readAsStringSync();

// --- candidates ---------------------------------------------------------------

Map<String, Object?> _block(String id, String catalogId, {Map<String, String> slots = const {}, Map<String, Object?> literals = const {}}) => {
      'id': id,
      'catalogId': catalogId,
      if (slots.isNotEmpty) 'slots': {for (final e in slots.entries) e.key: {'ref': e.value}},
      if (literals.isNotEmpty) 'literals': literals,
    };

/// `return LENGTH OF nums`.
Map<String, Object?> _lengthGraph() => {
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'len'}),
        'len': _block('len', 'arr.len', slots: {'array': 'nums'}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
      },
    };

/// `return <n>`.
Map<String, Object?> _constantGraph(int n) => {
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'n'}),
        'n': _block('n', 'lit.num', literals: {'value': n}),
      },
    };

/// `return LENGTH OF nums + 1` — wrong, but self-consistent with wrong fixtures.
Map<String, Object?> _offByOneGraph() => {
      'variables': {'nums': 'array<num>'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': _block('ret', 'ctrl.return', slots: {'value': 'add'}),
        'add': _block('add', 'arith.add', slots: {'left': 'len', 'right': 'one'}),
        'len': _block('len', 'arr.len', slots: {'array': 'nums'}),
        'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
        'one': _block('one', 'lit.num', literals: {'value': 1}),
      },
    };

const _defaultHidden = [
  {'id': 'empty', 'in': {'nums': <int>[]}, 'out': 0},
  {'id': 'one', 'in': {'nums': [7]}, 'out': 1},
  {'id': 'four', 'in': {'nums': [1, 1, 1, 1]}, 'out': 4},
  {'id': 'six', 'in': {'nums': [5, 4, 3, 2, 1, 0]}, 'out': 6},
];

Map<String, Object?> _spec({String family = 'array_scan', String pattern = 'count_items', String performance = 'correctness'}) => {
      'family': family,
      'pattern': pattern,
      'structure': 'array',
      'secondary': <String>[],
      'performance': performance,
      'traps': ['an empty list'],
      'oracle': 'test_length',
    };

/// One candidate: a puzzle JSON and its reference file.
({ContentFile puzzle, ContentFile reference}) _candidate({
  String id = 'count_items',
  String world = 'world_a',
  int tier = 1,
  String mode = 'build',
  List<String> concepts = const ['counting'],
  List<String> prerequisites = const [],
  List<String> allow = const ['ctrl.return', 'arr.len', 'var.get', 'lit.num', 'arith.add'],
  List<Object?> visible = const [
    {'id': 'v1', 'in': {'nums': [1, 2, 3]}, 'out': 3},
  ],
  List<Object?> hidden = _defaultHidden,
  Map<String, Object?>? limits,
  Map<String, Object?>? performance,
  Map<String, Object?>? spec,
  bool withSpec = true,
  Map<String, Object?>? solution,
  List<Object?>? rejects,
  Map<String, Object?>? metrics,
}) {
  final puzzle = {
    'id': id,
    'title': id,
    'world': world,
    'tier': tier,
    'mode': mode,
    'concepts': concepts,
    'prerequisites': prerequisites,
    'story': 'Count the numbers.',
    'io': {
      'inputs': [
        {'name': 'nums', 'type': 'array<num>'},
      ],
      'output': {'type': 'num'},
    },
    'blocks': {'allow': allow},
    'limits': limits ?? {'maxOps': 1000},
    'performance': ?performance,
    'hints': ['Count them.'],
    'fixtures': {'visible': visible, 'hidden': hidden},
    'reference': {'strategy': 'count'},
  };
  final reference = {
    'puzzle': id,
    'notes': 'Count the list.',
    if (withSpec) 'spec': spec ?? _spec(),
    'metrics': ?metrics,
    'solution': solution ?? _lengthGraph(),
    'rejects': ?rejects,
  };
  return (
    puzzle: ContentFile('$world/$id.json', jsonEncode(puzzle)),
    reference: ContentFile('$world/$id.json', jsonEncode(reference)),
  );
}

/// A world for the manifest: `(id, concepts, prerequisites, puzzles)`.
typedef _World = (String, List<String>, List<String>, List<String>);

String _worlds(List<_World> worlds) => jsonEncode({
      'worlds': [
        for (final (i, (id, concepts, prerequisites, puzzles)) in worlds.indexed)
          {'id': id, 'title': id, 'index': i + 1, 'concepts': concepts, 'prerequisites': prerequisites, 'puzzles': puzzles},
      ],
    });

ContentReport _run(
  List<({ContentFile puzzle, ContentFile reference})> candidates, {
  List<_World>? worlds,
  String? targets,
}) =>
    _validator.validateContent(
      puzzles: [for (final c in candidates) c.puzzle],
      worldsSource: _worlds(worlds ??
          [
            ('world_a', ['counting'], [], [for (final c in candidates) jsonDecode(c.puzzle.source)['id'] as String]),
          ]),
      references: [for (final c in candidates) c.reference],
      capabilitiesSource: _capabilities,
      targetsSource: targets,
    );

PuzzleVerdict _verdict(ContentReport report, String id) => report.verdicts.singleWhere((v) => v.id == id);

Iterable<ContentIssue> _errors(ContentReport report, int level) => report.errors.where((e) => e.level == level);

bool _says(ContentReport report, Severity severity, int level, String fragment) =>
    report.issues.any((i) => i.severity == severity && i.level == level && i.message.contains(fragment));

void main() {
  group('acceptance', () {
    test('a valid candidate is accepted at every level', () {
      final report = _run([_candidate(metrics: {'ops': 3, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 3})]);
      expect(report.errors, isEmpty, reason: report.issues.join('\n'));
      final verdict = _verdict(report, 'count_items');
      expect(verdict.accepted, isTrue);
      expect(verdict.campaign, isTrue);
    });

    test('a malformed candidate is rejected at the schema level', () {
      final bad = _candidate();
      final broken = ContentFile(bad.puzzle.path, bad.puzzle.source.replaceFirst('"tier":1', '"tier":9'));
      final report = _run([(puzzle: broken, reference: bad.reference)]);
      expect(_errors(report, Level.schema), isNotEmpty);
      expect(report.verdicts.single.accepted, isFalse);
      expect(report.verdicts.single.failed, contains(Level.schema));
    });

    test('a campaign puzzle without a spec is refused', () {
      final report = _run([_candidate(withSpec: false)]);
      expect(_says(report, Severity.error, Level.schema, 'needs a spec'), isTrue);
    });

    test('a malformed spec is refused field by field', () {
      final report = _run([
        _candidate(spec: {
          ..._spec(),
          'structure': 'rope',
          'performance': 'fast',
          'traps': <String>[],
          'colour': 'red',
        }),
      ]);
      for (final path in ['spec.structure', 'spec.performance', 'spec.traps', 'spec.colour']) {
        expect(report.errors.map((e) => e.path), contains(path), reason: path);
      }
    });
  });

  group('level 2: blocks and capabilities', () {
    test('a family the language cannot express is refused', () {
      final report = _run([_candidate(spec: _spec(family: 'heap'))]);
      expect(_says(report, Severity.error, Level.blocks, 'cannot express "heap"'), isTrue);
      expect(_verdict(report, 'count_items').failed, contains(Level.blocks));
    });

    test('an unknown family must be added to the audit first', () {
      final report = _run([_candidate(spec: _spec(family: 'quantum_sort'))]);
      expect(_says(report, Severity.error, Level.blocks, 'Unknown family'), isTrue);
    });

    test('a mode the product cannot play yet is refused', () {
      final report = _run([_candidate(mode: 'repair')]);
      expect(_says(report, Severity.error, Level.blocks, 'Mode "repair" is not playable yet'), isTrue);
    });

    test('a reference using a block outside the allowlist is refused', () {
      final report = _run([_candidate(allow: ['ctrl.return', 'var.get', 'lit.num'])]);
      expect(_errors(report, Level.blocks), isNotEmpty);
      expect(_verdict(report, 'count_items').accepted, isFalse);
    });
  });

  group('level 3: editor replay', () {
    test('a reference a player could not build is refused', () {
      final graph = _lengthGraph();
      (graph['blocks']! as Map<String, Object?>)['stray'] = _block('stray', 'lit.num', literals: {'value': 5});
      final report = _run([_candidate(solution: graph)]);
      expect(_says(report, Severity.error, Level.replay, 'not attached'), isTrue);
      expect(_verdict(report, 'count_items').failed, contains(Level.replay));
    });
  });

  group('level 4: execution and the oracle', () {
    test('a wrong reference with matching wrong fixtures is caught by the oracle', () {
      // The reference and the expected outputs agree with each other — and
      // both are wrong. The test runner alone would pass it.
      final report = _run([
        _candidate(
          solution: _offByOneGraph(),
          visible: const [
            {'id': 'v1', 'in': {'nums': [1, 2, 3]}, 'out': 4},
          ],
          hidden: const [
            {'id': 'empty', 'in': {'nums': <int>[]}, 'out': 1},
            {'id': 'one', 'in': {'nums': [7]}, 'out': 2},
            {'id': 'four', 'in': {'nums': [1, 1, 1, 1]}, 'out': 5},
            {'id': 'six', 'in': {'nums': [5, 4, 3, 2, 1, 0]}, 'out': 7},
          ],
        ),
      ]);
      expect(_says(report, Severity.error, Level.execution, 'but the oracle says'), isTrue);
      expect(_says(report, Severity.error, Level.execution, 'The reference and the oracle disagree'), isTrue);
      expect(_verdict(report, 'count_items').failed, contains(Level.execution));
    });

    test('a reference that only fits its own fixtures fails on sampled inputs', () {
      // Every fixture has three numbers, so "return 3" passes them all.
      final threes = [
        for (final (i, nums) in [
          [1, 2, 3],
          [4, 4, 4],
          [0, 9, 8],
          [5, 6, 7],
          [2, 2, 2],
        ].indexed)
          {'id': 'c$i', 'in': {'nums': nums}, 'out': 3},
      ];
      final report = _run([_candidate(solution: _constantGraph(3), visible: threes.sublist(0, 1), hidden: threes.sublist(1))]);
      expect(_says(report, Severity.error, Level.execution, 'disagree on sampled input'), isTrue);
    });

    test('a wrong fixture is reported against the oracle, never silently fixed', () {
      final report = _run([
        _candidate(hidden: const [
          {'id': 'empty', 'in': {'nums': <int>[]}, 'out': 0},
          {'id': 'one', 'in': {'nums': [7]}, 'out': 1},
          {'id': 'four', 'in': {'nums': [1, 1, 1, 1]}, 'out': 5},
          {'id': 'six', 'in': {'nums': [5, 4, 3, 2, 1, 0]}, 'out': 6},
        ]),
      ]);
      expect(_says(report, Severity.error, Level.execution, 'Case "four" expects 5, but the oracle says 4'), isTrue);
    });

    test('an unknown oracle is refused', () {
      final report = _run([_candidate(spec: {..._spec(), 'oracle': 'nobody'})]);
      expect(_says(report, Severity.error, Level.schema, 'No oracle "nobody"'), isTrue);
    });

    test('fixtures that always expect the same answer are refused (a constant would pass)', () {
      final report = _run([
        _candidate(hidden: const [
          {'id': 'h1', 'in': {'nums': [4, 5, 6]}, 'out': 3},
          {'id': 'h2', 'in': {'nums': [7, 8, 9]}, 'out': 3},
          {'id': 'h3', 'in': {'nums': [0, 0, 0]}, 'out': 3},
          {'id': 'h4', 'in': {'nums': [2, 2, 2]}, 'out': 3},
        ]),
      ]);
      expect(_says(report, Severity.error, Level.execution, 'Every case expects 3'), isTrue);
    });

    test('hidden cases must not repeat visible ones, and too few hidden cases warn', () {
      final report = _run([
        _candidate(hidden: const [
          {'id': 'copy', 'in': {'nums': [1, 2, 3]}, 'out': 3},
        ]),
      ]);
      expect(_says(report, Severity.error, Level.execution, 'repeats visible case "v1"'), isTrue);
      expect(_says(report, Severity.warning, Level.execution, 'Only 1 hidden case'), isTrue);
    });

    test('a reject must be caught the way it declares', () {
      final wrong = _candidate(rejects: [
        {'name': 'always three', 'expect': 'wrongAnswer', 'graph': _constantGraph(3)},
      ]);
      expect(_run([wrong]).errors, isEmpty);
      final uncaught = _candidate(rejects: [
        {'name': 'the right answer', 'expect': 'wrongAnswer', 'graph': _lengthGraph()},
      ]);
      expect(_says(_run([uncaught]), Severity.error, Level.execution, 'but it ended in Correct'), isTrue);
    });
  });

  group('level 5: performance', () {
    test('a reference over its budget is refused at the performance level', () {
      final report = _run([_candidate(limits: {'maxOps': 2})]);
      expect(_verdict(report, 'count_items').failed, contains(Level.performance));
    });

    test('drifted metrics are refused', () {
      final report = _run([_candidate(metrics: {'ops': 99, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 3})]);
      expect(_says(report, Severity.error, Level.performance, 'Recorded 99, measured 3'), isTrue);
    });

    test('a "budget" spec must declare performance.required', () {
      final report = _run([_candidate(spec: _spec(performance: 'budget'))]);
      expect(_says(report, Severity.error, Level.performance, 'must declare "performance"'), isTrue);
    });
  });

  group('level 6: progression', () {
    ContentReport campaign(List<_World> worlds, {Map<String, List<String>> prerequisites = const {}}) {
      final candidates = [
        for (final (world, _, _, puzzles) in worlds)
          for (final id in puzzles)
            _candidate(id: id, world: world, prerequisites: prerequisites[id] ?? const [], spec: _spec(pattern: id)),
      ];
      return _run(candidates, worlds: worlds);
    }

    test('a reachable campaign passes', () {
      final report = campaign([
        ('world_a', ['arrays'], [], ['p_a']),
        ('world_b', ['maps'], ['arrays'], ['p_b']),
      ]);
      expect(_errors(report, Level.progression), isEmpty, reason: report.issues.join('\n'));
    });

    test('worlds waiting on each other are a cycle', () {
      final report = campaign([
        ('world_a', ['arrays'], [], ['p_a']),
        ('world_b', ['maps'], ['sets'], ['p_b']),
        ('world_c', ['sets'], ['maps'], ['p_c']),
      ]);
      expect(_says(report, Severity.error, Level.progression, 'Circular gating: world_b → world_c → world_b'), isTrue);
      expect(_says(report, Severity.error, Level.progression, 'world_b never opens'), isTrue);
      expect(_verdict(report, 'p_b').failed, contains(Level.progression));
      expect(_verdict(report, 'p_a').accepted, isTrue);
    });

    test('a puzzle gated behind its own world is a cycle', () {
      // p_a needs "maps", taught only by world_b, which needs world_a done —
      // and world_a is only done once p_a is solved.
      final report = campaign(
        [
          ('world_a', ['arrays'], [], ['p_a', 'p_a2']),
          ('world_b', ['maps'], ['arrays'], ['p_b']),
        ],
        prerequisites: {
          'p_a': ['maps'],
        },
      );
      expect(_says(report, Severity.error, Level.progression, 'Circular gating'), isTrue);
      expect(_says(report, Severity.error, Level.progression, 'This puzzle can never be reached'), isTrue);
      expect(_verdict(report, 'p_a').accepted, isFalse);
    });

    test('a prerequisite no world teaches can never be learned', () {
      final report = campaign(
        [
          ('world_a', ['arrays'], [], ['p_a']),
          ('world_b', ['maps'], ['recursion'], ['p_b']),
        ],
        prerequisites: {
          'p_a': ['telepathy'],
        },
      );
      expect(_says(report, Severity.error, Level.progression, 'No world teaches "recursion", so world_b'), isTrue);
      expect(_says(report, Severity.error, Level.progression, 'No world teaches "telepathy", so this puzzle'), isTrue);
    });

    test('an unreachable puzzle in an open world is found', () {
      final report = campaign(
        [
          ('world_a', ['arrays'], [], ['p_a']),
          ('world_b', ['maps'], [], ['p_b']),
        ],
        prerequisites: {
          'p_b': ['graphs'],
        },
      );
      expect(_says(report, Severity.error, Level.progression, 'This puzzle can never be reached'), isTrue);
      expect(_verdict(report, 'p_b').failed, contains(Level.progression));
      expect(_verdict(report, 'p_a').accepted, isTrue);
    });

    test('a world with no puzzles only warns, and order is advice', () {
      final report = campaign([
        ('world_a', ['arrays'], ['maps'], ['p_a']),
        ('world_b', ['maps'], [], ['p_b']),
        ('world_c', ['heaps'], ['recursion'], []),
      ]);
      expect(_errors(report, Level.progression), isEmpty, reason: report.issues.join('\n'));
      expect(_says(report, Severity.warning, Level.progression, 'taught only by world_b, later in the campaign'), isTrue);
      expect(_says(report, Severity.warning, Level.progression, 'No world teaches "recursion".'), isTrue);
    });
  });

  group('level 7: the corpus', () {
    test('a restated puzzle is a near duplicate of the earlier one', () {
      final original = _candidate(id: 'count_items');
      final restated = _candidate(id: 'tally_things', spec: _spec(pattern: 'count_items'));
      final report = _run([original, restated]);
      expect(_says(report, Severity.error, Level.corpus, 'Near duplicate of count_items'), isTrue);
      expect(_verdict(report, 'tally_things').failed, contains(Level.corpus));
      expect(_verdict(report, 'count_items').accepted, isTrue);
    });

    test('renaming the pattern does not hide a duplicate', () {
      final original = _candidate(id: 'count_items');
      final renamed = _candidate(id: 'tally_things', spec: _spec(pattern: 'tally_list'));
      final report = _run([original, renamed]);
      expect(_says(report, Severity.error, Level.corpus, 'Near duplicate of count_items'), isTrue);
    });

    test('the same pattern with a different program is related, not a duplicate', () {
      // Counting with a loop instead of LENGTH: same pattern, a different
      // program shape and different blocks.
      final loop = {
        'variables': {'nums': 'array<num>', 'c': 'num', 'x': 'num'},
        'entryIds': ['start', 'each', 'ret'],
        'blocks': {
          'start': _block('start', 'var.set', slots: {'value': 'zero'}, literals: {'name': 'c'}),
          'zero': _block('zero', 'lit.num', literals: {'value': 0}),
          'each': {
            'id': 'each',
            'catalogId': 'ctrl.foreach',
            'literals': {'name': 'x'},
            'slots': {
              'collection': {'ref': 'nums'},
              'body': {
                'list': ['inc'],
              },
            },
          },
          'nums': _block('nums', 'var.get', literals: {'name': 'nums'}),
          'inc': _block('inc', 'var.inc', literals: {'name': 'c'}),
          'ret': _block('ret', 'ctrl.return', slots: {'value': 'c2'}),
          'c2': _block('c2', 'var.get', literals: {'name': 'c'}),
        },
      };
      final puzzle = parsePuzzleJson(_candidate().puzzle.source);
      final spec = readSpec(_spec(), (_, _) {})!;
      final a = Fingerprint.of(puzzle, spec, BlockGraph.fromJson(_lengthGraph()), 1);
      final b = Fingerprint.of(puzzle, spec, BlockGraph.fromJson(loop), 2);
      expect(a.skeleton, isNot(b.skeleton));
      expect(compareFingerprints(a, b).kind, Redundancy.related);
    });

    test('different reasoning is unique', () {
      final a = Fingerprint(
        puzzleId: 'a',
        order: 1,
        pattern: 'p1',
        family: 'f',
        io: '(array<num>)->num',
        mode: 'build',
        concepts: {'x'},
        skeleton: 'ctrl.return',
        histogram: {'ctrl.return': 1, 'arr.len': 1},
      );
      final b = Fingerprint(
        puzzleId: 'b',
        order: 2,
        pattern: 'p2',
        family: 'f',
        io: '(array<num>)->num',
        mode: 'build',
        concepts: {'x'},
        skeleton: 'ctrl.foreach{ctrl.if{var.inc}},ctrl.return',
        histogram: {'ctrl.foreach': 1, 'ctrl.if': 1, 'var.inc': 1, 'cmp.gt': 1, 'ctrl.return': 1},
      );
      expect(compareFingerprints(a, b).kind, Redundancy.unique);
    });

    test('the coverage matrix counts and reports gaps against targets', () {
      final targets = jsonEncode({
        'total': 10,
        'worlds': {
          'world_a': {'target': 3, 'tiers': [1, 2]},
        },
        'families': {'array_scan': 2, 'heap': 1},
        'modes': {'repair': 1},
      });
      final report = _run([_candidate()], targets: targets);
      final matrix = report.coverage!;
      expect(matrix['total'], 1);
      expect(matrix['tiers'], {'1': 1, '2': 0, '3': 0, '4': 0, '5': 0});
      expect(matrix['families'], {'array_scan': 1});
      final gaps = (matrix['gaps']! as List).cast<Map<String, Object?>>();
      expect(gaps, contains(equals({'area': 'world', 'id': 'world_a', 'have': 1, 'want': 3})));
      expect(gaps, contains(equals({'area': 'tiers', 'id': 'world_a', 'missing': [2]})));
      expect(gaps, contains(equals({'area': 'family', 'id': 'heap', 'have': 0, 'want': 1, 'note': 'blocked by the language'})));
      expect(gaps.where((g) => g['id'] == 'repair').single['note'], startsWith('blocked:'));
      // Deterministic: the same corpus gives the same text.
      expect(coverageJson(_run([_candidate()], targets: targets).coverage!), coverageJson(matrix));
    });

    test('a heavy program labelled tier 1 draws difficulty advice', () {
      final puzzle = parsePuzzleJson(_candidate().puzzle.source);
      const heavy = DifficultySignals(blocks: 70, loopDepth: 3, structures: 3, stateVariables: 8, concepts: 5, budget: true);
      expect(heavy.estimate, 5);
      expect(difficultyMismatch(puzzle, heavy), contains('looks like tier 5'));
      const light = DifficultySignals(blocks: 12, loopDepth: 1, structures: 0, stateVariables: 1, concepts: 1, budget: false);
      expect(difficultyMismatch(puzzle, light), isNull);
    });

    test('a duplicate puzzle id is refused', () {
      final a = _candidate();
      final b = _candidate(world: 'world_b');
      final report = _validator.validateContent(
        puzzles: [a.puzzle, b.puzzle],
        worldsSource: _worlds([
          ('world_a', ['counting'], [], ['count_items']),
          ('world_b', ['more'], [], []),
        ]),
        references: [a.reference],
        capabilitiesSource: _capabilities,
      );
      expect(_says(report, Severity.error, Level.schema, 'is also used by'), isTrue);
    });
  });

  group('the shipped corpus', () {
    ContentReport shipped() {
      List<ContentFile> files(String dir) {
        final root = Directory(dir);
        return [
          for (final f in root.listSync(recursive: true).whereType<File>())
            if (f.path.endsWith('.json')) ContentFile(f.absolute.uri.path.substring(root.absolute.uri.path.length), f.readAsStringSync()),
        ];
      }

      return const ContentValidator().validateContent(
        puzzles: files('../../assets/puzzles'),
        worldsSource: File('../../assets/worlds.json').readAsStringSync(),
        references: files('../../content/references'),
        capabilitiesSource: _capabilities,
        targetsSource: File('../../content/coverage_targets.json').readAsStringSync(),
      );
    }

    final report = shipped();

    test('every campaign puzzle is accepted at every level', () {
      expect(report.errors, isEmpty, reason: report.errors.join('\n'));
      final campaign = report.verdicts.where((v) => v.campaign).toList();
      expect(campaign, hasLength(107));
      expect(campaign.where((v) => !v.accepted), isEmpty);
    });

    test('the committed coverage matrix is up to date', () {
      // Git may check the file out with CRLF line ends on Windows.
      expect(
        coverageJson(report.coverage!),
        File('../../content/coverage.json').readAsStringSync().replaceAll('\r\n', '\n'),
      );
    });

    test('every oracle in the tooling is used by exactly one puzzle', () {
      final used = <String>[];
      for (final f in Directory('../../content/references').listSync(recursive: true).whereType<File>()) {
        final spec = (jsonDecode(f.readAsStringSync()) as Map<String, Object?>)['spec'];
        if (spec is Map<String, Object?>) used.add(spec['oracle']! as String);
      }
      expect(used.toSet(), oracleRegistry.keys.toSet());
      expect(used, hasLength(used.toSet().length));
    });

    test('no near duplicates, no blocked families, no unplayable modes', () {
      expect(report.issues.where((i) => i.message.startsWith('Near duplicate')), isEmpty);
      final capabilities = Capabilities.parse(_capabilities);
      final matrix = report.coverage!;
      for (final family in (matrix['families']! as Map<String, Object?>).keys) {
        expect(capabilities.families[family]!.status, isNot(CapabilityStatus.blocked), reason: family);
      }
      for (final mode in (matrix['modes']! as Map<String, Object?>).keys) {
        expect(capabilities.modes[mode]!.status, CapabilityStatus.supported, reason: mode);
      }
    });

    test('tree and linked-list content uses the L1 checks', () {
      final puzzles = (report.coverage!['puzzles']! as List).cast<Map<String, Object?>>();
      final structural = puzzles.where((p) => p['structure'] == 'tree' || p['structure'] == 'linked_list').toList();
      expect(structural, hasLength(greaterThanOrEqualTo(8)));
      for (final p in structural) {
        final source = File('../../content/references/${p['world']}/${p['id']}.json').readAsStringSync();
        expect(source, anyOf(contains('logic.is_not_nothing'), contains('logic.is_nothing')), reason: '${p['id']}');
      }
    });
  });
}
