import '../ast/ir.dart';
import '../blocks/catalog.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../types/value_type.dart';
import 'engine.dart';
import 'result_kind.dart';
import 'run_result.dart';

/// Run [program] over [input] under [limits]. A fresh [Interpreter] is used
/// for every run, so nothing carries over between runs.
RunResult runProgram(
  Program program,
  Map<String, RuntimeValue> input,
  RunLimits limits, {
  TraceSink? trace,
}) {
  return Interpreter(program, limits: limits, trace: trace).run(input);
}

/// Sandboxed, deterministic tree-walking interpreter for the Milestone 4 IR.
///
/// No `eval`, no codegen, no host I/O, no clock, no randomness: the same
/// [Program] and the same input always produce the same [RunResult]. Map and
/// set iteration is insertion ordered.
///
/// Budgets are the grading surface, not a static Big-O analyzer:
///
/// * **ops** — one per executed block. A loop header costs one op per
///   iteration. `seq` and the statement wrapper around a call are lowering
///   artifacts and cost nothing, so no block pays twice.
/// * **alloc** — live collection cells. Creating a container costs one cell,
///   each stored element costs one, and removing an element gives it back.
/// * **depth** — function frames. Only recursion nests.
///
/// Failures are game-facing and carry the `srcBlockId` of the block that
/// failed, never compiler jargon.
final class Interpreter {
  Interpreter(
    this.program, {
    this.limits = RunLimits.standard,
    this.trace,
  });

  final Program program;
  final RunLimits limits;
  final TraceSink? trace;

  /// Structural guard so a pathological IR cannot overflow the Dart stack
  /// before a budget stops it.
  static const _maxNesting = 2048;

  int _ops = 0;
  int _liveAlloc = 0;
  int _peakAlloc = 0;
  int _depth = 0;
  int _peakDepth = 0;
  int _nesting = 0;
  int _nextId = 1;

  /// Execute the entry function. Never throws: every failure comes back as a
  /// [RunResult]. [ResultKind.correct] means "ran to completion" — comparing
  /// the output against what a puzzle expects is the test runner's job.
  RunResult run(Map<String, RuntimeValue> input) {
    final entry = program.function(program.entry);
    if (entry == null) {
      return RunResult(
        kind: ResultKind.invalidProgram,
        metrics: _metrics(),
        message: 'This program has no starting point.',
      );
    }
    try {
      final output = _invoke(entry, input, isEntry: true);
      return RunResult(
        kind: ResultKind.correct,
        metrics: _metrics(),
        output: output,
      );
    } on _Halt catch (halt) {
      return RunResult(
        kind: halt.kind,
        metrics: _metrics(),
        message: halt.message,
        blockId: halt.blockId,
      );
    }
  }

  RunMetrics _metrics() => RunMetrics(
        ops: _ops,
        peakAlloc: _peakAlloc,
        peakDepth: _peakDepth,
      );

  // --- frames -------------------------------------------------------------

  RuntimeValue _invoke(
    FnDecl fn,
    Map<String, RuntimeValue> args, {
    bool isEntry = false,
  }) {
    _depth++;
    if (_depth > limits.maxDepth) {
      _depth--;
      throw _Halt(
        ResultKind.depthLimit,
        'This program went too many levels deep.',
        fn.srcBlockId,
      );
    }
    if (_depth > _peakDepth) _peakDepth = _depth;
    try {
      final vars = <String, RuntimeValue>{};
      for (final param in fn.params) {
        final value = args[param.name];
        if (value == null) {
          throw _Halt(
            ResultKind.invalidProgram,
            'This program did not get a value for ${param.name}.',
            fn.srcBlockId,
          );
        }
        // Given values are copied so a run can never mutate fixtures the test
        // runner reuses across cases.
        vars[param.name] = isEntry ? _copy(value, {}) : value;
      }
      if (isEntry) {
        for (final entry in args.entries) {
          vars.putIfAbsent(entry.key, () => _copy(entry.value, {}));
        }
      }
      try {
        _execAll(fn.body, vars);
        return const NilValue();
      } on _Return catch (signal) {
        return signal.value;
      } on _Loop catch (signal) {
        throw _Halt(
          ResultKind.invalidProgram,
          'This block only works inside a loop.',
          signal.blockId,
        );
      }
    } finally {
      _depth--;
    }
  }

