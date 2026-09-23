import '../runner/validators.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../types/value_type.dart';

enum PuzzleMode {
  build,
  complete,
  repair,
  optimize,
  structure,
  trace,
  predict,
  edge,
  budget,
  restricted,
  complexity,
  ops,
}

enum PuzzleTier { t1, t2, t3, t4, t5 }

/// Where hidden tests are evaluated. MVP is always [local]. Remote is
/// reserved so a later competitive mode can move hidden tests off-device
/// without rewriting the engine API.
enum VerdictSource { local, remote }

final class BlockPolicy {
  const BlockPolicy({
    required this.allow,
    this.forbid = const {},
    this.maxBlocks,
  });

  /// Closed allowlist. The editor palette is exactly this set.
  final Set<String> allow;
  final Set<String> forbid;
  final int? maxBlocks;

  bool allows(String catalogId) =>
      allow.contains(catalogId) && !forbid.contains(catalogId);
}

final class IoBinding {
  const IoBinding({required this.name, required this.type});
  final String name;
  final ValueType type;
}

final class IoSpec {
  const IoSpec({
    required this.inputs,
    required this.output,
    this.outputOrderMatters = true,
  });

  final List<IoBinding> inputs;
  final ValueType output;
  final bool outputOrderMatters;
}

final class ConstraintSpec {
  const ConstraintSpec({this.nMin, this.nMax, this.notes = const []});
  final int? nMin;
  final int? nMax;
  final List<String> notes;
}

final class ScoringSpec {
  const ScoringSpec({this.blockBudget, this.hintPenalty = true});
  final int? blockBudget;
  final bool hintPenalty;
}

/// Declares that a puzzle is backed by a reference solution.
///
/// The solution itself is never part of the puzzle: it lives with the offline
/// content tooling (`content/references/<world>/<id>.json`) and never ships in
/// the app. [strategy] names the intended approach so tooling can reason about
/// the content set (for example, spotting two puzzles that are the same idea).
final class PuzzleReference {
  const PuzzleReference({required this.strategy});

  final String strategy;
}

/// How a puzzle treats performance. The operation budget itself is
/// `limits.maxOps` — the one authoritative number; this only says whether
/// meeting it is the point of the puzzle.
final class PerformanceSpec {
  const PerformanceSpec({this.required = false, this.baselineFactor});

  /// Performance is part of the goal: the content tooling requires the
  /// reference file to prove that a correct but slow approach is turned away.
  final bool required;

  /// When set, that slow baseline must need at least this many times a case's
  /// budget — so any passing solution beats it by at least this factor.
  final int? baselineFactor;

  static const none = PerformanceSpec();
}

/// One fixture, already decoded and type-checked against the puzzle's io by
/// the schema. The runner hands [input] to the interpreter, which copies it on
/// entry, so a run never changes these values.
final class TestCase {
  const TestCase({
    required this.id,
    required this.input,
    required this.output,
    this.visible = true,
    this.maxOps,
  });

  final String id;

  /// One value per declared input, keyed by input name.
  final Map<String, RuntimeValue> input;

  /// The expected result, compared with the puzzle's named validator.
  final RuntimeValue output;

  final bool visible;

  /// A tighter operation budget for this case only, for example a small input
  /// that must stay cheap. Never larger than the puzzle's `limits.maxOps`.
  final int? maxOps;
}

final class Puzzle {
  const Puzzle({
    required this.id,
    required this.title,
    required this.world,
    required this.mode,
    required this.tier,
    required this.story,
    required this.io,
    required this.blocks,
    required this.limits,
    required this.visibleTests,
    required this.hiddenTests,
    required this.outputValidator,
    this.version = 1,
    this.chapter = '',
    this.concepts = const [],
    this.prerequisites = const [],
    this.constraints = const ConstraintSpec(),
    this.scoring = const ScoringSpec(),
    this.hints = const [],
    this.edgeCases = const [],
    this.verdictSource = VerdictSource.local,
    this.variablePool = const [],
    this.meta = const {},
    this.reference,
    this.performance = PerformanceSpec.none,
  });

  final String id;
  final int version;
  final String title;
  final String world;
  final String chapter;
  final PuzzleTier tier;
  final PuzzleMode mode;
  final List<String> concepts;
  final List<String> prerequisites;
  final String story;
  final IoSpec io;
  final ConstraintSpec constraints;
  final BlockPolicy blocks;
  final PerformanceTarget limits;
  final ScoringSpec scoring;
  final List<String> hints;

  /// A name from the closed validator registry, checked against [io] output.
  final ValidatorId outputValidator;
  final List<TestCase> visibleTests;
  final List<TestCase> hiddenTests;
  final List<String> edgeCases;
  final VerdictSource verdictSource;

  /// Closed names the player may CREATE. Not free text.
  final List<IoBinding> variablePool;

  /// Reserved forward-compatible metadata: flat string / number / boolean
  /// values the engine never reads. Nothing in it is ever executed.
  final Map<String, Object> meta;

  /// Reference-solution metadata, or null for a puzzle without one. Every
  /// puzzle a player can reach must have one (checked by the content tooling).
  final PuzzleReference? reference;

  final PerformanceSpec performance;

  /// The operation budget for [testCase]: its own, or the puzzle's.
  int opsBudgetFor(TestCase testCase) => testCase.maxOps ?? limits.maxOps;

  /// Hidden tests are UI-hidden only. On a local APK they can be unpacked.
  /// Do not treat them as cryptographic secrets.
  List<TestCase> get allTests => [...visibleTests, ...hiddenTests];
}
