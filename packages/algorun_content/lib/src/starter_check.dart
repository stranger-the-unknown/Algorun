import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'editor_replay.dart';

/// The most blocks a `repair` starter may differ from its reference in. A
/// realistic bug is one slip — a bound, a comparison, a missing update — not
/// a different program.
const repairMaxChangedBlocks = 4;

/// The fewest questions a `predict` puzzle asks (one per visible case).
const predictMinQuestions = 2;

/// Checks a puzzle's starter program (M1) against what its mode promises.
///
/// Every starter, in any mode:
///
/// * **buildable and typed** (level 3): rebuilt through the editor's own
///   commands, exactly like a reference, so every connection in it passes
///   `GraphTyping.canConnect`. Empty holes are fine — they are what the
///   player fills;
/// * **locks survive** (level 3): every locked block is in the reference
///   solution, unchanged and in the same place, so the reference is something
///   the player can reach without touching a lock.
///
/// `complete`: the starter does **not** pass the tests, and the reference
/// **only adds** to it — every starter block is in the reference with the
/// same contents and the same neighbours in the same order.
///
/// `repair`: the starter is a whole program that runs, it does **not** pass
/// the tests, and it differs from the reference in at most
/// [repairMaxChangedBlocks] blocks.
///
/// `predict`: the starter is a whole program that runs, it **is** the
/// reference (the same lowered program), it returns every fixture's answer —
/// so each expected answer is the reference's own output, which the oracle
/// has already been compared with — and there are at least
/// [predictMinQuestions] visible cases to ask.
///
/// That the reference itself passes, and agrees with the independent oracle,
/// is `ReferenceChecker`'s job and unchanged.
final class StarterChecker {
  const StarterChecker({this.engine = const DefaultEngine()});

  final AlgorunEngine engine;

  /// [file] is the puzzle's file. [reference] is the decoded reference
  /// solution, or null when there is none to compare with (not given, or
  /// unreadable — reported elsewhere).
  void check(Puzzle puzzle, String file, List<ContentIssue> issues, {BlockGraph? reference}) {
    final starter = puzzle.starter;
    if (starter == null) return;
    void error(int level, String path, String message) =>
        issues.add(ContentIssue(Severity.error, file, path, message, level: level, puzzle: puzzle.id));
    void info(int level, String path, String message) =>
        issues.add(ContentIssue(Severity.info, file, path, message, level: level, puzzle: puzzle.id));

    final replay = replayInEditor(starter.graph, puzzle);
    for (final issue in replay) {
      error(Level.replay, 'starter.graph.${issue.path}', issue.message);
    }
    if (replay.isNotEmpty) return;

    if (reference != null) _locks(starter, reference, error);

    switch (puzzle.mode) {
      case PuzzleMode.complete:
        _complete(puzzle, starter, reference, error);
      case PuzzleMode.repair:
        _repair(puzzle, starter, reference, error, info);
      case PuzzleMode.predict:
        _predict(puzzle, starter, reference, error);
      default:
        break;
    }
  }

  void _locks(StarterProgram starter, BlockGraph reference, void Function(int, String, String) error) {
    for (final id in starter.locked) {
      final mine = starter.graph.blocks[id]!;
      final theirs = reference.blocks[id];
      final path = 'starter.locked';
      if (theirs == null) {
        error(Level.replay, path, 'The reference solution has no block "$id": it could not be built with this lock.');
      } else if (!_sameContents(mine, theirs)) {
        error(Level.replay, path, 'The reference solution changes the locked block "$id".');
      } else if (_place(starter.graph, id) != _place(reference, id)) {
        error(Level.replay, path, 'The reference solution moves the locked block "$id".');
      }
    }
  }

  void _complete(
    Puzzle puzzle,
    StarterProgram starter,
    BlockGraph? reference,
    void Function(int, String, String) error,
  ) {
    final program = _lowered(puzzle, starter.graph);
    if (program != null && engine.runTests(program, puzzle).ok) {
      error(Level.execution, 'starter.graph', 'The starter already passes every case: nothing is left to complete.');
    }
    if (reference == null) return;
    var contained = true;
    for (final block in starter.graph.blocks.values) {
      final theirs = reference.blocks[block.id];
      final path = 'starter.graph.blocks.${block.id}';
      if (theirs == null) {
        error(Level.replay, path, 'Not in the reference solution: completing a program only adds to it.');
        contained = false;
        continue;
      }
      if (!_sameContents(block, theirs)) {
        error(Level.replay, path, 'The reference solution changes this block: completing a program only adds to it.');
        contained = false;
        continue;
      }
      for (final entry in block.slots.entries) {
        if (!_within(_ids(entry.value), _ids(theirs.slots[entry.key]))) {
          error(Level.replay, '$path.slots.${entry.key}',
              'The reference solution rearranges what the starter put here: completing a program only adds to it.');
          contained = false;
        }
      }
    }
    if (!_within(starter.graph.entryIds, reference.entryIds)) {
      error(Level.replay, 'starter.graph.entryIds',
          'The reference solution rearranges the starter\'s top-level instructions: completing a program only adds to it.');
      contained = false;
    }
    if (contained && reference.blocks.length <= starter.graph.blocks.length) {
      error(Level.replay, 'starter.graph', 'The reference solution adds nothing to the starter.');
    }
  }

