import 'dart:convert';
import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';

import 'prog.dart';

/// M1 authoring helper: the nine complete / repair / predict puzzles.
///
/// Offline, like every tool here; the app never imports it. Each puzzle's
/// reference is built with the editor's own commands ([Prog]); its starter is
/// *derived* from that reference — blocks taken out (complete), one slip put
/// in (repair), or nothing changed (predict) — so the two share block ids,
/// which is what the content pipeline's starter rules compare.
///
/// Expected answers are written here by hand. The tool refuses to write a
/// puzzle whose oracle or reference disagrees with one.
///
/// Run from `packages/algorun_content`: `dart run tool/m1_emit.dart` rewrites
/// the nine puzzle and reference files. The Turkish text and the world lists
/// are edited by hand (`assets/l10n/content_tr.json`, `assets/worlds.json`).
void main(List<String> args) {
  final check = args.contains('--check');
  for (final spec in _puzzles) {
    final built = spec.build();
    final puzzleJson = _puzzleJson(spec, built, maxOps: 100000, maxAlloc: 1000, maxBlocks: 200);
    var puzzle = parsePuzzleMap(puzzleJson);
    const engine = DefaultEngine();
    final lowered = engine.lower(built.reference, puzzle);
    if (lowered.program == null) {
      throw StateError('${spec.id}: the reference does not lower: ${lowered.errors.map((e) => e.message).join('; ')}');
    }
    final suite = engine.runTests(lowered.program!, puzzle);
    final oracle = oracleRegistry[spec.id]!;
    for (final c in puzzle.allTests) {
      final input = {for (final b in puzzle.io.inputs) b.name: valueToJson(c.input[b.name]!)};
      final said = jsonEncode(oracle.solve(input));
      final expected = jsonEncode(valueToJson(c.output));
      if (said != expected) throw StateError('${spec.id}/${c.id}: fixture $expected, oracle $said');
    }
    if (!suite.ok) throw StateError('${spec.id}: the reference fails: ${suite.message}');
    final m = suite.metrics;

    // Budgets with room for another correct program: three times the
    // reference's operations, twice its memory, half as many blocks again.
    final maxOps = _roundUp(m.ops * 3, 50);
    final maxAlloc = _roundUp(m.peakAlloc * 2 + 20, 50);
    final maxBlocks = m.blocks + (m.blocks / 2).ceil();
    final finalJson = _puzzleJson(spec, built, maxOps: maxOps, maxAlloc: maxAlloc, maxBlocks: maxBlocks);
    puzzle = parsePuzzleMap(finalJson);

    final reference = {
      'puzzle': spec.id,
      'notes': spec.notes,
      'spec': {
        'family': spec.family,
        'pattern': spec.pattern,
        'structure': spec.structure,
        'secondary': const <String>[],
        'performance': 'correctness',
        'traps': spec.traps,
        'oracle': spec.id,
      },
      'metrics': {'blocks': m.blocks, 'ops': m.ops, 'peakAlloc': m.peakAlloc, 'peakDepth': m.peakDepth},
      'solution': built.reference.toJson(),
    };
    final labels = {
      for (final b in [...built.reference.blocks.values, ...built.starter.blocks.values])
        BlockChrome.labelOf(b.catalogId),
    }.toList()
      ..sort();
    stdout.writeln('${spec.id}: ${spec.mode} t${spec.tier}  ops ${m.ops}/$maxOps  blocks ${m.blocks}/$maxBlocks  '
        'starter ${built.starter.blocks.length} blocks, ${changedBlocks(built.starter, built.reference).length} differ');
    stdout.writeln('  labels: ${labels.join(' · ')}');
    if (check) continue;
    _write('../../assets/puzzles/${spec.world}/${spec.id}.json', finalJson);
    _write('../../content/references/${spec.world}/${spec.id}.json', reference);
  }
}

int _roundUp(int value, int step) => ((value + step - 1) ~/ step) * step;

void _write(String path, Object? json) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
}

