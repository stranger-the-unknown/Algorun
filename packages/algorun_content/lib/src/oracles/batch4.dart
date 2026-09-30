import 'dart:math';

import 'oracle.dart';

// MS15 part 3: Sliding Window, Stack & Queue, Linked Lists, Trees, Graphs,
// Dynamic Programming. Each answer is computed another way than the
// reference: brute force, simulation of the story, recursion, union-find,
// patience sorting.

// Calm Stretches — every stretch added up.
Object? calmStretches(Map<String, Object?> input) {
  final rain = ints(input['rain']);
  final limit = integer(input['limit']);
  var count = 0;
  for (var i = 0; i < rain.length; i++) {
    var total = 0;
    for (var j = i; j < rain.length; j++) {
      total += rain[j];
      if (total <= limit) count++;
    }
  }
  return count;
}

Map<String, Object?> calmStretchesSample(Random r) =>
    {'rain': randomInts(r, between(r, 0, 10), 0, 6), 'limit': between(r, 0, 10)};

// Window Variety — a set per window.
Object? windowVariety(Map<String, Object?> input) {
  final songs = ints(input['songs']);
  final k = integer(input['k']);
  return [for (var i = 0; i + k <= songs.length; i++) songs.sublist(i, i + k).toSet().length];
}

Map<String, Object?> windowVarietySample(Random r) =>
    {'songs': randomInts(r, between(r, 0, 10), 1, 4), 'k': between(r, 1, 5)};

// Plate Minimum — the stack as a list, its minimum recomputed after each move.
Object? plateMinimum(Map<String, Object?> input) {
  final stack = <int>[];
  final out = <int>[];
  for (final op in ints(input['ops'])) {
    if (op > 0) {
      stack.add(op);
    } else {
      stack.removeLast();
    }
    out.add(stack.isEmpty ? 0 : stack.reduce(min));
  }
  return out;
}

Map<String, Object?> plateMinimumSample(Random r) {
  final ops = <int>[];
  var height = 0;
  for (var i = between(r, 0, 10); i > 0; i--) {
    if (height > 0 && r.nextInt(3) == 0) {
      ops.add(0);
      height--;
    } else {
      ops.add(between(r, 1, 6));
      height++;
    }
  }
  return {'ops': ops};
}

// Snowball Clash — resolve any meeting pair until none is left.
Object? snowballClash(Map<String, Object?> input) {
  final balls = ints(input['balls']);
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i + 1 < balls.length; i++) {
      if (balls[i] > 0 && balls[i + 1] < 0) {
        final a = balls[i];
        final b = -balls[i + 1];
        if (a == b) {
          balls.removeRange(i, i + 2);
        } else if (a > b) {
          balls.removeAt(i + 1);
        } else {
          balls.removeAt(i);
        }
        changed = true;
        break;
      }
    }
  }
  return balls.length;
}

Map<String, Object?> snowballClashSample(Random r) => {
      'balls': [for (var i = between(r, 0, 9); i > 0; i--) (r.nextBool() ? 1 : -1) * between(r, 1, 5)],
    };

// K-th From the Back — the values as a list.
Object? kthFromEnd(Map<String, Object?> input) {
  final values = chainValues(input['head']);
  final k = integer(input['k']);
  return k > values.length ? -1 : values[values.length - k];
}

Map<String, Object?> kthFromEndSample(Random r) =>
    {'head': chainJson(randomInts(r, between(r, 0, 8), 1, 9)), 'k': between(r, 1, 9)};

// No Repeats — keep a value unless it equals the one kept last.
Object? noRepeats(Map<String, Object?> input) {
  final out = <int>[];
  for (final v in chainValues(input['head'])) {
    if (out.isEmpty || out.last != v) out.add(v);
  }
  return chainJson(out);
}

Map<String, Object?> noRepeatsSample(Random r) => {'head': chainJson(sortedInts(r, between(r, 0, 9), 1, 4))};

// Mirror Tree — recursive comparison of mirrored branches.
Object? mirrorTree(Map<String, Object?> input) {
  bool mirror(TreeView? a, TreeView? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.value == b.value && mirror(a.left, b.right) && mirror(a.right, b.left);
  }

  final root = TreeView.of(input['root']);
  return root == null || mirror(root.left, root.right);
}

Map<String, Object?> mirrorTreeSample(Random r) {
  TreeView? half = randomTree(r, between(r, 0, 4), 1, 3);
  TreeView? flip(TreeView? t) => t == null ? null : TreeView(t.value, flip(t.right), flip(t.left));
  final other = r.nextBool() ? flip(half) : randomTree(r, between(r, 0, 4), 1, 3);
  return {'root': r.nextInt(6) == 0 ? null : treeJson(TreeView(between(r, 1, 3), half, other))};
}

