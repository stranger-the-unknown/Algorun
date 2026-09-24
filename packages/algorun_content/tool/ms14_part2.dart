part of 'ms14_build.dart';

void walkList(Prog p, String node, void Function() body) {
  p.whil(p.isNotNothing(p.get(node)), () {
    body();
    p.set(node, p.nextNode(p.get(node)));
  });
}

Built tailLamp() {
  final p = prog({'head': 'listNode?'}, {'node': 'listNode?', 'last': 'num', 'seen': 'num'});
  p.set('node', p.get('head'));
  p.set('seen', p.lit(0));
  p.set('last', p.lit(-1));
  walkList(p, 'node', () {
    p.set('last', p.nodeValue(p.get('node')));
    p.set('seen', p.lit(1));
  });
  p.iff(p.eq(p.get('seen'), p.lit(0)), () => p.ret(p.lit(-1)), els: () => p.ret(p.get('last')));

  final q = prog({'head': 'listNode?'}, {'node': 'listNode?'});
  q.iff(q.isNothing(q.get('head')), () => q.ret(q.lit(-1)), els: () => q.ret(q.nodeValue(q.get('head'))));
  return Built(p.graph, [Reject('report the first car', 'wrongAnswer', q.graph)]);
}

Built coldCars() {
  BlockGraph scan({required bool strict}) {
    final p = prog({'head': 'listNode?', 'limit': 'num'}, {'node': 'listNode?', 'count': 'num'});
    p.set('node', p.get('head'));
    p.set('count', p.lit(0));
    walkList(p, 'node', () {
      final hit = strict ? p.lt(p.nodeValue(p.get('node')), p.get('limit')) : p.le(p.nodeValue(p.get('node')), p.get('limit'));
      p.iff(hit, () => p.inc('count'));
    });
    p.ret(p.get('count'));
    return p.graph;
  }

  return Built(scan(strict: true), [Reject('a car at the limit counts as cold', 'wrongAnswer', scan(strict: false))]);
}

Built namedCar() {
  final p = prog({'head': 'listNode?', 'target': 'num'}, {'node': 'listNode?'});
  p.set('node', p.get('head'));
  walkList(p, 'node', () {
    p.iff(p.eq(p.nodeValue(p.get('node')), p.get('target')), () => p.ret(p.truth(true)));
  });
  p.ret(p.truth(false));

  final q = prog({'head': 'listNode?', 'target': 'num'}, {});
  q.iff(q.isNothing(q.get('head')), () => q.ret(q.truth(false)), els: () {
    q.ret(q.eq(q.nodeValue(q.get('head')), q.get('target')));
  });
  return Built(p.graph, [Reject('look only at the first car', 'wrongAnswer', q.graph)]);
}

Built endGap() {
  final p = prog({'head': 'listNode?'}, {'node': 'listNode?', 'count': 'num', 'first': 'num', 'last': 'num', 'value': 'num'});
  p.set('node', p.get('head'));
  p.set('count', p.lit(0));
  p.set('first', p.lit(0));
  p.set('last', p.lit(0));
  walkList(p, 'node', () {
    p.set('value', p.nodeValue(p.get('node')));
    p.iff(p.eq(p.get('count'), p.lit(0)), () => p.set('first', p.get('value')));
    p.set('last', p.get('value'));
    p.inc('count');
  });
  p.iff(p.lt(p.get('count'), p.lit(2)), () => p.ret(p.lit(0)), els: () => p.ret(p.sub(p.get('last'), p.get('first'))));

  final q = prog({'head': 'listNode?'}, {'node': 'listNode?', 'first': 'num', 'count': 'num'});
  q.set('node', q.get('head'));
  q.set('count', q.lit(0));
  q.set('first', q.lit(0));
  q.whil(q.and(q.isNotNothing(q.get('node')), q.lt(q.get('count'), q.lit(2))), () {
    q.iff(q.eq(q.get('count'), q.lit(0)), () => q.set('first', q.nodeValue(q.get('node'))), els: () {
      q.ret(q.sub(q.nodeValue(q.get('node')), q.get('first')));
    });
    q.inc('count');
    q.set('node', q.nextNode(q.get('node')));
  });
  q.ret(q.lit(0));
  return Built(p.graph, [Reject('stop at the second car', 'wrongAnswer', q.graph)]);
}

Built risingLinks() {
  BlockGraph scan({required bool strict}) {
    final p = prog({'head': 'listNode?'}, {'node': 'listNode?', 'have': 'num', 'prev': 'num', 'value': 'num', 'count': 'num'});
    p.set('node', p.get('head'));
    p.set('have', p.lit(0));
    p.set('prev', p.lit(0));
    p.set('count', p.lit(0));
    walkList(p, 'node', () {
      p.set('value', p.nodeValue(p.get('node')));
      p.iff(p.eq(p.get('have'), p.lit(1)), () {
        final hit = strict ? p.gt(p.get('value'), p.get('prev')) : p.ge(p.get('value'), p.get('prev'));
        p.iff(hit, () => p.inc('count'));
      });
      p.set('prev', p.get('value'));
      p.set('have', p.lit(1));
    });
    p.ret(p.get('count'));
    return p.graph;
  }

  return Built(scan(strict: true), [Reject('a repeated reading counts as a rise', 'wrongAnswer', scan(strict: false))]);
}