Map<String, Object?> _puzzleJson(
  _Spec spec,
  _Built built, {
  required int maxOps,
  required int maxAlloc,
  required int maxBlocks,
}) {
  final allow = {
    for (final b in [...built.reference.blocks.values, ...built.starter.blocks.values]) b.catalogId,
  }.toList()
    ..sort();
  Map<String, Object?> testCase(String id, _Case c) => {'id': id, 'in': c.input, 'out': c.out};
  return {
    'id': spec.id,
    'version': 1,
    'title': spec.title,
    'world': spec.world,
    'chapter': spec.pattern,
    'tier': spec.tier,
    'mode': spec.mode,
    'concepts': spec.concepts,
    'prerequisites': const <String>[],
    'story': spec.story,
    'io': {
      'inputs': [
        for (final e in spec.inputs.entries) {'name': e.key, 'type': e.value},
      ],
      'output': {'type': spec.output},
    },
    'constraints': {'notes': spec.constraints},
    'blocks': {'allow': allow, 'maxBlocks': maxBlocks},
    'limits': {'maxOps': maxOps, 'maxDepth': 32, 'maxAlloc': maxAlloc},
    'hints': spec.hints,
    'validators': {'output': 'equal'},
    'fixtures': {
      'visible': [for (final (i, c) in spec.visible.indexed) testCase('v${i + 1}', c)],
      'hidden': [for (final (i, c) in spec.hidden.indexed) testCase('h${'${i + 1}'.padLeft(2, '0')}', c)],
    },
    'edgeCases': spec.traps,
    'variables': {
      'pool': [
        for (final e in spec.pool.entries) {'name': e.key, 'type': e.value},
      ],
    },
    'reference': {'strategy': spec.pattern},
    'starter': {
      'graph': built.starter.toJson(),
      if (built.locked.isNotEmpty) 'locked': built.locked.toList(),
    },
  };
}

final class _Case {
  const _Case(this.input, this.out);
  final Map<String, Object?> input;
  final Object? out;
}

final class _Built {
  const _Built(this.reference, this.starter, {this.locked = const {}});
  final BlockGraph reference;
  final BlockGraph starter;
  final Set<String> locked;
}

final class _Spec {
  const _Spec({
    required this.id,
    required this.world,
    required this.title,
    required this.tier,
    required this.mode,
    required this.concepts,
    required this.story,
    required this.constraints,
    required this.hints,
    required this.inputs,
    required this.output,
    required this.pool,
    required this.family,
    required this.pattern,
    required this.structure,
    required this.traps,
    required this.notes,
    required this.visible,
    required this.hidden,
    required this.build,
  });

  final String id;
  final String world;
  final String title;
  final int tier;
  final String mode;
  final List<String> concepts;
  final String story;
  final List<String> constraints;
  final List<String> hints;
  final Map<String, String> inputs;
  final String output;
  final Map<String, String> pool;
  final String family;
  final String pattern;
  final String structure;
  final List<String> traps;
  final String notes;
  final List<_Case> visible;
  final List<_Case> hidden;
  final _Built Function() build;
}

// --- deriving a starter from a reference --------------------------------------

/// The ids of the blocks [build] adds to [p].
Set<String> _track(Prog p, void Function() build) {
  final before = p.graph.blocks.keys.toSet();
  build();
  return p.graph.blocks.keys.toSet().difference(before);
}

/// [graph] without [ids]: the blocks go, and so does every mention of them.
BlockGraph _without(BlockGraph graph, Set<String> ids) {
  final blocks = <String, BlockInstance>{};
  for (final b in graph.blocks.values) {
    if (ids.contains(b.id)) continue;
    final slots = <String, SlotBinding>{};
    for (final e in b.slots.entries) {
      switch (e.value) {
        case RefBinding(:final blockId):
          if (!ids.contains(blockId)) slots[e.key] = e.value;
        case ListBinding(:final blockIds):
          slots[e.key] = ListBinding([for (final id in blockIds) if (!ids.contains(id)) id]);
      }
    }
    blocks[b.id] = b.copyWith(slots: slots);
  }
  return BlockGraph(
    variables: graph.variables,
    entryIds: [for (final id in graph.entryIds) if (!ids.contains(id)) id],
    blocks: blocks,
  );
}

/// [graph] with block [id] turned into [catalogId], everything plugged into
/// it left where it is (both blocks must have the same ports).
BlockGraph _retyped(BlockGraph graph, String id, String catalogId) {
  final b = graph.blocks[id]!;
  return graph.replaceBlock(BlockInstance(id: id, catalogId: catalogId, slots: b.slots, literals: b.literals));
}

// --- the puzzles --------------------------------------------------------------

