part of 'ms14_build.dart';

Built firstDescent() {
  BlockGraph scan({required bool strict}) {
    final p = prog({'values': 'array<num>'}, {'i': 'num'});
    p.range('i', p.lit(1), p.len(p.get('values')), () {
      final drop = strict
          ? p.lt(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.sub(p.get('i'), p.lit(1))))
          : p.le(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.sub(p.get('i'), p.lit(1))));
      p.iff(drop, () => p.ret(p.get('i')));
    });
    p.ret(p.lit(-1));
    return p.graph;
  }

  return Built(scan(strict: true), [Reject('a flat step counts as a descent', 'wrongAnswer', scan(strict: false))]);
}

Built secondHighest() {
  BlockGraph scan({required bool strict}) {
    final p = prog({'values': 'array<num>'}, {
      'v': 'num',
      'best': 'num',
      'second': 'num',
      'haveBest': 'num',
      'haveSecond': 'num',
    });
    p.set('haveBest', p.lit(0));
    p.set('haveSecond', p.lit(0));
    p.set('best', p.lit(0));
    p.set('second', p.lit(0));
    p.each('v', p.get('values'), () {
      final higher = strict ? p.gt(p.get('v'), p.get('best')) : p.ge(p.get('v'), p.get('best'));
      p.iff(p.or(p.eq(p.get('haveBest'), p.lit(0)), higher), () {
        p.iff(p.eq(p.get('haveBest'), p.lit(1)), () {
          p.set('second', p.get('best'));
          p.set('haveSecond', p.lit(1));
        });
        p.set('best', p.get('v'));
        p.set('haveBest', p.lit(1));
      }, els: () {
        p.iff(
          p.and(p.lt(p.get('v'), p.get('best')), p.or(p.eq(p.get('haveSecond'), p.lit(0)), p.gt(p.get('v'), p.get('second')))),
          () {
            p.set('second', p.get('v'));
            p.set('haveSecond', p.lit(1));
          },
        );
      });
    });
    p.iff(p.eq(p.get('haveSecond'), p.lit(1)), () => p.ret(p.get('second')), els: () => p.ret(p.lit(-1)));
    return p.graph;
  }

  return Built(scan(strict: true), [Reject('a repeated peak becomes the runner-up', 'wrongAnswer', scan(strict: false))]);
}

Built evenPrefixes() {
  BlockGraph scan({required bool evens}) {
    final p = prog({'values': 'array<num>'}, {'v': 'num', 'sum': 'num', 'count': 'num'});
    p.set('sum', p.lit(0));
    p.set('count', evens ? p.lit(1) : p.lit(0));
    p.each('v', p.get('values'), () {
      p.set('sum', p.add(p.get('sum'), p.get('v')));
      final hit = evens
          ? p.eq(p.mod(p.get('sum'), p.lit(2)), p.lit(0))
          : p.ne(p.mod(p.get('sum'), p.lit(2)), p.lit(0));
      p.iff(hit, () => p.inc('count'));
    });
    p.ret(p.get('count'));
    return p.graph;
  }

  return Built(scan(evens: true), [Reject('count odd running totals', 'wrongAnswer', scan(evens: false))]);
}

Built nestedDistinct() {
  final p = prog({'values': 'array<num>'}, {'i': 'num', 'j': 'num', 'seen': 'num', 'count': 'num'});
  p.set('count', p.lit(0));
  p.range('i', p.lit(0), p.len(p.get('values')), () {
    p.set('seen', p.lit(0));
    p.range('j', p.lit(0), p.get('i'), () {
      p.iff(p.eq(p.at(p.get('values'), p.get('j')), p.at(p.get('values'), p.get('i'))), () => p.set('seen', p.lit(1)));
    });
    p.iff(p.eq(p.get('seen'), p.lit(0)), () => p.inc('count'));
  });
  p.ret(p.get('count'));

  final q = prog({'values': 'array<num>'}, {'v': 'num', 'bag': 'set<num>'});
  q.set('bag', q.freshSet());
  q.each('v', q.get('values'), () => q.addSet('bag', q.get('v')));
  q.ret(q.setSize('bag'));
  return Built(p.graph, [Reject('remember every value in a set', 'memoryLimit', q.graph)]);
}