// Range Count — every node visited recursively.
Object? rangeCount(Map<String, Object?> input) {
  final low = integer(input['low']);
  final high = integer(input['high']);
  int walk(TreeView? t) => t == null ? 0 : (t.value >= low && t.value <= high ? 1 : 0) + walk(t.left) + walk(t.right);
  return walk(TreeView.of(input['root']));
}

Map<String, Object?> rangeCountSample(Random r) {
  TreeView? insert(TreeView? t, int v) {
    if (t == null) return TreeView(v, null, null);
    if (v < t.value) return TreeView(t.value, insert(t.left, v), t.right);
    return TreeView(t.value, t.left, insert(t.right, v));
  }

  TreeView? root;
  final labels = ({for (var i = between(r, 0, 12); i > 0; i--) between(r, 1, 30)}.toList())..shuffle(r);
  for (final v in labels) {
    root = insert(root, v);
  }
  final a = between(r, 0, 31);
  final b = between(r, 0, 31);
  return {'root': treeJson(root), 'low': min(a, b), 'high': max(a, b)};
}

// Ring Road — union-find over the roads.
Object? ringRoad(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  final parent = {for (final v in adj.keys) v: v};
  int find(int v) => parent[v] == v ? v : parent[v] = find(parent[v]!);
  for (final e in adj.entries) {
    for (final n in e.value) {
      if (n <= e.key) continue; // each road once
      final a = find(e.key);
      final b = find(n);
      if (a == b) return true;
      parent[a] = b;
    }
  }
  return false;
}

Map<String, Object?> ringRoadSample(Random r) => {'roads': graphJson(randomUndirected(r, between(r, 1, 8), between(r, 0, 8)))};

// Hop Radius — the reachable set grown one ride at a time, `hops` times.
Object? hopRadius(Map<String, Object?> input) {
  final adj = adjacency(input['metro']);
  var reached = {integer(input['start'])};
  for (var h = 0; h < integer(input['hops']); h++) {
    reached = {...reached, for (final v in reached) ...adj[v]!};
  }
  return reached.length;
}

Map<String, Object?> hopRadiusSample(Random r) {
  final n = between(r, 1, 8);
  return {'metro': graphJson(randomDigraph(r, n, 2)), 'start': r.nextInt(n), 'hops': between(r, 0, 4)};
}

// Best Stretch — every run added up.
Object? bestStretch(Map<String, Object?> input) {
  final p = ints(input['profits']);
  var best = p[0];
  for (var i = 0; i < p.length; i++) {
    var total = 0;
    for (var j = i; j < p.length; j++) {
      total += p[j];
      best = max(best, total);
    }
  }
  return best;
}

Map<String, Object?> bestStretchSample(Random r) => {'profits': randomInts(r, between(r, 1, 10), -6, 6)};

// Rising Line — patience sorting: the smallest possible end of a rising group
// of each length.
Object? risingLine(Map<String, Object?> input) {
  final ends = <int>[];
  for (final h in ints(input['heights'])) {
    var lo = 0;
    var hi = ends.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (ends[mid] < h) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == ends.length) {
      ends.add(h);
    } else {
      ends[lo] = h;
    }
  }
  return ends.length;
}

Map<String, Object?> risingLineSample(Random r) => {'heights': randomInts(r, between(r, 0, 10), 1, 6)};

const batch4Oracles = {
  'calm_stretches': Oracle(id: 'calm_stretches', solve: calmStretches, sample: calmStretchesSample),
  'window_variety': Oracle(id: 'window_variety', solve: windowVariety, sample: windowVarietySample),
  'plate_minimum': Oracle(id: 'plate_minimum', solve: plateMinimum, sample: plateMinimumSample),
  'snowball_clash': Oracle(id: 'snowball_clash', solve: snowballClash, sample: snowballClashSample),
  'kth_from_end': Oracle(id: 'kth_from_end', solve: kthFromEnd, sample: kthFromEndSample),
  'no_repeats': Oracle(id: 'no_repeats', solve: noRepeats, sample: noRepeatsSample),
  'mirror_tree': Oracle(id: 'mirror_tree', solve: mirrorTree, sample: mirrorTreeSample),
  'range_count': Oracle(id: 'range_count', solve: rangeCount, sample: rangeCountSample),
  'ring_road': Oracle(id: 'ring_road', solve: ringRoad, sample: ringRoadSample),
  'hop_radius': Oracle(id: 'hop_radius', solve: hopRadius, sample: hopRadiusSample),
  'best_stretch': Oracle(id: 'best_stretch', solve: bestStretch, sample: bestStretchSample),
  'rising_line': Oracle(id: 'rising_line', solve: risingLine, sample: risingLineSample),
};
