import 'package:algorun_engine/algorun_engine.dart';

import 'content_spec.dart';

/// What the reference solution says about how hard a puzzle is.
final class DifficultySignals {
  const DifficultySignals({
    required this.blocks,
    required this.loopDepth,
    required this.structures,
    required this.stateVariables,
    required this.concepts,
    required this.budget,
  });

  /// Measured from the reference program and the puzzle.
  factory DifficultySignals.of(Puzzle puzzle, ContentSpec spec, BlockGraph solution) {
    const loops = {BlockIds.ctrlWhile, BlockIds.ctrlForRange, BlockIds.ctrlForEach};
    var depth = 0;
    void walk(List<String> ids, int d) {
      for (final id in ids) {
        final block = solution.blocks[id];
        if (block == null) continue;
        final here = loops.contains(block.catalogId) ? d + 1 : d;
        if (here > depth) depth = here;
        final def = BlockCatalog.of(block.catalogId);
        for (final port in def?.inputs ?? const <PortDefinition>[]) {
          if (port.isStmt) walk(solution.slotList(id, port.name), here);
          if (port.kind == PortKind.elseClause) {
            for (final e in solution.slotList(id, port.name)) {
              walk(solution.slotList(e, 'body'), here);
            }
          }
        }
      }
    }

    walk(solution.entryIds, 0);
    const containers = {TypeAtom.array, TypeAtom.map, TypeAtom.set, TypeAtom.stack, TypeAtom.queue, TypeAtom.heap};
    final givens = {for (final b in puzzle.io.inputs) b.name};
    // Structures the program builds itself: a graph handed in as input and
    // walked with one queue is one structure of the solver's choosing.
    final kinds = {
      for (final e in solution.variables.entries)
        if (!givens.contains(e.key) && containers.contains(e.value.atom)) e.value.atom,
    };
    return DifficultySignals(
      blocks: solution.blocks.length,
      loopDepth: depth,
      structures: kinds.length,
      stateVariables: solution.variables.keys.where((v) => !givens.contains(v)).length,
      concepts: {...puzzle.concepts, ...spec.secondary}.length,
      budget: spec.performance != PerformanceClass.correctness,
    );
  }

  final int blocks;
  final int loopDepth;
  final int structures;
  final int stateVariables;
  final int concepts;
  final bool budget;

  /// A tier estimate from several independent signals — never block count
  /// alone. Half a point each for: 30 or more blocks, 55 or more blocks,
  /// nested loops, three levels of nesting, two or more structures the
  /// program builds, three or more, five or more state variables, four or
  /// more concepts, and a performance requirement. The estimate is 1 plus
  /// the rounded points, capped at 5. Calibrated on the MS12 corpus.
  int get estimate {
    var points = 0.0;
    if (blocks >= 30) points += 0.5;
    if (blocks >= 55) points += 0.5;
    if (loopDepth >= 2) points += 0.5;
    if (loopDepth >= 3) points += 0.5;
    if (structures >= 2) points += 0.5;
    if (structures >= 3) points += 0.5;
    if (stateVariables >= 5) points += 0.5;
    if (concepts >= 4) points += 0.5;
    if (budget) points += 0.5;
    final estimate = 1 + points.round();
    return estimate > 5 ? 5 : estimate;
  }

  @override
  String toString() =>
      '$blocks blocks, loop depth $loopDepth, $structures structure(s), $stateVariables state variable(s), '
      '$concepts concept(s)${budget ? ', a budget' : ''}';
}

/// Tier metadata that the reference clearly contradicts, or null:
///
/// - the reference looks at least two tiers harder than declared (heavy
///   machinery labelled easy), or
/// - a tier 4 or 5 puzzle whose reference is trivial (estimate 1).
///
/// Advice, not a gate. A short program can still be a hard puzzle — the
/// insight is not in the block count — so a hard tier on a small program is
/// only flagged when the program is trivial.
String? difficultyMismatch(Puzzle puzzle, DifficultySignals signals) {
  final tier = puzzle.tier.index + 1;
  final estimate = signals.estimate;
  if (estimate - tier >= 2) {
    return 'Declared tier $tier, but the reference looks like tier $estimate ($signals).';
  }
  if (tier >= 4 && estimate <= 1) {
    return 'Declared tier $tier, but the reference is trivial ($signals).';
  }
  return null;
}
