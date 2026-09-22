import '../types/value_type.dart';
import 'definition.dart';
import 'ports.dart';

/// Closed catalog of block ids. Puzzles whitelist a subset via `blocks.allow`.
///
/// The editor must never present the full catalog. Showing only
/// [Puzzle.blocks.allow] is an architectural requirement, not a UI preference.
abstract final class BlockIds {
  static const ctrlIf = 'ctrl.if';
  static const ctrlElse = 'ctrl.else';
  static const ctrlWhile = 'ctrl.while';
  static const ctrlForRange = 'ctrl.for_range';
  static const ctrlForEach = 'ctrl.foreach';
  static const ctrlBreak = 'ctrl.break';
  static const ctrlContinue = 'ctrl.continue';
  static const ctrlReturn = 'ctrl.return';

  static const varSet = 'var.set';
  static const varGet = 'var.get';
  static const varInc = 'var.inc';
  static const varDec = 'var.dec';
  static const varSwap = 'var.swap';
  static const varCopy = 'var.copy';

  static const litNum = 'lit.num';
  static const litBool = 'lit.bool';
  static const litStr = 'lit.str';
  static const litNull = 'lit.null';

  static const cmpEq = 'cmp.eq';
  static const cmpNe = 'cmp.ne';
  static const cmpLt = 'cmp.lt';
  static const cmpLe = 'cmp.le';
  static const cmpGt = 'cmp.gt';
  static const cmpGe = 'cmp.ge';
  static const logicAnd = 'logic.and';
  static const logicOr = 'logic.or';
  static const logicNot = 'logic.not';

  static const arithAdd = 'arith.add';
  static const arithSub = 'arith.sub';
  static const arithMul = 'arith.mul';
  static const arithDiv = 'arith.div';

  /// Whole-number division that rounds down. DIVIDE is untouched: `7 / 2`
  /// is still `3.5`; FLOOR DIVIDE gives `3`, a valid list position.
  static const arithFloorDiv = 'arith.floor_div';
  static const arithMod = 'arith.mod';
  static const arithMin = 'arith.min';
  static const arithMax = 'arith.max';
  static const arithAbs = 'arith.abs';

  static const arrGet = 'arr.get';
  static const arrSet = 'arr.set';
  static const arrLen = 'arr.len';
  static const arrAppend = 'arr.append';
  static const arrRemove = 'arr.remove';
  static const arrSwap = 'arr.swap';

  static const mapGet = 'map.get';
  static const mapSet = 'map.set';
  static const mapHas = 'map.has';
  static const mapRemove = 'map.remove';
  static const mapSize = 'map.size';

  static const setAdd = 'set.add';
  static const setHas = 'set.has';
  static const setRemove = 'set.remove';
  static const setSize = 'set.size';

  static const stackPush = 'stack.push';
  static const stackPop = 'stack.pop';
  static const stackPeek = 'stack.peek';
  static const stackEmpty = 'stack.empty';

  static const queueEnq = 'queue.enq';
  static const queueDeq = 'queue.deq';
  static const queueFront = 'queue.front';
  static const queueEmpty = 'queue.empty';

  static const llValue = 'll.value';
  static const llNext = 'll.next';
  static const llSetNext = 'll.set_next';

  static const treeValue = 'tree.value';
  static const treeLeft = 'tree.left';
  static const treeRight = 'tree.right';

  static const graphNeighbors = 'graph.neighbors';
  static const graphMark = 'graph.mark';
  static const graphVisited = 'graph.visited';
  static const graphNodeCount = 'graph.node_count';

  static const newArray = 'new.array';
  static const newMap = 'new.map';
  static const newSet = 'new.set';
  static const newStack = 'new.stack';
  static const newQueue = 'new.queue';

  static const fnDef = 'fn.def';
  static const fnCall = 'fn.call';

  static const Set<String> all = {
    ctrlIf, ctrlElse, ctrlWhile, ctrlForRange, ctrlForEach,
    ctrlBreak, ctrlContinue, ctrlReturn,
    varSet, varGet, varInc, varDec, varSwap, varCopy,
    litNum, litBool, litStr, litNull,
    cmpEq, cmpNe, cmpLt, cmpLe, cmpGt, cmpGe,
    logicAnd, logicOr, logicNot,
    arithAdd, arithSub, arithMul, arithDiv, arithFloorDiv, arithMod,
    arithMin, arithMax, arithAbs,
    arrGet, arrSet, arrLen, arrAppend, arrRemove, arrSwap,
    mapGet, mapSet, mapHas, mapRemove, mapSize,
    setAdd, setHas, setRemove, setSize,
    stackPush, stackPop, stackPeek, stackEmpty,
    queueEnq, queueDeq, queueFront, queueEmpty,
    llValue, llNext, llSetNext,
    treeValue, treeLeft, treeRight,
    graphNeighbors, graphMark, graphVisited, graphNodeCount,
    newArray, newMap, newSet, newStack, newQueue,
    fnDef, fnCall,
  };

