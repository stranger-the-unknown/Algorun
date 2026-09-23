import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

/// How a puzzle's performance is judged — tracked by the coverage matrix.
enum PerformanceClass {
  /// Only the answer matters; the budget is generous.
  correctness,

  /// A correct but slow approach is turned away by the operation budget
  /// (the puzzle declares `performance.required`).
  budget,

  /// Mode `optimize`: a correct answer is the start; the budget is the goal.
  optimization,

  /// Mode `restricted`: memory, blocks or the palette are deliberately scarce.
  restricted,
}

/// The primary data structure a puzzle is about. Closed so the coverage
/// matrix counts like with like.
const structures = {
  'scalar',
  'array',
  'grid',
  'hash_map',
  'hash_set',
  'stack',
  'queue',
  'linked_list',
  'tree',
  'graph',
};

/// Fields of a reference file's `spec`.
const specFields = {'family', 'pattern', 'structure', 'secondary', 'performance', 'traps', 'oracle'};

/// Authoring metadata of a campaign puzzle: what it teaches and how it is
/// verified. It lives in the reference file (offline tooling, never bundled),
/// so the player never sees it.
///
/// ```json
/// "spec": {
///   "family": "sliding_window",
///   "pattern": "variable_window_shortest",
///   "structure": "array",
///   "secondary": ["two_pointers"],
///   "performance": "budget",
///   "traps": ["empty day", "a quota the whole day cannot reach"],
///   "oracle": "quota_hours"
/// }
/// ```
///
/// - `family`: an algorithm family from `content/capabilities.json`; a family
///   the language cannot express is refused.
/// - `pattern`: the key reasoning pattern, `lower_snake_case`. Two puzzles with
///   the same pattern are compared for redundancy.
/// - `structure`: one of [structures].
/// - `secondary`: other concepts the puzzle exercises.
/// - `performance`: a [PerformanceClass] name.
/// - `traps`: the edge cases and wrong strategies the hidden cases catch.
/// - `oracle`: the id of the independent oracle in the content tooling.
final class ContentSpec {
  const ContentSpec({
    required this.family,
    required this.pattern,
    required this.structure,
    required this.secondary,
    required this.performance,
    required this.traps,
    required this.oracle,
  });

  final String family;
  final String pattern;
  final String structure;
  final List<String> secondary;
  final PerformanceClass performance;
  final List<String> traps;
  final String oracle;
}

final _snake = RegExp(r'^[a-z][a-z0-9_]*$');

/// Reads a `spec` object, reporting every problem through [error].
ContentSpec? readSpec(Object? raw, void Function(String path, String message) error) {
  if (raw is! Map<String, Object?>) {
    error('spec', 'Must be an object with ${specFields.join(', ')}.');
    return null;
  }
  var ok = true;
  void fail(String path, String message) {
    ok = false;
    error(path, message);
  }

  for (final key in raw.keys) {
    if (!specFields.contains(key)) fail('spec.$key', 'Unknown field "$key". Allowed here: ${specFields.join(', ')}.');
  }
  String? id(String key) {
    final v = raw[key];
    if (v is String && _snake.hasMatch(v)) return v;
    fail('spec.$key', 'Required: a lower_snake_case name.');
    return null;
  }

  final family = id('family');
  final pattern = id('pattern');
  final oracle = id('oracle');
  final structure = raw['structure'];
  if (structure is! String || !structures.contains(structure)) {
    fail('spec.structure', 'Must be one of ${structures.join(', ')}.');
  }
  final secondaryRaw = raw['secondary'] ?? const <Object?>[];
  final secondary = <String>[];
  if (secondaryRaw is! List<Object?> || secondaryRaw.any((s) => s is! String || !_snake.hasMatch(s))) {
    fail('spec.secondary', 'Must be a list of lower_snake_case concepts.');
  } else {
    secondary.addAll(secondaryRaw.cast<String>());
  }
  final performance = PerformanceClass.values.where((c) => c.name == raw['performance']).firstOrNull;
  if (performance == null) {
    fail('spec.performance', 'Must be one of ${PerformanceClass.values.map((c) => c.name).join(', ')}.');
  }
  final trapsRaw = raw['traps'];
  final traps = <String>[];
  if (trapsRaw is! List<Object?> || trapsRaw.isEmpty || trapsRaw.any((t) => t is! String || t.trim().isEmpty)) {
    fail('spec.traps', 'Required: the edge cases and wrong strategies the hidden cases catch, as text.');
  } else {
    traps.addAll(trapsRaw.cast<String>());
  }
  if (!ok) return null;
  return ContentSpec(
    family: family!,
    pattern: pattern!,
    structure: structure! as String,
    secondary: secondary,
    performance: performance!,
    traps: traps,
    oracle: oracle!,
  );
}

enum CapabilityStatus { supported, partial, blocked }

/// One entry of the language capability audit.
final class Capability {
  const Capability(this.status, this.note);

  final CapabilityStatus status;
  final String note;
}

/// `content/capabilities.json`: what the block language (and the product)
/// can express today, by algorithm family and by puzzle mode.
final class Capabilities {
  const Capabilities({required this.families, required this.modes});

  final Map<String, Capability> families;
  final Map<String, Capability> modes;

  /// Reads the audit; throws [FormatException] on a malformed file.
  static Capabilities parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) throw const FormatException('capabilities: an object');
    Map<String, Capability> section(String key) {
      final raw = json[key];
      if (raw is! Map<String, Object?>) throw FormatException('capabilities: "$key" must be an object');
      return {
        for (final e in raw.entries) e.key: _capability(key, e.key, e.value),
      };
    }

    return Capabilities(families: section('families'), modes: section('modes'));
  }

  static Capability _capability(String section, String name, Object? raw) {
    if (raw is! Map<String, Object?>) throw FormatException('capabilities: $section.$name must be an object');
    final status = CapabilityStatus.values.where((s) => s.name == raw['status']).firstOrNull;
    final note = raw['note'];
    if (status == null || note is! String || note.trim().isEmpty) {
      throw FormatException('capabilities: $section.$name needs a status (supported, partial, blocked) and a note');
    }
    return Capability(status, note);
  }
}

/// `performance` must agree with what the puzzle declares.
List<String> performanceMismatch(ContentSpec spec, Puzzle puzzle) {
  return switch (spec.performance) {
    PerformanceClass.budget when !puzzle.performance.required => [
        'A "budget" puzzle must declare "performance": {"required": true} so a correct-but-slow '
            'baseline is proven to fail.',
      ],
    PerformanceClass.optimization when puzzle.mode != PuzzleMode.optimize || !puzzle.performance.required => [
        'An "optimization" puzzle is mode "optimize" and declares "performance": {"required": true}.',
      ],
    PerformanceClass.restricted when puzzle.mode != PuzzleMode.restricted => [
        'A "restricted" puzzle is mode "restricted".',
      ],
    _ => const [],
  };
}