Built leftVine() {
  final p = prog({'root': 'treeNode?'}, {'node': 'treeNode?', 'count': 'num'});
  p.set('node', p.get('root'));
  p.set('count', p.lit(0));
  p.whil(p.isNotNothing(p.get('node')), () {
    p.inc('count');
    p.set('node', p.treeLeft(p.get('node')));
  });
  p.ret(p.get('count'));

  final q = prog({'root': 'treeNode?'}, {'here': 'treeNode', 'st': 'stack<treeNode>', 'count': 'num', 'left': 'treeNode?', 'right': 'treeNode?'});
  q.set('st', q.freshStack());
  q.set('count', q.lit(0));
  q.iff(q.isNotNothing(q.get('root')), () => q.push('st', q.get('root')));
  q.whil(q.not(q.stackEmpty('st')), () {
    q.set('here', q.pop('st'));
    q.inc('count');
    q.set('left', q.treeLeft(q.get('here')));
    q.set('right', q.treeRight(q.get('here')));
    q.iff(q.isNotNothing(q.get('left')), () => q.push('st', q.get('left')));
    q.iff(q.isNotNothing(q.get('right')), () => q.push('st', q.get('right')));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count every branch', 'wrongAnswer', q.graph)]);
}

Built rightMarks() {
  final p = prog({'root': 'treeNode?'}, {'node': 'treeNode?', 'sum': 'num'});
  p.set('node', p.get('root'));
  p.set('sum', p.lit(0));
  p.whil(p.isNotNothing(p.get('node')), () {
    p.set('sum', p.add(p.get('sum'), p.treeValue(p.get('node'))));
    p.set('node', p.treeRight(p.get('node')));
  });
  p.ret(p.get('sum'));

  final q = prog({'root': 'treeNode?'}, {'here': 'treeNode', 'st': 'stack<treeNode>', 'sum': 'num', 'left': 'treeNode?', 'right': 'treeNode?'});
  q.set('st', q.freshStack());
  q.set('sum', q.lit(0));
  q.iff(q.isNotNothing(q.get('root')), () => q.push('st', q.get('root')));
  q.whil(q.not(q.stackEmpty('st')), () {
    q.set('here', q.pop('st'));
    q.set('sum', q.add(q.get('sum'), q.treeValue(q.get('here'))));
    q.set('left', q.treeLeft(q.get('here')));
    q.set('right', q.treeRight(q.get('here')));
    q.iff(q.isNotNothing(q.get('left')), () => q.push('st', q.get('left')));
    q.iff(q.isNotNothing(q.get('right')), () => q.push('st', q.get('right')));
  });
  q.ret(q.get('sum'));
  return Built(p.graph, [Reject('add every mark in the tree', 'wrongAnswer', q.graph)]);
}

Built loneTree() {
  final p = prog({'root': 'treeNode?'}, {'left': 'treeNode?', 'right': 'treeNode?'});
  p.iff(p.isNothing(p.get('root')), () => p.ret(p.truth(false)), els: () {
    p.set('left', p.treeLeft(p.get('root')));
    p.set('right', p.treeRight(p.get('root')));
    p.ret(p.and(p.isNothing(p.get('left')), p.isNothing(p.get('right'))));
  });

  final q = prog({'root': 'treeNode?'}, {});
  q.ret(q.isNotNothing(q.get('root')));
  return Built(p.graph, [Reject('any tree counts as alone', 'wrongAnswer', q.graph)]);
}

void treeStack(Prog p, void Function() onNode) {
  p.set('st', p.freshStack());
  p.iff(p.isNotNothing(p.get('root')), () => p.push('st', p.get('root')));
  p.whil(p.not(p.stackEmpty('st')), () {
    p.set('node', p.pop('st'));
    onNode();
  });
}

Built nodeCensus() {
  final p = prog({'root': 'treeNode?'}, {'node': 'treeNode', 'st': 'stack<treeNode>', 'count': 'num', 'left': 'treeNode?', 'right': 'treeNode?'});
  p.set('count', p.lit(0));
  treeStack(p, () {
    p.inc('count');
    p.set('left', p.treeLeft(p.get('node')));
    p.set('right', p.treeRight(p.get('node')));
    p.iff(p.isNotNothing(p.get('left')), () => p.push('st', p.get('left')));
    p.iff(p.isNotNothing(p.get('right')), () => p.push('st', p.get('right')));
  });
  p.ret(p.get('count'));

  final q = prog({'root': 'treeNode?'}, {'walk': 'treeNode?', 'count': 'num'});
  q.set('walk', q.get('root'));
  q.set('count', q.lit(0));
  q.whil(q.isNotNothing(q.get('walk')), () {
    q.inc('count');
    q.set('walk', q.treeLeft(q.get('walk')));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count only the left spine', 'wrongAnswer', q.graph)]);
}

Built leafCensus() {
  final p = prog({'root': 'treeNode?'}, {'node': 'treeNode', 'st': 'stack<treeNode>', 'count': 'num', 'left': 'treeNode?', 'right': 'treeNode?'});
  p.set('count', p.lit(0));
  treeStack(p, () {
    p.set('left', p.treeLeft(p.get('node')));
    p.set('right', p.treeRight(p.get('node')));
    p.iff(p.and(p.isNothing(p.get('left')), p.isNothing(p.get('right'))), () {
      p.inc('count');
    }, els: () {
      p.iff(p.isNotNothing(p.get('left')), () => p.push('st', p.get('left')));
      p.iff(p.isNotNothing(p.get('right')), () => p.push('st', p.get('right')));
    });
  });
  p.ret(p.get('count'));

  final q = prog({'root': 'treeNode?'}, {'node': 'treeNode', 'st': 'stack<treeNode>', 'count': 'num', 'left': 'treeNode?', 'right': 'treeNode?'});
  q.set('count', q.lit(0));
  treeStack(q, () {
    q.inc('count');
    q.set('left', q.treeLeft(q.get('node')));
    q.set('right', q.treeRight(q.get('node')));
    q.iff(q.isNotNothing(q.get('left')), () => q.push('st', q.get('left')));
    q.iff(q.isNotNothing(q.get('right')), () => q.push('st', q.get('right')));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count every node', 'wrongAnswer', q.graph)]);
}

Built lowestLeaf() {
  final p = prog({'root': 'treeNode?'}, {
    'node': 'treeNode',
    'st': 'stack<treeNode>',
    'have': 'num',
    'best': 'num',
    'left': 'treeNode?',
    'right': 'treeNode?',
  });
  p.set('have', p.lit(0));
  p.set('best', p.lit(0));
  treeStack(p, () {
    p.set('left', p.treeLeft(p.get('node')));
    p.set('right', p.treeRight(p.get('node')));
    p.iff(p.and(p.isNothing(p.get('left')), p.isNothing(p.get('right'))), () {
      p.iff(p.eq(p.get('have'), p.lit(0)), () {
        p.set('best', p.treeValue(p.get('node')));
        p.set('have', p.lit(1));
      }, els: () {
        p.set('best', p.min(p.get('best'), p.treeValue(p.get('node'))));
      });
    }, els: () {
      p.iff(p.isNotNothing(p.get('left')), () => p.push('st', p.get('left')));
      p.iff(p.isNotNothing(p.get('right')), () => p.push('st', p.get('right')));
    });
  });
  p.iff(p.eq(p.get('have'), p.lit(0)), () => p.ret(p.lit(-1)), els: () => p.ret(p.get('best')));

  final q = prog({'root': 'treeNode?'}, {
    'node': 'treeNode',
    'st': 'stack<treeNode>',
    'have': 'num',
    'best': 'num',
    'left': 'treeNode?',
    'right': 'treeNode?',
  });
  q.set('have', q.lit(0));
  q.set('best', q.lit(0));
  treeStack(q, () {
    q.iff(q.eq(q.get('have'), q.lit(0)), () {
      q.set('best', q.treeValue(q.get('node')));
      q.set('have', q.lit(1));
    }, els: () {
      q.set('best', q.min(q.get('best'), q.treeValue(q.get('node'))));
    });
    q.set('left', q.treeLeft(q.get('node')));
    q.set('right', q.treeRight(q.get('node')));
    q.iff(q.isNotNothing(q.get('left')), () => q.push('st', q.get('left')));
    q.iff(q.isNotNothing(q.get('right')), () => q.push('st', q.get('right')));
  });
  q.iff(q.eq(q.get('have'), q.lit(0)), () => q.ret(q.lit(-1)), els: () => q.ret(q.get('best')));
  return Built(p.graph, [Reject('the lowest mark anywhere, not only a leaf', 'wrongAnswer', q.graph)]);
}

Map<String, Object?> graphOf(List<List<int>> adj) => {
      'type': 'graph',
      'nodes': [
        for (var i = 0; i < adj.length; i++) {'id': i, 'neighbors': adj[i]},
      ],
    };

Built platformDoors() {
  final p = prog({'roads': 'graph', 'station': 'num'}, {});
  p.ret(p.len(p.neighbors(p.get('roads'), p.get('station'))));

  final q = prog({'roads': 'graph', 'station': 'num'}, {});
  q.iff(q.eq(q.get('station'), q.lit(0)), () {
    q.ret(q.len(q.neighbors(q.get('roads'), q.get('station'))));
  }, els: () {
    q.ret(q.lit(0));
  });
  return Built(p.graph, [Reject('only stop zero has doors worth counting', 'wrongAnswer', q.graph)]);
}

Built directHop() {
  final p = prog({'roads': 'graph', 'start': 'num', 'goal': 'num'}, {'n': 'num', 'found': 'bool'});
  p.set('found', p.truth(false));
  p.each('n', p.neighbors(p.get('roads'), p.get('start')), () {
    p.iff(p.eq(p.get('n'), p.get('goal')), () => p.set('found', p.truth(true)));
  });
  p.ret(p.get('found'));

  final q = prog({'roads': 'graph', 'start': 'num', 'goal': 'num'}, {'nbrs': 'array<num>'});
  q.set('nbrs', q.neighbors(q.get('roads'), q.get('start')));
  q.iff(q.eq(q.len(q.get('nbrs')), q.lit(0)), () => q.ret(q.truth(false)), els: () {
    q.ret(q.eq(q.at(q.get('nbrs'), q.lit(0)), q.get('goal')));
  });
  return Built(p.graph, [Reject('trust only the first listed door', 'wrongAnswer', q.graph)]);
}

Built silentStops() {
  final p = prog({'roads': 'graph'}, {'i': 'num', 'count': 'num'});
  p.set('count', p.lit(0));
  p.range('i', p.lit(0), p.nodeCount(p.get('roads')), () {
    p.iff(p.eq(p.len(p.neighbors(p.get('roads'), p.get('i'))), p.lit(0)), () => p.inc('count'));
  });
  p.ret(p.get('count'));

  final q = prog({'roads': 'graph'}, {'i': 'num', 'count': 'num'});
  q.set('count', q.lit(0));
  q.range('i', q.lit(0), q.nodeCount(q.get('roads')), () {
    q.iff(q.gt(q.len(q.neighbors(q.get('roads'), q.get('i'))), q.lit(0)), () => q.inc('count'));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count the stops that do have a door', 'wrongAnswer', q.graph)]);
}

Built _search({required bool depth, required bool reach, String box = 'box'}) {
  final kind = depth ? 'stack<num>' : 'queue<num>';
  final p = prog({'roads': 'graph', 'start': 'num'}, {
    'here': 'num',
    'n': 'num',
    'last': 'num',
    'count': 'num',
    box: kind,
  });
  p.set(box, depth ? p.freshStack() : p.freshQueue());
  p.mark('roads', p.get('start'));
  if (depth) {
    p.push(box, p.get('start'));
  } else {
    p.enq(box, p.get('start'));
  }
  p.set('last', p.get('start'));
  p.set('count', p.lit(0));
  p.whil(depth ? p.not(p.stackEmpty(box)) : p.not(p.queueEmpty(box)), () {
    p.set('here', depth ? p.pop(box) : p.deq(box));
    p.set('last', p.get('here'));
    p.inc('count');
    p.each('n', p.neighbors(p.get('roads'), p.get('here')), () {
      p.iff(p.not(p.visited(p.get('roads'), p.get('n'))), () {
        p.mark('roads', p.get('n'));
        if (depth) {
          p.push(box, p.get('n'));
        } else {
          p.enq(box, p.get('n'));
        }
      });
    });
  });
  p.ret(reach ? p.get('count') : p.get('last'));
  return Built(p.graph, const []);
}

Built scoutReach() {
  final good = _search(depth: true, reach: true);
  final q = prog({'roads': 'graph', 'start': 'num'}, {});
  q.ret(q.nodeCount(q.get('roads')));
  return Built(good.solution, [Reject('count every stop, reached or not', 'wrongAnswer', q.graph)]);
}

Built scoutLast() {
  final good = _search(depth: true, reach: false);
  final bad = _search(depth: false, reach: false, box: 'line');
  return Built(good.solution, [Reject('walk breadth-first and keep the last stop', 'wrongAnswer', bad.solution)]);
}

Built biggestPatch() {
  final p = prog({'roads': 'graph'}, {
    's': 'num',
    'here': 'num',
    'n': 'num',
    'size': 'num',
    'best': 'num',
    'st': 'stack<num>',
  });
  p.set('st', p.freshStack());
  p.set('best', p.lit(0));
  p.range('s', p.lit(0), p.nodeCount(p.get('roads')), () {
    p.iff(p.not(p.visited(p.get('roads'), p.get('s'))), () {
      p.mark('roads', p.get('s'));
      p.push('st', p.get('s'));
      p.set('size', p.lit(0));
      p.whil(p.not(p.stackEmpty('st')), () {
        p.set('here', p.pop('st'));
        p.inc('size');
        p.each('n', p.neighbors(p.get('roads'), p.get('here')), () {
          p.iff(p.not(p.visited(p.get('roads'), p.get('n'))), () {
            p.mark('roads', p.get('n'));
            p.push('st', p.get('n'));
          });
        });
      });
      p.iff(p.gt(p.get('size'), p.get('best')), () => p.set('best', p.get('size')));
    });
  });
  p.ret(p.get('best'));

  final q = prog({'roads': 'graph'}, {});
  q.ret(q.nodeCount(q.get('roads')));
  return Built(p.graph, [Reject('the whole network is one patch', 'wrongAnswer', q.graph)]);
}

void bfsRadius(Prog p, {required bool repeat}) {
  p.set('dist', p.freshList());
  p.range('i', p.lit(0), p.nodeCount(p.get('roads')), () => p.append('dist', p.lit(-1)));
  p.set('line', p.freshQueue());
  p.set('best', p.lit(0));
  void once() {
    p.range('i', p.lit(0), p.nodeCount(p.get('roads')), () => p.setAt('dist', p.get('i'), p.lit(-1)));
    p.whil(p.not(p.queueEmpty('line')), () => p.set('gone', p.deq('line')));
    p.setAt('dist', p.get('start'), p.lit(0));
    p.enq('line', p.get('start'));
    p.whil(p.not(p.queueEmpty('line')), () {
      p.set('here', p.deq('line'));
      p.each('n', p.neighbors(p.get('roads'), p.get('here')), () {
        p.iff(p.eq(p.at(p.get('dist'), p.get('n')), p.lit(-1)), () {
          p.set('d', p.add(p.at(p.get('dist'), p.get('here')), p.lit(1)));
          p.setAt('dist', p.get('n'), p.get('d'));
          p.iff(p.gt(p.get('d'), p.get('best')), () => p.set('best', p.get('d')));
          p.enq('line', p.get('n'));
        });
      });
    });
  }

  if (repeat) {
    p.range('round', p.lit(0), p.nodeCount(p.get('roads')), once);
  } else {
    once();
  }
  p.ret(p.get('best'));
}

Built sourceRadius() {
  final pool = {
    'i': 'num',
    'here': 'num',
    'n': 'num',
    'd': 'num',
    'best': 'num',
    'gone': 'num',
    'dist': 'array<num>',
    'line': 'queue<num>',
    'round': 'num',
  };
  final p = prog({'roads': 'graph', 'start': 'num'}, pool);
  bfsRadius(p, repeat: false);
  final q = prog({'roads': 'graph', 'start': 'num'}, pool);
  bfsRadius(q, repeat: true);
  return Built(p.graph, [Reject('search again once per stop', 'operationLimit', q.graph)]);
}

Built lastLayer() {
  final p = prog({'roads': 'graph', 'start': 'num'}, {
    'i': 'num',
    'here': 'num',
    'n': 'num',
    'd': 'num',
    'best': 'num',
    'count': 'num',
    'dist': 'array<num>',
    'line': 'queue<num>',
  });
  p.set('dist', p.freshList());
  p.range('i', p.lit(0), p.nodeCount(p.get('roads')), () => p.append('dist', p.lit(-1)));
  p.set('line', p.freshQueue());
  p.set('best', p.lit(0));
  p.setAt('dist', p.get('start'), p.lit(0));
  p.enq('line', p.get('start'));
  p.whil(p.not(p.queueEmpty('line')), () {
    p.set('here', p.deq('line'));
    p.each('n', p.neighbors(p.get('roads'), p.get('here')), () {
      p.iff(p.eq(p.at(p.get('dist'), p.get('n')), p.lit(-1)), () {
        p.set('d', p.add(p.at(p.get('dist'), p.get('here')), p.lit(1)));
        p.setAt('dist', p.get('n'), p.get('d'));
        p.iff(p.gt(p.get('d'), p.get('best')), () => p.set('best', p.get('d')));
        p.enq('line', p.get('n'));
      });
    });
  });
  p.set('count', p.lit(0));
  p.range('i', p.lit(0), p.nodeCount(p.get('roads')), () {
    p.iff(p.eq(p.at(p.get('dist'), p.get('i')), p.get('best')), () => p.inc('count'));
  });
  p.ret(p.get('count'));

  final q = prog({'roads': 'graph', 'start': 'num'}, {
    'i': 'num',
    'here': 'num',
    'n': 'num',
    'd': 'num',
    'best': 'num',
    'dist': 'array<num>',
    'line': 'queue<num>',
  });
  q.set('dist', q.freshList());
  q.range('i', q.lit(0), q.nodeCount(q.get('roads')), () => q.append('dist', q.lit(-1)));
  q.set('line', q.freshQueue());
  q.set('best', q.lit(0));
  q.setAt('dist', q.get('start'), q.lit(0));
  q.enq('line', q.get('start'));
  q.whil(q.not(q.queueEmpty('line')), () {
    q.set('here', q.deq('line'));
    q.each('n', q.neighbors(q.get('roads'), q.get('here')), () {
      q.iff(q.eq(q.at(q.get('dist'), q.get('n')), q.lit(-1)), () {
        q.set('d', q.add(q.at(q.get('dist'), q.get('here')), q.lit(1)));
        q.setAt('dist', q.get('n'), q.get('d'));
        q.iff(q.gt(q.get('d'), q.get('best')), () => q.set('best', q.get('d')));
        q.enq('line', q.get('n'));
      });
    });
  });
  q.ret(q.get('best'));
  return Built(p.graph, [Reject('report how far the last layer is, not how wide', 'wrongAnswer', q.graph)]);
}

Built cookieGifts() {
  final p = prog({'children': 'array<num>', 'cookies': 'array<num>'}, {'i': 'num', 'j': 'num', 'fed': 'num'});
  p.set('i', p.lit(0));
  p.set('j', p.lit(0));
  p.set('fed', p.lit(0));
  p.whil(p.and(p.lt(p.get('i'), p.len(p.get('children'))), p.lt(p.get('j'), p.len(p.get('cookies')))), () {
    p.iff(p.ge(p.at(p.get('cookies'), p.get('j')), p.at(p.get('children'), p.get('i'))), () {
      p.inc('fed');
      p.inc('i');
      p.inc('j');
    }, els: () => p.inc('j'));
  });
  p.ret(p.get('fed'));

  final q = prog({'children': 'array<num>', 'cookies': 'array<num>'}, {'i': 'num', 'fed': 'num'});
  q.set('i', q.lit(0));
  q.set('fed', q.lit(0));
  q.whil(q.and(q.lt(q.get('i'), q.len(q.get('children'))), q.lt(q.get('i'), q.len(q.get('cookies')))), () {
    q.iff(q.ge(q.at(q.get('cookies'), q.get('i')), q.at(q.get('children'), q.get('i'))), () => q.inc('fed'));
    q.inc('i');
  });
  q.ret(q.get('fed'));
  return Built(p.graph, [Reject('never skip a cookie that is too small', 'wrongAnswer', q.graph)]);
}

Built dockOverlap() {
  BlockGraph scan({required bool strict}) {
    final p = prog({'starts': 'array<num>', 'ends': 'array<num>'}, {'i': 'num', 'j': 'num', 'cur': 'num', 'best': 'num'});
    p.set('i', p.lit(0));
    p.set('j', p.lit(0));
    p.set('cur', p.lit(0));
    p.set('best', p.lit(0));
    p.whil(p.and(p.lt(p.get('i'), p.len(p.get('starts'))), p.lt(p.get('j'), p.len(p.get('ends')))), () {
      final arrive = strict
          ? p.lt(p.at(p.get('starts'), p.get('i')), p.at(p.get('ends'), p.get('j')))
          : p.le(p.at(p.get('starts'), p.get('i')), p.at(p.get('ends'), p.get('j')));
      p.iff(arrive, () {
        p.inc('cur');
        p.iff(p.gt(p.get('cur'), p.get('best')), () => p.set('best', p.get('cur')));
        p.inc('i');
      }, els: () {
        p.dec('cur');
        p.inc('j');
      });
    });
    p.ret(p.get('best'));
    return p.graph;
  }

  return Built(scan(strict: true), [Reject('a departure at the same minute still occupies a berth', 'wrongAnswer', scan(strict: false))]);
}

Built leapReach() {
  BlockGraph scan({required bool guard}) {
    final p = prog({'jumps': 'array<num>'}, {'i': 'num', 'reach': 'num'});
    p.iff(p.eq(p.len(p.get('jumps')), p.lit(0)), () => p.ret(p.truth(false)));
    p.set('reach', p.lit(0));
    p.range('i', p.lit(0), p.len(p.get('jumps')), () {
      if (guard) {
        p.iff(p.gt(p.get('i'), p.get('reach')), () => p.ret(p.truth(false)));
      }
      p.set('reach', p.max(p.get('reach'), p.add(p.get('i'), p.at(p.get('jumps'), p.get('i')))));
      p.iff(p.ge(p.get('reach'), p.sub(p.len(p.get('jumps')), p.lit(1))), () => p.ret(p.truth(true)));
    });
    p.ret(p.truth(true));
    return p.graph;
  }

  return Built(scan(guard: true), [Reject('step past a gap you never reached', 'wrongAnswer', scan(guard: false))]);
}

Built plankWays() {
  final p = prog({'length': 'num'}, {'i': 'num', 'a': 'num', 'b': 'num', 'c': 'num'});
  p.iff(p.le(p.get('length'), p.lit(1)), () => p.ret(p.lit(1)));
  p.set('a', p.lit(1));
  p.set('b', p.lit(1));
  p.range('i', p.lit(2), p.add(p.get('length'), p.lit(1)), () {
    p.set('c', p.add(p.get('a'), p.get('b')));
    p.set('a', p.get('b'));
    p.set('b', p.get('c'));
  });
  p.ret(p.get('b'));

  final q = prog({'length': 'num'}, {'i': 'num', 'a': 'num', 'b': 'num', 'c': 'num'});
  q.iff(q.le(q.get('length'), q.lit(0)), () => q.ret(q.lit(0)));
  q.iff(q.eq(q.get('length'), q.lit(1)), () => q.ret(q.lit(1)));
  q.set('a', q.lit(1));
  q.set('b', q.lit(1));
  q.range('i', q.lit(2), q.add(q.get('length'), q.lit(1)), () {
    q.set('c', q.add(q.get('a'), q.get('b')));
    q.set('a', q.get('b'));
    q.set('b', q.get('c'));
  });
  q.ret(q.get('b'));
  return Built(p.graph, [Reject('a dock of length zero has no way to stand', 'wrongAnswer', q.graph)]);
}

Built stepToll() {
  final p = prog({'costs': 'array<num>'}, {'i': 'num', 'prev2': 'num', 'prev1': 'num', 'here': 'num'});
  p.iff(p.eq(p.len(p.get('costs')), p.lit(0)), () => p.ret(p.lit(0)));
  p.iff(p.eq(p.len(p.get('costs')), p.lit(1)), () => p.ret(p.at(p.get('costs'), p.lit(0))));
  p.set('prev2', p.at(p.get('costs'), p.lit(0)));
  p.set('prev1', p.add(p.get('prev2'), p.at(p.get('costs'), p.lit(1))));
  p.range('i', p.lit(2), p.len(p.get('costs')), () {
    p.set('here', p.add(p.at(p.get('costs'), p.get('i')), p.min(p.get('prev1'), p.get('prev2'))));
    p.set('prev2', p.get('prev1'));
    p.set('prev1', p.get('here'));
  });
  p.ret(p.get('prev1'));

  final q = prog({'costs': 'array<num>'}, {'i': 'num', 'sum': 'num'});
  q.set('sum', q.lit(0));
  q.each('i', q.get('costs'), () => q.set('sum', q.add(q.get('sum'), q.get('i'))));
  q.ret(q.get('sum'));
  return Built(p.graph, [Reject('pay every stone', 'wrongAnswer', q.graph)]);
}

Built aisleCost() {
  final p = prog({'grid': 'array<array<num>>'}, {
    'r': 'num',
    'c': 'num',
    'rows': 'num',
    'cols': 'num',
    'row': 'array<num>',
    'above': 'array<num>',
    'best': 'num',
  });
  p.set('rows', p.len(p.get('grid')));
  p.set('row', p.at(p.get('grid'), p.lit(0)));
  p.set('cols', p.len(p.get('row')));
  p.range('c', p.lit(1), p.get('cols'), () {
    p.setAt('row', p.get('c'), p.add(p.at(p.get('row'), p.get('c')), p.at(p.get('row'), p.sub(p.get('c'), p.lit(1)))));
  });
  p.range('r', p.lit(1), p.get('rows'), () {
    p.set('row', p.at(p.get('grid'), p.get('r')));
    p.set('above', p.at(p.get('grid'), p.sub(p.get('r'), p.lit(1))));
    p.setAt('row', p.lit(0), p.add(p.at(p.get('row'), p.lit(0)), p.at(p.get('above'), p.lit(0))));
  });
  p.range('r', p.lit(1), p.get('rows'), () {
    p.range('c', p.lit(1), p.get('cols'), () {
      p.set('row', p.at(p.get('grid'), p.get('r')));
      p.set('above', p.at(p.get('grid'), p.sub(p.get('r'), p.lit(1))));
      p.set('best', p.min(p.at(p.get('above'), p.get('c')), p.at(p.get('row'), p.sub(p.get('c'), p.lit(1)))));
      p.setAt('row', p.get('c'), p.add(p.at(p.get('row'), p.get('c')), p.get('best')));
    });
  });
  p.set('row', p.at(p.get('grid'), p.sub(p.get('rows'), p.lit(1))));
  p.ret(p.at(p.get('row'), p.sub(p.get('cols'), p.lit(1))));

  final q = prog({'grid': 'array<array<num>>'}, {'r': 'num', 'c': 'num', 'sum': 'num', 'row': 'array<num>'});
  q.set('sum', q.lit(0));
  q.range('r', q.lit(0), q.len(q.get('grid')), () {
    q.set('row', q.at(q.get('grid'), q.get('r')));
    q.range('c', q.lit(0), q.len(q.get('row')), () {
      q.set('sum', q.add(q.get('sum'), q.at(q.get('row'), q.get('c'))));
    });
  });
  q.ret(q.get('sum'));
  return Built(p.graph, [Reject('pay for every square, not the cheapest path', 'wrongAnswer', q.graph)]);
}

Built openLanes() {
  final p = prog({'grid': 'array<array<num>>'}, {
    'r': 'num',
    'c': 'num',
    'rows': 'num',
    'cols': 'num',
    'idx': 'num',
    'cell': 'num',
    'up': 'num',
    'left': 'num',
    'cells': 'num',
    'dp': 'array<num>',
    'row': 'array<num>',
  });
  p.set('rows', p.len(p.get('grid')));
  p.set('row', p.at(p.get('grid'), p.lit(0)));
  p.set('cols', p.len(p.get('row')));
  p.set('cell', p.at(p.get('row'), p.lit(0)));
  p.set('row', p.at(p.get('grid'), p.sub(p.get('rows'), p.lit(1))));
  p.set('up', p.at(p.get('row'), p.sub(p.get('cols'), p.lit(1))));
  p.iff(p.or(p.eq(p.get('cell'), p.lit(1)), p.eq(p.get('up'), p.lit(1))), () => p.ret(p.lit(0)));
  p.set('dp', p.freshList());
  p.set('cells', p.mul(p.get('rows'), p.get('cols')));
  p.range('r', p.lit(0), p.get('cells'), () => p.append('dp', p.lit(0)));
  p.setAt('dp', p.lit(0), p.lit(1));
  p.range('r', p.lit(0), p.get('rows'), () {
    p.range('c', p.lit(0), p.get('cols'), () {
      p.set('idx', p.add(p.mul(p.get('r'), p.get('cols')), p.get('c')));
      p.set('row', p.at(p.get('grid'), p.get('r')));
      p.set('cell', p.at(p.get('row'), p.get('c')));
      p.iff(p.eq(p.get('cell'), p.lit(1)), () {
        p.setAt('dp', p.get('idx'), p.lit(0));
      }, els: () {
        p.iff(p.or(p.gt(p.get('r'), p.lit(0)), p.gt(p.get('c'), p.lit(0))), () {
          p.set('up', p.lit(0));
          p.set('left', p.lit(0));
          p.iff(p.gt(p.get('r'), p.lit(0)), () {
            p.set('up', p.at(p.get('dp'), p.add(p.mul(p.sub(p.get('r'), p.lit(1)), p.get('cols')), p.get('c'))));
          });
          p.iff(p.gt(p.get('c'), p.lit(0)), () => p.set('left', p.at(p.get('dp'), p.sub(p.get('idx'), p.lit(1)))));
          p.setAt('dp', p.get('idx'), p.add(p.get('up'), p.get('left')));
        });
      });
    });
  });
  p.ret(p.at(p.get('dp'), p.sub(p.get('cells'), p.lit(1))));

  final q = prog({'grid': 'array<array<num>>'}, {
    'r': 'num',
    'c': 'num',
    'rows': 'num',
    'cols': 'num',
    'ways': 'num',
    'row': 'array<num>',
  });
  q.set('rows', q.len(q.get('grid')));
  q.set('row', q.at(q.get('grid'), q.lit(0)));
  q.set('cols', q.len(q.get('row')));
  q.set('ways', q.lit(1));
  q.range('r', q.lit(0), q.get('rows'), () {
    q.range('c', q.lit(0), q.get('cols'), () {
      q.set('row', q.at(q.get('grid'), q.get('r')));
      q.iff(q.eq(q.at(q.get('row'), q.get('c')), q.lit(1)), () => q.set('ways', q.lit(0)));
    });
  });
  q.ret(q.get('ways'));
  return Built(p.graph, [Reject('one wall blocks every route', 'wrongAnswer', q.graph)]);
}

Built diagonalHaul() {
  final p = prog({'grid': 'array<array<num>>'}, {
    'r': 'num',
    'c': 'num',
    'rows': 'num',
    'cols': 'num',
    'row': 'array<num>',
    'above': 'array<num>',
    'best': 'num',
    'any': 'num',
  });
  p.set('rows', p.len(p.get('grid')));
  p.set('row', p.at(p.get('grid'), p.lit(0)));
  p.set('cols', p.len(p.get('row')));
  p.range('r', p.lit(0), p.get('rows'), () {
    p.range('c', p.lit(0), p.get('cols'), () {
      p.set('any', p.lit(0));
      p.set('best', p.lit(0));
      p.iff(p.gt(p.get('c'), p.lit(0)), () {
        p.set('row', p.at(p.get('grid'), p.get('r')));
        p.set('best', p.at(p.get('row'), p.sub(p.get('c'), p.lit(1))));
        p.set('any', p.lit(1));
      });
      p.iff(p.gt(p.get('r'), p.lit(0)), () {
        p.set('above', p.at(p.get('grid'), p.sub(p.get('r'), p.lit(1))));
        p.iff(p.eq(p.get('any'), p.lit(0)), () {
          p.set('best', p.at(p.get('above'), p.get('c')));
          p.set('any', p.lit(1));
        }, els: () {
          p.set('best', p.max(p.get('best'), p.at(p.get('above'), p.get('c'))));
        });
      });
      p.iff(p.and(p.gt(p.get('r'), p.lit(0)), p.gt(p.get('c'), p.lit(0))), () {
        p.set('above', p.at(p.get('grid'), p.sub(p.get('r'), p.lit(1))));
        p.set('best', p.max(p.get('best'), p.at(p.get('above'), p.sub(p.get('c'), p.lit(1)))));
        p.set('any', p.lit(1));
      });
      p.iff(p.eq(p.get('any'), p.lit(1)), () {
        p.set('row', p.at(p.get('grid'), p.get('r')));
        p.setAt('row', p.get('c'), p.add(p.at(p.get('row'), p.get('c')), p.get('best')));
      });
    });
  });
  p.set('row', p.at(p.get('grid'), p.sub(p.get('rows'), p.lit(1))));
  p.ret(p.at(p.get('row'), p.sub(p.get('cols'), p.lit(1))));

  final q = prog({'grid': 'array<array<num>>'}, {'c': 'num', 'sum': 'num', 'row': 'array<num>'});
  q.set('row', q.at(q.get('grid'), q.lit(0)));
  q.set('sum', q.lit(0));
  q.range('c', q.lit(0), q.len(q.get('row')), () {
    q.set('sum', q.add(q.get('sum'), q.at(q.get('row'), q.get('c'))));
  });
  q.ret(q.get('sum'));
  return Built(p.graph, [Reject('haul only along the first row', 'wrongAnswer', q.graph)]);
}

Built packBins() {
  final p = prog({'weights': 'array<num>', 'values': 'array<num>', 'cap': 'num'}, {
    'i': 'num',
    'c': 'num',
    'w': 'num',
    'v': 'num',
    'withItem': 'num',
    'dp': 'array<num>',
  });
  p.set('dp', p.freshList());
  p.range('i', p.lit(0), p.add(p.get('cap'), p.lit(1)), () => p.append('dp', p.lit(0)));
  p.range('i', p.lit(0), p.len(p.get('weights')), () {
    p.set('w', p.at(p.get('weights'), p.get('i')));
    p.set('v', p.at(p.get('values'), p.get('i')));
    p.range('c', p.get('cap'), p.sub(p.get('w'), p.lit(1)), () {
      p.set('withItem', p.add(p.at(p.get('dp'), p.sub(p.get('c'), p.get('w'))), p.get('v')));
      p.iff(p.gt(p.get('withItem'), p.at(p.get('dp'), p.get('c'))), () => p.setAt('dp', p.get('c'), p.get('withItem')));
    }, step: p.lit(-1));
  });
  p.ret(p.at(p.get('dp'), p.get('cap')));

  final q = prog({'weights': 'array<num>', 'values': 'array<num>', 'cap': 'num'}, {
    'mask': 'num',
    'total': 'num',
    'i': 'num',
    'm': 'num',
    'wsum': 'num',
    'vsum': 'num',
    'best': 'num',
  });
  q.set('best', q.lit(0));
  q.set('total', q.lit(1));
  q.range('i', q.lit(0), q.len(q.get('weights')), () => q.set('total', q.mul(q.get('total'), q.lit(2))));
  q.range('mask', q.lit(0), q.get('total'), () {
    q.set('m', q.get('mask'));
    q.set('wsum', q.lit(0));
    q.set('vsum', q.lit(0));
    q.range('i', q.lit(0), q.len(q.get('weights')), () {
      q.iff(q.eq(q.mod(q.get('m'), q.lit(2)), q.lit(1)), () {
        q.set('wsum', q.add(q.get('wsum'), q.at(q.get('weights'), q.get('i'))));
        q.set('vsum', q.add(q.get('vsum'), q.at(q.get('values'), q.get('i'))));
      });
      q.set('m', q.floorDiv(q.get('m'), q.lit(2)));
    });
    q.iff(q.and(q.le(q.get('wsum'), q.get('cap')), q.gt(q.get('vsum'), q.get('best'))), () => q.set('best', q.get('vsum')));
  });
  q.ret(q.get('best'));
  return Built(p.graph, [Reject('try every subset', 'operationLimit', q.graph)]);
}
