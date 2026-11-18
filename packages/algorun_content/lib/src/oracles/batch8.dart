import 'dart:collection';
import 'dart:math';

import 'oracle.dart';

// MS16 part 2: Trees, Graphs, Greedy, Sliding Window. None of these is the
// reference's technique: paths found by a full search, heap numbering,
// a walk from every node, relaxation to a fixpoint, reachability, a ring
// closed through every road in turn, tables, and every stretch tried.

// --- trees ---------------------------------------------------------------------------------

// Shared Ancestor — the path from the root to each label, found by searching
// the whole tree (the search-tree order is never used); the last node the two
// paths share.
Object? sharedAncestor(Map<String, Object?> input) {
  List<int>? path(TreeView? t, int label) {
    if (t == null) return null;
    if (t.value == label) return [t.value];
    final below = path(t.left, label) ?? path(t.right, label);
    return below == null ? null : [t.value, ...below];
  }

  final root = TreeView.of(input['root']);
  final a = path(root, integer(input['a']))!;
  final b = path(root, integer(input['b']))!;
  var last = -1;
  for (var i = 0; i < a.length && i < b.length && a[i] == b[i]; i++) {
    last = a[i];
  }
  return last;
}

TreeView? _insert(TreeView? t, int v) => t == null
    ? TreeView(v, null, null)
    : v < t.value
        ? TreeView(t.value, _insert(t.left, v), t.right)
        : TreeView(t.value, t.left, _insert(t.right, v));

Map<String, Object?> sharedAncestorSample(Random r) {
  final labels = {for (var i = between(r, 2, 14); i > 0; i--) between(r, 1, 60)}.toList()..shuffle(r);
  if (labels.length < 2) labels.add(labels.first + 1);
  TreeView? root;
  for (final v in labels) {
    root = _insert(root, v);
  }
  final a = labels[r.nextInt(labels.length)];
  var b = labels[r.nextInt(labels.length)];
  if (b == a) b = labels[(labels.indexOf(a) + 1) % labels.length];
  return {'root': treeJson(root), 'a': a, 'b': b};
}

// Full Rows — number the places like a heap (root 1, children 2i and 2i + 1):
// the rows are full with no gap exactly when the largest number used equals
// the number of nodes.
Object? fullRows(Map<String, Object?> input) {
  var count = 0;
  var largest = BigInt.zero;
  void walk(TreeView? t, BigInt place) {
    if (t == null) return;
    count++;
    if (place > largest) largest = place;
    walk(t.left, place * BigInt.two);
    walk(t.right, place * BigInt.two + BigInt.one);
  }

  walk(TreeView.of(input['root']), BigInt.one);
  return largest == BigInt.from(count);
}

/// The tree whose heap places 1..[size] are taken, except those in [holes]
/// (a hole removes everything under it too).
TreeView? _heapTree(int size, Set<int> holes, [int place = 1]) => place > size || holes.contains(place)
    ? null
    : TreeView(place, _heapTree(size, holes, place * 2), _heapTree(size, holes, place * 2 + 1));

Map<String, Object?> fullRowsSample(Random r) {
  final size = between(r, 0, 14);
  return switch (r.nextInt(3)) {
    0 => {'root': treeJson(_heapTree(size, const {}))},
    1 => {
        'root': treeJson(_heapTree(size, {if (size > 1) between(r, 2, size)})),
      },
    _ => {'root': treeJson(randomTree(r, between(r, 0, 7), 1, 30))},
  };
}

