import 'catalog.dart';

/// Player-facing chrome. Never a catalog id (`cmp.gt`).
enum BlockCategory { control, value, logic, math, collection, structure }

enum BlockLayout {
  infixBinary,
  prefix,
  verbObject,
  stmtHat,
  cBlock,
  elseHat,
  reporter,
}

final class BlockChrome {
  const BlockChrome({
    required this.label,
    required this.category,
    required this.layout,
  });

  final String label;
  final BlockCategory category;
  final BlockLayout layout;

  static BlockChrome of(String catalogId) =>
      _all[catalogId] ??
      const BlockChrome(
        label: 'BLOCK',
        category: BlockCategory.value,
        layout: BlockLayout.reporter,
      );

  static String labelOf(String catalogId) => of(catalogId).label;

  static bool hiddenFromEditor(String catalogId) =>
      catalogId == BlockIds.fnDef || catalogId == BlockIds.fnCall;

  static String holeCaption(String portName) {
    return switch (portName) {
      'condition' => 'condition',
      'index' || 'i' || 'j' || 'start' || 'end' || 'step' => 'number',
      'array' || 'collection' => 'list',
      'map' => 'map',
      'set' => 'set',
      'stack' => 'stack',
      'queue' => 'queue',
      'value' || 'left' || 'right' || 'arg' => 'value',
      'key' => 'key',
      'node' || 'next' => 'node',
      'graph' => 'graph',
      'body' || 'then' => 'instruction',
      'else' => 'else',
      _ => 'value',
    };
  }

  static String categoryLabel(BlockCategory category) {
    return switch (category) {
      BlockCategory.control => 'CONTROL',
      BlockCategory.value => 'VALUES',
      BlockCategory.logic => 'LOGIC',
      BlockCategory.math => 'MATH',
      BlockCategory.collection => 'LISTS',
      BlockCategory.structure => 'STRUCTURE',
    };
  }
}

const _c = BlockCategory.control;
const _v = BlockCategory.value;
const _l = BlockCategory.logic;
const _m = BlockCategory.math;
const _k = BlockCategory.collection;
const _s = BlockCategory.structure;

BlockChrome _ch(
  String label,
  BlockCategory category,
  BlockLayout layout,
) =>
    BlockChrome(label: label, category: category, layout: layout);

