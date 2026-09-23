import '../blocks/block_graph.dart';
import '../blocks/catalog.dart';
import '../blocks/definition.dart';
import '../blocks/narrowing.dart';
import '../blocks/ports.dart';
import '../blocks/structure.dart';
import '../blocks/typing.dart';
import '../puzzles/puzzle.dart';
import '../types/parse_type.dart';
import '../types/value_type.dart';
import '../validation/validation_report.dart';
import 'ir.dart';

/// Outcome of [lower]. Never throws for a malformed graph.
final class LowerResult {
  const LowerResult._({this.program, this.errors = const []});

  factory LowerResult.ok(Program program) => LowerResult._(program: program);

  factory LowerResult.fail(List<ValidationMessage> errors) =>
      LowerResult._(errors: errors);

  final Program? program;
  final List<ValidationMessage> errors;
  bool get ok => program != null && errors.isEmpty;
}

/// BlockGraph → typed [Program]. UI fields are ignored.
///
/// Same as [Lowerer.lower]. Callers should not depend on [Lowerer] internals.
LowerResult lower(BlockGraph graph, Puzzle puzzle) =>
    const Lowerer().lower(graph, puzzle);

/// BlockGraph → typed [Program]. UI fields are ignored.
final class Lowerer {
  const Lowerer();

  LowerResult lower(BlockGraph graph, Puzzle puzzle) {
    return _Session(graph, puzzle).run();
  }
}

final class _Session {
  _Session(this.graph, this.puzzle)
      : env = {
          for (final input in puzzle.io.inputs) input.name: input.type,
          ...graph.variables,
        };

  final BlockGraph graph;
  final Puzzle puzzle;
  final Map<String, ValueType> env;
  final List<ValidationMessage> errors = [];
  late final Narrowing narrowing = Narrowing.of(graph);

  /// [name] as a GET at [blockId] reads it: narrowed where a check proved it
  /// holds something (L1).
  ValueType? _read(String name, String blockId) {
    final declared = env[name];
    if (declared == null) return null;
    return Narrowing.read(declared, name, narrowing.at(blockId));
  }

  LowerResult run() {
    final structure = GraphStructure.validate(graph);
    errors.addAll(structure.messages);
    if (graph.isEmpty) {
      _err('empty_program', 'The canvas is empty.');
    }
    for (final block in graph.blocks.values) {
      if (!BlockIds.exists(block.catalogId)) {
        _err('unknown_block', 'Unknown block.', block.id);
      }
    }
    if (errors.isNotEmpty) {
      return LowerResult.fail(List.unmodifiable(errors));
    }

    final body = <Stmt>[];
    for (final id in graph.entryIds) {
      final stmt = _stmt(id);
      if (stmt != null) body.add(stmt);
    }
    if (errors.isNotEmpty) {
      return LowerResult.fail(List.unmodifiable(errors));
    }
    final program = Program(
      functions: [
        FnDecl(
          name: 'main',
          params: [
            for (final input in puzzle.io.inputs) Param(input.name, input.type),
          ],
          returnType: puzzle.io.output,
          body: body,
        ),
      ],
    );
    return LowerResult.ok(program);
  }

  Stmt? _stmt(String id) {
    final block = graph.blocks[id];
    if (block == null) {
      _err('missing_block', 'A stack points at a missing block.', id);
      return null;
    }
    final cat = block.catalogId;
    try {
      return switch (cat) {
        BlockIds.ctrlIf => _if(block),
        BlockIds.ctrlElse => _badElse(block),
        BlockIds.ctrlWhile => _while(block),
        BlockIds.ctrlForRange => _forRange(block),
        BlockIds.ctrlForEach => _forEach(block),
        BlockIds.ctrlBreak => BreakStmt(srcBlockId: id),
        BlockIds.ctrlContinue => ContinueStmt(srcBlockId: id),
        BlockIds.ctrlReturn => ReturnStmt(
            value: _optExpr(id, 'value'),
            srcBlockId: id,
          ),
        BlockIds.varSet => _assignVar(block),
        BlockIds.varInc => _incDec(block, inc: true),
        BlockIds.varDec => _incDec(block, inc: false),
        BlockIds.varSwap => _swap(block),
        BlockIds.varCopy => _copy(block),
        BlockIds.arrSet => _arrSet(block),
        BlockIds.arrAppend ||
        BlockIds.arrRemove ||
        BlockIds.arrSwap ||
        BlockIds.mapSet ||
        BlockIds.mapRemove ||
        BlockIds.setAdd ||
        BlockIds.setRemove ||
        BlockIds.stackPush ||
        BlockIds.queueEnq ||
        BlockIds.graphMark =>
          _callStmt(block),
        BlockIds.llSetNext => _fieldAssign(block, 'next', 'node', 'next'),
        BlockIds.fnDef || BlockIds.fnCall => _unsupported(block),
        _ => _maybeExprStmt(block),
      };
    } on FormatException {
      _err(
        'malformed',
        'This program is not put together correctly.',
        id,
      );
      return null;
    }
  }