  // --- statements ---------------------------------------------------------

  void _execAll(List<Stmt> body, Map<String, RuntimeValue> vars) {
    for (final stmt in body) {
      _exec(stmt, vars);
    }
  }

  void _exec(Stmt stmt, Map<String, RuntimeValue> vars) {
    _enter(stmt.srcBlockId);
    try {
      switch (stmt) {
        case final SeqStmt s:
          _execAll(s.stmts, vars);
        case final ExprStmt s:
          _eval(s.expr, vars);
        case final IfStmt s:
          _tick(s.srcBlockId);
          _emit('if', s.srcBlockId, vars);
          if (_bool(_eval(s.cond, vars), s.cond.srcBlockId)) {
            _execAll(s.thenBody, vars);
          } else {
            final otherwise = s.elseBody;
            if (otherwise != null) _execAll(otherwise, vars);
          }
        case final WhileStmt s:
          while (true) {
            _tick(s.srcBlockId);
            _emit('while', s.srcBlockId, vars);
            if (!_bool(_eval(s.cond, vars), s.cond.srcBlockId)) break;
            if (_loopBody(s.body, vars)) break;
          }
        case final ForRangeStmt s:
          _execForRange(s, vars);
        case final ForEachStmt s:
          _execForEach(s, vars);
        case final BreakStmt s:
          _tick(s.srcBlockId);
          throw _Loop(isBreak: true, blockId: s.srcBlockId);
        case final ContinueStmt s:
          _tick(s.srcBlockId);
          throw _Loop(isBreak: false, blockId: s.srcBlockId);
        case final ReturnStmt s:
          _tick(s.srcBlockId);
          _emit('return', s.srcBlockId, vars);
          final value = s.value;
          throw _Return(value == null ? const NilValue() : _eval(value, vars));
        case final AssignStmt s:
          _tick(s.srcBlockId);
          _assign(s.target, _eval(s.value, vars), vars);
          _emit('assign', s.srcBlockId, vars);
        case final IncStmt s:
          _step(s.target, 1, s.srcBlockId, vars);
        case final DecStmt s:
          _step(s.target, -1, s.srcBlockId, vars);
      }
    } finally {
      _nesting--;
    }
  }

  void _execForRange(ForRangeStmt s, Map<String, RuntimeValue> vars) {
    _tick(s.srcBlockId);
    final start = _num(_eval(s.start, vars), s.start.srcBlockId);
    final end = _num(_eval(s.end, vars), s.end.srcBlockId);
    final stepExpr = s.step;
    final step =
        stepExpr == null ? 1 : _num(_eval(stepExpr, vars), stepExpr.srcBlockId);
    if (step == 0) {
      throw _Halt(
        ResultKind.runtimeError,
        'This loop would never finish.',
        s.srcBlockId,
      );
    }
    var cursor = start;
    while (step > 0 ? cursor < end : cursor > end) {
      _tick(s.srcBlockId);
      // The counter belongs to the loop: changing the loop variable inside
      // the body cannot change how many times it runs.
      vars[s.loopVar] = NumValue(cursor);
      _emit('forRange', s.srcBlockId, vars);
      if (_loopBody(s.body, vars)) break;
      cursor += step;
    }
  }

  void _execForEach(ForEachStmt s, Map<String, RuntimeValue> vars) {
    _tick(s.srcBlockId);
    // Snapshot: appending to the collection inside the loop does not extend
    // the iteration.
    final items = _iterable(_eval(s.collection, vars), s.collection.srcBlockId);
    final indexVar = s.indexVar;
    for (var index = 0; index < items.length; index++) {
      _tick(s.srcBlockId);
      vars[s.itemVar] = items[index];
      if (indexVar != null) vars[indexVar] = NumValue(index);
      _emit('forEach', s.srcBlockId, vars);
      if (_loopBody(s.body, vars)) break;
    }
  }