  static bool exists(String id) => all.contains(id);
}

/// Port layout for every catalog id. This is the source of truth for snap.
abstract final class BlockCatalog {
  static BlockDefinition? of(String id) => _defs[id];

  static Iterable<BlockDefinition> get all => _defs.values;

  static final Map<String, BlockDefinition> _defs = {
    BlockIds.ctrlIf: stackBlock(BlockIds.ctrlIf, [
      exprIn('condition', ValueType.boolean),
      stmtList('then'),
      elseIn,
    ]),
    BlockIds.ctrlElse: const BlockDefinition(
      id: BlockIds.ctrlElse,
      role: BlockRole.elseClause,
      ports: [elseOut, PortDefinition(
        name: 'body',
        kind: PortKind.statement,
        direction: PortDirection.input,
        arity: PortArity.many,
      )],
    ),
    BlockIds.ctrlWhile: stackBlock(BlockIds.ctrlWhile, [
      exprIn('condition', ValueType.boolean),
      stmtList('body'),
    ]),
    BlockIds.ctrlForRange: stackBlock(BlockIds.ctrlForRange, [
      exprIn('start', ValueType.number),
      exprIn('end', ValueType.number),
      exprIn('step', ValueType.number),
      stmtList('body'),
    ]),
    BlockIds.ctrlForEach: BlockDefinition(
      id: BlockIds.ctrlForEach,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('collection', ValueType.array(ValueType.t)),
        stmtList('body'),
      ],
    ),
    BlockIds.ctrlBreak: stackBlock(BlockIds.ctrlBreak, const []),
    BlockIds.ctrlContinue: stackBlock(BlockIds.ctrlContinue, const []),
    BlockIds.ctrlReturn: stackBlock(BlockIds.ctrlReturn, [
      exprIn('value', ValueType.t),
    ]),
    BlockIds.varSet: stackBlock(BlockIds.varSet, [
      exprIn('value', ValueType.t),
    ]),
    BlockIds.varGet: reporter(BlockIds.varGet, ValueType.t, const []),
    BlockIds.varInc: stackBlock(BlockIds.varInc, const []),
    BlockIds.varDec: stackBlock(BlockIds.varDec, const []),
    BlockIds.varSwap: stackBlock(BlockIds.varSwap, const []),
    BlockIds.varCopy: stackBlock(BlockIds.varCopy, const []),
    BlockIds.litNum: reporter(BlockIds.litNum, ValueType.number, const []),
    BlockIds.litBool: reporter(BlockIds.litBool, ValueType.boolean, const []),
    BlockIds.litStr: reporter(BlockIds.litStr, ValueType.string, const []),
    BlockIds.litNull: reporter(BlockIds.litNull, ValueType.nil, const []),
    BlockIds.cmpEq: _eq(BlockIds.cmpEq),
    BlockIds.cmpNe: _eq(BlockIds.cmpNe),
    BlockIds.cmpLt: _numCmp(BlockIds.cmpLt),
    BlockIds.cmpLe: _numCmp(BlockIds.cmpLe),
    BlockIds.cmpGt: _numCmp(BlockIds.cmpGt),
    BlockIds.cmpGe: _numCmp(BlockIds.cmpGe),
    BlockIds.logicAnd: _boolBin(BlockIds.logicAnd),
    BlockIds.logicOr: _boolBin(BlockIds.logicOr),
    BlockIds.logicNot: reporter(BlockIds.logicNot, ValueType.boolean, [
      exprIn('arg', ValueType.boolean),
    ]),
    BlockIds.arithAdd: _numBin(BlockIds.arithAdd),
    BlockIds.arithSub: _numBin(BlockIds.arithSub),
    BlockIds.arithMul: _numBin(BlockIds.arithMul),
    BlockIds.arithDiv: _numBin(BlockIds.arithDiv),
    BlockIds.arithMod: _numBin(BlockIds.arithMod),
    BlockIds.arithMin: _numBin(BlockIds.arithMin),
    BlockIds.arithMax: _numBin(BlockIds.arithMax),
    BlockIds.arithFloorDiv: _numBin(BlockIds.arithFloorDiv),
    BlockIds.arithAbs: reporter(BlockIds.arithAbs, ValueType.number, [
      exprIn('arg', ValueType.number),
    ]),
    BlockIds.arrGet: reporter(
      BlockIds.arrGet,
      ValueType.t,
      [
        exprIn('array', ValueType.array(ValueType.t)),
        exprIn('index', ValueType.number),
      ],
      typeParams: const ['T'],
    ),
    BlockIds.arrSet: BlockDefinition(
      id: BlockIds.arrSet,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('array', ValueType.array(ValueType.t)),
        exprIn('index', ValueType.number),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.arrLen: reporter(BlockIds.arrLen, ValueType.number, [
      exprIn('array', ValueType.array(ValueType.t)),
    ], typeParams: const ['T']),
    BlockIds.arrAppend: BlockDefinition(
      id: BlockIds.arrAppend,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('array', ValueType.array(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.arrRemove: BlockDefinition(
      id: BlockIds.arrRemove,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('array', ValueType.array(ValueType.t)),
        exprIn('index', ValueType.number),
      ],
    ),
    BlockIds.arrSwap: BlockDefinition(
      id: BlockIds.arrSwap,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('array', ValueType.array(ValueType.t)),
        exprIn('i', ValueType.number),
        exprIn('j', ValueType.number),
      ],
    ),
    BlockIds.mapGet: reporter(
      BlockIds.mapGet,
      ValueType.v.asNullable,
      [
        exprIn('map', ValueType.mapOf(ValueType.k, ValueType.v)),
        exprIn('key', ValueType.k),
      ],
      typeParams: const ['K', 'V'],
    ),
    BlockIds.mapSet: BlockDefinition(
      id: BlockIds.mapSet,
      role: BlockRole.statement,
      typeParams: const ['K', 'V'],
      ports: [
        stmtOut,
        exprIn('map', ValueType.mapOf(ValueType.k, ValueType.v)),
        exprIn('key', ValueType.k),
        exprIn('value', ValueType.v),
      ],
    ),
    BlockIds.mapHas: reporter(
      BlockIds.mapHas,
      ValueType.boolean,
      [
        exprIn('map', ValueType.mapOf(ValueType.k, ValueType.v)),
        exprIn('key', ValueType.k),
      ],
      typeParams: const ['K', 'V'],
    ),
    BlockIds.mapRemove: BlockDefinition(
      id: BlockIds.mapRemove,
      role: BlockRole.statement,
      typeParams: const ['K', 'V'],
      ports: [
        stmtOut,
        exprIn('map', ValueType.mapOf(ValueType.k, ValueType.v)),
        exprIn('key', ValueType.k),
      ],
    ),
    BlockIds.mapSize: reporter(BlockIds.mapSize, ValueType.number, [
      exprIn('map', ValueType.mapOf(ValueType.k, ValueType.v)),
    ], typeParams: const ['K', 'V']),
    BlockIds.setAdd: BlockDefinition(
      id: BlockIds.setAdd,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('set', ValueType.setOf(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.setHas: reporter(
      BlockIds.setHas,
      ValueType.boolean,
      [
        exprIn('set', ValueType.setOf(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
      typeParams: const ['T'],
    ),
    BlockIds.setRemove: BlockDefinition(
      id: BlockIds.setRemove,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('set', ValueType.setOf(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.setSize: reporter(BlockIds.setSize, ValueType.number, [
      exprIn('set', ValueType.setOf(ValueType.t)),
    ], typeParams: const ['T']),
    BlockIds.stackPush: BlockDefinition(
      id: BlockIds.stackPush,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('stack', ValueType.stackOf(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.stackPop: reporter(
      BlockIds.stackPop,
      ValueType.t,
      [exprIn('stack', ValueType.stackOf(ValueType.t))],
      typeParams: const ['T'],
    ),
    BlockIds.stackPeek: reporter(
      BlockIds.stackPeek,
      ValueType.t,
      [exprIn('stack', ValueType.stackOf(ValueType.t))],
      typeParams: const ['T'],
    ),
    BlockIds.stackEmpty: reporter(BlockIds.stackEmpty, ValueType.boolean, [
      exprIn('stack', ValueType.stackOf(ValueType.t)),
    ], typeParams: const ['T']),
    BlockIds.queueEnq: BlockDefinition(
      id: BlockIds.queueEnq,
      role: BlockRole.statement,
      typeParams: const ['T'],
      ports: [
        stmtOut,
        exprIn('queue', ValueType.queueOf(ValueType.t)),
        exprIn('value', ValueType.t),
      ],
    ),
    BlockIds.queueDeq: reporter(
      BlockIds.queueDeq,
      ValueType.t,
      [exprIn('queue', ValueType.queueOf(ValueType.t))],
      typeParams: const ['T'],
    ),
    BlockIds.queueFront: reporter(
      BlockIds.queueFront,
      ValueType.t,
      [exprIn('queue', ValueType.queueOf(ValueType.t))],
      typeParams: const ['T'],
    ),
    BlockIds.queueEmpty: reporter(BlockIds.queueEmpty, ValueType.boolean, [
      exprIn('queue', ValueType.queueOf(ValueType.t)),
    ], typeParams: const ['T']),
    BlockIds.llValue: reporter(BlockIds.llValue, ValueType.number, [
      exprIn('node', ValueType.listNode),
    ]),
    BlockIds.llNext: reporter(BlockIds.llNext, ValueType.listNode.asNullable, [
      exprIn('node', ValueType.listNode),
    ]),
    BlockIds.llSetNext: stackBlock(BlockIds.llSetNext, [
      exprIn('node', ValueType.listNode),
      exprIn('next', ValueType.listNode.asNullable),
    ]),
    BlockIds.treeValue: reporter(BlockIds.treeValue, ValueType.number, [
      exprIn('node', ValueType.treeNode),
    ]),
    BlockIds.treeLeft: reporter(BlockIds.treeLeft, ValueType.treeNode.asNullable, [
      exprIn('node', ValueType.treeNode),
    ]),
    BlockIds.treeRight: reporter(
      BlockIds.treeRight,
      ValueType.treeNode.asNullable,
      [exprIn('node', ValueType.treeNode)],
    ),
    BlockIds.graphNeighbors: reporter(
      BlockIds.graphNeighbors,
      ValueType.array(ValueType.number),
      [
        exprIn('graph', ValueType.graph),
        exprIn('node', ValueType.number),
      ],
    ),
    BlockIds.graphMark: stackBlock(BlockIds.graphMark, [
      exprIn('graph', ValueType.graph),
      exprIn('node', ValueType.number),
    ]),
    BlockIds.graphVisited: reporter(BlockIds.graphVisited, ValueType.boolean, [
      exprIn('graph', ValueType.graph),
      exprIn('node', ValueType.number),
    ]),
    BlockIds.graphNodeCount: reporter(
      BlockIds.graphNodeCount,
      ValueType.number,
      [exprIn('graph', ValueType.graph)],
    ),
    BlockIds.newArray: reporter(
      BlockIds.newArray,
      ValueType.array(ValueType.t),
      const [],
      typeParams: const ['T'],
    ),
    BlockIds.newMap: reporter(
      BlockIds.newMap,
      ValueType.mapOf(ValueType.k, ValueType.v),
      const [],
      typeParams: const ['K', 'V'],
    ),
    BlockIds.newSet: reporter(
      BlockIds.newSet,
      ValueType.setOf(ValueType.t),
      const [],
      typeParams: const ['T'],
    ),
    BlockIds.newStack: reporter(
      BlockIds.newStack,
      ValueType.stackOf(ValueType.t),
      const [],
      typeParams: const ['T'],
    ),
    BlockIds.newQueue: reporter(
      BlockIds.newQueue,
      ValueType.queueOf(ValueType.t),
      const [],
      typeParams: const ['T'],
    ),
    BlockIds.fnDef: stackBlock(BlockIds.fnDef, [stmtList('body')]),
    BlockIds.fnCall: reporter(BlockIds.fnCall, ValueType.t, const [],
        typeParams: const ['T']),
  };
}

BlockDefinition _numBin(String id) => reporter(id, ValueType.number, [
      exprIn('left', ValueType.number),
      exprIn('right', ValueType.number),
    ]);

BlockDefinition _numCmp(String id) => reporter(id, ValueType.boolean, [
      exprIn('left', ValueType.number),
      exprIn('right', ValueType.number),
    ]);

BlockDefinition _boolBin(String id) => reporter(id, ValueType.boolean, [
      exprIn('left', ValueType.boolean),
      exprIn('right', ValueType.boolean),
    ]);

BlockDefinition _eq(String id) => reporter(
      id,
      ValueType.boolean,
      [
        exprIn('left', ValueType.t),
        exprIn('right', ValueType.t),
      ],
      typeParams: const ['T'],
    );