// Longest Crawl — the tree as chambers joined both ways; a walk outward from
// every chamber, and the farthest any walk gets.
Object? longestCrawl(Map<String, Object?> input) {
  final links = <List<int>>[];
  int number(TreeView? t, int parent) {
    if (t == null) return -1;
    final me = links.length;
    links.add([if (parent >= 0) parent]);
    for (final child in [t.left, t.right]) {
      final c = number(child, me);
      if (c >= 0) links[me].add(c);
    }
    return me;
  }

  number(TreeView.of(input['root']), -1);
  var best = 0;
  for (var s = 0; s < links.length; s++) {
    final far = List.filled(links.length, -1);
    far[s] = 0;
    final todo = Queue<int>()..add(s);
    while (todo.isNotEmpty) {
      final u = todo.removeFirst();
      best = max(best, far[u]);
      for (final v in links[u]) {
        if (far[v] < 0) {
          far[v] = far[u] + 1;
          todo.add(v);
        }
      }
    }
  }
  return best;
}

/// A random tree with the labels 1..[size], each once.
TreeView? _labelled(Random r, int size) {
  final labels = [for (var i = 1; i <= size; i++) i]..shuffle(r);
  var next = 0;
  TreeView? grow(int n) {
    if (n == 0) return null;
    final label = labels[next++];
    final left = r.nextInt(n);
    return TreeView(label, grow(left), grow(n - 1 - left));
  }

  return grow(size);
}

Map<String, Object?> longestCrawlSample(Random r) => {'root': treeJson(_labelled(r, between(r, 0, 12)))};

// --- graphs --------------------------------------------------------------------------------

// Lift Buttons — every floor's count improved from its neighbours again and
// again until nothing changes (no queue, no order of visiting).
Object? liftButtons(Map<String, Object?> input) {
  final floors = integer(input['floors']);
  final up = integer(input['up']);
  final down = integer(input['down']);
  const never = 1 << 30;
  final presses = List.filled(floors + 1, never);
  presses[integer(input['start'])] = 0;
  var changed = true;
  while (changed) {
    changed = false;
    for (var f = 1; f <= floors; f++) {
      if (presses[f] == never) continue;
      for (final g in [f + up, f - down]) {
        if (g >= 1 && g <= floors && presses[f] + 1 < presses[g]) {
          presses[g] = presses[f] + 1;
          changed = true;
        }
      }
    }
  }
  final answer = presses[integer(input['goal'])];
  return answer == never ? -1 : answer;
}

Map<String, Object?> liftButtonsSample(Random r) {
  final floors = between(r, 1, 30);
  return {
    'floors': floors,
    'start': between(r, 1, floors),
    'goal': between(r, 1, floors),
    'up': between(r, 1, 9),
    'down': between(r, 1, 9),
  };
}

// News Towns — a town must be told directly exactly when no other town's news
// can ever arrive there: everything each town reaches, then the towns nobody
// reaches.
Object? newsTowns(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  final reached = <int>{};
  for (final s in adj.keys) {
    final seen = {s};
    final todo = [s];
    while (todo.isNotEmpty) {
      for (final v in adj[todo.removeLast()]!) {
        if (seen.add(v)) todo.add(v);
      }
    }
    reached.addAll(seen..remove(s));
  }
  return adj.length - reached.length;
}

/// A random network without a way back: towns in a hidden order, roads only
/// forward in it.
List<List<int>> randomOneWay(Random r, int n, int roads) {
  final order = [for (var i = 0; i < n; i++) i]..shuffle(r);
  final adj = [for (var i = 0; i < n; i++) <int>{}];
  for (var k = 0; k < roads && n > 1; k++) {
    final a = r.nextInt(n);
    final b = r.nextInt(n);
    if (a == b) continue;
    adj[order[min(a, b)]].add(order[max(a, b)]);
  }
  return [for (final s in adj) s.toList()];
}

Map<String, Object?> newsTownsSample(Random r) {
  final n = between(r, 1, 10);
  return {'roads': graphJson(randomOneWay(r, n, between(r, 0, n + 3)))};
}