  /// Runs a loop body. Returns `true` when the body asked to break out.
  bool _loopBody(List<Stmt> body, Map<String, RuntimeValue> vars) {
    try {
      _execAll(body, vars);
    } on _Loop catch (signal) {
      return signal.isBreak;
    }
    return false;
  }

  void _step(
    LValue target,
    int delta,
    String? blockId,
    Map<String, RuntimeValue> vars,
  ) {
    _tick(blockId);
    final current = _num(_read(target, vars, blockId), blockId);
    _assign(target, NumValue(current + delta), vars);
    _emit(delta > 0 ? 'inc' : 'dec', blockId, vars);
  }

  // --- targets ------------------------------------------------------------

  RuntimeValue _read(
    LValue target,
    Map<String, RuntimeValue> vars,
    String? blockId,
  ) {
    return switch (target) {
      final VarLValue t => _lookup(t.name, t.srcBlockId ?? blockId, vars),
      final IndexLValue t => _indexRead(
          _eval(t.collection, vars),
          _eval(t.index, vars),
          t.srcBlockId ?? blockId,
        ),
      final FieldLValue t => _fieldRead(
          _eval(t.object, vars),
          t.field,
          t.srcBlockId ?? blockId,
        ),
    };
  }

  void _assign(
    LValue target,
    RuntimeValue value,
    Map<String, RuntimeValue> vars,
  ) {
    switch (target) {
      case final VarLValue t:
        vars[t.name] = value;
      case final IndexLValue t:
        _indexWrite(
          _eval(t.collection, vars),
          _eval(t.index, vars),
          value,
          t.srcBlockId,
        );
      case final FieldLValue t:
        _fieldWrite(_eval(t.object, vars), t.field, value, t.srcBlockId);
    }
  }

  // --- expressions --------------------------------------------------------

  RuntimeValue _eval(Expr expr, Map<String, RuntimeValue> vars) {
    _enter(expr.srcBlockId);
    try {
      _tick(expr.srcBlockId);
      return switch (expr) {
        final LitExpr e => _literal(e),
        NullExpr() => const NilValue(),
        final VarExpr e => _lookup(e.name, e.srcBlockId, vars),
        final BinaryExpr e => _binary(e, vars),
        final UnaryExpr e => _unary(e, vars),
        final IndexExpr e => _indexRead(
            _eval(e.collection, vars),
            _eval(e.index, vars),
            e.srcBlockId,
          ),
        final FieldExpr e => _fieldRead(
            _eval(e.object, vars),
            e.field,
            e.srcBlockId,
          ),
        final NewExpr e => _construct(e),
        final CallExpr e => _call(e, vars),
      };
    } finally {
      _nesting--;
    }
  }

  RuntimeValue _literal(LitExpr expr) {
    final value = expr.value;
    return switch (value) {
      null => const NilValue(),
      final num n => NumValue(n),
      final bool b => BoolValue(b),
      final String s => StrValue(s),
      _ => throw _Halt(
          ResultKind.invalidProgram,
          'This value cannot be used here.',
          expr.srcBlockId,
        ),
    };
  }

  RuntimeValue _lookup(
    String name,
    String? blockId,
    Map<String, RuntimeValue> vars,
  ) {
    final value = vars[name];
    if (value == null) {
      throw _Halt(ResultKind.runtimeError, 'This name has no value yet.', blockId);
    }
    return value;
  }