Built maxProductTwo() {
  final p = prog({'values': 'array<num>'}, {
    'v': 'num',
    'max1': 'num',
    'max2': 'num',
    'min1': 'num',
    'min2': 'num',
  });
  p.iff(p.lt(p.len(p.get('values')), p.lit(2)), () => p.ret(p.lit(0)));
  p.set('max1', p.lit(-999999));
  p.set('max2', p.lit(-999999));
  p.set('min1', p.lit(999999));
  p.set('min2', p.lit(999999));
  p.each('v', p.get('values'), () {
    p.iff(p.gt(p.get('v'), p.get('max1')), () {
      p.set('max2', p.get('max1'));
      p.set('max1', p.get('v'));
    }, els: () {
      p.iff(p.gt(p.get('v'), p.get('max2')), () => p.set('max2', p.get('v')));
    });
    p.iff(p.lt(p.get('v'), p.get('min1')), () {
      p.set('min2', p.get('min1'));
      p.set('min1', p.get('v'));
    }, els: () {
      p.iff(p.lt(p.get('v'), p.get('min2')), () => p.set('min2', p.get('v')));
    });
  });
  p.ret(p.max(p.mul(p.get('max1'), p.get('max2')), p.mul(p.get('min1'), p.get('min2'))));

  final q = prog({'values': 'array<num>'}, {'i': 'num', 'j': 'num', 'best': 'num'});
  q.iff(q.lt(q.len(q.get('values')), q.lit(2)), () => q.ret(q.lit(0)));
  q.set('best', q.mul(q.at(q.get('values'), q.lit(0)), q.at(q.get('values'), q.lit(1))));
  q.range('i', q.lit(0), q.len(q.get('values')), () {
    q.range('j', q.add(q.get('i'), q.lit(1)), q.len(q.get('values')), () {
      q.set('best', q.max(q.get('best'), q.mul(q.at(q.get('values'), q.get('i')), q.at(q.get('values'), q.get('j')))));
    });
  });
  q.ret(q.get('best'));
  return Built(p.graph, [Reject('every pair', 'operationLimit', q.graph)]);
}

Built pairSumCount() {
  final p = prog({'values': 'array<num>', 'target': 'num'}, {
    'v': 'num',
    'seen': 'map<num,num>',
    'need': 'num',
    'found': 'num?',
    'cur': 'num?',
    'count': 'num',
  });
  p.set('seen', p.freshMap());
  p.set('count', p.lit(0));
  p.each('v', p.get('values'), () {
    p.set('need', p.sub(p.get('target'), p.get('v')));
    p.set('found', p.mapGet('seen', p.get('need')));
    p.iff(p.isNothing(p.get('found')), () {}, els: () {
      p.set('count', p.add(p.get('count'), p.get('found')));
    });
    p.set('cur', p.mapGet('seen', p.get('v')));
    p.iff(p.isNothing(p.get('cur')), () {
      p.put('seen', p.get('v'), p.lit(1));
    }, els: () {
      p.put('seen', p.get('v'), p.add(p.get('cur'), p.lit(1)));
    });
  });
  p.ret(p.get('count'));

  final q = prog({'values': 'array<num>', 'target': 'num'}, {'i': 'num', 'j': 'num', 'count': 'num'});
  q.set('count', q.lit(0));
  q.range('i', q.lit(0), q.len(q.get('values')), () {
    q.range('j', q.add(q.get('i'), q.lit(1)), q.len(q.get('values')), () {
      q.iff(q.eq(q.add(q.at(q.get('values'), q.get('i')), q.at(q.get('values'), q.get('j'))), q.get('target')), () {
        q.inc('count');
      });
    });
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('every pair of positions', 'operationLimit', q.graph)]);
}

