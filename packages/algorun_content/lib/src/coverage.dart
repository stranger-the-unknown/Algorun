import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import 'content_spec.dart';

/// One accepted campaign puzzle as the coverage matrix counts it.
final class CoverageEntry {
  const CoverageEntry({required this.puzzle, required this.world, required this.spec});

  final Puzzle puzzle;
  final WorldDef world;
  final ContentSpec spec;
}

/// `content/coverage_targets.json`: planning targets, not rules.
///
/// ```json
/// {
///   "total": 300,
///   "worlds": {"world_02": {"target": 30, "tiers": [1, 2, 3, 4]}},
///   "families": {"graph_bfs": 8},
///   "modes": {"budget": 20}
/// }
/// ```
final class CoverageTargets {
  const CoverageTargets({required this.total, required this.worlds, required this.families, required this.modes});

  final int total;
  final Map<String, ({int target, List<int> tiers})> worlds;
  final Map<String, int> families;
  final Map<String, int> modes;

  static CoverageTargets parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) throw const FormatException('coverage targets: an object');
    int count(Object? v, String where) {
      if (v is int && v >= 0) return v;
      throw FormatException('coverage targets: $where must be a whole number');
    }

    final worlds = <String, ({int target, List<int> tiers})>{};
    for (final e in ((json['worlds'] ?? const {}) as Map<String, Object?>).entries) {
      final w = e.value! as Map<String, Object?>;
      worlds[e.key] = (
        target: count(w['target'], 'worlds.${e.key}.target'),
        tiers: [for (final t in (w['tiers'] ?? const []) as List<Object?>) count(t, 'worlds.${e.key}.tiers')],
      );
    }
    Map<String, int> counts(String key) => {
          for (final e in ((json[key] ?? const {}) as Map<String, Object?>).entries) e.key: count(e.value, '$key.${e.key}'),
        };
    return CoverageTargets(
      total: count(json['total'], 'total'),
      worlds: worlds,
      families: counts('families'),
      modes: counts('modes'),
    );
  }
}

int _tier(Puzzle p) => p.tier.index + 1;

Map<String, int> _count(Iterable<String> keys) {
  final out = <String, int>{};
  for (final k in keys) {
    out[k] = (out[k] ?? 0) + 1;
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

/// The machine-readable coverage matrix, and the gaps against [targets].
/// Deterministic: the same corpus always gives the same JSON.
Map<String, Object?> coverageMatrix({
  required WorldsManifest manifest,
  required List<CoverageEntry> entries,
  required Capabilities? capabilities,
  required CoverageTargets? targets,
}) {
  final sorted = [...entries]..sort((a, b) => a.puzzle.id.compareTo(b.puzzle.id));
  final tiers = {for (var t = 1; t <= 5; t++) '$t': 0};
  for (final e in sorted) {
    tiers['${_tier(e.puzzle)}'] = tiers['${_tier(e.puzzle)}']! + 1;
  }

  final worlds = <Object?>[];
  final gaps = <Object?>[];
  for (final w in manifest.worlds) {
    final mine = sorted.where((e) => e.world.id == w.id).toList();
    final worldTiers = {for (var t = 1; t <= 5; t++) '$t': mine.where((e) => _tier(e.puzzle) == t).length};
    final target = targets?.worlds[w.id];
    final blocked = [
      for (final c in w.concepts)
        if (capabilities?.families[c]?.status == CapabilityStatus.blocked) c,
    ];
    worlds.add({
      'id': w.id,
      'title': w.title,
      'concepts': w.concepts,
      'count': mine.length,
      'tiers': worldTiers,
      'families': _count(mine.map((e) => e.spec.family)),
      'patterns': _count(mine.map((e) => e.spec.pattern)),
      if (target != null) 'target': target.target,
    });
    if (target == null) continue;
    final note = blocked.isEmpty ? null : 'blocked by the language: ${blocked.join(', ')}';
    if (mine.length < target.target) {
      gaps.add({
        'area': 'world',
        'id': w.id,
        'have': mine.length,
        'want': target.target,
        'note': ?note,
      });
    }
    final missingTiers = [for (final t in target.tiers) if (worldTiers['$t'] == 0) t];
    if (missingTiers.isNotEmpty) {
      gaps.add({'area': 'tiers', 'id': w.id, 'missing': missingTiers, 'note': ?note});
    }
  }
  final families = _count(sorted.map((e) => e.spec.family));
  for (final e in (targets?.families ?? const <String, int>{}).entries) {
    final have = families[e.key] ?? 0;
    if (have < e.value) {
      final status = capabilities?.families[e.key]?.status;
      gaps.add({
        'area': 'family',
        'id': e.key,
        'have': have,
        'want': e.value,
        if (status == CapabilityStatus.blocked) 'note': 'blocked by the language',
      });
    }
  }
  final modes = _count(sorted.map((e) => e.puzzle.mode.name));
  for (final e in (targets?.modes ?? const <String, int>{}).entries) {
    final have = modes[e.key] ?? 0;
    if (have < e.value) {
      final status = capabilities?.modes[e.key]?.status;
      gaps.add({
        'area': 'mode',
        'id': e.key,
        'have': have,
        'want': e.value,
        if (status == CapabilityStatus.blocked) 'note': 'blocked: ${capabilities!.modes[e.key]!.note}',
      });
    }
  }

  return {
    'total': sorted.length,
    if (targets != null) 'targetTotal': targets.total,
    'tiers': tiers,
    'modes': modes,
    'structures': _count(sorted.map((e) => e.spec.structure)),
    'families': families,
    'performance': _count(sorted.map((e) => e.spec.performance.name)),
    'concepts': _count(sorted.expand((e) => {...e.puzzle.concepts, ...e.spec.secondary})),
    'worlds': worlds,
    'puzzles': [
      for (final e in sorted)
        {
          'id': e.puzzle.id,
          'world': e.world.id,
          'tier': _tier(e.puzzle),
          'mode': e.puzzle.mode.name,
          'family': e.spec.family,
          'pattern': e.spec.pattern,
          'structure': e.spec.structure,
          'secondary': e.spec.secondary,
          'performance': e.spec.performance.name,
          'concepts': e.puzzle.concepts,
        },
    ],
    'gaps': gaps,
  };
}

/// The matrix as the committed file holds it.
String coverageJson(Map<String, Object?> matrix) => '${const JsonEncoder.withIndent('  ').convert(matrix)}\n';