  RuntimeValue _binary(BinaryExpr expr, Map<String, RuntimeValue> vars) {
    // AND / OR short-circuit, so the right side is neither evaluated nor
    // charged when the left side already decides the answer.
    if (expr.op == BinaryOp.and || expr.op == BinaryOp.or) {
      final left = _bool(_eval(expr.left, vars), expr.left.srcBlockId);
      if (expr.op == BinaryOp.and && !left) return const BoolValue(false);
      if (expr.op == BinaryOp.or && left) return const BoolValue(true);
      return BoolValue(_bool(_eval(expr.right, vars), expr.right.srcBlockId));
    }
    final left = _eval(expr.left, vars);
    final right = _eval(expr.right, vars);
    if (expr.op == BinaryOp.eq) return BoolValue(_same(left, right));
    if (expr.op == BinaryOp.ne) return BoolValue(!_same(left, right));
    final id = expr.srcBlockId;
    final a = _num(left, expr.left.srcBlockId ?? id);
    final b = _num(right, expr.right.srcBlockId ?? id);
    return switch (expr.op) {
      BinaryOp.add => NumValue(a + b),
      BinaryOp.sub => NumValue(a - b),
      BinaryOp.mul => NumValue(a * b),
      BinaryOp.div => NumValue(_divide(a, b, id)),
      BinaryOp.mod => NumValue(_modulo(a, b, id)),
      BinaryOp.min => NumValue(a < b ? a : b),
      BinaryOp.max => NumValue(a > b ? a : b),
      BinaryOp.lt => BoolValue(a < b),
      BinaryOp.le => BoolValue(a <= b),
      BinaryOp.gt => BoolValue(a > b),
      BinaryOp.ge => BoolValue(a >= b),
      BinaryOp.and || BinaryOp.or || BinaryOp.eq || BinaryOp.ne =>
        throw StateError('short-circuit and equality are handled above'),
    };
  }

  /// Whole results stay whole: `4 / 2` is `2`, `3 / 2` is `1.5`.
  num _divide(num a, num b, String? blockId) {
    if (b == 0) {
      throw _Halt(ResultKind.runtimeError, 'You cannot divide by zero.', blockId);
    }
    if (a is int && b is int && a % b == 0) return a ~/ b;
    return a / b;
  }

  num _modulo(num a, num b, String? blockId) {
    if (b == 0) {
      throw _Halt(ResultKind.runtimeError, 'You cannot divide by zero.', blockId);
    }
    return a % b;
  }

  RuntimeValue _unary(UnaryExpr expr, Map<String, RuntimeValue> vars) {
    final arg = _eval(expr.arg, vars);
    final id = expr.arg.srcBlockId ?? expr.srcBlockId;
    return switch (expr.op) {
      UnaryOp.not => BoolValue(!_bool(arg, id)),
      UnaryOp.neg => NumValue(-_num(arg, id)),
      UnaryOp.abs => NumValue(_num(arg, id).abs()),
    };
  }

  /// Equality a player can predict: numbers, text, yes/no and empty compare by
  /// value; a list, map, set, node or graph is only equal to itself.
  bool _same(RuntimeValue a, RuntimeValue b) {
    if (a is NilValue || b is NilValue) return a is NilValue && b is NilValue;
    if (a is NumValue && b is NumValue) return a.value == b.value;
    if (a is StrValue && b is StrValue) return a.value == b.value;
    if (a is BoolValue && b is BoolValue) return a.value == b.value;
    return identical(a, b);
  }

  RuntimeValue _construct(NewExpr expr) {
    _alloc(1, expr.srcBlockId);
    final type = expr.type;
    final id = _nextId++;
    return switch (expr.kind) {
      CollKind.array =>
        ArrayValue([], id: id, elementType: type.param ?? ValueType.number),
      CollKind.map => MapValue(
          {},
          id: id,
          keyType: type.param ?? ValueType.string,
          valueType: type.param2 ?? ValueType.number,
        ),
      CollKind.set =>
        SetValue({}, id: id, elementType: type.param ?? ValueType.number),
      CollKind.stack =>
        StackValue([], id: id, elementType: type.param ?? ValueType.number),
      CollKind.queue =>
        QueueValue([], id: id, elementType: type.param ?? ValueType.number),
      CollKind.deque =>
        DequeValue([], id: id, elementType: type.param ?? ValueType.number),
    };
  }

  // --- calls --------------------------------------------------------------