Built sameValueSpan() {
  final p = prog({'values': 'array<num>'}, {
    'i': 'num',
    'first': 'map<num,num>',
    'found': 'num?',
    'gap': 'num',
    'best': 'num',
  });
  p.set('first', p.freshMap());
  p.set('best', p.lit(-1));
  p.range('i', p.lit(0), p.len(p.get('values')), () {
    p.set('found', p.mapGet('first', p.at(p.get('values'), p.get('i'))));
    p.iff(p.isNothing(p.get('found')), () {
      p.put('first', p.at(p.get('values'), p.get('i')), p.get('i'));
    }, els: () {
      p.set('gap', p.sub(p.get('i'), p.get('found')));
      p.iff(p.gt(p.get('gap'), p.get('best')), () => p.set('best', p.get('gap')));
    });
  });
  p.ret(p.get('best'));

  final q = prog({'values': 'array<num>'}, {'i': 'num', 'j': 'num', 'best': 'num', 'gap': 'num'});
  q.set('best', q.lit(-1));
  q.range('i', q.lit(0), q.len(q.get('values')), () {
    q.range('j', q.add(q.get('i'), q.lit(1)), q.len(q.get('values')), () {
      q.iff(q.eq(q.at(q.get('values'), q.get('i')), q.at(q.get('values'), q.get('j'))), () {
        q.set('gap', q.sub(q.get('j'), q.get('i')));
        q.iff(q.gt(q.get('gap'), q.get('best')), () => q.set('best', q.get('gap')));
      });
    });
  });
  q.ret(q.get('best'));
  return Built(p.graph, [Reject('compare every pair of positions', 'operationLimit', q.graph)]);
}