// Shortest Ring — a ring is a road plus another way between its two ends:
// close every road in turn and find the shortest way round without it.
Object? shortestRing(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  var best = -1;
  for (final a in adj.keys) {
    for (final b in adj[a]!) {
      if (a > b) continue;
      final far = {a: 0};
      final todo = Queue<int>()..add(a);
      while (todo.isNotEmpty && !far.containsKey(b)) {
        final u = todo.removeFirst();
        for (final v in adj[u]!) {
          if (u == a && v == b) continue; // the closed road
          if (!far.containsKey(v)) {
            far[v] = far[u]! + 1;
            todo.add(v);
          }
        }
      }
      final round = far[b];
      if (round != null && (best < 0 || round + 1 < best)) best = round + 1;
    }
  }
  return best;
}

Map<String, Object?> shortestRingSample(Random r) {
  final n = between(r, 1, 9);
  return {'roads': graphJson(randomUndirected(r, n, between(r, 0, n + 2)))};
}

// --- greedy --------------------------------------------------------------------------------

// Drum Line — a table from the back: the fewest passes from each drummer to
// the last one, trying every drummer it can hand to.
Object? drumLine(Map<String, Object?> input) {
  final reach = ints(input['reach']);
  final n = reach.length;
  const never = 1 << 30;
  final need = List.filled(n, never);
  need[n - 1] = 0;
  for (var i = n - 2; i >= 0; i--) {
    for (var j = i + 1; j < n && j <= i + reach[i]; j++) {
      if (need[j] + 1 < need[i]) need[i] = need[j] + 1;
    }
  }
  return need[0] >= never ? -1 : need[0];
}

Map<String, Object?> drumLineSample(Random r) {
  final n = between(r, 1, 12);
  return {'reach': randomInts(r, n, 0, r.nextBool() ? 2 : 5)};
}

// Set Breaks — a cut after a track is allowed exactly when no style played
// so far is played again later; the most parts cut at every allowed place.
Object? playlistCuts(Map<String, Object?> input) {
  final kinds = ints(input['styles']);
  final sizes = <int>[];
  var start = 0;
  for (var i = 0; i < kinds.length; i++) {
    final before = kinds.sublist(0, i + 1).toSet();
    final after = kinds.sublist(i + 1).toSet();
    if (before.intersection(after).isEmpty) {
      sizes.add(i + 1 - start);
      start = i + 1;
    }
  }
  return sizes;
}

Map<String, Object?> playlistCutsSample(Random r) {
  final n = between(r, 0, 14);
  final spread = between(r, 2, 4);
  // Kinds drift upward, so the list really falls into several parts.
  return {
    'styles': [for (var i = 0; i < n; i++) i ~/ 2 + r.nextInt(spread)],
  };
}

// Sign Flips — every way to end up with some entries turned: a table of the
// best total with exactly c entries turned; spare flips go in pairs, so c has
// k's parity and is at most k.
Object? signFlips(Map<String, Object?> input) {
  final ledger = ints(input['ledger']);
  final k = integer(input['k']);
  const never = -(1 << 40);
  var best = [0, ...List.filled(ledger.length, never)];
  for (final v in ledger) {
    final next = List.filled(ledger.length + 1, never);
    for (var c = 0; c <= ledger.length; c++) {
      if (best[c] == never) continue;
      next[c] = max(next[c], best[c] + v);
      if (c < ledger.length) next[c + 1] = max(next[c + 1], best[c] - v);
    }
    best = next;
  }
  var answer = never;
  for (var c = k % 2; c <= k && c <= ledger.length; c += 2) {
    answer = max(answer, best[c]);
  }
  return answer;
}

Map<String, Object?> signFlipsSample(Random r) {
  final n = between(r, 1, 8);
  final lo = between(r, -20, 5);
  return {'ledger': sortedInts(r, n, lo, lo + between(r, 0, 25)), 'k': between(r, 0, 12)};
}

// --- sliding window ------------------------------------------------------------------------