  RuntimeValue _call(CallExpr expr, Map<String, RuntimeValue> vars) {
    final id = expr.srcBlockId;
    if (expr.callee == BlockIds.varSwap) return _swapNames(expr, vars);

    // A callee that names a function in this program is a real call. Player
    // defined functions arrive in a later milestone; the path is here so the
    // VM does not have to change when they do.
    final fn = program.function(expr.callee);
    if (fn != null) {
      if (expr.args.length < fn.params.length) {
        throw _Halt(ResultKind.invalidProgram, 'This call is missing a value.', id);
      }
      return _invoke(fn, {
        for (var i = 0; i < fn.params.length; i++)
          fn.params[i].name: _eval(expr.args[i], vars),
      });
    }

    final args = [for (final arg in expr.args) _eval(arg, vars)];
    RuntimeValue at(int index) {
      if (index >= args.length) {
        throw _Halt(ResultKind.invalidProgram, 'This block is missing a value.', id);
      }
      return args[index];
    }

    switch (expr.callee) {
      case BlockIds.arrLen:
        return NumValue(_array(at(0), id).elements.length);
      case BlockIds.arrAppend:
        {
          final array = _array(at(0), id);
          if (array.elements.length >= limits.maxArrayLen) {
            throw _Halt(ResultKind.memoryLimit, 'This list got too big.', id);
          }
          _alloc(1, id);
          array.elements.add(at(1));
          return const NilValue();
        }
      case BlockIds.arrRemove:
        {
          final array = _array(at(0), id);
          array.elements.removeAt(_position(at(1), array.elements.length, id));
          _free(1);
          return const NilValue();
        }
      case BlockIds.arrSwap:
        {
          final array = _array(at(0), id);
          final i = _position(at(1), array.elements.length, id);
          final j = _position(at(2), array.elements.length, id);
          final held = array.elements[i];
          array.elements[i] = array.elements[j];
          array.elements[j] = held;
          return const NilValue();
        }
      case BlockIds.mapGet:
        return _map(at(0), id).entries[_key(at(1), id)] ?? const NilValue();
      case BlockIds.mapSet:
        {
          final map = _map(at(0), id);
          final key = _key(at(1), id);
          if (!map.entries.containsKey(key)) {
            if (map.entries.length >= limits.maxMapSize) {
              throw _Halt(ResultKind.memoryLimit, 'This map got too big.', id);
            }
            _alloc(1, id);
          }
          map.entries[key] = at(2);
          return const NilValue();
        }
      case BlockIds.mapHas:
        return BoolValue(_map(at(0), id).entries.containsKey(_key(at(1), id)));
      case BlockIds.mapRemove:
        {
          final map = _map(at(0), id);
          if (map.entries.remove(_key(at(1), id)) != null) _free(1);
          return const NilValue();
        }
      case BlockIds.mapSize:
        return NumValue(_map(at(0), id).entries.length);
      case BlockIds.setAdd:
        {
          final set = _set(at(0), id);
          final key = _key(at(1), id);
          if (!set.members.containsKey(key)) {
            if (set.members.length >= limits.maxMapSize) {
              throw _Halt(ResultKind.memoryLimit, 'This set got too big.', id);
            }
            _alloc(1, id);
            set.members[key] = at(1);
          }
          return const NilValue();
        }
      case BlockIds.setHas:
        return BoolValue(_set(at(0), id).members.containsKey(_key(at(1), id)));
      case BlockIds.setRemove:
        {
          final set = _set(at(0), id);
          if (set.members.remove(_key(at(1), id)) != null) _free(1);
          return const NilValue();
        }
      case BlockIds.setSize:
        return NumValue(_set(at(0), id).members.length);
      case BlockIds.stackPush:
        {
          final stack = _stack(at(0), id);
          if (stack.items.length >= limits.maxArrayLen) {
            throw _Halt(ResultKind.memoryLimit, 'This stack got too big.', id);
          }
          _alloc(1, id);
          stack.items.add(at(1));
          return const NilValue();
        }
      case BlockIds.stackPop:
        {
          final stack = _stack(at(0), id);
          if (stack.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This stack is empty.', id);
          }
          _free(1);
          return stack.items.removeLast();
        }
      case BlockIds.stackPeek:
        {
          final stack = _stack(at(0), id);
          if (stack.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This stack is empty.', id);
          }
          return stack.items.last;
        }
      case BlockIds.stackEmpty:
        return BoolValue(_stack(at(0), id).items.isEmpty);
      case BlockIds.queueEnq:
        {
          final queue = _queue(at(0), id);
          if (queue.items.length >= limits.maxArrayLen) {
            throw _Halt(ResultKind.memoryLimit, 'This queue got too big.', id);
          }
          _alloc(1, id);
          queue.items.add(at(1));
          return const NilValue();
        }
      case BlockIds.queueDeq:
        {
          final queue = _queue(at(0), id);
          if (queue.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This queue is empty.', id);
          }
          _free(1);
          return queue.items.removeAt(0);
        }
      case BlockIds.queueFront:
        {
          final queue = _queue(at(0), id);
          if (queue.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This queue is empty.', id);
          }
          return queue.items.first;
        }
      case BlockIds.queueEmpty:
        return BoolValue(_queue(at(0), id).items.isEmpty);
      case BlockIds.graphNeighbors:
        {
          final graph = _graph(at(0), id);
          final node = _num(at(1), id);
          final neighbors = graph.adjacency[node] ?? const <num>[];
          _alloc(1 + neighbors.length, id);
          return ArrayValue(
            [for (final n in neighbors) NumValue(n)],
            id: _nextId++,
          );
        }
      case BlockIds.graphMark:
        _graph(at(0), id).visited.add(_num(at(1), id));
        return const NilValue();
      case BlockIds.graphVisited:
        return BoolValue(_graph(at(0), id).visited.contains(_num(at(1), id)));
      case BlockIds.graphNodeCount:
        return NumValue(_graph(at(0), id).adjacency.length);
      default:
        throw _Halt(
          ResultKind.invalidProgram,
          'This block cannot run yet.',
          id,
        );
    }
  }