  void _repair(
    Puzzle puzzle,
    StarterProgram starter,
    BlockGraph? reference,
    void Function(int, String, String) error,
    void Function(int, String, String) info,
  ) {
    final program = _whole(puzzle, starter.graph, 'repair', error);
    if (program != null) {
      final suite = engine.runTests(program, puzzle);
      if (suite.ok) {
        error(Level.execution, 'starter.graph', 'The starter already passes every case: there is nothing to repair.');
      } else {
        const runner = TestRunner();
        final failed = [
          for (final testCase in puzzle.allTests)
            if (!runner.runCases(program, puzzle, [testCase]).ok) testCase,
        ];
        info(
          Level.execution,
          'starter.graph',
          'The starter ends in ${suite.kind.label}: it fails ${failed.length} of ${puzzle.allTests.length} case(s), '
          '${failed.where((c) => c.visible).length} of them visible.',
        );
      }
    }
    if (reference == null) return;
    final changed = changedBlocks(starter.graph, reference);
    if (changed.isEmpty) {
      error(Level.replay, 'starter.graph', 'The starter is the reference solution: there is nothing to repair.');
    } else if (changed.length > repairMaxChangedBlocks) {
      error(
        Level.replay,
        'starter.graph',
        'The starter differs from the reference solution in ${changed.length} blocks (${changed.join(', ')}); '
        'a repair is at most $repairMaxChangedBlocks. A realistic bug is one slip, not another program.',
      );
    }
  }

  void _predict(
    Puzzle puzzle,
    StarterProgram starter,
    BlockGraph? reference,
    void Function(int, String, String) error,
  ) {
    if (puzzle.visibleTests.length < predictMinQuestions) {
      error(Level.execution, 'fixtures.visible',
          'A predict puzzle asks one question per visible case; give at least $predictMinQuestions.');
    }
    final program = _whole(puzzle, starter.graph, 'predict', error);
    if (program == null) return;
    // The player is graded against what this program returns, so a fixture
    // that says otherwise would be a wrong answer shown as the right one.
    const runner = TestRunner();
    for (final testCase in puzzle.allTests) {
      final suite = runner.runCases(program, puzzle, [testCase]);
      if (!suite.ok) {
        final side = testCase.visible ? 'visible' : 'hidden';
        error(Level.execution, 'starter.graph',
            'The program does not return the expected answer of $side case "${testCase.id}" (${suite.kind.label}).');
      }
    }
    if (reference == null) return;
    final theirs = _lowered(puzzle, reference);
    if (theirs == null) return; // The reference's own errors are reported with it.
    if (jsonEncode(program.toJson()) != jsonEncode(theirs.toJson())) {
      error(Level.replay, 'starter.graph',
          'A predict puzzle shows its reference solution: the starter and the reference must be the same program.');
    }
  }

  /// The starter as a program that runs, or null with the reasons reported.
  Program? _whole(Puzzle puzzle, BlockGraph graph, String mode, void Function(int, String, String) error) {
    final lowered = engine.lower(graph, puzzle);
    for (final m in lowered.errors) {
      error(
        Level.replay,
        m.blockId == null ? 'starter.graph' : 'starter.graph.blocks.${m.blockId}',
        'A $mode starter must be a whole program that runs: ${m.message}',
      );
    }
    return lowered.program;
  }

  Program? _lowered(Puzzle puzzle, BlockGraph graph) => engine.lower(graph, puzzle).program;
}

/// The blocks in which [starter] and [reference] differ, by id: a block only
/// one of them has, or one whose kind, contents or plugged-in blocks differ.
/// `@main` stands for a different top-level order.
List<String> changedBlocks(BlockGraph starter, BlockGraph reference) {
  final out = <String>[];
  for (final id in {...starter.blocks.keys, ...reference.blocks.keys}) {
    final a = starter.blocks[id];
    final b = reference.blocks[id];
    if (a == null || b == null || !_sameContents(a, b) || !_sameSlots(a, b)) out.add(id);
  }
  if (!_listEquals(starter.entryIds, reference.entryIds)) out.add(BlockGraph.mainId);
  return out..sort();
}

bool _sameContents(BlockInstance a, BlockInstance b) =>
    a.catalogId == b.catalogId && _canonical(a.literals) == _canonical(b.literals);

bool _sameSlots(BlockInstance a, BlockInstance b) {
  final keys = {...a.slots.keys, ...b.slots.keys};
  return keys.every((k) => _listEquals(_ids(a.slots[k]), _ids(b.slots[k])));
}

String _canonical(Map<String, Object?> literals) =>
    jsonEncode({for (final k in literals.keys.toList()..sort()) k: literals[k]});

List<String> _ids(SlotBinding? slot) => switch (slot) {
      null => const [],
      RefBinding(:final blockId) => [blockId],
      ListBinding(:final blockIds) => blockIds,
    };

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether [part] appears in [whole] in the same order (other items may sit
/// between).
bool _within(List<String> part, List<String> whole) {
  var at = 0;
  for (final id in whole) {
    if (at < part.length && part[at] == id) at++;
  }
  return at == part.length;
}

/// Where a block is plugged in: the block and port that hold it.
String _place(BlockGraph graph, String id) {
  final parent = graph.parentOf(id);
  return parent == null ? '' : '${parent.blockId}.${parent.port}';
}