Built sharedValues() {
  final p = prog({'left': 'array<num>', 'right': 'array<num>'}, {
    'v': 'num',
    'leftSet': 'set<num>',
    'both': 'set<num>',
  });
  p.set('leftSet', p.freshSet());
  p.each('v', p.get('left'), () => p.addSet('leftSet', p.get('v')));
  p.set('both', p.freshSet());
  p.each('v', p.get('right'), () {
    p.iff(p.setHas('leftSet', p.get('v')), () => p.addSet('both', p.get('v')));
  });
  p.ret(p.setSize('both'));

  final q = prog({'left': 'array<num>', 'right': 'array<num>'}, {'v': 'num', 'leftSet': 'set<num>', 'count': 'num'});
  q.set('leftSet', q.freshSet());
  q.each('v', q.get('left'), () => q.addSet('leftSet', q.get('v')));
  q.set('count', q.lit(0));
  q.each('v', q.get('right'), () {
    q.iff(q.setHas('leftSet', q.get('v')), () => q.inc('count'));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count every copy on the right', 'wrongAnswer', q.graph)]);
}

Built exactGaps() {
  final p = prog({'values': 'array<num>', 'gap': 'num'}, {'i': 'num', 'j': 'num', 'count': 'num'});
  p.set('j', p.lit(0));
  p.set('count', p.lit(0));
  p.range('i', p.lit(0), p.len(p.get('values')), () {
    p.whil(
      p.and(
        p.lt(p.get('j'), p.len(p.get('values'))),
        p.lt(p.sub(p.at(p.get('values'), p.get('j')), p.at(p.get('values'), p.get('i'))), p.get('gap')),
      ),
      () => p.inc('j'),
    );
    p.iff(
      p.and(
        p.lt(p.get('j'), p.len(p.get('values'))),
        p.eq(p.sub(p.at(p.get('values'), p.get('j')), p.at(p.get('values'), p.get('i'))), p.get('gap')),
      ),
      () => p.inc('count'),
    );
  });
  p.ret(p.get('count'));

  final q = prog({'values': 'array<num>', 'gap': 'num'}, {'v': 'num', 'bag': 'set<num>', 'count': 'num'});
  q.set('bag', q.freshSet());
  q.each('v', q.get('values'), () => q.addSet('bag', q.get('v')));
  q.set('count', q.lit(0));
  q.each('v', q.get('values'), () {
    q.iff(q.setHas('bag', q.add(q.get('v'), q.get('gap'))), () => q.inc('count'));
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('remember every reading in a set', 'memoryLimit', q.graph)]);
}

Built pairsUnder() {
  BlockGraph scan({required bool span}) {
    final p = prog({'values': 'array<num>', 'limit': 'num'}, {'i': 'num', 'j': 'num', 'count': 'num'});
    p.set('i', p.lit(0));
    p.set('j', p.sub(p.len(p.get('values')), p.lit(1)));
    p.set('count', p.lit(0));
    p.whil(p.lt(p.get('i'), p.get('j')), () {
      p.iff(p.le(p.add(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.get('j'))), p.get('limit')), () {
        p.set('count', p.add(p.get('count'), span ? p.sub(p.get('j'), p.get('i')) : p.lit(1)));
        p.inc('i');
      }, els: () => p.dec('j'));
    });
    p.ret(p.get('count'));
    return p.graph;
  }

  return Built(scan(span: true), [Reject('count one pair and skip the rest of the span', 'wrongAnswer', scan(span: false))]);
}

Built sortedUnion() {
  final p = prog({'left': 'array<num>', 'right': 'array<num>'}, {
    'i': 'num',
    'j': 'num',
    'count': 'num',
    'have': 'num',
    'last': 'num',
    'takeLeft': 'bool',
    'v': 'num',
  });
  p.set('i', p.lit(0));
  p.set('j', p.lit(0));
  p.set('count', p.lit(0));
  p.set('have', p.lit(0));
  p.set('last', p.lit(0));
  p.whil(p.or(p.lt(p.get('i'), p.len(p.get('left'))), p.lt(p.get('j'), p.len(p.get('right')))), () {
    p.set(
      'takeLeft',
      p.or(
        p.ge(p.get('j'), p.len(p.get('right'))),
        p.and(
          p.lt(p.get('i'), p.len(p.get('left'))),
          p.le(p.at(p.get('left'), p.get('i')), p.at(p.get('right'), p.get('j'))),
        ),
      ),
    );
    p.iff(p.get('takeLeft'), () {
      p.set('v', p.at(p.get('left'), p.get('i')));
    }, els: () {
      p.set('v', p.at(p.get('right'), p.get('j')));
    });
    p.iff(p.or(p.eq(p.get('have'), p.lit(0)), p.ne(p.get('v'), p.get('last'))), () {
      p.inc('count');
      p.set('last', p.get('v'));
      p.set('have', p.lit(1));
    });
    p.iff(
      p.and(p.lt(p.get('i'), p.len(p.get('left'))), p.eq(p.at(p.get('left'), p.get('i')), p.get('v'))),
      () => p.inc('i'),
    );
    p.iff(
      p.and(p.lt(p.get('j'), p.len(p.get('right'))), p.eq(p.at(p.get('right'), p.get('j')), p.get('v'))),
      () => p.inc('j'),
    );
  });
  p.ret(p.get('count'));

  final q = prog({'left': 'array<num>', 'right': 'array<num>'}, {
    'i': 'num',
    'j': 'num',
    'count': 'num',
    'takeLeft': 'bool',
    'v': 'num',
  });
  q.set('i', q.lit(0));
  q.set('j', q.lit(0));
  q.set('count', q.lit(0));
  q.whil(q.or(q.lt(q.get('i'), q.len(q.get('left'))), q.lt(q.get('j'), q.len(q.get('right')))), () {
    q.set(
      'takeLeft',
      q.or(
        q.ge(q.get('j'), q.len(q.get('right'))),
        q.and(
          q.lt(q.get('i'), q.len(q.get('left'))),
          q.le(q.at(q.get('left'), q.get('i')), q.at(q.get('right'), q.get('j'))),
        ),
      ),
    );
    q.iff(q.get('takeLeft'), () {
      q.set('v', q.at(q.get('left'), q.get('i')));
      q.inc('i');
    }, els: () {
      q.set('v', q.at(q.get('right'), q.get('j')));
      q.inc('j');
    });
    q.inc('count');
  });
  q.ret(q.get('count'));
  return Built(p.graph, [Reject('count a repeated bell every time', 'wrongAnswer', q.graph)]);
}

Built closestGap() {
  final p = prog({'values': 'array<num>', 'target': 'num'}, {'i': 'num', 'j': 'num', 'best': 'num', 'sum': 'num'});
  p.set('i', p.lit(0));
  p.set('j', p.sub(p.len(p.get('values')), p.lit(1)));
  p.set('best', p.abs(p.sub(p.add(p.at(p.get('values'), p.lit(0)), p.at(p.get('values'), p.lit(1))), p.get('target'))));
  p.whil(p.lt(p.get('i'), p.get('j')), () {
    p.set('sum', p.add(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.get('j'))));
    p.set('best', p.min(p.get('best'), p.abs(p.sub(p.get('sum'), p.get('target')))));
    p.iff(p.lt(p.get('sum'), p.get('target')), () => p.inc('i'), els: () => p.dec('j'));
  });
  p.ret(p.get('best'));

  final q = prog({'values': 'array<num>', 'target': 'num'}, {'i': 'num', 'j': 'num', 'best': 'num', 'diff': 'num'});
  q.set('best', q.abs(q.sub(q.add(q.at(q.get('values'), q.lit(0)), q.at(q.get('values'), q.lit(1))), q.get('target'))));
  q.range('i', q.lit(0), q.len(q.get('values')), () {
    q.range('j', q.add(q.get('i'), q.lit(1)), q.len(q.get('values')), () {
      q.set('diff', q.abs(q.sub(q.add(q.at(q.get('values'), q.get('i')), q.at(q.get('values'), q.get('j'))), q.get('target'))));
      q.set('best', q.min(q.get('best'), q.get('diff')));
    });
  });
  q.ret(q.get('best'));
  return Built(p.graph, [Reject('every pair', 'operationLimit', q.graph)]);
}