  RuntimeValue _swapNames(CallExpr expr, Map<String, RuntimeValue> vars) {
    final id = expr.srcBlockId;
    if (expr.args.length != 2) {
      throw _Halt(ResultKind.invalidProgram, 'This block is missing a name.', id);
    }
    final first = expr.args[0];
    final second = expr.args[1];
    if (first is! VarExpr || second is! VarExpr) {
      throw _Halt(
        ResultKind.invalidProgram,
        'This block can only swap two names.',
        id,
      );
    }
    final held = _lookup(first.name, id, vars);
    vars[first.name] = _lookup(second.name, id, vars);
    vars[second.name] = held;
    return const NilValue();
  }

  // --- collections and nodes ----------------------------------------------

  RuntimeValue _indexRead(
    RuntimeValue collection,
    RuntimeValue index,
    String? blockId,
  ) {
    if (collection is ArrayValue) {
      return collection.elements[
          _position(index, collection.elements.length, blockId)];
    }
    if (collection is MapValue) {
      return collection.entries[_key(index, blockId)] ?? const NilValue();
    }
    throw _Halt(ResultKind.runtimeError, 'This block needs a list.', blockId);
  }

  void _indexWrite(
    RuntimeValue collection,
    RuntimeValue index,
    RuntimeValue value,
    String? blockId,
  ) {
    if (collection is ArrayValue) {
      collection.elements[_position(index, collection.elements.length, blockId)] =
          value;
      return;
    }
    if (collection is MapValue) {
      final key = _key(index, blockId);
      if (!collection.entries.containsKey(key)) {
        if (collection.entries.length >= limits.maxMapSize) {
          throw _Halt(ResultKind.memoryLimit, 'This map got too big.', blockId);
        }
        _alloc(1, blockId);
      }
      collection.entries[key] = value;
      return;
    }
    throw _Halt(ResultKind.runtimeError, 'This block needs a list.', blockId);
  }

  RuntimeValue _fieldRead(RuntimeValue object, String field, String? blockId) {
    if (object is NilValue) {
      throw _Halt(ResultKind.runtimeError, 'There is nothing here.', blockId);
    }
    if (object is ListNodeValue) {
      return switch (field) {
        'value' => NumValue(object.value),
        'next' => object.next ?? const NilValue(),
        _ => throw _Halt(
            ResultKind.invalidProgram,
            'This block cannot run yet.',
            blockId,
          ),
      };
    }
    if (object is TreeNodeValue) {
      return switch (field) {
        'value' => NumValue(object.value),
        'left' => object.left ?? const NilValue(),
        'right' => object.right ?? const NilValue(),
        _ => throw _Halt(
            ResultKind.invalidProgram,
            'This block cannot run yet.',
            blockId,
          ),
      };
    }
    throw _Halt(ResultKind.runtimeError, 'This block needs a node.', blockId);
  }