  Stmt? _badElse(BlockInstance block) {
    _err(
      'wrong_kind',
      'Only an else branch fits here.',
      block.id,
    );
    return null;
  }

  Stmt? _unsupported(BlockInstance block) {
    _err(
      'unsupported',
      'This piece cannot be used yet.',
      block.id,
    );
    return null;
  }

  Stmt? _maybeExprStmt(BlockInstance block) {
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) {
      _err('unknown_block', 'Unknown block.', block.id);
      return null;
    }
    if (def.role != BlockRole.statement) {
      _err(
        'wrong_kind',
        'This spot needs an instruction, not a value.',
        block.id,
      );
      return null;
    }
    return _unsupported(block);
  }

  IfStmt? _if(BlockInstance block) {
    final cond = _reqExpr(block.id, 'condition', expect: ValueType.boolean);
    final thenBody = _stmts(block.id, 'then');
    List<Stmt>? elseBody;
    final elseIds = graph.slotList(block.id, 'else');
    if (elseIds.isNotEmpty) {
      final elseBlock = graph.blocks[elseIds.first];
      if (elseBlock == null) {
        _err('missing_block', 'A connection points at a missing block.', block.id,
            'else');
      } else if (elseBlock.catalogId != BlockIds.ctrlElse) {
        _err(
          'wrong_kind',
          'Only an else branch fits here.',
          block.id,
          'else',
        );
      } else {
        elseBody = _stmts(elseBlock.id, 'body');
      }
    }
    if (cond == null) return null;
    return IfStmt(
      cond: cond,
      thenBody: thenBody,
      elseBody: elseBody,
      srcBlockId: block.id,
    );
  }

  WhileStmt? _while(BlockInstance block) {
    final cond = _reqExpr(block.id, 'condition', expect: ValueType.boolean);
    final body = _stmts(block.id, 'body');
    if (cond == null) return null;
    return WhileStmt(cond: cond, body: body, srcBlockId: block.id);
  }

  ForRangeStmt? _forRange(BlockInstance block) {
    final name = block.literals['name'] as String?;
    if (name == null || name.isEmpty) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    final start = _reqExpr(block.id, 'start', expect: ValueType.number);
    final end = _reqExpr(block.id, 'end', expect: ValueType.number);
    final step = _optExpr(block.id, 'step', expect: ValueType.number);
    final saved = env[name];
    env[name] = ValueType.number;
    final body = _stmts(block.id, 'body');
    if (saved == null) {
      env.remove(name);
    } else {
      env[name] = saved;
    }
    if (start == null || end == null) return null;
    return ForRangeStmt(
      loopVar: name,
      start: start,
      end: end,
      step: step,
      body: body,
      srcBlockId: block.id,
    );
  }

  ForEachStmt? _forEach(BlockInstance block) {
    final name = block.literals['name'] as String?;
    if (name == null || name.isEmpty) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    final collection = _reqExpr(block.id, 'collection');
    if (collection == null) return null;
    if (collection.type.atom != TypeAtom.array) {
      _err('type_mismatch', 'This block needs a list.', block.id, 'collection');
      return null;
    }
    final itemType = collection.type.param ?? ValueType.t;
    final saved = env[name];
    env[name] = itemType;
    final body = _stmts(block.id, 'body');
    if (saved == null) {
      env.remove(name);
    } else {
      env[name] = saved;
    }
    return ForEachStmt(
      itemVar: name,
      collection: collection,
      body: body,
      srcBlockId: block.id,
    );
  }

  AssignStmt? _assignVar(BlockInstance block) {
    final name = block.literals['name'] as String?;
    if (name == null || name.isEmpty) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    final declared = env[name];
    if (declared == null) {
      _err('undefined_variable', 'This variable is not defined.', block.id);
      return null;
    }
    final value = _reqExpr(block.id, 'value', expect: declared);
    if (value == null) return null;
    return AssignStmt(
      target: VarLValue(name, srcBlockId: block.id),
      value: value,
      srcBlockId: block.id,
    );
  }

  Stmt? _incDec(BlockInstance block, {required bool inc}) {
    final name = block.literals['name'] as String?;
    if (name == null || name.isEmpty) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    final declared = env[name];
    if (declared == null) {
      _err('undefined_variable', 'This variable is not defined.', block.id);
      return null;
    }
    if (declared.atom != TypeAtom.number) {
      _err('type_mismatch', 'This variable is not a number.', block.id);
      return null;
    }
    final target = VarLValue(name, srcBlockId: block.id);
    return inc
        ? IncStmt(target, srcBlockId: block.id)
        : DecStmt(target, srcBlockId: block.id);
  }

  Stmt? _swap(BlockInstance block) {
    final a = block.literals['name'] as String?;
    final b = (block.literals['other'] ?? block.literals['b']) as String?;
    if (a == null || b == null) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    for (final n in [a, b]) {
      if (!env.containsKey(n)) {
        _err('undefined_variable', 'This variable is not defined.', block.id);
        return null;
      }
    }
    final aType = _read(a, block.id)!;
    final bType = _read(b, block.id)!;
    if (!_fitsVariable(env[a]!, bType, block.id) ||
        !_fitsVariable(env[b]!, aType, block.id)) {
      return null;
    }
    return ExprStmt(
      CallExpr(
        BlockIds.varSwap,
        [
          VarExpr(a, type: aType, srcBlockId: block.id),
          VarExpr(b, type: bType, srcBlockId: block.id),
        ],
        type: ValueType.voidType,
        srcBlockId: block.id,
      ),
      srcBlockId: block.id,
    );
  }

  Stmt? _copy(BlockInstance block) {
    final dest = block.literals['name'] as String?;
    final from = (block.literals['from'] ?? block.literals['src']) as String?;
    if (dest == null || from == null) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    if (!env.containsKey(dest) || !env.containsKey(from)) {
      _err('undefined_variable', 'This variable is not defined.', block.id);
      return null;
    }
    final fromType = _read(from, block.id)!;
    if (!_fitsVariable(env[dest]!, fromType, block.id)) return null;
    return AssignStmt(
      target: VarLValue(dest, srcBlockId: block.id),
      value: VarExpr(from, type: fromType, srcBlockId: block.id),
      srcBlockId: block.id,
    );
  }

  /// SWAP / COPY write a variable without a value hole: the value must still
  /// fit the variable, and one that may be empty needs a check first.
  bool _fitsVariable(ValueType declared, ValueType value, String blockId) {
    if (_fitsHole(declared, value)) return true;
    if (Narrowing.onlyMayBeEmpty(value, (t) => _fitsHole(declared, t))) {
      _err('may_be_empty', Narrowing.mayBeEmptyMessage, blockId);
    } else {
      _err('type_mismatch', 'This piece does not fit here.', blockId);
    }
    return false;
  }

  AssignStmt? _arrSet(BlockInstance block) {
    final array = _reqExpr(block.id, 'array');
    final index = _reqExpr(block.id, 'index', expect: ValueType.number);
    if (array == null || index == null) return null;
    if (array.type.atom != TypeAtom.array) {
      _err('type_mismatch', 'This block needs a list.', block.id, 'array');
      return null;
    }
    final elem = array.type.param ?? ValueType.t;
    final value = _reqExpr(
      block.id,
      'value',
      expect: elem.isGeneric ? null : elem,
    );
    if (value == null) return null;
    return AssignStmt(
      target: IndexLValue(array, index, srcBlockId: block.id),
      value: value,
      srcBlockId: block.id,
    );
  }

  AssignStmt? _fieldAssign(
    BlockInstance block,
    String field,
    String objectPort,
    String valuePort,
  ) {
    final object = _reqExpr(block.id, objectPort);
    final value = _reqExpr(block.id, valuePort);
    if (object == null || value == null) return null;
    return AssignStmt(
      target: FieldLValue(object, field, srcBlockId: block.id),
      value: value,
      srcBlockId: block.id,
    );
  }

  ExprStmt? _callStmt(BlockInstance block) {
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) {
      _err('unknown_block', 'Unknown block.', block.id);
      return null;
    }
    final args = <Expr>[];
    for (final port in def.inputs.where((p) => p.isExpr)) {
      final arg = _reqExpr(block.id, port.name);
      if (arg == null) return null;
      args.add(arg);
    }
    return ExprStmt(
      CallExpr(
        block.catalogId,
        args,
        type: ValueType.voidType,
        srcBlockId: block.id,
      ),
      srcBlockId: block.id,
    );
  }

  List<Stmt> _stmts(String parentId, String port) {
    final out = <Stmt>[];
    for (final id in graph.slotList(parentId, port)) {
      final stmt = _stmt(id);
      if (stmt != null) out.add(stmt);
    }
    return out;
  }

  Expr? _optExpr(String parentId, String port, {ValueType? expect}) {
    final ids = graph.slotList(parentId, port);
    if (ids.isEmpty) return null;
    return _reqExpr(parentId, port, expect: expect);
  }

  Expr? _reqExpr(String parentId, String port, {ValueType? expect}) {
    final ids = graph.slotList(parentId, port);
    if (ids.isEmpty) {
      _err('missing_expr', _holeMessage(port), parentId, port);
      return null;
    }
    final expr = _expr(ids.first);
    if (expr == null) return null;
    final hole = expect ??
        GraphTyping.resolveInput(graph, PortRef(parentId, port));
    if (hole != null && !_fitsHole(hole, expr.type)) {
      if (Narrowing.onlyMayBeEmpty(expr.type, (t) => _fitsHole(hole, t))) {
        _err('may_be_empty', Narrowing.mayBeEmptyMessage, parentId, port);
      } else {
        _err('type_mismatch', _holeMessage(port), parentId, port);
      }
      return null;
    }
    return expr;
  }

  /// Catalog hole vs plugged value. Generics (`T`, `array<T>`) unify; a
  /// concrete mismatch fails rather than producing an untyped Program.
  bool _fitsHole(ValueType hole, ValueType plug) {
    if (hole.isGeneric || plug.isGeneric) return true;
    if (plug.atom == TypeAtom.nil) return hole.nullable;
    if (hole.atom != plug.atom) return false;
    if (!hole.nullable && plug.nullable) return false;
    if (hole.param != null) {
      if (plug.param == null) return false;
      if (!_fitsHole(hole.param!, plug.param!)) return false;
    }
    if (hole.param2 != null) {
      if (plug.param2 == null) return false;
      if (!_fitsHole(hole.param2!, plug.param2!)) return false;
    }
    return true;
  }

  Expr? _expr(String id) {
    final block = graph.blocks[id];
    if (block == null) {
      _err('missing_block', 'A connection points at a missing block.', id);
      return null;
    }
    final cat = block.catalogId;
    try {
      final built = switch (cat) {
        BlockIds.litNum => _litNum(block),
        BlockIds.litBool => _litBool(block),
        BlockIds.litStr => _litStr(block),
        BlockIds.litNull => NullExpr(srcBlockId: id),
        BlockIds.varGet => _varGet(block),
        BlockIds.cmpEq => _binary(block, BinaryOp.eq, ValueType.boolean),
        BlockIds.cmpNe => _binary(block, BinaryOp.ne, ValueType.boolean),
        BlockIds.cmpLt => _binary(block, BinaryOp.lt, ValueType.boolean),
        BlockIds.cmpLe => _binary(block, BinaryOp.le, ValueType.boolean),
        BlockIds.cmpGt => _binary(block, BinaryOp.gt, ValueType.boolean),
        BlockIds.cmpGe => _binary(block, BinaryOp.ge, ValueType.boolean),
        BlockIds.logicAnd => _binary(block, BinaryOp.and, ValueType.boolean),
        BlockIds.logicOr => _binary(block, BinaryOp.or, ValueType.boolean),
        BlockIds.logicNot => _unary(block, UnaryOp.not, 'arg', ValueType.boolean),
        BlockIds.logicIsNothing => _nothingCheck(block, UnaryOp.isNothing),
        BlockIds.logicIsNotNothing =>
          _nothingCheck(block, UnaryOp.isNotNothing),
        BlockIds.arithAdd => _binary(block, BinaryOp.add, ValueType.number),
        BlockIds.arithSub => _binary(block, BinaryOp.sub, ValueType.number),
        BlockIds.arithMul => _binary(block, BinaryOp.mul, ValueType.number),
        BlockIds.arithDiv => _binary(block, BinaryOp.div, ValueType.number),
        BlockIds.arithFloorDiv =>
          _binary(block, BinaryOp.floorDiv, ValueType.number),
        BlockIds.arithMod => _binary(block, BinaryOp.mod, ValueType.number),
        BlockIds.arithMin => _binary(block, BinaryOp.min, ValueType.number),
        BlockIds.arithMax => _binary(block, BinaryOp.max, ValueType.number),
        BlockIds.arithAbs => _unary(block, UnaryOp.abs, 'arg', ValueType.number),
        BlockIds.arrGet => _index(block),
        BlockIds.llValue => _field(block, 'value', ValueType.number),
        BlockIds.llNext => _field(block, 'next', ValueType.listNode.asNullable),
        BlockIds.treeValue => _field(block, 'value', ValueType.number),
        BlockIds.treeLeft => _field(block, 'left', ValueType.treeNode.asNullable),
        BlockIds.treeRight =>
          _field(block, 'right', ValueType.treeNode.asNullable),
        BlockIds.newArray => _new(block, CollKind.array),
        BlockIds.newMap => _new(block, CollKind.map),
        BlockIds.newSet => _new(block, CollKind.set),
        BlockIds.newStack => _new(block, CollKind.stack),
        BlockIds.newQueue => _new(block, CollKind.queue),
        BlockIds.fnCall => _unsupportedExpr(block),
        _ => _callExpr(block),
      };
      return built;
    } on FormatException {
      _err(
        'malformed',
        'This program is not put together correctly.',
        id,
      );
      return null;
    }
  }

  Expr? _unsupportedExpr(BlockInstance block) {
    _err('unsupported', 'This piece cannot be used yet.', block.id);
    return null;
  }

  LitExpr? _litNum(BlockInstance block) {
    final raw = block.literals['value'] ?? 0;
    final n = raw is num ? raw : num.tryParse('$raw');
    if (n == null) {
      _err('malformed', 'This block needs a number.', block.id);
      return null;
    }
    return LitExpr(n, type: ValueType.number, srcBlockId: block.id);
  }

  LitExpr? _litBool(BlockInstance block) {
    final raw = block.literals['value'] ?? false;
    final v = raw == true || raw == 'true';
    return LitExpr(v, type: ValueType.boolean, srcBlockId: block.id);
  }

  LitExpr? _litStr(BlockInstance block) {
    final raw = block.literals['value'] ?? '';
    return LitExpr('$raw', type: ValueType.string, srcBlockId: block.id);
  }

  VarExpr? _varGet(BlockInstance block) {
    final name = block.literals['name'] as String?;
    if (name == null || name.isEmpty) {
      _err('undefined_variable', 'Choose a name.', block.id);
      return null;
    }
    final type = _read(name, block.id);
    if (type == null) {
      _err('undefined_variable', 'This variable is not defined.', block.id);
      return null;
    }
    return VarExpr(name, type: type, srcBlockId: block.id);
  }

  /// IS NOTHING / IS NOT NOTHING: a real check at runtime. Only a value that
  /// may be empty can be checked.
  UnaryExpr? _nothingCheck(BlockInstance block, UnaryOp op) {
    final arg = _reqExpr(block.id, 'value');
    if (arg == null) return null;
    final problem = Narrowing.checkProblem(arg.type);
    if (problem != null) {
      _err('type_mismatch', problem, block.id, 'value');
      return null;
    }
    return UnaryExpr(op, arg, type: ValueType.boolean, srcBlockId: block.id);
  }

  BinaryExpr? _binary(BlockInstance block, BinaryOp op, ValueType type) {
    final left = _reqExpr(block.id, 'left');
    final right = _reqExpr(block.id, 'right');
    if (left == null || right == null) return null;
    return BinaryExpr(op, left, right, type: type, srcBlockId: block.id);
  }

  UnaryExpr? _unary(
    BlockInstance block,
    UnaryOp op,
    String port,
    ValueType type,
  ) {
    final arg = _reqExpr(block.id, port);
    if (arg == null) return null;
    return UnaryExpr(op, arg, type: type, srcBlockId: block.id);
  }

  IndexExpr? _index(BlockInstance block) {
    final array = _reqExpr(block.id, 'array');
    final index = _reqExpr(block.id, 'index', expect: ValueType.number);
    if (array == null || index == null) return null;
    if (array.type.atom != TypeAtom.array) {
      _err('type_mismatch', 'This block needs a list.', block.id, 'array');
      return null;
    }
    final elem = array.type.param ?? ValueType.t;
    if (elem.isGeneric) {
      _err('type_mismatch', 'This block needs a list.', block.id, 'array');
      return null;
    }
    return IndexExpr(array, index, type: elem, srcBlockId: block.id);
  }

  FieldExpr? _field(BlockInstance block, String field, ValueType type) {
    final object = _reqExpr(block.id, 'node');
    if (object == null) return null;
    return FieldExpr(object, field, type: type, srcBlockId: block.id);
  }

  NewExpr? _new(BlockInstance block, CollKind kind) {
    final resolved = GraphTyping.resolveOutput(graph, block.id);
    ValueType type;
    if (resolved != null && !resolved.isGeneric) {
      type = resolved;
    } else {
      final of = block.literals['of'] as String?;
      if (of == null) {
        _err(
          'type_mismatch',
          'This piece does not fit here.',
          block.id,
        );
        return null;
      }
      try {
        final inner = parseValueType(of);
        type = switch (kind) {
          CollKind.array => ValueType.array(inner),
          CollKind.set => ValueType.setOf(inner),
          CollKind.stack => ValueType.stackOf(inner),
          CollKind.queue => ValueType.queueOf(inner),
          CollKind.deque => ValueType.dequeOf(inner),
          CollKind.map => ValueType.mapOf(ValueType.string, inner),
        };
      } on FormatException {
        _err('malformed', 'This program is not put together correctly.', block.id);
        return null;
      }
    }
    return NewExpr(kind, type: type, srcBlockId: block.id);
  }

  CallExpr? _callExpr(BlockInstance block) {
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) {
      _err('unknown_block', 'Unknown block.', block.id);
      return null;
    }
    if (def.role != BlockRole.expression) {
      _err(
        'wrong_kind',
        'This spot needs a value, not a full instruction.',
        block.id,
      );
      return null;
    }
    final args = <Expr>[];
    for (final port in def.inputs.where((p) => p.isExpr)) {
      final arg = _reqExpr(block.id, port.name);
      if (arg == null) return null;
      args.add(arg);
    }
    final type = GraphTyping.resolveOutput(graph, block.id);
    if (type == null || type.isGeneric) {
      _err('type_mismatch', 'This piece does not fit here.', block.id);
      return null;
    }
    return CallExpr(
      block.catalogId,
      args,
      type: type,
      srcBlockId: block.id,
    );
  }

  void _err(String code, String message, [String? blockId, String? port]) {
    errors.add(ValidationMessage(
      code: code,
      message: message,
      blockId: blockId,
      port: port,
    ));
  }

  String _holeMessage(String port) {
    return switch (port) {
      'condition' => 'This block needs a condition.',
      'index' || 'i' || 'j' || 'start' || 'end' || 'step' =>
        'This block needs a number.',
      'array' || 'collection' => 'This block needs a list.',
      'map' => 'This block needs a map.',
      'set' => 'This block needs a set.',
      'stack' => 'This block needs a stack.',
      'queue' => 'This block needs a queue.',
      // MS13: an empty value slot said "does not fit" — it is simply empty.
      'value' || 'left' || 'right' || 'arg' => 'This block needs a value.',
      'key' => 'This block needs a key.',
      'node' || 'next' => 'This block needs a node.',
      'graph' => 'This block needs a graph.',
      _ => 'This piece does not fit here.',
    };
  }
}
