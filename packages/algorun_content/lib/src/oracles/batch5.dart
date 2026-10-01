import 'dart:math';

import 'oracle.dart';

// L2: world 12, Recursion & Backtracking. The references recurse; these
// answers come another way — a fold, an explicit stack, heights recomputed
// per node, every subset as a bit mask, a DP table, every permutation.

// Coin Stack — the list folded.
Object? coinStack(Map<String, Object?> input) => ints(input['coins']).fold<int>(0, (a, b) => a + b);

Map<String, Object?> coinStackSample(Random r) => {'coins': randomInts(r, between(r, 0, 9), 0, 30)};

// Tree Total — an explicit stack.
Object? treeTotal(Map<String, Object?> input) {
  final stack = <TreeView>[];
  final root = TreeView.of(input['root']);
  if (root != null) stack.add(root);
  var total = 0;
  while (stack.isNotEmpty) {
    final t = stack.removeLast();
    total += t.value;
    if (t.left != null) stack.add(t.left!);
    if (t.right != null) stack.add(t.right!);
  }
  return total;
}

Map<String, Object?> treeTotalSample(Random r) => {'root': treeJson(randomTree(r, between(r, 0, 10), -5, 9))};

// Even Branches — every node's two heights computed from scratch.
Object? evenBranches(Map<String, Object?> input) {
  int height(TreeView? t) => t == null ? 0 : 1 + max(height(t.left), height(t.right));
  bool even(TreeView? t) =>
      t == null || ((height(t.left) - height(t.right)).abs() <= 1 && even(t.left) && even(t.right));
  return even(TreeView.of(input['root']));
}

Map<String, Object?> evenBranchesSample(Random r) => {'root': treeJson(randomTree(r, between(r, 0, 9), 1, 9))};

// Exact Weight — every subset as a bit mask.
Object? exactWeight(Map<String, Object?> input) {
  final w = ints(input['weights']);
  final target = integer(input['target']);
  var count = 0;
  for (var mask = 0; mask < 1 << w.length; mask++) {
    var sum = 0;
    for (var i = 0; i < w.length; i++) {
      if (mask & (1 << i) != 0) sum += w[i];
    }
    if (sum == target) count++;
  }
  return count;
}

Map<String, Object?> exactWeightSample(Random r) =>
    {'weights': randomInts(r, between(r, 0, 8), 0, 6), 'target': between(r, 0, 15)};

// Change Ways — the classic table: ways to make every amount, one coin value
// at a time.
Object? changeWays(Map<String, Object?> input) {
  final coins = ints(input['coins']);
  final amount = integer(input['amount']);
  final ways = List.filled(amount + 1, 0)..[0] = 1;
  for (final c in coins) {
    for (var a = c; a <= amount; a++) {
      ways[a] += ways[a - c];
    }
  }
  return ways[amount];
}

Map<String, Object?> changeWaysSample(Random r) {
  final coins = ({for (var i = between(r, 0, 3); i > 0; i--) between(r, 1, 8)}.toList())..sort();
  return {'coins': coins, 'amount': between(r, 0, 20)};
}

// Watchtowers — every ordering of the columns, kept if no two share a
// diagonal.
Object? watchtowers(Map<String, Object?> input) {
  final n = integer(input['n']);
  var count = 0;
  final cols = <int>[];
  final used = List.filled(n, false);
  void permute() {
    if (cols.length == n) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          if ((cols[i] - cols[j]).abs() == j - i) return;
        }
      }
      count++;
      return;
    }
    for (var c = 0; c < n; c++) {
      if (used[c]) continue;
      used[c] = true;
      cols.add(c);
      permute();
      cols.removeLast();
      used[c] = false;
    }
  }

  permute();
  return count;
}

Map<String, Object?> watchtowersSample(Random r) => {'n': between(r, 1, 6)};

const batch5Oracles = {
  'coin_stack': Oracle(id: 'coin_stack', solve: coinStack, sample: coinStackSample),
  'tree_total': Oracle(id: 'tree_total', solve: treeTotal, sample: treeTotalSample),
  'even_branches': Oracle(id: 'even_branches', solve: evenBranches, sample: evenBranchesSample),
  'exact_weight': Oracle(id: 'exact_weight', solve: exactWeight, sample: exactWeightSample),
  'change_ways': Oracle(id: 'change_ways', solve: changeWays, sample: changeWaysSample),
  'watchtowers': Oracle(id: 'watchtowers', solve: watchtowers, sample: watchtowersSample, samples: 12),
};
