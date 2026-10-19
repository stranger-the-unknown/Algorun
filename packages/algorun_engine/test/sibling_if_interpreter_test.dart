import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// Sibling [IfStmt] nodes run independently. A false condition skips only
/// that node's own body. Nesting the second IF is a different program.
void main() {
  for (final sample in const [
    (true, false, 10),
    (false, true, 1),
    (true, true, 11),
    (false, false, 0),
  ]) {
    test('two sibling IFs: top ${sample.$1}, bottom ${sample.$2}', () {
      final result = _run(_two(sample.$1, sample.$2));
      expect(result.kind, ResultKind.correct, reason: result.message);
      expect(_number(result), sample.$3);
    });
  }

  test('three sibling IFs run in order when every condition is true', () {
    final result = _run(_three(true, true, true));
    expect(result.kind, ResultKind.correct, reason: result.message);
    expect(_number(result), 111);
  });

  test('three sibling IFs: only the middle body runs', () {
    final result = _run(_three(false, true, false));
    expect(result.kind, ResultKind.correct, reason: result.message);
    expect(_number(result), 10);
  });

  test('three sibling IFs run nothing when every condition is false', () {
    final result = _run(_three(false, false, false));
    expect(result.kind, ResultKind.correct, reason: result.message);
    expect(_number(result), 0);
  });

  test('a second IF nested in THEN does not run when the outer condition is false', () {
    final result = _run(_program([
      _set('a', _n(0)),
      _set('b', _n(0)),
      IfStmt(
        cond: _bool(false),
        thenBody: [
          _set('a', _n(1), src: 'top-body'),
          IfStmt(
            cond: _bool(true),
            thenBody: [_set('b', _n(1), src: 'nested-body')],
            srcBlockId: 'if-nested',
          ),
        ],
        srcBlockId: 'if-top',
      ),
      ReturnStmt(value: _pack2()),
    ]));
    expect(result.kind, ResultKind.correct, reason: result.message);
    expect(_number(result), 0);
  });
}

Program _two(bool top, bool bottom) {
  return _program([
    _set('a', _n(0)),
    _set('b', _n(0)),
    IfStmt(
      cond: _bool(top),
      thenBody: [_set('a', _n(1), src: 'top-body')],
      srcBlockId: 'if-top',
    ),
    IfStmt(
      cond: _bool(bottom),
      thenBody: [_set('b', _n(1), src: 'bottom-body')],
      srcBlockId: 'if-bottom',
    ),
    ReturnStmt(value: _pack2()),
  ]);
}

Program _three(bool first, bool second, bool third) {
  return _program([
    _set('a', _n(0)),
    _set('b', _n(0)),
    _set('c', _n(0)),
    IfStmt(
      cond: _bool(first),
      thenBody: [_set('a', _n(1), src: 'body-1')],
      srcBlockId: 'if-1',
    ),
    IfStmt(
      cond: _bool(second),
      thenBody: [_set('b', _n(1), src: 'body-2')],
      srcBlockId: 'if-2',
    ),
    IfStmt(
      cond: _bool(third),
      thenBody: [_set('c', _n(1), src: 'body-3')],
      srcBlockId: 'if-3',
    ),
    ReturnStmt(value: _pack3()),
  ]);
}

/// `10 * a + b`.
Expr _pack2() => _add(_mul(_get('a'), _n(10)), _get('b'));

/// `100 * a + 10 * b + c`.
Expr _pack3() => _add(_add(_mul(_get('a'), _n(100)), _mul(_get('b'), _n(10))), _get('c'));

Program _program(List<Stmt> body) =>
    Program(functions: [FnDecl(name: 'main', params: const [], body: body)]);

Expr _n(num value) => LitExpr(value, type: ValueType.number);

Expr _bool(bool value) => LitExpr(value, type: ValueType.boolean);

Expr _get(String name) => VarExpr(name, type: ValueType.number);

Stmt _set(String name, Expr value, {String? src}) =>
    AssignStmt(target: VarLValue(name), value: value, srcBlockId: src);

Expr _add(Expr a, Expr b) => BinaryExpr(BinaryOp.add, a, b, type: ValueType.number);

Expr _mul(Expr a, Expr b) => BinaryExpr(BinaryOp.mul, a, b, type: ValueType.number);

RunResult _run(Program program) =>
    const DefaultEngine().run(program, const {}, RunLimits.standard);

num _number(RunResult result) => (result.output as NumValue).value;
