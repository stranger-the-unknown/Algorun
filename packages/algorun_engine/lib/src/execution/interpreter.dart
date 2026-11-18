import 'dart:collection';

import '../ast/ir.dart';
import '../blocks/catalog.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../runtime/whole_number.dart';
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

  // Trace only: the open frames, and whether the failure has been reported.
  // Nothing here is touched when [trace] is null.
  final List<TraceFrame> _frames = [];
  late final List<TraceFrame> _framesView = UnmodifiableListView(_frames);
  int _frameSerial = 0;
  bool _haltEmitted = false;

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
      _emitHalt(halt);
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
    final tracing = trace != null;
    var framed = false;
    try {
      final vars = <String, RuntimeValue>{};
      if (tracing) {
        _frames.add(TraceFrame(
          serial: ++_frameSerial,
          function: fn.name,
          blockId: fn.srcBlockId,
          vars: vars,
        ));
        framed = true;
      }
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
      if (tracing) {
        _emit(isEntry ? TraceKinds.start : TraceKinds.call, fn.srcBlockId, vars);
      }
      switch (_execAll(fn.body, vars)) {
        case final _Return signal:
          return signal.value;
        case final _Loop signal:
          throw _Halt(
            ResultKind.invalidProgram,
            'This block only works inside a loop.',
            signal.blockId,
          );
        case null:
          // A player FUNCTION that promises a value must RETURN one (L2).
          final promised = fn.returnType;
          if (!isEntry && promised != null && promised.atom != TypeAtom.voidType) {
            throw _Halt(ResultKind.runtimeError, 'FUNCTION ${fn.name} ended without RETURN.', fn.srcBlockId);
          }
          return const NilValue();
      }
    } on _Halt catch (halt) {
      // Reported from the innermost frame, while its names are still there.
      _emitHalt(halt);
      rethrow;
    } finally {
      if (framed) _frames.removeLast();
      _depth--;
    }
  }

  // --- statements ---------------------------------------------------------

  /// Runs [body] in order. Stops at the first RETURN, BREAK or CONTINUE and
  /// hands it up; `null` means the body ran to its end.
  _Flow? _execAll(List<Stmt> body, Map<String, RuntimeValue> vars) {
    for (final stmt in body) {
      final flow = _exec(stmt, vars);
      if (flow != null) return flow;
    }
    return null;
  }

  // RETURN, BREAK and CONTINUE travel up as values, not exceptions: a Dart
  // throw records the whole stack, which made every RETURN deep in a
  // recursion cost hundreds of microseconds.
  _Flow? _exec(Stmt stmt, Map<String, RuntimeValue> vars) {
    _enter(stmt.srcBlockId);
    try {
      switch (stmt) {
        case final SeqStmt s:
          return _execAll(s.stmts, vars);
        case final ExprStmt s:
          final value = _eval(s.expr, vars);
          _emit(TraceKinds.expr, s.srcBlockId ?? s.expr.srcBlockId, vars, value: value);
        case final IfStmt s:
          _tick(s.srcBlockId);
          final holds = _bool(_eval(s.cond, vars), s.cond.srcBlockId);
          _emit(TraceKinds.ifStep, s.srcBlockId, vars, flag: holds);
          if (holds) {
            return _execAll(s.thenBody, vars);
          } else {
            final otherwise = s.elseBody;
            if (otherwise != null) return _execAll(otherwise, vars);
          }
        case final WhileStmt s:
          while (true) {
            _tick(s.srcBlockId);
            final holds = _bool(_eval(s.cond, vars), s.cond.srcBlockId);
            _emit(TraceKinds.whileStep, s.srcBlockId, vars, flag: holds);
            if (!holds) break;
            final flow = _loopBody(s.body, vars);
            if (flow is _Return) return flow;
            if (flow != null) break;
          }
        case final ForRangeStmt s:
          return _execForRange(s, vars);
        case final ForEachStmt s:
          return _execForEach(s, vars);
        case final BreakStmt s:
          _tick(s.srcBlockId);
          _emit(TraceKinds.breakStep, s.srcBlockId, vars);
          return _Loop(isBreak: true, blockId: s.srcBlockId);
        case final ContinueStmt s:
          _tick(s.srcBlockId);
          _emit(TraceKinds.continueStep, s.srcBlockId, vars);
          return _Loop(isBreak: false, blockId: s.srcBlockId);
        case final ReturnStmt s:
          _tick(s.srcBlockId);
          final value = s.value;
          final result = value == null ? const NilValue() : _eval(value, vars);
          _emit(TraceKinds.returnStep, s.srcBlockId, vars, value: result);
          return _Return(result);
        case final AssignStmt s:
          _tick(s.srcBlockId);
          _assign(s.target, _eval(s.value, vars), vars);
          _emit(TraceKinds.assign, s.srcBlockId, vars);
        case final IncStmt s:
          _step(s.target, 1, s.srcBlockId, vars);
        case final DecStmt s:
          _step(s.target, -1, s.srcBlockId, vars);
      }
      return null;
    } finally {
      _nesting--;
    }
  }

  _Flow? _execForRange(ForRangeStmt s, Map<String, RuntimeValue> vars) {
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
    var cursor = start.toInt();
    while (step > 0 ? cursor < end : cursor > end) {
      _tick(s.srcBlockId);
      // The counter belongs to the loop: changing the loop variable inside
      // the body cannot change how many times it runs.
      vars[s.loopVar] = NumValue(cursor);
      _emit(TraceKinds.forRange, s.srcBlockId, vars);
      final flow = _loopBody(s.body, vars);
      if (flow is _Return) return flow;
      if (flow != null) return null;
      cursor = _add(cursor, step, s.srcBlockId);
    }
    _emit(TraceKinds.loopEnd, s.srcBlockId, vars);
    return null;
  }

  _Flow? _execForEach(ForEachStmt s, Map<String, RuntimeValue> vars) {
    _tick(s.srcBlockId);
    // Snapshot: appending to the collection inside the loop does not extend
    // the iteration.
    final items = _iterable(_eval(s.collection, vars), s.collection.srcBlockId);
    final indexVar = s.indexVar;
    for (var index = 0; index < items.length; index++) {
      _tick(s.srcBlockId);
      vars[s.itemVar] = items[index];
      if (indexVar != null) vars[indexVar] = NumValue(index);
      _emit(TraceKinds.forEach, s.srcBlockId, vars);
      final flow = _loopBody(s.body, vars);
      if (flow is _Return) return flow;
      if (flow != null) return null;
    }
    _emit(TraceKinds.loopEnd, s.srcBlockId, vars);
    return null;
  }

  /// Runs one pass of a loop body. `null` goes on to the next pass (the body
  /// ended or asked to CONTINUE); a BREAK or a RETURN comes back to the loop.
  _Flow? _loopBody(List<Stmt> body, Map<String, RuntimeValue> vars) {
    final flow = _execAll(body, vars);
    if (flow is _Loop && !flow.isBreak) return null;
    return flow;
  }

  void _step(
    LValue target,
    int delta,
    String? blockId,
    Map<String, RuntimeValue> vars,
  ) {
    _tick(blockId);
    final current = _num(_read(target, vars, blockId), blockId);
    _assign(target, NumValue(_add(current, delta, blockId)), vars);
    _emit(delta > 0 ? TraceKinds.inc : TraceKinds.dec, blockId, vars);
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
      final num n => NumValue(_whole(n, expr.srcBlockId, 'Only whole numbers can be used.')),
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
      BinaryOp.add => NumValue(_add(a, b, id)),
      BinaryOp.sub => NumValue(_safe(a.toInt() - b.toInt(), id)),
      BinaryOp.mul => NumValue(_mul(a, b, id)),
      BinaryOp.div => NumValue(_divide(a, b, id)),
      BinaryOp.floorDiv => NumValue(_floorDivide(a, b, id)),
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

  // --- numbers (L3: safe whole numbers; runtime/whole_number.dart) ----------
  //
  // Every number in a run is a whole number inside +-maxSafeNumber: literals
  // and inputs are checked on the way in (_whole), and every operation that
  // can leave the range goes through _safe. Inside the range the Dart VM,
  // dart2js and dart2wasm agree bit for bit; tool/number_model_probe.dart and
  // tool/web_parity.sh measure it.

  Never _tooBig(String? blockId) => throw _Halt(ResultKind.runtimeError, 'This number is too big.', blockId);

  /// [r] when it is inside the range, else "This number is too big."
  /// (algorun-lang D2, with the limit at 2^53 - 1).
  int _safe(int r, String? blockId) {
    if (r > maxSafeNumber || r < -maxSafeNumber) _tooBig(blockId);
    return r;
  }

  /// Two numbers inside the range cannot wrap 64 bits when added, and a sum
  /// that JavaScript has to round is already outside the range.
  int _add(num a, num b, String? blockId) => _safe(a.toInt() + b.toInt(), blockId);

  int _mul(num a, num b, String? blockId) {
    // On the phone a product can wrap around 64 bits and land back inside
    // the range, so its size is judged on the double product first: that one
    // only rounds, and never down past 2^53.
    final size = a.toDouble() * b.toDouble();
    if (size > maxSafeNumber || size < -maxSafeNumber) _tooBig(blockId);
    return _unsigned0(a.toInt() * b.toInt());
  }

  /// JavaScript has a negative zero (`0 * -3`, `-1 ~/ 5`, `-0`) and prints
  /// it; the phone does not have one.
  static int _unsigned0(int r) => r == 0 ? 0 : r;

  /// A number on its way into a run: a literal or part of an input. A whole
  /// `2.0` is the number 2; a fraction is refused with [fraction]
  /// (algorun-lang D4); a number outside the range is too big.
  int _whole(num n, String? blockId, String fraction) {
    switch (numberProblem(n)) {
      case null:
        return wholeNumber(n);
      case NumberProblem.fraction:
        throw _Halt(ResultKind.invalidProgram, fraction, blockId);
      case NumberProblem.tooBig:
        _tooBig(blockId);
    }
  }

  static const _wholeInputs = 'This program only works with whole numbers.';

  /// A map key or set member of an input: a number key is a number too.
  Object _inputKey(Object key) => key is num ? _whole(key, null, _wholeInputs) : key;

  /// DIVIDE truncates toward zero: `7 / 2` is 3 and `-7 / 2` is -3
  /// (algorun-lang D3). FLOOR DIVIDE rounds down instead.
  int _divide(num a, num b, String? blockId) {
    if (b == 0) {
      throw _Halt(ResultKind.runtimeError, 'You cannot divide by zero.', blockId);
    }
    return _unsigned0(a.toInt() ~/ b.toInt());
  }

  /// FLOOR DIVIDE: the largest whole number not above `a / b`, so 7 FLOOR
  /// DIVIDE 2 is 3 and -7 FLOOR DIVIDE 2 is -4.
  int _floorDivide(num a, num b, String? blockId) {
    final x = a.toInt();
    final y = b.toInt();
    final truncated = _divide(x, y, blockId);
    final inexact = truncated * y != x;
    return inexact && (x < 0) != (y < 0) ? truncated - 1 : truncated;
  }

  /// REMAINDER is never negative for a divisor other than zero.
  int _modulo(num a, num b, String? blockId) {
    if (b == 0) {
      throw _Halt(ResultKind.runtimeError, 'You cannot divide by zero.', blockId);
    }
    return _unsigned0(a.toInt() % b.toInt());
  }

  RuntimeValue _unary(UnaryExpr expr, Map<String, RuntimeValue> vars) {
    final arg = _eval(expr.arg, vars);
    final id = expr.arg.srcBlockId ?? expr.srcBlockId;
    return switch (expr.op) {
      UnaryOp.not => BoolValue(!_bool(arg, id)),
      UnaryOp.neg => NumValue(_unsigned0(-_num(arg, id).toInt())),
      UnaryOp.abs => NumValue(_num(arg, id).toInt().abs()),
      // A real check on the value: never an error, whatever it holds.
      UnaryOp.isNothing => BoolValue(arg is NilValue),
      UnaryOp.isNotNothing => BoolValue(arg is! NilValue),
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
      CollKind.minHeap => HeapValue([], isMax: false, id: id),
      CollKind.maxHeap => HeapValue([], isMax: true, id: id),
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
      // --- algorun-lang A3 ------------------------------------------------
      case BlockIds.varCopy:
        return _copyCharged(at(0), id);
      case BlockIds.strLen:
        return NumValue(_str(at(0), id).runes.length);
      case BlockIds.strCharAt:
        {
          final cps = _str(at(0), id).runes.toList();
          final i = _bound(at(1), cps.length - 1, id);
          return StrValue(String.fromCharCode(cps[i]));
        }
      case BlockIds.strConcat:
        return _text(_str(at(0), id) + _str(at(1), id), id);
      case BlockIds.strSubstring:
        {
          final cps = _str(at(0), id).runes.toList();
          final start = _bound(at(1), cps.length, id);
          final end = _bound(at(2), cps.length, id);
          if (start > end) {
            throw _Halt(ResultKind.runtimeError, 'That position is outside the text.', id);
          }
          return StrValue(String.fromCharCodes(cps.sublist(start, end)));
        }
      case BlockIds.strCompare:
        return NumValue(_compareText(_str(at(0), id), _str(at(1), id)));
      case BlockIds.strFromNum:
        return StrValue(_digits(_num(at(0), id)));
      case BlockIds.strToNum:
        {
          final n = _parseWhole(_str(at(0), id));
          return n == null ? const NilValue() : NumValue(n);
        }
      case BlockIds.dequePushFront || BlockIds.dequePushBack:
        {
          final deque = _deque(at(0), id);
          if (deque.items.length >= limits.maxArrayLen) {
            throw _Halt(ResultKind.memoryLimit, 'This deque got too big.', id);
          }
          _alloc(1, id);
          if (expr.callee == BlockIds.dequePushFront) {
            deque.items.insert(0, at(1));
          } else {
            deque.items.add(at(1));
          }
          return const NilValue();
        }
      case BlockIds.dequePopFront ||
            BlockIds.dequePopBack ||
            BlockIds.dequeFront ||
            BlockIds.dequeBack:
        {
          final deque = _deque(at(0), id);
          if (deque.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This deque is empty.', id);
          }
          switch (expr.callee) {
            case BlockIds.dequePopFront:
              _free(1);
              return deque.items.removeAt(0);
            case BlockIds.dequePopBack:
              _free(1);
              return deque.items.removeLast();
            case BlockIds.dequeFront:
              return deque.items.first;
            default:
              return deque.items.last;
          }
        }
      case BlockIds.dequeSize:
        return NumValue(_deque(at(0), id).items.length);
      case BlockIds.dequeEmpty:
        return BoolValue(_deque(at(0), id).items.isEmpty);
      case BlockIds.arrSort:
        _sort(_array(at(0), id).elements, id);
        return const NilValue();
      case BlockIds.pairMake:
        _alloc(1, id);
        return PairValue(at(0), at(1), id: _nextId++);
      case BlockIds.pairFirst:
        return _pair(at(0), id).first;
      case BlockIds.pairSecond:
        return _pair(at(0), id).second;
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
      case BlockIds.heapInsert:
        {
          final heap = _heap(at(0), id);
          if (heap.items.length >= limits.maxArrayLen) {
            throw _Halt(ResultKind.memoryLimit, 'This heap got too big.', id);
          }
          _alloc(1, id);
          heap.insert(_num(at(1), id));
          return const NilValue();
        }
      case BlockIds.heapTake:
        {
          final heap = _heap(at(0), id);
          if (heap.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This heap is empty.', id);
          }
          _free(1);
          return NumValue(heap.takeTop());
        }
      case BlockIds.heapTop:
        {
          final heap = _heap(at(0), id);
          if (heap.items.isEmpty) {
            throw _Halt(ResultKind.runtimeError, 'This heap is empty.', id);
          }
          return NumValue(heap.top);
        }
      case BlockIds.heapSize:
        return NumValue(_heap(at(0), id).items.length);
      case BlockIds.heapEmpty:
        return BoolValue(_heap(at(0), id).items.isEmpty);
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

  // --- algorun-lang A3 helpers --------------------------------------------

  String _str(RuntimeValue value, String? blockId) {
    if (value is StrValue) return value.value;
    throw _Halt(ResultKind.runtimeError, 'This block needs some text.', blockId);
  }

  DequeValue _deque(RuntimeValue value, String? blockId) {
    if (value is DequeValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a deque.', blockId);
  }

  PairValue _pair(RuntimeValue value, String? blockId) {
    if (value is PairValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a pair.', blockId);
  }

  /// Text longer than maxArrayLen code points is a memory limit.
  StrValue _text(String s, String? blockId) {
    if (s.runes.length > limits.maxArrayLen) {
      throw _Halt(ResultKind.memoryLimit, 'This text got too long.', blockId);
    }
    return StrValue(s);
  }

  /// A position in text: a whole number from 0 to [last] inclusive
  /// (LETTER AT: the last letter; PART OF TEXT: the length, a cut after it).
  int _bound(RuntimeValue value, int last, String? blockId) {
    final raw = _num(value, blockId);
    if (raw < 0 || raw > last) {
      throw _Halt(ResultKind.runtimeError, 'That position is outside the text.', blockId);
    }
    return raw.toInt();
  }

  /// NUMBER AS TEXT: decimal digits, `-` for a negative number.
  String _digits(num n) => n.toInt().toString();

  /// TEXT AS NUMBER: `-?[0-9]+` that fits [maxSafeNumber], else null. Digit by
  /// digit, because `int.parse` rounds large values in a browser.
  static int? _parseWhole(String s) {
    var i = 0;
    final negative = s.startsWith('-');
    if (negative) i = 1;
    if (i >= s.length) return null;
    var n = 0;
    for (; i < s.length; i++) {
      final digit = s.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) return null;
      if (n > (maxSafeNumber - digit) ~/ 10) return null;
      n = n * 10 + digit;
    }
    return negative && n != 0 ? -n : n;
  }

  /// -1, 0 or 1 by Unicode code point order (not UTF-16 units).
  static int _compareText(String a, String b) {
    final x = a.runes.toList();
    final y = b.runes.toList();
    final n = x.length < y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
    }
    return x.length == y.length ? 0 : (x.length < y.length ? -1 : 1);
  }

  /// SORT (D8): ascending, stable, in place. Only numbers or only text.
  /// Bottom-up merge sort; every comparison costs one op, so the op count is
  /// part of the spec (docs/spec.md §10.10).
  void _sort(List<RuntimeValue> items, String? blockId) {
    if (items.length < 2) return;
    final allNum = items.every((v) => v is NumValue);
    final allStr = items.every((v) => v is StrValue);
    if (!allNum && !allStr) {
      throw _Halt(
        ResultKind.runtimeError,
        'SORT needs a list of only numbers or only text.',
        blockId,
      );
    }
    int cmp(RuntimeValue a, RuntimeValue b) {
      _tick(blockId);
      if (allNum) {
        final x = (a as NumValue).value;
        final y = (b as NumValue).value;
        return x < y ? -1 : (x > y ? 1 : 0);
      }
      return _compareText((a as StrValue).value, (b as StrValue).value);
    }

    var src = List.of(items);
    var dst = List<RuntimeValue>.filled(items.length, const NilValue());
    final n = items.length;
    for (var width = 1; width < n; width *= 2) {
      for (var lo = 0; lo < n; lo += 2 * width) {
        final mid = lo + width < n ? lo + width : n;
        final hi = lo + 2 * width < n ? lo + 2 * width : n;
        var i = lo, j = mid, k = lo;
        while (i < mid && j < hi) {
          dst[k++] = cmp(src[j], src[i]) < 0 ? src[j++] : src[i++];
        }
        while (i < mid) {
          dst[k++] = src[i++];
        }
        while (j < hi) {
          dst[k++] = src[j++];
        }
      }
      final t = src;
      src = dst;
      dst = t;
    }
    for (var i = 0; i < n; i++) {
      items[i] = src[i];
    }
  }

  /// COPY (D5): a deep copy, charged one alloc cell per copied container,
  /// pair and node plus one per element stored in a container.
  RuntimeValue _copyCharged(RuntimeValue value, String? blockId) {
    final copy = _copy(value, {});
    _alloc(_cells(copy, Set.identity()), blockId);
    return copy;
  }

  int _cells(RuntimeValue v, Set<RuntimeValue> seen) {
    if (v is NilValue || v is NumValue || v is BoolValue || v is StrValue) return 0;
    if (!seen.add(v)) return 0;
    return switch (v) {
      ArrayValue(:final elements) => 1 + elements.length + elements.fold(0, (a, e) => a + _cells(e, seen)),
      MapValue(:final entries) => 1 + entries.length + entries.values.fold(0, (a, e) => a + _cells(e, seen)),
      SetValue(:final members) => 1 + members.length,
      StackValue(:final items) => 1 + items.length + items.fold(0, (a, e) => a + _cells(e, seen)),
      QueueValue(:final items) => 1 + items.length + items.fold(0, (a, e) => a + _cells(e, seen)),
      DequeValue(:final items) => 1 + items.length + items.fold(0, (a, e) => a + _cells(e, seen)),
      HeapValue(:final items) => 1 + items.length,
      PairValue(:final first, :final second) => 1 + _cells(first, seen) + _cells(second, seen),
      ListNodeValue(:final next) => 1 + (next == null ? 0 : _cells(next, seen)),
      TreeNodeValue(:final left, :final right) =>
        1 + (left == null ? 0 : _cells(left, seen)) + (right == null ? 0 : _cells(right, seen)),
      GraphValue(:final adjacency) => 1 + adjacency.length,
      _ => 0,
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

  HeapValue _heap(RuntimeValue value, String? blockId) {
    if (value is HeapValue) return value;
    throw _Halt(ResultKind.runtimeError, 'This block needs a heap.', blockId);
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
    final index = _num(value, blockId).toInt();
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

  /// One step for the sink. Never counts an operation and never touches the
  /// run: with no sink this returns at once.
  void _emit(
    String kind,
    String? blockId,
    Map<String, RuntimeValue> vars, {
    RuntimeValue? value,
    bool? flag,
  }) {
    final sink = trace;
    if (sink == null) return;
    sink(TraceEvent(
      opIndex: _ops,
      kind: kind,
      blockId: blockId,
      frames: _framesView,
      value: value ?? (flag == null ? null : BoolValue(flag)),
    ));
  }

  /// The failure that stops the run, once, as the last event.
  void _emitHalt(_Halt halt) {
    final sink = trace;
    if (sink == null || _haltEmitted) return;
    _haltEmitted = true;
    sink(TraceEvent(
      opIndex: _ops,
      kind: TraceKinds.halt,
      blockId: halt.blockId,
      frames: _framesView,
      message: halt.message,
    ));
  }

  // --- input copy ---------------------------------------------------------

  /// Deep copy of a given value. Cycles are preserved through [seen], and
  /// copying is free: the player did not allocate the input.
  RuntimeValue _copy(RuntimeValue value, Map<RuntimeValue, RuntimeValue> seen) {
    final existing = seen[value];
    if (existing != null) return existing;
    switch (value) {
      case NumValue(value: final n):
        return NumValue(_whole(n, null, _wholeInputs));
      case NilValue() || BoolValue() || StrValue():
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
          copy.entries[_inputKey(entry.key)] = _copy(entry.value, seen);
        }
        return copy;
      case final SetValue v:
        final copy = SetValue({}, id: _nextId++, elementType: v.elementType);
        seen[value] = copy;
        for (final entry in v.members.entries) {
          copy.members[_inputKey(entry.key)] = _copy(entry.value, seen);
        }
        return copy;
      case final HeapValue v:
        final copy = HeapValue([for (final n in v.items) _whole(n, null, _wholeInputs)], isMax: v.isMax, id: _nextId++);
        seen[value] = copy;
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
        final copy = ListNodeValue(_whole(v.value, null, _wholeInputs), id: _nextId++);
        seen[value] = copy;
        final next = v.next;
        if (next != null) copy.next = _copy(next, seen) as ListNodeValue;
        return copy;
      case final TreeNodeValue v:
        final copy = TreeNodeValue(_whole(v.value, null, _wholeInputs), id: _nextId++);
        seen[value] = copy;
        final left = v.left;
        final right = v.right;
        if (left != null) copy.left = _copy(left, seen) as TreeNodeValue;
        if (right != null) copy.right = _copy(right, seen) as TreeNodeValue;
        return copy;
      case final PairValue v:
        final copy = PairValue(_copy(v.first, seen), _copy(v.second, seen), id: _nextId++);
        seen[value] = copy;
        return copy;
      case final GraphValue v:
        final copy = GraphValue(
          {
            for (final entry in v.adjacency.entries)
              _whole(entry.key, null, _wholeInputs): [for (final n in entry.value) _whole(n, null, _wholeInputs)],
          },
          visited: {for (final n in v.visited) _whole(n, null, _wholeInputs)},
          id: _nextId++,
        );
        seen[value] = copy;
        return copy;
    }
  }
}

/// How a statement ended when it did not just run to its end.
sealed class _Flow {
  const _Flow();
}

/// A `return` travelling up to its function frame.
final class _Return extends _Flow {
  const _Return(this.value);
  final RuntimeValue value;
}

/// A `break` or `continue` travelling up to its loop.
final class _Loop extends _Flow {
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
