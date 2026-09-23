import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';

/// Level 6: can every listed puzzle be reached?
///
/// It plays the campaign with the game's own unlock rules
/// ([evaluateUnlocks] — the function the app runs, not a copy) as a player
/// who solves everything the moment it opens, until nothing new opens. What
/// is still closed then can never be reached by anyone, and is refused:
///
/// - a prerequisite no world teaches (it can never be learned);
/// - a world or a puzzle that never opens, with the concepts it waits for and
///   why each of them is never mastered;
/// - circular gating — a world waiting for a concept that only a world behind
///   it teaches, a puzzle gated behind its own world, a world requiring what
///   it teaches — reported as the cycle itself (`world_05 → world_07 →
///   world_05`).
///
/// Worlds with no puzzles yet only warn: they cannot lock anyone out today.
/// A prerequisite that is taught only by a world later in the manifest order
/// is advice (the campaign still works, but the order misleads).
///
/// It never changes the rules to make content pass; it reports.
List<ContentIssue> checkProgression({
  required WorldsManifest manifest,
  required Map<String, Puzzle> listed,
  required String worldsFile,
  required Map<String, String> puzzleFiles,
}) {
  final issues = <ContentIssue>[];
  void report(Severity severity, String file, String path, String message, {String? puzzle}) =>
      issues.add(ContentIssue(severity, file, path, message, level: Level.progression, puzzle: puzzle));

  final worlds = manifest.worlds;
  final worldIndex = {for (final (i, w) in worlds.indexed) w.id: i};
  final prerequisites = {for (final e in listed.entries) e.key: e.value.prerequisites};
  final teachers = <String, List<String>>{};
  for (final w in worlds) {
    for (final c in w.concepts) {
      (teachers[c] ??= []).add(w.id);
    }
  }

  // The perfect player.
  final completed = <String>{};
  var state = evaluateUnlocks(manifest, prerequisites, completed);
  while (true) {
    final fresh = state.openPuzzles.difference(completed);
    if (fresh.isEmpty) break;
    completed.addAll(fresh);
    state = evaluateUnlocks(manifest, prerequisites, completed);
  }

  String worldOf(String puzzleId) => worlds.firstWhere((w) => w.puzzleIds.contains(puzzleId)).id;
  String why(String concept) {
    final by = teachers[concept];
    if (by == null) return '"$concept" is taught by no world';
    return '"$concept" is taught by ${by.join(', ')}, which never '
        '${by.length == 1 ? 'completes' : 'complete'}';
  }

  // Concepts nobody teaches.
  for (final (i, w) in worlds.indexed) {
    for (final (j, c) in w.prerequisites.indexed) {
      if (teachers.containsKey(c)) continue;
      if (w.puzzleIds.isEmpty) {
        report(Severity.warning, worldsFile, 'worlds[$i].prerequisites[$j]', 'No world teaches "$c".');
      } else {
        report(Severity.error, worldsFile, 'worlds[$i].prerequisites[$j]',
            'No world teaches "$c", so ${w.id} and its ${w.puzzleIds.length} puzzle(s) can never open.');
      }
    }
  }
  for (final e in listed.entries) {
    for (final (j, c) in e.value.prerequisites.indexed) {
      if (!teachers.containsKey(c)) {
        report(Severity.error, puzzleFiles[e.key]!, 'prerequisites[$j]',
            'No world teaches "$c", so this puzzle can never open.',
            puzzle: e.key);
      }
    }
  }

  // Worlds and puzzles that never open.
  for (final (i, w) in worlds.indexed) {
    if (state.openWorlds.contains(w.id)) continue;
    final waits = state.missing[w.id] ?? const <String>[];
    final reasons = waits.map(why).join('; ');
    if (w.puzzleIds.isEmpty) {
      report(Severity.warning, worldsFile, 'worlds[$i]', '${w.id} never opens (it has no puzzles yet): $reasons.');
    } else {
      report(Severity.error, worldsFile, 'worlds[$i]', '${w.id} never opens: $reasons.');
    }
  }
  for (final id in listed.keys.toList()..sort()) {
    if (completed.contains(id)) continue;
    final waits = state.missing[id] ?? const <String>[];
    final world = worldOf(id);
    final reason = state.openWorlds.contains(world)
        ? waits.map(why).join('; ')
        : 'its world $world never opens';
    report(Severity.error, puzzleFiles[id]!, 'prerequisites', 'This puzzle can never be reached: $reason.', puzzle: id);
  }

  // Circular gating among whatever is stuck.
  final edges = <String, Set<String>>{};
  void edge(String from, String to) => (edges[from] ??= {}).add(to);
  for (final w in worlds) {
    if (state.completeWorlds.contains(w.id)) continue;
    if (!state.openWorlds.contains(w.id)) {
      for (final c in state.missing[w.id] ?? const <String>[]) {
        for (final t in teachers[c] ?? const <String>[]) {
          edge(w.id, t);
        }
      }
    } else {
      for (final p in w.puzzleIds) {
        if (!completed.contains(p)) edge(w.id, p);
      }
    }
  }
  for (final id in listed.keys) {
    if (completed.contains(id)) continue;
    final world = worldOf(id);
    if (!state.openWorlds.contains(world)) {
      edge(id, world);
      continue;
    }
    for (final c in state.missing[id] ?? const <String>[]) {
      for (final t in teachers[c] ?? const <String>[]) {
        edge(id, t);
      }
    }
  }
  for (final cycle in _cycles(edges)) {
    final path = [...cycle, cycle.first].join(' → ');
    final culprits = cycle.where(listed.containsKey).toList()..sort();
    report(Severity.error, worldsFile, '', 'Circular gating: $path. Nothing in it can ever open.',
        puzzle: culprits.isEmpty ? null : culprits.first);
  }

  // Order advice: a prerequisite taught only later in the manifest.
  for (final (i, w) in worlds.indexed) {
    for (final (j, c) in w.prerequisites.indexed) {
      final by = teachers[c];
      if (by != null && by.every((t) => worldIndex[t]! > i)) {
        report(Severity.warning, worldsFile, 'worlds[$i].prerequisites[$j]',
            '"$c" is taught only by ${by.join(', ')}, later in the campaign than ${w.id}.');
      }
    }
  }
  for (final e in listed.entries) {
    final own = worldIndex[worldOf(e.key)]!;
    for (final (j, c) in e.value.prerequisites.indexed) {
      final by = teachers[c];
      if (by != null && by.every((t) => worldIndex[t]! > own)) {
        report(Severity.warning, puzzleFiles[e.key]!, 'prerequisites[$j]',
            '"$c" is taught only by ${by.join(', ')}, later in the campaign than this puzzle\'s world.',
            puzzle: e.key);
      }
    }
  }
  return issues;
}