  void _fieldWrite(
    RuntimeValue object,
    String field,
    RuntimeValue value,
    String? blockId,
  ) {
    if (object is NilValue) {
      throw _Halt(ResultKind.runtimeError, 'There is nothing here.', blockId);
    }
    if (object is ListNodeValue) {
      switch (field) {
        case 'value':
          object.value = _num(value, blockId);
          return;
        case 'next':
          object.next = _optionalNode<ListNodeValue>(value, blockId);
          return;
      }
    }
    if (object is TreeNodeValue) {
      switch (field) {
        case 'value':
          object.value = _num(value, blockId);
          return;
        case 'left':
          object.left = _optionalNode<TreeNodeValue>(value, blockId);
          return;
        case 'right':
          object.right = _optionalNode<TreeNodeValue>(value, blockId);
          return;
      }
    }
    throw _Halt(ResultKind.runtimeError, 'This block needs a node.', blockId);
  }

  T? _optionalNode<T extends RuntimeValue>(RuntimeValue value, String? blockId) {
    if (value is NilValue) return null;
    if (value is T) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a node.', blockId);
  }

  List<RuntimeValue> _iterable(RuntimeValue value, String? blockId) {
    return switch (value) {
      ArrayValue(:final elements) => List.of(elements),
      SetValue(:final members) => List.of(members.values),
      StackValue(:final items) => List.of(items),
      QueueValue(:final items) => List.of(items),
      DequeValue(:final items) => List.of(items),
      _ => throw _Halt(
          ResultKind.runtimeError,
          'This block needs a list.',
          blockId,
        ),
    };
  }

  // --- coercions ----------------------------------------------------------

  bool _bool(RuntimeValue value, String? blockId) {
    if (value is BoolValue) return value.value;
    throw _Halt(
      ResultKind.runtimeError,
      'This block needs a yes or no value.',
      blockId,
    );
  }

  num _num(RuntimeValue value, String? blockId) {
    if (value is NumValue) return value.value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a number.', blockId);
  }