final _puzzles = <_Spec>[
  _Spec(
    id: 'flag_lines',
    world: 'world_01',
    title: 'Flag Lines',
    tier: 1,
    mode: 'complete',
    concepts: const ['variables', 'control'],
    story: 'For a street party, flags hang in lines across the road. The first line holds 1 flag, and every '
        'line holds 2 more flags than the line before it: 1, 3, 5, 7 and so on. How many flags hang in all the '
        'lines together? The program already walks through the lines; what happens at each line is missing.',
    constraints: const ['There are 0 to 40 lines.'],
    hints: const [
      'Each trip through the loop is one line of flags: that line has to be added to the total.',
      'After a line is added, flags must be made ready for the next line, which holds 2 more.',
      'Inside FOR: SET total to total PLUS flags, then SET flags to flags PLUS 2.',
    ],
    inputs: const {'lines': 'num'},
    output: 'num',
    pool: const {'total': 'num', 'flags': 'num', 'line': 'num'},
    family: 'control_flow',
    pattern: 'sum_of_growing_terms',
    structure: 'scalar',
    traps: const ['no lines at all', 'a single line'],
    notes: 'A running total and a term that grows by 2 each trip. The starter holds the two starting values, the '
        'loop and the RETURN, all locked; the two instructions of the loop body are the player\'s.',
    visible: const [
      _Case({'lines': 3}, 9),
      _Case({'lines': 5}, 25),
    ],
    hidden: const [
      _Case({'lines': 0}, 0),
      _Case({'lines': 1}, 1),
      _Case({'lines': 2}, 4),
      _Case({'lines': 7}, 49),
      _Case({'lines': 10}, 100),
      _Case({'lines': 40}, 1600),
    ],
    build: () {
      final p = Prog(inputs: const {'lines': 'num'}, pool: const {'total': 'num', 'flags': 'num', 'line': 'num'});
      p.set('total', p.lit(0));
      p.set('flags', p.lit(1));
      late Set<String> body;
      p.range('line', p.lit(0), p.get('lines'), () {
        body = _track(p, () {
          p.set('total', p.add(p.get('total'), p.get('flags')));
          p.set('flags', p.add(p.get('flags'), p.lit(2)));
        });
      });
      p.ret(p.get('total'));
      final starter = _without(p.graph, body);
      return _Built(p.graph, starter, locked: starter.blocks.keys.toSet());
    },
  ),
  _Spec(
    id: 'fence_posts',
    world: 'world_01',
    title: 'Fence Posts',
    tier: 1,
    mode: 'repair',
    concepts: const ['variables', 'control'],
    story: 'A fence runs along a field edge that is some metres long. A post stands at 0 metres, and then one '
        'every gap metres for as long as it is still on the fence; a post exactly at the far end counts too. '
        'The program should count the posts, but sometimes its answer is one short. Find the mistake and fix it.',
    constraints: const ['The fence is 0 to 500 metres long.', 'The gap is a whole number from 1 to 50.'],
    hints: const [
      'Compare the two cases you can see: the answer is wrong only when a post lands exactly on the end of the fence.',
      'Follow pos through the loop for a 12 metre fence with a gap of 4. What happens when pos reaches 12?',
      'The WHILE condition stops one post early: the post at the very end needs LESS OR EQUAL, not LESS THAN.',
    ],
    inputs: const {'length': 'num', 'gap': 'num'},
    output: 'num',
    pool: const {'posts': 'num', 'pos': 'num'},
    family: 'control_flow',
    pattern: 'count_marks_inclusive_end',
    structure: 'scalar',
    traps: const ['a post exactly at the end', 'a fence of 0 metres', 'a gap longer than the fence'],
    notes: 'Count while the position is still on the fence, the end included. The starter compares with LESS THAN, '
        'so it is one short exactly when the length is a multiple of the gap (and right otherwise).',
    visible: const [
      _Case({'length': 10, 'gap': 4}, 3),
      _Case({'length': 12, 'gap': 4}, 4),
    ],
    hidden: const [
      _Case({'length': 0, 'gap': 5}, 1),
      _Case({'length': 9, 'gap': 3}, 4),
      _Case({'length': 7, 'gap': 7}, 2),
      _Case({'length': 20, 'gap': 6}, 4),
      _Case({'length': 1, 'gap': 1}, 2),
      _Case({'length': 3, 'gap': 50}, 1),
      _Case({'length': 100, 'gap': 1}, 101),
      _Case({'length': 500, 'gap': 7}, 72),
    ],
    build: () {
      final p = Prog(inputs: const {'length': 'num', 'gap': 'num'}, pool: const {'posts': 'num', 'pos': 'num'});
      p.set('posts', p.lit(0));
      p.set('pos', p.lit(0));
      final onFence = p.le(p.get('pos'), p.get('length'));
      p.whil(onFence, () {
        p.inc('posts');
        p.set('pos', p.add(p.get('pos'), p.get('gap')));
      });
      p.ret(p.get('posts'));
      return _Built(p.graph, _retyped(p.graph, onFence, BlockIds.cmpLt));
    },
  ),
  _Spec(
    id: 'halve_or_step',
    world: 'world_01',
    title: 'Halve or Step',
    tier: 2,
    mode: 'predict',
    concepts: const ['variables', 'control'],
    story: 'A counting machine is given a starting number and plays with it until nothing is left. The program is '
        'the machine\'s rule book, and what it returns is how long the game lasted. Read the program and say what '
        'it returns for each starting number.',
    constraints: const ['The starting number is a whole number from 0 to 1000.'],
    hints: const [
      'Keep a small table on paper: one row per trip through WHILE, with x and moves in it.',
      'REMAINDER 2 is 0 for an even number. Even numbers take the first branch, odd numbers the ELSE branch.',
      'For 5 the number goes 5, 4, 2, 1, 0: four moves. Count the steps between the numbers, not the numbers.',
    ],
    inputs: const {'start': 'num'},
    output: 'num',
    pool: const {'x': 'num', 'moves': 'num'},
    family: 'control_flow',
    pattern: 'halve_even_decrement_odd_count',
    structure: 'scalar',
    traps: const ['starting at 0', 'a power of two', 'a run of odd numbers'],
    notes: 'Halve an even number, take 1 from an odd one, count the moves down to 0. The oracle does not play the '
        'game: the count is the number of binary digits plus the number of 1 digits, minus 1.',
    visible: const [
      _Case({'start': 6}, 4),
      _Case({'start': 7}, 5),
      _Case({'start': 16}, 5),
    ],
    hidden: const [
      _Case({'start': 0}, 0),
      _Case({'start': 1}, 1),
      _Case({'start': 2}, 2),
      _Case({'start': 15}, 7),
      _Case({'start': 64}, 7),
      _Case({'start': 100}, 9),
      _Case({'start': 255}, 15),
      _Case({'start': 1000}, 15),
    ],
    build: () {
      final p = Prog(inputs: const {'start': 'num'}, pool: const {'x': 'num', 'moves': 'num'});
      p.set('x', p.get('start'));
      p.set('moves', p.lit(0));
      p.whil(p.gt(p.get('x'), p.lit(0)), () {
        p.iff(
          p.eq(p.mod(p.get('x'), p.lit(2)), p.lit(0)),
          () => p.set('x', p.floorDiv(p.get('x'), p.lit(2))),
          els: () => p.dec('x'),
        );
        p.inc('moves');
      });
      p.ret(p.get('moves'));
      return _Built(p.graph, p.graph);
    },
  ),
  _Spec(
    id: 'high_water_marks',
    world: 'world_02',
    title: 'High-Water Marks',
    tier: 2,
    mode: 'complete',
    concepts: const ['arrays'],
    story: 'A river gauge is read once a day. For every day, the harbour master writes down the highest level seen '
        'so far, that day included. Levels are 0 or more. Return the list of those marks, one per day. The program '
        'already writes a mark for each day, but its marks never rise.',
    constraints: const ['There are 0 to 60 days.', 'Each level is a whole number from 0 to 100.'],
    hints: const [
      'The program writes one mark per day, and the mark is always best. Nothing ever changes best.',
      'Before a day\'s mark is written, check whether that day\'s level beats the best so far.',
      'Inside FOR EACH, above APPEND: IF level is GREATER THAN best, SET best to level.',
    ],
    inputs: const {'levels': 'array<num>'},
    output: 'array<num>',
    pool: const {'marks': 'array<num>', 'best': 'num', 'level': 'num'},
    family: 'array_scan',
    pattern: 'running_maximum_list',
    structure: 'array',
    traps: const ['no days at all', 'a level equal to the best so far', 'levels that only fall'],
    notes: 'One pass that keeps the best level so far and appends it for every day. The starter is the whole '
        'program without the IF that raises best, so it runs and returns only zeros.',
    visible: const [
      _Case({
        'levels': [2, 5, 3, 6],
      }, [2, 5, 5, 6]),
      _Case({
        'levels': [4, 1, 1],
      }, [4, 4, 4]),
    ],
    hidden: const [
      _Case({'levels': <int>[]}, <int>[]),
      _Case({
        'levels': [0, 0],
      }, [0, 0]),
      _Case({
        'levels': [7],
      }, [7]),
      _Case({
        'levels': [1, 2, 3, 4],
      }, [1, 2, 3, 4]),
      _Case({
        'levels': [5, 5, 2, 9, 9, 1],
      }, [5, 5, 5, 9, 9, 9]),
      _Case({
        'levels': [0, 3, 0, 3, 8, 2, 8],
      }, [0, 3, 3, 3, 8, 8, 8]),
      _Case({
        'levels': [100, 40, 99, 100, 0],
      }, [100, 100, 100, 100, 100]),
    ],
    build: () {
      final p = Prog(
        inputs: const {'levels': 'array<num>'},
        pool: const {'marks': 'array<num>', 'best': 'num', 'level': 'num'},
      );
      p.set('marks', p.freshList());
      p.set('best', p.lit(0));
      late Set<String> raise;
      p.each('level', p.get('levels'), () {
        raise = _track(p, () {
          p.iff(p.gt(p.get('level'), p.get('best')), () => p.set('best', p.get('level')));
        });
        p.append('marks', p.get('best'));
      });
      p.ret(p.get('marks'));
      return _Built(p.graph, _without(p.graph, raise));
    },
  ),
  _Spec(
    id: 'no_step_down',
    world: 'world_02',
    title: 'No Step Down',
    tier: 2,
    mode: 'repair',
    concepts: const ['arrays'],
    story: 'A stair builder lists the height of every step, from the bottom up. The stairs are fine when no step is '
        'lower than the step before it; two steps of the same height are allowed. The program should answer TRUE '
        'for fine stairs and FALSE for the others, but it turns some fine stairs away. Find the mistake and fix it.',
    constraints: const ['There are 0 to 60 steps.', 'Each height is a whole number from 0 to 100.'],
    hints: const [
      'Look at the case the program gets wrong: which two steps does it complain about?',
      'Two steps of the same height are allowed. What does the IF do when both heights are equal?',
      'The comparison is too strict: a step is only wrong when it is LESS THAN the one before it, not LESS OR EQUAL.',
    ],
    inputs: const {'heights': 'array<num>'},
    output: 'bool',
    pool: const {'i': 'num'},
    family: 'array_scan',
    pattern: 'non_decreasing_check',
    structure: 'array',
    traps: const ['two equal neighbours', 'no steps at all', 'a single step', 'a drop at the very end'],
    notes: 'Compare every step with the one before it and stop at the first drop. The starter compares with LESS OR '
        'EQUAL, so equal neighbours — which the story allows — are turned away.',
    visible: const [
      _Case({
        'heights': [1, 3, 5],
      }, true),
      _Case({
        'heights': [2, 2, 4],
      }, true),
      _Case({
        'heights': [4, 1, 6],
      }, false),
    ],
    hidden: const [
      _Case({'heights': <int>[]}, true),
      _Case({
        'heights': [7],
      }, true),
      _Case({
        'heights': [3, 3, 3],
      }, true),
      _Case({
        'heights': [1, 2, 1],
      }, false),
      _Case({
        'heights': [5, 6, 7, 7],
      }, true),
      _Case({
        'heights': [9, 8],
      }, false),
      _Case({
        'heights': [1, 2, 3, 4, 5, 4],
      }, false),
      _Case({
        'heights': [0, 0],
      }, true),
    ],
    build: () {
      final p = Prog(inputs: const {'heights': 'array<num>'}, pool: const {'i': 'num'});
      late String drop;
      p.range('i', p.lit(1), p.len(p.get('heights')), () {
        drop = p.lt(p.at(p.get('heights'), p.get('i')), p.at(p.get('heights'), p.sub(p.get('i'), p.lit(1))));
        p.iff(drop, () => p.retBool(false));
      });
      p.retBool(true);
      return _Built(p.graph, _retyped(p.graph, drop, BlockIds.cmpLe));
    },
  ),
  _Spec(
    id: 'one_pass',
    world: 'world_02',
    title: 'One Pass',
    tier: 2,
    mode: 'predict',
    concepts: const ['arrays'],
    story: 'A sorting robot walks once along a row of numbered crates, from left to right. The program is its rule '
        'book, and what it returns is a count. Read the program and say what it returns for each row of crates.',
    constraints: const ['There are 0 to 40 crates.', 'Each crate number is a whole number from 0 to 99.'],
    hints: const [
      'Write the row down and change it as the program does: a SWAP changes what the next comparison sees.',
      'After a SWAP the larger crate has moved one place to the right, and it is compared again on the next trip.',
      'For 2, 1, 3: 2 and 1 change places (one swap), then 2 and 3 stay. The program returns 1.',
    ],
    inputs: const {'crates': 'array<num>'},
    output: 'num',
    pool: const {'swaps': 'num', 'i': 'num'},
    family: 'array_scan',
    pattern: 'count_swaps_single_bubble_pass',
    structure: 'array',
    traps: const ['equal neighbours are not swapped', 'a large crate carried along the row', 'an empty row'],
    notes: 'One left-to-right pass of neighbour swaps, counting them. The oracle does not move anything: a crate is '
        'swapped exactly when it is smaller than the largest crate before it.',
    visible: const [
      _Case({
        'crates': [3, 1, 2],
      }, 2),
      _Case({
        'crates': [2, 5, 1, 4, 3],
      }, 3),
      _Case({
        'crates': [1, 4, 4, 6],
      }, 0),
    ],
    hidden: const [
      _Case({'crates': <int>[]}, 0),
      _Case({
        'crates': [5],
      }, 0),
      _Case({
        'crates': [2, 1],
      }, 1),
      _Case({
        'crates': [4, 3, 2, 1],
      }, 3),
      _Case({
        'crates': [1, 3, 2, 4],
      }, 1),
      _Case({
        'crates': [2, 2, 1],
      }, 1),
      _Case({
        'crates': [9, 1, 8, 2, 7],
      }, 4),
    ],
    build: () {
      final p = Prog(inputs: const {'crates': 'array<num>'}, pool: const {'swaps': 'num', 'i': 'num'});
      p.set('swaps', p.lit(0));
      p.range('i', p.lit(0), p.sub(p.len(p.get('crates')), p.lit(1)), () {
        p.iff(
          p.gt(p.at(p.get('crates'), p.get('i')), p.at(p.get('crates'), p.add(p.get('i'), p.lit(1)))),
          () {
            p.swap('crates', p.get('i'), p.add(p.get('i'), p.lit(1)));
            p.inc('swaps');
          },
        );
      });
      p.ret(p.get('swaps'));
      return _Built(p.graph, p.graph);
    },
  ),
  _Spec(
    id: 'mirror_shelf',
    world: 'world_04',
    title: 'Mirror Shelf',
    tier: 2,
    mode: 'complete',
    concepts: const ['two_pointers'],
    story: 'A shop window shelf looks right when it reads the same from both ends: the first item matches the last, '
        'the second matches the second to last, and so on. The items are given as numbers. Return TRUE when the '
        'shelf is a mirror of itself. The program already walks two markers toward each other; where the second '
        'marker starts, and what is checked at each stop, are missing.',
    constraints: const ['There are 0 to 60 items.', 'Each item is a whole number from 0 to 9.'],
    hints: const [
      'lo starts on the first item. Where must hi start so that it points at the last one?',
      'Each trip through WHILE looks at one pair: the item at lo and the item at hi. One pair that differs settles the answer.',
      'SET hi to LENGTH of items MINUS 1. Inside WHILE, above the two moves: IF the item at lo is NOT EQUAL to the item at hi, RETURN FALSE.',
    ],
    inputs: const {'items': 'array<num>'},
    output: 'bool',
    pool: const {'lo': 'num', 'hi': 'num'},
    family: 'two_pointers',
    pattern: 'mirror_check_from_both_ends',
    structure: 'array',
    traps: const ['an empty shelf', 'a single item', 'a mismatch in the middle pair', 'an even number of items'],
    notes: 'Two markers from the ends, one comparison per pair. The starter holds the markers, the loop, the two '
        'moves and RETURN TRUE, all locked; the value of hi (a hole in a locked block) and the IF are the player\'s.',
    visible: const [
      _Case({
        'items': [1, 2, 1],
      }, true),
      _Case({
        'items': [3, 4, 4, 3],
      }, true),
      _Case({
        'items': [1, 2, 3],
      }, false),
    ],
    hidden: const [
      _Case({'items': <int>[]}, true),
      _Case({
        'items': [5],
      }, true),
      _Case({
        'items': [1, 2],
      }, false),
      _Case({
        'items': [2, 2],
      }, true),
      _Case({
        'items': [1, 2, 3, 2, 1],
      }, true),
      _Case({
        'items': [1, 2, 3, 4, 1],
      }, false),
      _Case({
        'items': [7, 1, 1, 8],
      }, false),
      _Case({
        'items': [4, 5, 6, 6, 5, 4],
      }, true),
      _Case({
        'items': [4, 5, 6, 7, 5, 4],
      }, false),
    ],
    build: () {
      final p = Prog(inputs: const {'items': 'array<num>'}, pool: const {'lo': 'num', 'hi': 'num'});
      p.set('lo', p.lit(0));
      late String last;
      final lastBlocks = _track(p, () => last = p.sub(p.len(p.get('items')), p.lit(1)));
      p.set('hi', last);
      late Set<String> check;
      p.whil(p.lt(p.get('lo'), p.get('hi')), () {
        check = _track(p, () {
          p.iff(
            p.ne(p.at(p.get('items'), p.get('lo')), p.at(p.get('items'), p.get('hi'))),
            () => p.retBool(false),
          );
        });
        p.inc('lo');
        p.dec('hi');
      });
      p.retBool(true);
      final starter = _without(p.graph, {...lastBlocks, ...check});
      return _Built(p.graph, starter, locked: starter.blocks.keys.toSet());
    },
  ),
  _Spec(
    id: 'glove_pairs',
    world: 'world_04',
    title: 'Glove Pairs',
    tier: 3,
    mode: 'repair',
    concepts: const ['two_pointers'],
    story: 'Two boxes hold gloves, left ones in one box and right ones in the other. Every glove is marked with its '
        'size, and each box is sorted from small to large. A left glove pairs with a right glove of the same size, '
        'and a glove can be in one pair only. The program should count the pairs, but for some boxes it counts too '
        'many. Find the mistake and fix it.',
    constraints: const ['Each box holds 0 to 40 gloves.', 'Sizes are whole numbers from 1 to 20, sorted, and may repeat.'],
    hints: const [
      'The answer is too high only when a size appears more than once in a box. Follow the failing case by hand.',
      'When two gloves pair up, both are used. Does the program move on in both boxes?',
      'In the branch where the sizes are EQUAL the program moves i but not j: add INCREMENT j there.',
    ],
    inputs: const {'lefts': 'array<num>', 'rights': 'array<num>'},
    output: 'num',
    pool: const {'i': 'num', 'j': 'num', 'pairs': 'num'},
    family: 'two_pointers',
    pattern: 'count_matched_pairs_sorted_multisets',
    structure: 'array',
    traps: const ['a size repeated in one box only', 'an empty box', 'no size in common', 'one box much longer'],
    notes: 'Walk both sorted boxes; equal sizes make a pair and use up one glove on each side. The starter forgets '
        'to move on in the right box after a pair, so one right glove is paired again with every equal left one. '
        'Boxes without repeated sizes still come out right.',
    visible: const [
      _Case({
        'lefts': [1, 3, 5],
        'rights': [3, 4, 5],
      }, 2),
      _Case({
        'lefts': [2, 2, 6],
        'rights': [2, 6, 6],
      }, 2),
    ],
    hidden: const [
      _Case({'lefts': <int>[], 'rights': <int>[]}, 0),
      _Case({
        'lefts': [4],
        'rights': <int>[],
      }, 0),
      _Case({
        'lefts': [1, 1, 1],
        'rights': [1],
      }, 1),
      _Case({
        'lefts': [1, 1],
        'rights': [1, 1],
      }, 2),
      _Case({
        'lefts': [1, 2, 3],
        'rights': [4, 5],
      }, 0),
      _Case({
        'lefts': [3, 3, 3, 7],
        'rights': [3, 3, 7, 7],
      }, 3),
      _Case({
        'lefts': [5, 8, 8, 9],
        'rights': [8],
      }, 1),
      _Case({
        'lefts': [2, 4, 6, 8],
        'rights': [1, 2, 3, 4, 5, 6, 7, 8],
      }, 4),
    ],
    build: () {
      final p = Prog(
        inputs: const {'lefts': 'array<num>', 'rights': 'array<num>'},
        pool: const {'i': 'num', 'j': 'num', 'pairs': 'num'},
      );
      p.set('i', p.lit(0));
      p.set('j', p.lit(0));
      p.set('pairs', p.lit(0));
      late Set<String> moveRight;
      p.whil(
        p.and(p.lt(p.get('i'), p.len(p.get('lefts'))), p.lt(p.get('j'), p.len(p.get('rights')))),
        () {
          p.iff(
            p.eq(p.at(p.get('lefts'), p.get('i')), p.at(p.get('rights'), p.get('j'))),
            () {
              p.inc('pairs');
              p.inc('i');
              moveRight = _track(p, () => p.inc('j'));
            },
            els: () {
              p.iff(
                p.lt(p.at(p.get('lefts'), p.get('i')), p.at(p.get('rights'), p.get('j'))),
                () => p.inc('i'),
                els: () => p.inc('j'),
              );
            },
          );
        },
      );
      p.ret(p.get('pairs'));
      return _Built(p.graph, _without(p.graph, moveRight));
    },
  ),
  _Spec(
    id: 'closing_in',
    world: 'world_04',
    title: 'Closing In',
    tier: 3,
    mode: 'predict',
    concepts: const ['two_pointers'],
    story: 'Two markers start at the two ends of a row of numbered cards and walk toward each other. The program is '
        'their rule book. Read it and say what it returns for each row. There is always at least one card.',
    constraints: const ['There are 1 to 40 cards.', 'Each card is a whole number from 0 to 99.'],
    hints: const [
      'Keep two fingers on the row, one for lo and one for hi, and move one finger per trip through WHILE.',
      'Each trip, the marker on the smaller card moves. When the two cards are equal, hi moves.',
      'Which card can a marker never walk away from? The loop ends with both markers standing on it.',
    ],
    inputs: const {'cards': 'array<num>'},
    output: 'num',
    pool: const {'lo': 'num', 'hi': 'num'},
    family: 'two_pointers',
    pattern: 'converge_on_maximum',
    structure: 'array',
    traps: const ['a single card', 'two equal largest cards', 'the largest card at an end'],
    notes: 'The marker on the smaller card always moves, so the two markers meet on a largest card. The oracle '
        'simply takes the largest card.',
    visible: const [
      _Case({
        'cards': [3, 8, 2],
      }, 8),
      _Case({
        'cards': [5, 1, 4, 9, 2, 6],
      }, 9),
      _Case({
        'cards': [7, 7, 1],
      }, 7),
    ],
    hidden: const [
      _Case({
        'cards': [4],
      }, 4),
      _Case({
        'cards': [1, 2],
      }, 2),
      _Case({
        'cards': [2, 1],
      }, 2),
      _Case({
        'cards': [6, 6],
      }, 6),
      _Case({
        'cards': [1, 2, 3, 4, 5],
      }, 5),
      _Case({
        'cards': [5, 4, 3, 2, 1],
      }, 5),
      _Case({
        'cards': [2, 9, 9, 3],
      }, 9),
      _Case({
        'cards': [0, 0, 0],
      }, 0),
    ],
    build: () {
      final p = Prog(inputs: const {'cards': 'array<num>'}, pool: const {'lo': 'num', 'hi': 'num'});
      p.set('lo', p.lit(0));
      p.set('hi', p.sub(p.len(p.get('cards')), p.lit(1)));
      p.whil(p.lt(p.get('lo'), p.get('hi')), () {
        p.iff(
          p.lt(p.at(p.get('cards'), p.get('lo')), p.at(p.get('cards'), p.get('hi'))),
          () => p.inc('lo'),
          els: () => p.dec('hi'),
        );
      });
      p.ret(p.at(p.get('cards'), p.get('lo')));
      return _Built(p.graph, p.graph);
    },
  ),
];