/// Strongly connected components with more than one node (or a self loop),
/// each as a cycle in a stable order.
List<List<String>> _cycles(Map<String, Set<String>> edges) {
  final nodes = {...edges.keys, for (final t in edges.values) ...t}.toList()..sort();
  var counter = 0;
  final index = <String, int>{};
  final low = <String, int>{};
  final stack = <String>[];
  final onStack = <String>{};
  final components = <List<String>>[];

  void connect(String v) {
    index[v] = low[v] = counter++;
    stack.add(v);
    onStack.add(v);
    for (final w in (edges[v] ?? const <String>{}).toList()..sort()) {
      if (!index.containsKey(w)) {
        connect(w);
        low[v] = low[v]! < low[w]! ? low[v]! : low[w]!;
      } else if (onStack.contains(w)) {
        low[v] = low[v]! < index[w]! ? low[v]! : index[w]!;
      }
    }
    if (low[v] == index[v]) {
      final component = <String>[];
      String w;
      do {
        w = stack.removeLast();
        onStack.remove(w);
        component.add(w);
      } while (w != v);
      final selfLoop = component.length == 1 && (edges[v]?.contains(v) ?? false);
      if (component.length > 1 || selfLoop) components.add(component);
    }
  }

  for (final v in nodes) {
    if (!index.containsKey(v)) connect(v);
  }
  // Walk each component as a cycle starting from its smallest node.
  return [
    for (final component in components) _walk(component.toSet(), edges),
  ]..sort((a, b) => a.first.compareTo(b.first));
}

/// The shortest cycle through the component's smallest node.
List<String> _walk(Set<String> component, Map<String, Set<String>> edges) {
  final start = (component.toList()..sort()).first;
  final parent = <String, String>{};
  final queue = <String>[start];
  for (var i = 0; i < queue.length; i++) {
    final at = queue[i];
    for (final next in (edges[at] ?? const <String>{}).where(component.contains).toList()..sort()) {
      if (next == start) {
        final path = <String>[at];
        while (path.last != start) {
          path.add(parent[path.last]!);
        }
        return path.reversed.toList();
      }
      if (!parent.containsKey(next) && next != start) {
        parent[next] = at;
        queue.add(next);
      }
    }
  }
  return [start];
}