Built windowsAtLeast() {
  final p = prog({'values': 'array<num>', 'width': 'num', 'goal': 'num'}, {'i': 'num', 'sum': 'num', 'count': 'num'});
  p.iff(p.or(p.le(p.get('width'), p.lit(0)), p.gt(p.get('width'), p.len(p.get('values')))), () => p.ret(p.lit(0)));
  p.set('sum', p.lit(0));
  p.range('i', p.lit(0), p.get('width'), () {
    p.set('sum', p.add(p.get('sum'), p.at(p.get('values'), p.get('i'))));
  });
  p.set('count', p.lit(0));
  p.iff(p.ge(p.get('sum'), p.get('goal')), () => p.inc('count'));
  p.range('i', p.get('width'), p.len(p.get('values')), () {
    p.set('sum', p.add(p.get('sum'), p.sub(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.sub(p.get('i'), p.get('width'))))));
    p.iff(p.ge(p.get('sum'), p.get('goal')), () => p.inc('count'));
  });
  p.ret(p.get('count'));

  final q = prog({'values': 'array<num>', 'width': 'num', 'goal': 'num'}, {'i': 'num', 'sum': 'num'});
  q.iff(q.or(q.le(q.get('width'), q.lit(0)), q.gt(q.get('width'), q.len(q.get('values')))), () => q.ret(q.lit(0)));
  q.set('sum', q.lit(0));
  q.range('i', q.lit(0), q.get('width'), () {
    q.set('sum', q.add(q.get('sum'), q.at(q.get('values'), q.get('i'))));
  });
  q.iff(q.ge(q.get('sum'), q.get('goal')), () => q.ret(q.lit(1)), els: () => q.ret(q.lit(0)));
  return Built(p.graph, [Reject('only the first window', 'wrongAnswer', q.graph)]);
}

Built oneDropout() {
  BlockGraph scan({required int limit}) {
    final p = prog({'values': 'array<num>'}, {'left': 'num', 'right': 'num', 'zeros': 'num', 'best': 'num', 'span': 'num'});
    p.set('left', p.lit(0));
    p.set('zeros', p.lit(0));
    p.set('best', p.lit(0));
    p.range('right', p.lit(0), p.len(p.get('values')), () {
      p.iff(p.eq(p.at(p.get('values'), p.get('right')), p.lit(0)), () => p.inc('zeros'));
      p.whil(p.gt(p.get('zeros'), p.lit(limit)), () {
        p.iff(p.eq(p.at(p.get('values'), p.get('left')), p.lit(0)), () => p.dec('zeros'));
        p.inc('left');
      });
      p.set('span', p.add(p.sub(p.get('right'), p.get('left')), p.lit(1)));
      p.iff(p.gt(p.get('span'), p.get('best')), () => p.set('best', p.get('span')));
    });
    p.ret(p.get('best'));
    return p.graph;
  }

  return Built(scan(limit: 1), [Reject('allow no dropout at all', 'wrongAnswer', scan(limit: 0))]);
}