final Map<String, BlockChrome> _all = {
  BlockIds.ctrlIf: _ch('IF', _c, BlockLayout.cBlock),
  BlockIds.ctrlElse: _ch('ELSE', _c, BlockLayout.elseHat),
  BlockIds.ctrlWhile: _ch('WHILE', _c, BlockLayout.cBlock),
  BlockIds.ctrlForRange: _ch('FOR', _c, BlockLayout.cBlock),
  BlockIds.ctrlForEach: _ch('FOR EACH', _c, BlockLayout.cBlock),
  BlockIds.ctrlBreak: _ch('BREAK', _c, BlockLayout.stmtHat),
  BlockIds.ctrlContinue: _ch('CONTINUE', _c, BlockLayout.stmtHat),
  BlockIds.ctrlReturn: _ch('RETURN', _c, BlockLayout.stmtHat),
  BlockIds.varSet: _ch('SET', _v, BlockLayout.stmtHat),
  BlockIds.varGet: _ch('GET', _v, BlockLayout.reporter),
  BlockIds.varInc: _ch('INCREMENT', _v, BlockLayout.stmtHat),
  BlockIds.varDec: _ch('DECREMENT', _v, BlockLayout.stmtHat),
  BlockIds.varSwap: _ch('SWAP', _v, BlockLayout.stmtHat),
  BlockIds.varCopy: _ch('COPY', _v, BlockLayout.stmtHat),
  BlockIds.litNum: _ch('NUMBER', _v, BlockLayout.reporter),
  BlockIds.litBool: _ch('BOOLEAN', _v, BlockLayout.reporter),
  BlockIds.litStr: _ch('TEXT', _v, BlockLayout.reporter),
  BlockIds.litNull: _ch('NOTHING', _v, BlockLayout.reporter),
  BlockIds.cmpEq: _ch('EQUAL', _l, BlockLayout.infixBinary),
  BlockIds.cmpNe: _ch('NOT EQUAL', _l, BlockLayout.infixBinary),
  BlockIds.cmpLt: _ch('LESS THAN', _l, BlockLayout.infixBinary),
  BlockIds.cmpLe: _ch('LESS OR EQUAL', _l, BlockLayout.infixBinary),
  BlockIds.cmpGt: _ch('GREATER THAN', _l, BlockLayout.infixBinary),
  BlockIds.cmpGe: _ch('GREATER OR EQUAL', _l, BlockLayout.infixBinary),
  BlockIds.logicAnd: _ch('AND', _l, BlockLayout.infixBinary),
  BlockIds.logicOr: _ch('OR', _l, BlockLayout.infixBinary),
  BlockIds.logicNot: _ch('NOT', _l, BlockLayout.prefix),
  BlockIds.arithAdd: _ch('PLUS', _m, BlockLayout.infixBinary),
  BlockIds.arithSub: _ch('MINUS', _m, BlockLayout.infixBinary),
  BlockIds.arithMul: _ch('TIMES', _m, BlockLayout.infixBinary),
  BlockIds.arithDiv: _ch('DIVIDE', _m, BlockLayout.infixBinary),
  BlockIds.arithMod: _ch('REMAINDER', _m, BlockLayout.infixBinary),
  BlockIds.arithMin: _ch('MIN', _m, BlockLayout.infixBinary),
  BlockIds.arithMax: _ch('MAX', _m, BlockLayout.infixBinary),
  BlockIds.arithAbs: _ch('ABSOLUTE', _m, BlockLayout.prefix),
  BlockIds.arrGet: _ch('GET ELEMENT', _k, BlockLayout.verbObject),
  BlockIds.arrSet: _ch('SET ELEMENT', _k, BlockLayout.stmtHat),
  BlockIds.arrLen: _ch('LENGTH', _k, BlockLayout.verbObject),
  BlockIds.arrAppend: _ch('APPEND', _k, BlockLayout.stmtHat),
  BlockIds.arrRemove: _ch('REMOVE AT', _k, BlockLayout.stmtHat),
  BlockIds.arrSwap: _ch('SWAP ELEMENTS', _k, BlockLayout.stmtHat),
  BlockIds.mapGet: _ch('GET', _k, BlockLayout.verbObject),
  BlockIds.mapSet: _ch('PUT', _k, BlockLayout.stmtHat),
  BlockIds.mapHas: _ch('HAS KEY', _k, BlockLayout.verbObject),
  BlockIds.mapRemove: _ch('REMOVE KEY', _k, BlockLayout.stmtHat),
  BlockIds.mapSize: _ch('SIZE', _k, BlockLayout.verbObject),
  BlockIds.setAdd: _ch('ADD', _k, BlockLayout.stmtHat),
  BlockIds.setHas: _ch('HAS', _k, BlockLayout.verbObject),
  BlockIds.setRemove: _ch('REMOVE', _k, BlockLayout.stmtHat),
  BlockIds.setSize: _ch('SIZE', _k, BlockLayout.verbObject),
  BlockIds.stackPush: _ch('PUSH', _k, BlockLayout.stmtHat),
  BlockIds.stackPop: _ch('POP', _k, BlockLayout.verbObject),
  BlockIds.stackPeek: _ch('PEEK', _k, BlockLayout.verbObject),
  BlockIds.stackEmpty: _ch('IS EMPTY', _k, BlockLayout.verbObject),
  BlockIds.queueEnq: _ch('ENQUEUE', _k, BlockLayout.stmtHat),
  BlockIds.queueDeq: _ch('DEQUEUE', _k, BlockLayout.verbObject),
  BlockIds.queueFront: _ch('FRONT', _k, BlockLayout.verbObject),
  BlockIds.queueEmpty: _ch('IS EMPTY', _k, BlockLayout.verbObject),
  BlockIds.llValue: _ch('NODE VALUE', _s, BlockLayout.verbObject),
  BlockIds.llNext: _ch('NEXT NODE', _s, BlockLayout.verbObject),
  BlockIds.llSetNext: _ch('SET NEXT', _s, BlockLayout.stmtHat),
  BlockIds.treeValue: _ch('NODE VALUE', _s, BlockLayout.verbObject),
  BlockIds.treeLeft: _ch('LEFT', _s, BlockLayout.verbObject),
  BlockIds.treeRight: _ch('RIGHT', _s, BlockLayout.verbObject),
  BlockIds.graphNeighbors: _ch('NEIGHBORS', _s, BlockLayout.verbObject),
  BlockIds.graphMark: _ch('MARK', _s, BlockLayout.stmtHat),
  BlockIds.graphVisited: _ch('VISITED', _s, BlockLayout.verbObject),
  BlockIds.graphNodeCount: _ch('NODE COUNT', _s, BlockLayout.verbObject),
  BlockIds.newArray: _ch('NEW LIST', _k, BlockLayout.reporter),
  BlockIds.newMap: _ch('NEW MAP', _k, BlockLayout.reporter),
  BlockIds.newSet: _ch('NEW SET', _k, BlockLayout.reporter),
  BlockIds.newStack: _ch('NEW STACK', _k, BlockLayout.reporter),
  BlockIds.newQueue: _ch('NEW QUEUE', _k, BlockLayout.reporter),
  BlockIds.fnDef: _ch('FUNCTION', _c, BlockLayout.cBlock),
  BlockIds.fnCall: _ch('CALL', _c, BlockLayout.reporter),
};