  ArrayValue _array(RuntimeValue value, String? blockId) {
    if (value is ArrayValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a list.', blockId);
  }

  MapValue _map(RuntimeValue value, String? blockId) {
    if (value is MapValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a map.', blockId);
  }

  SetValue _set(RuntimeValue value, String? blockId) {
    if (value is SetValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a set.', blockId);
  }

  StackValue _stack(RuntimeValue value, String? blockId) {
    if (value is StackValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a stack.', blockId);
  }

  QueueValue _queue(RuntimeValue value, String? blockId) {
    if (value is QueueValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a queue.', blockId);
  }

  GraphValue _graph(RuntimeValue value, String? blockId) {
    if (value is GraphValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a graph.', blockId);
  }

  Object _key(RuntimeValue value, String? blockId) {
    final key = primitiveKey(value);
    if (key == null) {
      throw _Halt(
        ResultKind.runtimeError,
        'This block needs a number, some text, or a yes or no value as the key.',
        blockId,
      );
    }
    return key;
  }

  int _position(RuntimeValue value, int length, String? blockId) {
    final raw = _num(value, blockId);
    if (raw % 1 != 0) {
      throw _Halt(
        ResultKind.runtimeError,
        'A position has to be a whole number.',
        blockId,
      );
    }
    final index = raw.toInt();
    if (index < 0 || index >= length) {
      throw _Halt(
        ResultKind.runtimeError,
        'That position is outside the list.',
        blockId,
      );
    }
    return index;
  }

  // --- budgets ------------------------------------------------------------

  void _enter(String? blockId) {
    _nesting++;
    if (_nesting > _maxNesting) {
      _nesting--;
      throw _Halt(
        ResultKind.runtimeError,
        'This program is nested too deeply.',
        blockId,
      );
    }
  }

  /// Budgets are checked before the step is taken, so the metrics report the
  /// work that actually happened, never the step that broke the budget.
  void _tick(String? blockId) {
    if (_ops >= limits.maxOps) {
      throw _Halt(
        ResultKind.operationLimit,
        'This program took too many steps.',
        blockId,
      );
    }
    _ops++;
  }

  void _alloc(int cells, String? blockId) {
    if (_liveAlloc + cells > limits.maxAlloc) {
      throw _Halt(
        ResultKind.memoryLimit,
        'This program used too much memory.',
        blockId,
      );
    }
    _liveAlloc += cells;
    if (_liveAlloc > _peakAlloc) _peakAlloc = _liveAlloc;
  }

  void _free(int cells) {
    _liveAlloc -= cells;
    if (_liveAlloc < 0) _liveAlloc = 0;
  }

  // --- trace --------------------------------------------------------------

  void _emit(String kind, String? blockId, Map<String, RuntimeValue> vars) {
    final sink = trace;
    if (sink == null) return;
    sink(TraceEvent(
      opIndex: _ops,
      kind: kind,
      blockId: blockId,
      locals: {
        for (final entry in vars.entries) entry.key: '${entry.value.toJson()}',
      },
    ));
  }

  // --- input copy ---------------------------------------------------------

  /// Deep copy of a given value. Cycles are preserved through [seen], and
  /// copying is free: the player did not allocate the input.
  RuntimeValue _copy(RuntimeValue value, Map<RuntimeValue, RuntimeValue> seen) {
    final existing = seen[value];
    if (existing != null) return existing;
    switch (value) {
      case NilValue() || NumValue() || BoolValue() || StrValue():
        return value;
      case final ArrayValue v:
        final copy =
            ArrayValue([], id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final item in v.elements) {
          copy.elements.add(_copy(item, seen));
        }
        return copy;
      case final MapValue v:
        final copy = MapValue(
          {},
          id: _nextId++,
          keyType: v.keyType,
          valueType: v.valueType,
        );
        seen[value] = copy;
        for (final entry in v.entries.entries) {
          copy.entries[entry.key] = _copy(entry.value, seen);
        }
        return copy;
      case final SetValue v:
        final copy = SetValue({}, id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final entry in v.members.entries) {
          copy.members[entry.key] = _copy(entry.value, seen);
        }
        return copy;
      case final StackValue v:
        final copy = StackValue([], id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final item in v.items) {
          copy.items.add(_copy(item, seen));
        }
        return copy;
      case final QueueValue v:
        final copy = QueueValue([], id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final item in v.items) {
          copy.items.add(_copy(item, seen));
        }
        return copy;
      case final DequeValue v:
        final copy = DequeValue([], id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final item in v.items) {
          copy.items.add(_copy(item, seen));
        }
        return copy;
      case final ListNodeValue v:
        final copy = ListNodeValue(v.value, id: _nextId++);
        seen[value] = copy;
        final next = v.next;
        if (next != null) copy.next = _copy(next, seen) as ListNodeValue;
        return copy;
      case final TreeNodeValue v:
        final copy = TreeNodeValue(v.value, id: _nextId++);
        seen[value] = copy;
        final left = v.left;
        final right = v.right;
        if (left != null) copy.left = _copy(left, seen) as TreeNodeValue;
        if (right != null) copy.right = _copy(right, seen) as TreeNodeValue;
        return copy;
      case final GraphValue v:
        final copy = GraphValue(
          {for (final entry in v.adjacency.entries) entry.key: List.of(entry.value)},
          visited: Set.of(v.visited),
          id: _nextId++,
        );
        seen[value] = copy;
        return copy;
    }
  }
}

/// A `return` travelling up to its function frame.
final class _Return implements Exception {
  const _Return(this.value);
  final RuntimeValue value;
}

/// A `break` or `continue` travelling up to its loop.
final class _Loop implements Exception {
  const _Loop({required this.isBreak, this.blockId});
  final bool isBreak;
  final String? blockId;
}

/// Execution stopped: a budget, a runtime failure, or a program the VM cannot
/// run. Carries the game-facing message and the block to highlight.
final class _Halt implements Exception {
  const _Halt(this.kind, this.message, this.blockId);
  final ResultKind kind;
  final String message;
  final String? blockId;

  @override
  String toString() => message;
}