// The Parts Aisle — every stretch, from every bin, checked against the whole
// list.
Object? partsAisle(Map<String, Object?> input) {
  final bins = ints(input['bins']);
  final need = <int, int>{};
  for (final x in ints(input['parts'])) {
    need[x] = (need[x] ?? 0) + 1;
  }
  var best = -1;
  for (var start = 0; start < bins.length; start++) {
    final have = <int, int>{};
    var short = need.length;
    for (var end = start; end < bins.length; end++) {
      if (best >= 0 && end - start + 1 >= best) break;
      final x = bins[end];
      have[x] = (have[x] ?? 0) + 1;
      if (have[x] == need[x]) short--;
      if (short == 0) {
        best = end - start + 1;
        break;
      }
    }
  }
  return best;
}

Map<String, Object?> partsAisleSample(Random r) {
  final kinds = between(r, 2, 5);
  return {
    'bins': randomInts(r, between(r, 0, 14), 1, kinds),
    // Now and then the list names a kind the aisle does not have.
    'parts': randomInts(r, between(r, 1, 4), 1, kinds + (r.nextInt(6) == 0 ? 1 : 0)),
  };
}

// Both Ends — every split: i baskets from the left end and k - i from the
// right, each added up from scratch.
Object? bothEnds(Map<String, Object?> input) {
  final baskets = ints(input['baskets']);
  final k = integer(input['k']);
  var best = 0;
  for (var i = 0; i <= k; i++) {
    var total = 0;
    for (var j = 0; j < i; j++) {
      total += baskets[j];
    }
    for (var j = 0; j < k - i; j++) {
      total += baskets[baskets.length - 1 - j];
    }
    best = max(best, total);
  }
  return best;
}

Map<String, Object?> bothEndsSample(Random r) {
  final n = between(r, 0, 12);
  return {'baskets': randomInts(r, n, 0, 20), 'k': between(r, 0, n)};
}

// Night Coffee — the coffee tried on every run of k nights, the ships counted
// night by night each time.
Object? nightCoffee(Map<String, Object?> input) {
  final ships = ints(input['ships']);
  final awake = ints(input['awake']);
  final k = integer(input['k']);
  var best = 0;
  for (var start = 0; start + k <= ships.length; start++) {
    var seen = 0;
    for (var i = 0; i < ships.length; i++) {
      if (awake[i] == 1 || (i >= start && i < start + k)) seen += ships[i];
    }
    best = max(best, seen);
  }
  return best;
}

Map<String, Object?> nightCoffeeSample(Random r) {
  final n = between(r, 1, 12);
  return {'ships': randomInts(r, n, 0, 15), 'awake': randomInts(r, n, 0, 1), 'k': between(r, 1, n)};
}

const Map<String, Oracle> batch8Oracles = {
  'shared_ancestor': Oracle(id: 'shared_ancestor', solve: sharedAncestor, sample: sharedAncestorSample),
  'full_rows': Oracle(id: 'full_rows', solve: fullRows, sample: fullRowsSample),
  'longest_crawl': Oracle(id: 'longest_crawl', solve: longestCrawl, sample: longestCrawlSample),
  'lift_buttons': Oracle(id: 'lift_buttons', solve: liftButtons, sample: liftButtonsSample),
  'news_towns': Oracle(id: 'news_towns', solve: newsTowns, sample: newsTownsSample),
  'shortest_ring': Oracle(id: 'shortest_ring', solve: shortestRing, sample: shortestRingSample),
  'drum_line': Oracle(id: 'drum_line', solve: drumLine, sample: drumLineSample),
  'playlist_cuts': Oracle(id: 'playlist_cuts', solve: playlistCuts, sample: playlistCutsSample),
  'sign_flips': Oracle(id: 'sign_flips', solve: signFlips, sample: signFlipsSample),
  'parts_aisle': Oracle(id: 'parts_aisle', solve: partsAisle, sample: partsAisleSample),
  'both_ends': Oracle(id: 'both_ends', solve: bothEnds, sample: bothEndsSample),
  'night_coffee': Oracle(id: 'night_coffee', solve: nightCoffee, sample: nightCoffeeSample),
};