Built peakWindows() {
  final p = prog({'values': 'array<num>', 'width': 'num'}, {
    'i': 'num',
    'dq': 'array<num>',
    'head': 'num',
    'tail': 'num',
    'sum': 'num',
  });
  p.iff(p.or(p.le(p.get('width'), p.lit(0)), p.gt(p.get('width'), p.len(p.get('values')))), () => p.ret(p.lit(0)));
  p.set('dq', p.freshList());
  p.set('head', p.lit(0));
  p.set('tail', p.lit(0));
  p.set('sum', p.lit(0));
  p.range('i', p.lit(0), p.len(p.get('values')), () {
    p.whil(
      p.and(p.lt(p.get('head'), p.get('tail')), p.le(p.at(p.get('dq'), p.get('head')), p.sub(p.get('i'), p.get('width')))),
      () => p.inc('head'),
    );
    p.whil(
      p.and(
        p.gt(p.get('tail'), p.get('head')),
        p.le(p.at(p.get('values'), p.at(p.get('dq'), p.sub(p.get('tail'), p.lit(1)))), p.at(p.get('values'), p.get('i'))),
      ),
      () => p.dec('tail'),
    );
    p.iff(p.eq(p.get('tail'), p.len(p.get('dq'))), () {
      p.append('dq', p.get('i'));
    }, els: () {
      p.setAt('dq', p.get('tail'), p.get('i'));
    });
    p.inc('tail');
    p.iff(p.ge(p.get('i'), p.sub(p.get('width'), p.lit(1))), () {
      p.set('sum', p.add(p.get('sum'), p.at(p.get('values'), p.at(p.get('dq'), p.get('head')))));
    });
  });
  p.ret(p.get('sum'));

  final q = prog({'values': 'array<num>', 'width': 'num'}, {'start': 'num', 'k': 'num', 'm': 'num', 'sum': 'num'});
  q.iff(q.or(q.le(q.get('width'), q.lit(0)), q.gt(q.get('width'), q.len(q.get('values')))), () => q.ret(q.lit(0)));
  q.set('sum', q.lit(0));
  q.range('start', q.lit(0), q.sub(q.add(q.len(q.get('values')), q.lit(1)), q.get('width')), () {
    q.set('m', q.at(q.get('values'), q.get('start')));
    q.range('k', q.lit(1), q.get('width'), () {
      q.set('m', q.max(q.get('m'), q.at(q.get('values'), q.add(q.get('start'), q.get('k')))));
    });
    q.set('sum', q.add(q.get('sum'), q.get('m')));
  });
  q.ret(q.get('sum'));
  return Built(p.graph, [Reject('rescan every window', 'operationLimit', q.graph)]);
}

Built counterSum() {
  BlockGraph scan({required bool queue}) {
    final inputs = {'actions': 'array<num>'};
    final box = queue ? 'line' : 'pile';
    final pool = queue
        ? {'a': 'num', 'line': 'queue<num>', 'sum': 'num', 'served': 'num'}
        : {'a': 'num', 'pile': 'stack<num>', 'sum': 'num', 'served': 'num'};
    final p = prog(inputs, pool);
    p.set(box, queue ? p.freshQueue() : p.freshStack());
    p.set('sum', p.lit(0));
    p.each('a', p.get('actions'), () {
      p.iff(p.gt(p.get('a'), p.lit(0)), () {
        if (queue) {
          p.enq(box, p.get('a'));
        } else {
          p.push(box, p.get('a'));
        }
      }, els: () {
        p.iff(p.eq(p.get('a'), p.lit(0)), () {
          p.iff(queue ? p.not(p.queueEmpty(box)) : p.not(p.stackEmpty(box)), () {
            p.set('served', queue ? p.deq(box) : p.pop(box));
            p.set('sum', p.add(p.get('sum'), p.get('served')));
          });
        });
      });
    });
    p.ret(p.get('sum'));
    return p.graph;
  }

  return Built(scan(queue: true), [Reject('serve the newest customer', 'wrongAnswer', scan(queue: false))]);
}

