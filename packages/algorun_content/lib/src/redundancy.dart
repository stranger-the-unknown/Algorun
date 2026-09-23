import 'package:algorun_engine/algorun_engine.dart';

import 'content_spec.dart';

/// What a puzzle is, for comparing it with every other puzzle — never its
/// title or story.
final class Fingerprint {
  Fingerprint({
    required this.puzzleId,
    required this.order,
    required this.pattern,
    required this.family,
    required this.io,
    required this.mode,
    required this.concepts,
    required this.skeleton,
    required this.histogram,
  });

  /// Built from a puzzle, its spec and its reference solution. [order] is the
  /// puzzle's place in the campaign (world, then list position).
  factory Fingerprint.of(Puzzle puzzle, ContentSpec spec, BlockGraph solution, int order) => Fingerprint(
        puzzleId: puzzle.id,
        order: order,
        pattern: spec.pattern,
        family: spec.family,
        io: ioSignature(puzzle),
        mode: puzzle.mode.name,
        concepts: {...puzzle.concepts, ...spec.secondary},
        skeleton: skeletonOf(solution),
        histogram: histogramOf(solution),
      );

  final String puzzleId;
  final int order;
  final String pattern;
  final String family;
  final String io;
  final String mode;
  final Set<String> concepts;
  final String skeleton;
  final Map<String, int> histogram;
}

/// `(array<num>,num)->num`: input types in order, then the output type.
String ioSignature(Puzzle puzzle) =>
    '(${puzzle.io.inputs.map((b) => b.type).join(',')})->${puzzle.io.output}';

/// The statement structure of a program: every instruction by catalog id,
/// nested as it is nested, with names, literals and expressions left out.
/// `var.set` and `ctrl.return` are kept: where a program assigns and returns
/// is part of its shape.
String skeletonOf(BlockGraph graph) {
  late final String Function(List<String>) list;
  String statement(String id) {
    final block = graph.blocks[id];
    if (block == null) return '?';
    final def = BlockCatalog.of(block.catalogId);
    final bodies = <String>[];
    for (final port in def?.inputs ?? const <PortDefinition>[]) {
      if (port.isStmt) bodies.add(list(graph.slotList(id, port.name)));
      if (port.kind == PortKind.elseClause) {
        for (final elseId in graph.slotList(id, port.name)) {
          bodies.add('else:${list(graph.slotList(elseId, 'body'))}');
        }
      }
    }
    return bodies.isEmpty ? block.catalogId : '${block.catalogId}{${bodies.join('|')}}';
  }

  list = (ids) => ids.map(statement).join(',');
  return list(graph.entryIds);
}

/// Blocks that carry meaning, counted by catalog id. Reading variables and
/// writing literals is everywhere, so it is not counted.
Map<String, int> histogramOf(BlockGraph graph) {
  const ignored = {BlockIds.varGet, BlockIds.litNum, BlockIds.litBool, BlockIds.litNull, BlockIds.ctrlElse};
  final counts = <String, int>{};
  for (final block in graph.blocks.values) {
    if (ignored.contains(block.catalogId)) continue;
    counts[block.catalogId] = (counts[block.catalogId] ?? 0) + 1;
  }
  return counts;
}

/// Weighted Jaccard similarity of two histograms, 0 to 1.
double similarity(Map<String, int> a, Map<String, int> b) {
  var shared = 0;
  var total = 0;
  for (final key in {...a.keys, ...b.keys}) {
    final x = a[key] ?? 0;
    final y = b[key] ?? 0;
    shared += x < y ? x : y;
    total += x > y ? x : y;
  }
  return total == 0 ? 1 : shared / total;
}

enum Redundancy { unique, related, nearDuplicate }

/// The documented, deterministic rule. For two campaign puzzles A and B:
///
/// - **near duplicate** when they have the same io signature and either
///   (a) the same `pattern` and (the same skeleton or a histogram similarity
///   of at least [nearDuplicateSimilarity]), or (b) a different `pattern` but
///   the same skeleton, the same concepts and a similarity of at least
///   [renamedPatternSimilarity] — the same exercise under a new pattern name;
/// - **related** when they share the `pattern`, or the same skeleton, or a
///   similarity of at least [nearDuplicateSimilarity];
/// - **unique** otherwise.
///
/// A near duplicate is an error against the puzzle that comes later in the
/// campaign; related pairs are reported as information.
const nearDuplicateSimilarity = 0.8;
const renamedPatternSimilarity = 0.9;

({Redundancy kind, double similarity, bool sameSkeleton}) compareFingerprints(Fingerprint a, Fingerprint b) {
  final sim = similarity(a.histogram, b.histogram);
  final sameSkeleton = a.skeleton == b.skeleton;
  final samePattern = a.pattern == b.pattern;
  final sameIo = a.io == b.io;
  final sameConcepts = a.concepts.length == b.concepts.length && a.concepts.containsAll(b.concepts);
  final near = sameIo &&
      ((samePattern && (sameSkeleton || sim >= nearDuplicateSimilarity)) ||
          (!samePattern && sameSkeleton && sameConcepts && sim >= renamedPatternSimilarity));
  if (near) return (kind: Redundancy.nearDuplicate, similarity: sim, sameSkeleton: sameSkeleton);
  if (samePattern || sameSkeleton || sim >= nearDuplicateSimilarity) {
    return (kind: Redundancy.related, similarity: sim, sameSkeleton: sameSkeleton);
  }
  return (kind: Redundancy.unique, similarity: sim, sameSkeleton: sameSkeleton);
}

/// Every pair that is not unique, the later puzzle second.
List<({Fingerprint earlier, Fingerprint later, Redundancy kind, double similarity, bool sameSkeleton})> redundancyReport(
  List<Fingerprint> fingerprints,
) {
  final sorted = [...fingerprints]..sort((a, b) => a.order.compareTo(b.order));
  final out = <({Fingerprint earlier, Fingerprint later, Redundancy kind, double similarity, bool sameSkeleton})>[];
  for (var j = 0; j < sorted.length; j++) {
    for (var i = 0; i < j; i++) {
      final r = compareFingerprints(sorted[i], sorted[j]);
      if (r.kind != Redundancy.unique) {
        out.add((
          earlier: sorted[i],
          later: sorted[j],
          kind: r.kind,
          similarity: r.similarity,
          sameSkeleton: r.sameSkeleton,
        ));
      }
    }
  }
  return out;
}
