import 'dart:math';

import 'oracle.dart';

// The tree oracles use Dart recursion: the tooling may, the block language
// cannot, which keeps them independent of the iterative references.

int _height(TreeView? t) => t == null ? 0 : 1 + max(_height(t.left), _height(t.right));

void _widths(TreeView? t, int depth, List<int> out) {
  if (t == null) return;
  if (out.length < depth) out.add(0);
  out[depth - 1]++;
  _widths(t.left, depth + 1, out);
  _widths(t.right, depth + 1, out);
}

List<int> _trailSums(TreeView? t, int acc) {
  if (t == null) return const [];
  final here = acc + t.value;
  if (t.leaf) return [here];
  return [..._trailSums(t.left, here), ..._trailSums(t.right, here)];
}

bool _ordered(TreeView? t, int? low, int? high) {
  if (t == null) return true;
  if ((low != null && t.value <= low) || (high != null && t.value >= high)) return false;
  return _ordered(t.left, low, t.value) && _ordered(t.right, t.value, high);
}

// Canopy Height — recursive height.
Object? canopyHeight(Map<String, Object?> input) => _height(TreeView.of(input['root']));

Map<String, Object?> canopyHeightSample(Random r) => {'root': treeJson(randomTree(r, between(r, 0, 12), -5, 5))};

// Busiest Level — count people per level recursively, first maximum.
Object? widestLevel(Map<String, Object?> input) {
  final widths = <int>[];
  _widths(TreeView.of(input['root']), 1, widths);
  return widths.indexOf(widths.reduce(max)) + 1;
}

Map<String, Object?> widestLevelSample(Random r) => {'root': treeJson(randomTree(r, between(r, 1, 12), -5, 5))};

// Trail Sum — every root-to-leaf total.
Object? trailSum(Map<String, Object?> input) =>
    _trailSums(TreeView.of(input['root']), 0).contains(integer(input['target']));

Map<String, Object?> trailSumSample(Random r) =>
    {'root': treeJson(randomTree(r, between(r, 0, 10), -3, 3)), 'target': between(r, -5, 5)};

// Sorted Grove — every label inside the bounds its ancestors set.
Object? sortedGrove(Map<String, Object?> input) => _ordered(TreeView.of(input['root']), null, null);

TreeView? _insert(TreeView? t, int v) {
  if (t == null) return TreeView(v, null, null);
  return v < t.value ? TreeView(t.value, _insert(t.left, v), t.right) : TreeView(t.value, t.left, _insert(t.right, v));
}

Map<String, Object?> sortedGroveSample(Random r) {
  if (r.nextBool()) {
    // A real search tree, sometimes with one label nudged.
    TreeView? t;
    final labels = ({for (var i = between(r, 0, 10); i > 0; i--) between(r, -20, 20)}).toList();
    for (final v in labels) {
      t = _insert(t, v);
    }
    return {'root': treeJson(t)};
  }
  return {'root': treeJson(randomTree(r, between(r, 0, 8), -4, 4))};
}

const treeOracles = {
  'canopy_height': Oracle(id: 'canopy_height', solve: canopyHeight, sample: canopyHeightSample),
  'widest_level': Oracle(id: 'widest_level', solve: widestLevel, sample: widestLevelSample),
  'trail_sum': Oracle(id: 'trail_sum', solve: trailSum, sample: trailSumSample),
  'sorted_grove': Oracle(id: 'sorted_grove', solve: sortedGrove, sample: sortedGroveSample),
};