Built josephusLine() {
  final p = prog({'people': 'num', 'count': 'num'}, {'i': 'num', 't': 'num', 'line': 'queue<num>', 'left': 'num', 'gone': 'num'});
  p.set('line', p.freshQueue());
  p.range('i', p.lit(1), p.add(p.get('people'), p.lit(1)), () => p.enq('line', p.get('i')));
  p.set('left', p.get('people'));
  p.whil(p.gt(p.get('left'), p.lit(1)), () {
    p.range('t', p.lit(0), p.sub(p.get('count'), p.lit(1)), () => p.enq('line', p.deq('line')));
    p.set('gone', p.deq('line'));
    p.dec('left');
  });
  p.ret(p.front('line'));

  final q = prog({'people': 'num', 'count': 'num'}, {});
  q.ret(q.get('people'));
  return Built(p.graph, [Reject('the last person in the original line always remains', 'wrongAnswer', q.graph)]);
}

Built ticketMinutes() {
  final p = prog({'tickets': 'array<num>', 'person': 'num'}, {'i': 'num', 'need': 'num', 'cap': 'num', 'take': 'num', 'time': 'num'});
  p.set('need', p.at(p.get('tickets'), p.get('person')));
  p.set('time', p.lit(0));
  p.range('i', p.lit(0), p.len(p.get('tickets')), () {
    p.iff(p.le(p.get('i'), p.get('person')), () {
      p.set('cap', p.get('need'));
    }, els: () {
      p.set('cap', p.sub(p.get('need'), p.lit(1)));
    });
    p.set('cap', p.max(p.get('cap'), p.lit(0)));
    p.set('take', p.min(p.at(p.get('tickets'), p.get('i')), p.get('cap')));
    p.set('time', p.add(p.get('time'), p.get('take')));
  });
  p.ret(p.get('time'));

  final q = prog({'tickets': 'array<num>', 'person': 'num'}, {'i': 'num', 'line': 'queue<num>', 'time': 'num'});
  q.set('line', q.freshQueue());
  q.range('i', q.lit(0), q.len(q.get('tickets')), () => q.enq('line', q.get('i')));
  q.set('time', q.lit(0));
  q.whil(q.truth(true), () {
    q.set('i', q.deq('line'));
    q.setAt('tickets', q.get('i'), q.sub(q.at(q.get('tickets'), q.get('i')), q.lit(1)));
    q.inc('time');
    q.iff(q.and(q.eq(q.get('i'), q.get('person')), q.eq(q.at(q.get('tickets'), q.get('i')), q.lit(0))), () {
      q.ret(q.get('time'));
    });
    q.iff(q.gt(q.at(q.get('tickets'), q.get('i')), q.lit(0)), () => q.enq('line', q.get('i')));
  });
  return Built(p.graph, [Reject('simulate the queue one ticket at a time', 'operationLimit', q.graph)]);
}

Built stackSorted() {
  final p = prog({'want': 'array<num>'}, {'x': 'num', 'i': 'num', 'n': 'num', 'st': 'stack<num>', 'gone': 'num'});
  p.set('st', p.freshStack());
  p.set('i', p.lit(0));
  p.set('n', p.len(p.get('want')));
  p.range('x', p.lit(1), p.add(p.get('n'), p.lit(1)), () {
    p.push('st', p.get('x'));
    p.whil(
      p.and(
        p.not(p.stackEmpty('st')),
        p.and(p.lt(p.get('i'), p.get('n')), p.eq(p.peek('st'), p.at(p.get('want'), p.get('i')))),
      ),
      () {
        p.set('gone', p.pop('st'));
        p.inc('i');
      },
    );
  });
  p.ret(p.eq(p.get('i'), p.get('n')));

  final q = prog({'want': 'array<num>'}, {'i': 'num', 'ok': 'bool'});
  q.set('ok', q.truth(true));
  q.range('i', q.lit(0), q.len(q.get('want')), () {
    q.iff(q.ne(q.at(q.get('want'), q.get('i')), q.add(q.get('i'), q.lit(1))), () => q.set('ok', q.truth(false)));
  });
  q.ret(q.get('ok'));
  return Built(p.graph, [Reject('accept only the already sorted order', 'wrongAnswer', q.graph)]);
}
