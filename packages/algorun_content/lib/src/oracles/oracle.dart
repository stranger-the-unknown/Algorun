import 'dart:math';

/// An independent answer key for one puzzle.
///
/// A reference program cannot prove its own answers. The oracle is the second
/// opinion: plain Dart in the content tooling (never in puzzle data, never in
/// the app), written the simplest obviously-correct way — usually brute force
/// — and deliberately *not* the reference's algorithm. The validator requires
/// three things to agree: the oracle, every fixture's expected output, and the
/// reference program run by the real interpreter, on the fixtures and on
/// [samples] extra random inputs.
///
/// Values cross this boundary as canonical fixture JSON (`valueToJson`):
/// numbers, lists, `{"type": "listNode", "values": […], "cycleTo": k}`,
/// `{"type": "treeNode", "value": v, "left": …, "right": …}`,
/// `{"type": "graph", "nodes": [{"id": i, "neighbors": […]}]}`, `null`.
final class Oracle {
  const Oracle({
    required this.id,
    required this.solve,
    required this.sample,
    this.samples = 40,
  });

  final String id;

  /// The expected output for `{input name: fixture JSON}`, as fixture JSON.
  final Object? Function(Map<String, Object?> input) solve;

  /// A small random input inside the puzzle's stated constraints.
  final Map<String, Object?> Function(Random random) sample;

  /// How many sampled inputs the reference must agree on.
  final int samples;
}

// --- helpers for oracles ------------------------------------------------------

List<int> ints(Object? json) => [for (final v in json! as List<Object?>) (v! as num).toInt()];

List<List<int>> intRows(Object? json) => [for (final row in json! as List<Object?>) ints(row)];

int integer(Object? json) => (json! as num).toInt();

/// The values of a linked list in order, following at most the listed nodes.
List<int> chainValues(Object? json) => json == null ? const [] : ints((json as Map<String, Object?>)['values']);

/// Where the last node of a linked list points back to, or null.
int? chainCycle(Object? json) => json == null ? null : (json as Map<String, Object?>)['cycleTo'] as int?;

Object? chainJson(List<int> values) => values.isEmpty ? null : {'type': 'listNode', 'values': values};

/// A tree node from fixture JSON: `(value, left, right)`.
final class TreeView {
  TreeView(this.value, this.left, this.right);

  static TreeView? of(Object? json) {
    if (json == null) return null;
    final m = json as Map<String, Object?>;
    return TreeView(integer(m['value']), of(m['left']), of(m['right']));
  }

  final int value;
  final TreeView? left;
  final TreeView? right;

  bool get leaf => left == null && right == null;
}

Object? treeJson(TreeView? t) => t == null
    ? null
    : {'type': 'treeNode', 'value': t.value, 'left': treeJson(t.left), 'right': treeJson(t.right)};

/// Adjacency lists by node id.
Map<int, List<int>> adjacency(Object? json) {
  final nodes = (json! as Map<String, Object?>)['nodes']! as List<Object?>;
  return {
    for (final n in nodes.cast<Map<String, Object?>>()) integer(n['id']): ints(n['neighbors']),
  };
}

Object? graphJson(List<List<int>> adj) => {
      'type': 'graph',
      'nodes': [
        for (var i = 0; i < adj.length; i++) {'id': i, 'neighbors': adj[i]},
      ],
    };

// --- random inputs --------------------------------------------------------------

int between(Random r, int lo, int hi) => lo + r.nextInt(hi - lo + 1);

List<int> randomInts(Random r, int length, int lo, int hi) => [for (var i = 0; i < length; i++) between(r, lo, hi)];

List<int> sortedInts(Random r, int length, int lo, int hi) => randomInts(r, length, lo, hi)..sort();

/// A random tree of [size] nodes with values in [lo, hi].
TreeView? randomTree(Random r, int size, int lo, int hi) {
  if (size == 0) return null;
  final leftSize = r.nextInt(size);
  return TreeView(between(r, lo, hi), randomTree(r, leftSize, lo, hi), randomTree(r, size - 1 - leftSize, lo, hi));
}

/// A random directed graph on [n] nodes, each with up to [maxOut] edges.
List<List<int>> randomDigraph(Random r, int n, int maxOut) => [
      for (var u = 0; u < n; u++) {for (var k = between(r, 0, maxOut); k > 0; k--) r.nextInt(n)}.toList(),
    ];

/// A random undirected graph on [n] nodes (every edge listed both ways), no
/// self loops.
List<List<int>> randomUndirected(Random r, int n, int edges) {
  final adj = [for (var i = 0; i < n; i++) <int>{}];
  for (var k = 0; k < edges && n > 1; k++) {
    final a = r.nextInt(n);
    final b = r.nextInt(n);
    if (a == b) continue;
    adj[a].add(b);
    adj[b].add(a);
  }
  return [for (final s in adj) s.toList()..sort()];
}
