import 'dart:math';

import 'oracle.dart';

/// Shortest ride counts from [sources] by relaxing every edge until nothing
/// improves (Bellman-Ford) — never a breadth-first search.
List<int> _relaxed(Map<int, List<int>> adj, Iterable<int> sources) {
  final dist = {for (final v in adj.keys) v: -1};
  for (final s in sources) {
    dist[s] = 0;
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (final u in adj.keys) {
      if (dist[u]! < 0) continue;
      for (final v in adj[u]!) {
        if (dist[v]! < 0 || dist[u]! + 1 < dist[v]!) {
          dist[v] = dist[u]! + 1;
          changed = true;
        }
      }
    }
  }
  return [for (var i = 0; i < adj.length; i++) dist[i]!];
}

// Fewest Rides.
Object? fewestRides(Map<String, Object?> input) =>
    _relaxed(adjacency(input['metro']), [integer(input['start'])])[integer(input['goal'])];

Map<String, Object?> fewestRidesSample(Random r) {
  final n = between(r, 1, 8);
  return {'metro': graphJson(randomDigraph(r, n, 2)), 'start': r.nextInt(n), 'goal': r.nextInt(n)};
}

// Island Count — union-find over the connections.
Object? islandCount(Map<String, Object?> input) {
  final adj = adjacency(input['islands']);
  final parent = {for (final v in adj.keys) v: v};
  int find(int v) {
    while (parent[v] != v) {
      v = parent[v]!;
    }
    return v;
  }

  for (final u in adj.keys) {
    for (final v in adj[u]!) {
      parent[find(u)] = find(v);
    }
  }
  return adj.keys.map(find).toSet().length;
}

Map<String, Object?> islandCountSample(Random r) {
  final n = between(r, 1, 8);
  return {'islands': graphJson(randomUndirected(r, n, between(r, 0, 8)))};
}

// Two Teams — depth-first colouring with a stack, not breadth-first.
Object? twoTeams(Map<String, Object?> input) {
  final adj = adjacency(input['players']);
  final side = <int, int>{};
  for (final s in adj.keys) {
    if (side.containsKey(s)) continue;
    side[s] = 0;
    final stack = [s];
    while (stack.isNotEmpty) {
      final u = stack.removeLast();
      for (final v in adj[u]!) {
        final want = 1 - side[u]!;
        if (!side.containsKey(v)) {
          side[v] = want;
          stack.add(v);
        } else if (side[v] != want) {
          return false;
        }
      }
    }
  }
  return true;
}

Map<String, Object?> twoTeamsSample(Random r) {
  final n = between(r, 1, 8);
  return {'players': graphJson(randomUndirected(r, n, between(r, 0, 8)))};
}

// Nearest Depot — relax from all depots together.
Object? nearestDepot(Map<String, Object?> input) =>
    _relaxed(adjacency(input['roads']), ints(input['depots']));

Map<String, Object?> nearestDepotSample(Random r) {
  final n = between(r, 1, 8);
  return {
    'roads': graphJson(randomDigraph(r, n, 2)),
    'depots': [for (var k = between(r, 1, 3); k > 0; k--) r.nextInt(n)],
  };
}

// Task Order — depth-first search for a task that waits on itself.
Object? taskOrder(Map<String, Object?> input) {
  final adj = adjacency(input['tasks']);
  final state = {for (final v in adj.keys) v: 0}; // 0 new, 1 on the path, 2 done
  bool loops(int u) {
    state[u] = 1;
    for (final v in adj[u]!) {
      if (state[v] == 1 || (state[v] == 0 && loops(v))) return true;
    }
    state[u] = 2;
    return false;
  }

  for (final u in adj.keys) {
    if (state[u] == 0 && loops(u)) return false;
  }
  return true;
}

Map<String, Object?> taskOrderSample(Random r) {
  final n = between(r, 1, 7);
  if (r.nextBool()) {
    // Rules only from lower to higher numbers: always possible.
    return {
      'tasks': graphJson([
        for (var u = 0; u < n; u++) {for (var k = between(r, 0, 2); k > 0 && u + 1 < n; k--) between(r, u + 1, n - 1)}.toList(),
      ]),
    };
  }
  return {'tasks': graphJson(randomDigraph(r, n, 2))};
}

// Many Shortest Routes — distances by relaxation, then route counts summed
// over squares in order of distance.
Object? manyShortestRoutes(Map<String, Object?> input) {
  final adj = adjacency(input['city']);
  final start = integer(input['start']);
  final goal = integer(input['goal']);
  final dist = _relaxed(adj, [start]);
  final ways = List.filled(adj.length, 0);
  ways[start] = 1;
  final order = [for (var v = 0; v < adj.length; v++) if (dist[v] >= 0) v]..sort((a, b) => dist[a].compareTo(dist[b]));
  for (final u in order) {
    for (final v in adj[u]!) {
      if (dist[v] == dist[u] + 1) ways[v] += ways[u];
    }
  }
  return ways[goal];
}

Map<String, Object?> manyShortestRoutesSample(Random r) {
  final n = between(r, 1, 8);
  return {'city': graphJson(randomDigraph(r, n, 3)), 'start': r.nextInt(n), 'goal': r.nextInt(n)};
}

const graphOracles = {
  'fewest_rides': Oracle(id: 'fewest_rides', solve: fewestRides, sample: fewestRidesSample),
  'island_count': Oracle(id: 'island_count', solve: islandCount, sample: islandCountSample),
  'two_teams': Oracle(id: 'two_teams', solve: twoTeams, sample: twoTeamsSample),
  'nearest_depot': Oracle(id: 'nearest_depot', solve: nearestDepot, sample: nearestDepotSample),
  'task_order': Oracle(id: 'task_order', solve: taskOrder, sample: taskOrderSample),
  'many_shortest_routes': Oracle(id: 'many_shortest_routes', solve: manyShortestRoutes, sample: manyShortestRoutesSample),
};
