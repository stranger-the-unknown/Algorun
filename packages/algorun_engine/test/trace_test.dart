import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// T1: the step trace. What the interpreter reports at each step, what
/// [recordTrace] keeps of it, how a long run is cut into windows, and the one
/// door a puzzle's cases are traced through.

const _num = ValueType.number;
final _nums = ValueType.array(_num);

Program _program(List<Stmt> body, {List<Param> params = const [], List<FnDecl> functions = const []}) =>
    Program(functions: [FnDecl(name: 'main', params: params, body: body), ...functions]);

Expr _n(num value) => LitExpr(value, type: _num);
Expr _get(String name, {ValueType type = _num}) => VarExpr(name, type: type);
Expr _list(String name) => VarExpr(name, type: _nums);
Stmt _set(String name, Expr value, {String? src}) =>
    AssignStmt(target: VarLValue(name), value: value, srcBlockId: src);
Expr _bin(BinaryOp op, Expr a, Expr b, {ValueType type = _num}) => BinaryExpr(op, a, b, type: type);
Expr _lt(Expr a, Expr b) => _bin(BinaryOp.lt, a, b, type: ValueType.boolean);
Expr _call(String callee, List<Expr> args, {ValueType type = _num, String? src}) =>
    CallExpr(callee, args, type: type, srcBlockId: src);
Stmt _do(String callee, List<Expr> args, {String? src}) =>
    ExprStmt(_call(callee, args, type: ValueType.voidType, src: src), srcBlockId: src);
Expr _new(CollKind kind, ValueType type) => NewExpr(kind, type: type);

List<TraceEvent> _events(Program program, {Map<String, RuntimeValue> input = const {}, RunLimits limits = RunLimits.standard}) {
  final events = <TraceEvent>[];
  runProgram(program, input, limits, trace: events.add);
  return events;
}

/// A value with everything it refers to, as plain JSON-like data.
Object? _show(TraceRecording r, TraceValue? value, int step, [Set<int>? open]) {
  switch (value) {
    case null:
      return null;
    case TraceNothing():
      return null;
    case TraceNumber(:final value):
      return value;
    case TraceBool(:final value):
      return value;
    case TraceText(:final value):
      return value;
    case TraceUnknown(:final text):
      return text;
    case TraceRef(:final id):
      final seen = open ?? <int>{};
      if (!seen.add(id)) return '↻';
      final object = r.objectAt(id, step);
      final out = switch (object) {
        null => 'missing #$id',
        TraceSequence(:final items) => [for (final item in items) _show(r, item, step, seen)],
        TraceMap(:final entries) => {
            for (final e in entries) '${_show(r, e.key, step, seen)}': _show(r, e.value, step, seen),
          },
        TraceListNode(:final value, :final next) => [value, _show(r, next, step, seen)],
        TraceTreeNode(:final value, :final left, :final right) => {
            'v': value,
            'l': _show(r, left, step, seen),
            'r': _show(r, right, step, seen),
          },
        TraceGraph(:final adjacency, :final visited) => {'edges': '$adjacency', 'visited': visited},
      };
      seen.remove(id);
      return out;
  }
}

/// A step as text: enough to tell whether two recordings agree on it.
String _stepText(TraceRecording r, TraceStep s) => jsonEncode({
      'index': s.index,
      'op': s.opIndex,
      'kind': s.kind,
      'block': s.blockId,
      'value': _show(r, s.value, s.index),
      'message': s.message,
      'changed': s.changed.toList()..sort(),
      'frames': [
        for (final frame in s.frames)
          {
            'fn': frame.function,
            'serial': frame.serial,
            'vars': {for (final v in frame.vars.entries) v.key: _show(r, v.value, s.index)},
          },
      ],
    });

Map<String, Object?> _vars(TraceRecording r, TraceStep s, [int? depth]) => {
      for (final v in s.frames[depth ?? s.frames.length - 1].vars.entries) v.key: _show(r, v.value, s.index),
    };

/// `total = 0; for i in 0..len(nums): total = total + nums[i]; return total`
Program _sum() => _program(
      [
        _set('total', _n(0), src: 'init'),
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _call(BlockIds.arrLen, [_list('nums')]),
          body: [
            _set('total', _bin(BinaryOp.add, _get('total'), IndexExpr(_list('nums'), _get('i'), type: _num)), src: 'add'),
          ],
          srcBlockId: 'for',
        ),
        ReturnStmt(value: _get('total'), srcBlockId: 'ret'),
      ],
      params: [Param('nums', _nums)],
    );

/// `fact(n)`: `if n < 2 return 1; return n * fact(n - 1)`, called from main.
/// k × fact(k − 1); with [op] `add` the same shape without the size (150!
/// is far past the numbers the game counts with).
Program _factorial({BinaryOp op = BinaryOp.mul}) => _program(
      [ReturnStmt(value: _call('fact', [_get('n')], src: 'call'), srcBlockId: 'main-ret')],
      params: [const Param('n', _num)],
      functions: [
        FnDecl(
          name: 'fact',
          params: const [Param('k', _num)],
          returnType: _num,
          srcBlockId: 'fn',
          body: [
            IfStmt(
              cond: _lt(_get('k'), _n(2)),
              thenBody: [ReturnStmt(value: _n(1), srcBlockId: 'base')],
              srcBlockId: 'if',
            ),
            ReturnStmt(
              value: _bin(op, _get('k'), _call('fact', [_bin(BinaryOp.sub, _get('k'), _n(1))], src: 'rec')),
              srcBlockId: 'step',
            ),
          ],
        ),
      ],
    );

/// Appends 0 … count-1 to a new list, one per pass.
Program _filler() => _program(
      [
        _set('out', _new(CollKind.array, _nums), src: 'new'),
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _get('count'),
          body: [_do(BlockIds.arrAppend, [_list('out'), _get('i')], src: 'append')],
          srcBlockId: 'for',
        ),
        ReturnStmt(value: _list('out'), srcBlockId: 'ret'),
      ],
      params: [const Param('count', _num)],
    );

void main() {
  group('events', () {
    test('one per instruction, in the order they ran, each with its block', () {
      final events = _events(_sum(), input: {'nums': valueFromJson([4, 5])});
      expect(
        [for (final e in events) '${e.kind}:${e.blockId}'],
        [
          'start:null',
          'assign:init',
          'forRange:for',
          'assign:add',
          'forRange:for',
          'assign:add',
          'loopEnd:for',
          'return:ret',
        ],
      );
      // Operations only ever go up, and a step's count includes itself.
      for (var i = 1; i < events.length; i++) {
        expect(events[i].opIndex, greaterThanOrEqualTo(events[i - 1].opIndex));
      }
      expect(events[1].opIndex, greaterThan(0));
      expect((events.last.value! as NumValue).value, 9);
    });

    test('a loop that never runs still says it was reached', () {
      final events = _events(_sum(), input: {'nums': valueFromJson(<Object?>[])});
      expect([for (final e in events) e.kind], ['start', 'assign', 'loopEnd', 'return']);
    });

    test('IF and WHILE report what their condition came to', () {
      final events = _events(_program([
        _set('i', _n(0)),
        WhileStmt(
          cond: _lt(_get('i'), _n(2)),
          body: [IncStmt(const VarLValue('i'), srcBlockId: 'inc')],
          srcBlockId: 'while',
        ),
        IfStmt(cond: _lt(_get('i'), _n(2)), thenBody: const [], elseBody: [DecStmt(const VarLValue('i'), srcBlockId: 'dec')], srcBlockId: 'if'),
      ]));
      expect(
        [for (final e in events) e.value is BoolValue ? '${e.kind}=${(e.value! as BoolValue).value}' : e.kind],
        ['start', 'assign', 'while=true', 'inc', 'while=true', 'inc', 'while=false', 'if=false', 'dec'],
      );
    });

    test('BREAK and CONTINUE are steps; a broken loop does not also end', () {
      final events = _events(_program([
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _n(5),
          body: [
            IfStmt(cond: _lt(_get('i'), _n(1)), thenBody: const [ContinueStmt(srcBlockId: 'cont')], srcBlockId: 'if1'),
            const BreakStmt(srcBlockId: 'brk'),
          ],
          srcBlockId: 'for',
        ),
      ]));
      expect(
        [for (final e in events) e.kind],
        ['start', 'forRange', 'if', 'continue', 'forRange', 'if', 'break'],
      );
    });

    test('an instruction that is one working block is a step', () {
      final events = _events(_filler(), input: {'count': const NumValue(2)});
      expect(
        [for (final e in events) '${e.kind}:${e.blockId}'],
        ['start:null', 'assign:new', 'forRange:for', 'expr:append', 'forRange:for', 'expr:append', 'loopEnd:for', 'return:ret'],
      );
    });

    test('a call opens a frame with its parameters; RETURN shows the value before the frame closes', () {
      final events = _events(_factorial(), input: {'n': const NumValue(3)});
      expect(
        [for (final e in events) '${e.kind}@${e.depth}'],
        [
          'start@1',
          'call@2', 'if@2',
          'call@3', 'if@3',
          'call@4', 'if@4', 'return@4',
          'return@3',
          'return@2',
          'return@1',
        ],
      );
      final calls = events.where((e) => e.kind == TraceKinds.call).toList();
      expect([for (final e in calls) e.blockId], ['fn', 'fn', 'fn']);
      // The values a sink sees are live, so they are read while it runs.
      final seen = <String>[];
      final serials = <int>[];
      runProgram(_factorial(), {'n': const NumValue(3)}, RunLimits.standard, trace: (e) {
        if (e.kind != TraceKinds.returnStep) return;
        seen.add('${[for (final f in e.frames) '${f.function}${f.vars.values.map((v) => v.toJson()).toList()}'].join('>')}'
            ' = ${e.value!.toJson()}');
        serials.add(e.frames.last.serial);
      });
      expect(seen, [
        'main[3]>fact[3]>fact[2]>fact[1] = 1',
        'main[3]>fact[3]>fact[2] = 2',
        'main[3]>fact[3] = 6',
        'main[3] = 6',
      ]);
      expect(serials, [4, 3, 2, 1]);
    });

    test('a failure is the last step: where, why, with the frame that failed still open', () {
      final program = _program(
        [ReturnStmt(value: _call('pick', [_list('nums')], src: 'call'))],
        params: [Param('nums', _nums)],
        functions: [
          FnDecl(
            name: 'pick',
            params: [Param('items', _nums)],
            returnType: _num,
            srcBlockId: 'fn',
            body: [
              _set('at', _n(7), src: 'set'),
              ReturnStmt(value: IndexExpr(_list('items'), _get('at'), type: _num, srcBlockId: 'get'), srcBlockId: 'ret'),
            ],
          ),
        ],
      );
      String? frames;
      final kinds = <String>[];
      TraceEvent? last;
      final result = runProgram(program, {'nums': valueFromJson([1, 2])}, RunLimits.standard, trace: (e) {
        kinds.add(e.kind);
        last = e;
        if (e.kind == TraceKinds.halt) frames = [for (final f in e.frames) '${f.function}:${f.vars.keys.join(',')}'].join(' > ');
      });
      expect(result.kind, ResultKind.runtimeError);
      expect(kinds, ['start', 'call', 'assign', 'halt']);
      expect(last!.blockId, 'get');
      expect(last!.blockId, result.blockId);
      expect(last!.message, result.message);
      expect(frames, 'main:nums > pick:items,at');
    });

    test('running out of operations or depth ends with the same failure step', () {
      final loop = _program([WhileStmt(cond: const LitExpr(true, type: ValueType.boolean), body: [_set('x', _n(1))], srcBlockId: 'w')]);
      final events = _events(loop, limits: const RunLimits(maxOps: 50));
      expect(events.last.kind, TraceKinds.halt);
      expect(events.last.message, 'This program took too many steps.');
      expect(events.where((e) => e.kind == TraceKinds.halt), hasLength(1));

      final deep = _events(_factorial(), input: {'n': const NumValue(50)}, limits: const RunLimits(maxDepth: 5));
      expect(deep.last.kind, TraceKinds.halt);
      expect(deep.last.message, 'This program went too many levels deep.');
      // The frame that could not open is not there; the five that did are.
      expect(deep.last.depth, 5);
      expect(deep.where((e) => e.kind == TraceKinds.halt), hasLength(1));
    });

    test('locals reads the running frame as display text', () {
      final events = <String>[];
      runProgram(_sum(), {'nums': valueFromJson([4, 5])}, RunLimits.standard, trace: (e) {
        if (e.kind == TraceKinds.returnStep) events.add('${e.locals}');
      });
      expect(events, ['{nums: [4, 5], total: 9, i: 1}']);
    });
  });

  group('recording', () {
    test('holds every step of a short run, and the run itself is unchanged', () {
      final input = {'nums': valueFromJson([4, 5])};
      final plain = runProgram(_sum(), input, RunLimits.standard);
      final r = recordTrace(_sum(), input, RunLimits.standard);
      expect(r.complete, isTrue);
      expect(r.totalSteps, 8);
      expect(r.firstStep, 0);
      expect([for (final s in r.steps) s.index], [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(r.result.kind, plain.kind);
      expect(r.result.metrics.ops, plain.metrics.ops);
      expect(r.result.metrics.peakAlloc, plain.metrics.peakAlloc);
      expect(r.steps.last.opIndex, plain.metrics.ops);
      expect(_vars(r, r.steps[0]), {'nums': [4, 5]});
      expect(_vars(r, r.steps[3]), {'nums': [4, 5], 'total': 4, 'i': 0});
      expect(_vars(r, r.steps[7]), {'nums': [4, 5], 'total': 9, 'i': 1});
      expect(_show(r, r.steps[7].value, 7), 9);
    });

    test('says which names a step bound: none at the start, the target of a SET, the counter of a FOR', () {
      final r = recordTrace(_sum(), {'nums': valueFromJson([4, 5])}, RunLimits.standard);
      expect(
        [for (final s in r.steps) '${s.kind}${(s.changed.toList()..sort())}'],
        ['start[]', 'assign[total]', 'forRange[i]', 'assign[total]', 'forRange[i]', 'assign[total]', 'loopEnd[]', 'return[]'],
      );
    });

    test('a frame just entered lists its parameters; back in the caller nothing is marked', () {
      final r = recordTrace(_factorial(), {'n': const NumValue(2)}, RunLimits.standard);
      expect(
        [for (final s in r.steps) '${s.kind}@${s.depth}${s.changed.toList()}'],
        ['start@1[]', 'call@2[k]', 'if@2[]', 'call@3[k]', 'if@3[]', 'return@3[]', 'return@2[]', 'return@1[]'],
      );
      expect(r.steps[3].frames.map((f) => '${f.function}${f.vars}').toList(), ['main{n: 2}', 'fact{k: 2}', 'fact{k: 1}']);
    });

    test('what did not change is stored once', () {
      final r = recordTrace(_factorial(), {'n': const NumValue(6)}, RunLimits.standard);
      // While the recursion goes down, each earlier frame is the same object
      // step after step.
      final deepest = r.steps.firstWhere((s) => s.depth == 7);
      final before = r.steps[deepest.index - 1];
      for (var depth = 0; depth < before.frames.length; depth++) {
        expect(identical(deepest.frames[depth], before.frames[depth]), isTrue, reason: 'frame $depth');
      }
      // The given list of a loop is one object for the whole run.
      final sum = recordTrace(_sum(), {'nums': valueFromJson([1, 2, 3, 4])}, RunLimits.standard);
      final id = (sum.steps.first.frames.single.vars['nums']! as TraceRef).id;
      final first = sum.objectAt(id, 0);
      for (final step in sum.steps) {
        expect(identical(sum.objectAt(id, step.index), first), isTrue);
        expect(step.changedObjects, isEmpty);
      }
    });

    test('a list keeps a version for each step that changed it', () {
      final r = recordTrace(_filler(), {'count': const NumValue(3)}, RunLimits.standard);
      final appends = r.steps.where((s) => s.blockId == 'append').toList();
      final id = (appends.first.frames.single.vars['out']! as TraceRef).id;
      expect([for (final s in appends) _show(r, TraceRef(id), s.index)], [[0], [0, 1], [0, 1, 2]]);
      for (final s in appends) {
        expect(s.changedObjects, {id});
        final before = r.objectBefore(id, s.index)! as TraceSequence;
        final after = r.objectAt(id, s.index)! as TraceSequence;
        expect(before.items.length, after.items.length - 1);
        expect(changedPositions(before, after), {after.items.length - 1});
      }
      // A step that left it alone has no "before".
      final loop = r.steps.firstWhere((s) => s.kind == TraceKinds.forRange && s.index > appends.first.index);
      expect(r.objectBefore(id, loop.index), isNull);
      expect(loop.changedObjects, isEmpty);
      // New on the step that made it: the name is marked, the list is not
      // "changed".
      final made = r.steps.firstWhere((s) => s.blockId == 'new');
      expect(made.changed, {'out'});
      expect(made.changedObjects, isEmpty);
      expect(r.objectBefore(id, made.index), isNull);
    });

    test('two names for one list are one object; changing it through either shows in both', () {
      final r = recordTrace(
        _program([
          _set('a', _new(CollKind.array, _nums)),
          _set('b', _list('a')),
          _do(BlockIds.arrAppend, [_list('b'), _n(9)], src: 'append'),
        ]),
        const {},
        RunLimits.standard,
      );
      final last = r.steps.last;
      expect(last.frames.single.vars['a'], last.frames.single.vars['b']);
      expect(_vars(r, last), {'a': [9], 'b': [9]});
    });

    test('the given values are copies: the trace never shows a fixture changing', () {
      final nums = valueFromJson([3, 1]) as ArrayValue;
      final r = recordTrace(
        _program(
          [AssignStmt(target: IndexLValue(_list('nums'), _n(0)), value: _n(8), srcBlockId: 'put')],
          params: [Param('nums', _nums)],
        ),
        {'nums': nums},
        RunLimits.standard,
      );
      expect(_vars(r, r.steps.last), {'nums': [8, 1]});
      expect(nums.toJson(), [3, 1]);
      final id = (r.steps.last.frames.single.vars['nums']! as TraceRef).id;
      expect(
        changedPositions(r.objectBefore(id, r.steps.last.index)! as TraceSequence, r.objectAt(id, r.steps.last.index)! as TraceSequence),
        {0},
      );
    });

    test('map, set, stack, queue and heap are recorded in the order a player reads them', () {
      final heap = ValueType.heapOf(_num);
      final r = recordTrace(
        _program([
          _set('m', _new(CollKind.map, ValueType.mapOf(ValueType.string, _num))),
          _do(BlockIds.mapSet, [_get('m'), const LitExpr('a', type: ValueType.string), _n(1)]),
          _do(BlockIds.mapSet, [_get('m'), const LitExpr('b', type: ValueType.string), _n(2)]),
          _do(BlockIds.mapSet, [_get('m'), const LitExpr('a', type: ValueType.string), _n(5)], src: 'reset'),
          _set('s', _new(CollKind.set, ValueType.setOf(_num))),
          _do(BlockIds.setAdd, [_get('s'), _n(7)]),
          _do(BlockIds.setAdd, [_get('s'), _n(3)], src: 'set-add'),
          _set('st', _new(CollKind.stack, ValueType.stackOf(_num))),
          _do(BlockIds.stackPush, [_get('st'), _n(1)]),
          _do(BlockIds.stackPush, [_get('st'), _n(2)]),
          _do(BlockIds.stackPop, [_get('st')], src: 'pop'),
          _set('q', _new(CollKind.queue, ValueType.queueOf(_num))),
          _do(BlockIds.queueEnq, [_get('q'), _n(1)]),
          _do(BlockIds.queueEnq, [_get('q'), _n(2)]),
          _do(BlockIds.queueDeq, [_get('q')], src: 'deq'),
          _set('h', _new(CollKind.minHeap, heap)),
          _do(BlockIds.heapInsert, [_get('h'), _n(5)]),
          _do(BlockIds.heapInsert, [_get('h'), _n(9)]),
          _do(BlockIds.heapInsert, [_get('h'), _n(2)], src: 'insert'),
        ]),
        const {},
        RunLimits.standard,
      );
      expect(r.result.kind, ResultKind.correct);
      expect(_vars(r, r.steps.last), {
        'm': {'a': 5, 'b': 2},
        's': [7, 3],
        'st': [1],
        'q': [2],
        'h': [2, 5, 9],
      });
      TraceObject at(String name, TraceStep s) => r.objectAt((s.frames.single.vars[name]! as TraceRef).id, s.index)!;
      TraceObject before(String name, TraceStep s) => r.objectBefore((s.frames.single.vars[name]! as TraceRef).id, s.index)!;
      TraceStep step(String block) => r.steps.firstWhere((s) => s.blockId == block);

      expect((at('h', r.steps.last) as TraceSequence).shape, TraceShape.minHeap);
      expect((at('st', r.steps.last) as TraceSequence).shape, TraceShape.stack);
      expect(changedEntries(before('m', step('reset')) as TraceMap, at('m', step('reset')) as TraceMap), {0});
      expect(changedPositions(before('s', step('set-add')) as TraceSequence, at('s', step('set-add')) as TraceSequence), {1});
      // Taking from an end marks nothing: what is left did not change.
      expect(changedPositions(before('st', step('pop')) as TraceSequence, at('st', step('pop')) as TraceSequence), isEmpty);
      expect(changedPositions(before('q', step('deq')) as TraceSequence, at('q', step('deq')) as TraceSequence), isEmpty);
      // The heap lists smallest first; the new 2 is at the front.
      expect(changedPositions(before('h', step('insert')) as TraceSequence, at('h', step('insert')) as TraceSequence), {0});
      // A POP's own value is the step's value.
      expect(_show(r, step('pop').value, step('pop').index), 2);
    });

    test('changedPositions: an insert at the front, a swap, a repeat in a heap', () {
      TraceSequence seq(TraceShape shape, List<num> items) => TraceSequence(shape, [for (final n in items) TraceNumber(n)]);
      expect(changedPositions(seq(TraceShape.deque, [2, 3]), seq(TraceShape.deque, [1, 2, 3])), {0});
      expect(changedPositions(seq(TraceShape.array, [1, 2, 3]), seq(TraceShape.array, [3, 2, 1])), {0, 2});
      expect(changedPositions(seq(TraceShape.array, [1, 2, 3]), seq(TraceShape.array, [1, 3])), {1});
      expect(changedPositions(seq(TraceShape.minHeap, [2, 5]), seq(TraceShape.minHeap, [2, 2, 5])), {1});
      expect(changedPositions(seq(TraceShape.array, []), seq(TraceShape.array, [])), isEmpty);
    });

    test('linked nodes: relinking makes a new version of one node, and a loop in the chain cannot hang it', () {
      final c = ListNodeValue(3);
      final b = ListNodeValue(2, next: c);
      final a = ListNodeValue(1, next: b);
      final node = ValueType.listNode;
      final r = recordTrace(
        _program(
          [
            _set('second', FieldExpr(_get('head', type: node), 'next', type: node)),
            // head.next = head.next.next, then make the tail point back.
            AssignStmt(
              target: FieldLValue(_get('head', type: node), 'next'),
              value: FieldExpr(_get('second', type: node), 'next', type: node),
              srcBlockId: 'skip',
            ),
            AssignStmt(
              target: FieldLValue(FieldExpr(_get('head', type: node), 'next', type: node), 'next'),
              value: _get('head', type: node),
              srcBlockId: 'loop',
            ),
          ],
          params: [Param('head', node)],
        ),
        {'head': a},
        RunLimits.standard,
      );
      expect(r.result.kind, ResultKind.correct);
      expect(_vars(r, r.steps[1]), {'head': [1, [2, [3, null]]], 'second': [2, [3, null]]});
      final skip = r.steps.firstWhere((s) => s.blockId == 'skip');
      expect(_vars(r, skip), {'head': [1, [3, null]], 'second': [2, [3, null]]});
      final headId = (skip.frames.single.vars['head']! as TraceRef).id;
      expect(skip.changedObjects, {headId});
      expect(skip.changed, isEmpty);
      final loop = r.steps.firstWhere((s) => s.blockId == 'loop');
      expect(_vars(r, loop)['head'], [1, [3, '↻']]);
      // The fixture itself is untouched.
      expect(a.next, same(b));
    });

    test('trees and graphs', () {
      final tree = TreeNodeValue(5, left: TreeNodeValue(3), right: TreeNodeValue(8));
      final graph = GraphValue({0: [1, 2], 1: [0], 2: [0]});
      final r = recordTrace(
        _program(
          [
            _do(BlockIds.graphMark, [_get('g', type: ValueType.graph), _n(0)], src: 'mark0'),
            _do(BlockIds.graphMark, [_get('g', type: ValueType.graph), _n(2)], src: 'mark2'),
            _set('near', _call(BlockIds.graphNeighbors, [_get('g', type: ValueType.graph), _n(0)], type: _nums)),
          ],
          params: [Param('root', ValueType.treeNode), Param('g', ValueType.graph)],
        ),
        {'root': tree, 'g': graph},
        RunLimits.standard,
      );
      expect(r.result.kind, ResultKind.correct);
      final last = r.steps.last;
      expect(_vars(r, last)['root'], {
        'v': 5,
        'l': {'v': 3, 'l': null, 'r': null},
        'r': {'v': 8, 'l': null, 'r': null},
      });
      expect(_vars(r, last)['near'], [1, 2]);
      final id = (last.frames.single.vars['g']! as TraceRef).id;
      final marked = r.steps.firstWhere((s) => s.blockId == 'mark2');
      expect((r.objectAt(id, marked.index)! as TraceGraph).visited, [0, 2]);
      expect((r.objectBefore(id, marked.index)! as TraceGraph).visited, [0]);
      expect((r.objectAt(id, 0)! as TraceGraph).visited, isEmpty);
      // The edges never changed: one copy for every version.
      expect(
        identical((r.objectAt(id, 0)! as TraceGraph).adjacency, (r.objectAt(id, marked.index)! as TraceGraph).adjacency),
        isTrue,
      );
      expect(graph.visited, isEmpty);
    });

    test('a failed run records its failure as the last step', () {
      final r = recordTrace(_factorial(), {'n': const NumValue(50)}, const RunLimits(maxDepth: 4));
      expect(r.result.kind, ResultKind.depthLimit);
      expect(r.steps.last.kind, TraceKinds.halt);
      expect(r.steps.last.message, r.result.message);
      expect(r.steps.last.depth, 4);
    });
  });

  group('limits', () {
    final thousand = {'count': const NumValue(1000)};

    test('a long run keeps one window of steps and still knows how long the run is', () {
      const limits = TraceLimits(maxSteps: 100);
      final plain = runProgram(_filler(), thousand, RunLimits.standard);
      final r = recordTrace(_filler(), thousand, RunLimits.standard, traceLimits: limits);
      expect(r.steps, hasLength(100));
      expect(r.firstStep, 0);
      expect(r.endStep, 100);
      expect(r.totalSteps, 2004);
      expect(r.complete, isFalse);
      expect(r.cutByCells, isFalse);
      expect(r.holds(99), isTrue);
      expect(r.holds(100), isFalse);
      expect(r.stepAt(100), isNull);
      // The whole run still ran, and counted what it always counts.
      expect(r.result.kind, ResultKind.correct);
      expect(r.result.metrics.ops, plain.metrics.ops);
      expect(r.result.metrics.peakAlloc, plain.metrics.peakAlloc);
      expect((r.result.output! as ArrayValue).elements, hasLength(1000));
    });

    test('any window says exactly what the whole recording says about its steps', () {
      final whole = recordTrace(_filler(), {'count': const NumValue(60)}, RunLimits.standard);
      expect(whole.complete, isTrue);
      for (final from in [0, 1, 2, 37, 100, whole.totalSteps - 1]) {
        final part = recordTrace(_filler(), {'count': const NumValue(60)}, RunLimits.standard,
            from: from, traceLimits: const TraceLimits(maxSteps: 20));
        expect(part.firstStep, from);
        expect(part.totalSteps, whole.totalSteps);
        expect(part.steps.length, from + 20 > whole.totalSteps ? whole.totalSteps - from : 20);
        for (final step in part.steps) {
          final same = whole.stepAt(step.index)!;
          expect(_stepText(part, step), _stepText(whole, same));
          expect(step.changedObjects.length, same.changedObjects.length, reason: 'step ${step.index}');
          for (final id in step.changedObjects) {
            expect(part.objectBefore(id, step.index), isNotNull);
          }
        }
      }
      // The same holds across calls and returns.
      final fact = recordTrace(_factorial(), {'n': const NumValue(12)}, RunLimits.standard);
      for (var from = 0; from < fact.totalSteps; from += 5) {
        final part = recordTrace(_factorial(), {'n': const NumValue(12)}, RunLimits.standard,
            from: from, traceLimits: const TraceLimits(maxSteps: 7));
        for (final step in part.steps) {
          expect(_stepText(part, step), _stepText(fact, fact.stepAt(step.index)!));
        }
      }
    });

    test('past the end there is nothing, and the count is still right', () {
      final r = recordTrace(_sum(), {'nums': valueFromJson([1])}, RunLimits.standard, from: 500);
      expect(r.steps, isEmpty);
      expect(r.totalSteps, 6);
      expect(r.firstStep, 6);
      expect(r.complete, isFalse);
    });

    test('a window also closes on the values it has looked at, and windows in a row cover the run', () {
      // A list that grows to 1000: every step looks at all of it.
      const limits = TraceLimits(maxSteps: 5000, maxCells: 20000);
      final whole = recordTrace(_filler(), thousand, RunLimits.standard,
          traceLimits: const TraceLimits(maxSteps: 5000, maxCells: 1 << 40));
      expect(whole.complete, isTrue);
      var from = 0;
      var windows = 0;
      while (from < whole.totalSteps) {
        final part = recordTrace(_filler(), thousand, RunLimits.standard, from: from, traceLimits: limits);
        expect(part.firstStep, from);
        expect(part.steps, isNotEmpty);
        // Never far past the allowance: one step's worth at most.
        expect(part.steps.length, lessThan(2004));
        if (part.endStep < whole.totalSteps) expect(part.cutByCells, isTrue);
        expect(_stepText(part, part.steps.last), _stepText(whole, whole.stepAt(part.endStep - 1)!));
        from = part.endStep;
        windows++;
      }
      expect(windows, greaterThan(20));
    });

    test('a window always holds at least one step, however small the allowance', () {
      final r = recordTrace(_filler(), thousand, RunLimits.standard,
          from: 1500, traceLimits: const TraceLimits(maxSteps: 50, maxCells: 1));
      expect(r.steps, hasLength(1));
      expect(r.cutByCells, isTrue);
      expect(r.firstStep, 1500);
    });

    test('deep recursion and a long loop stay small: shared frames, bounded steps', () {
      // 150 frames deep, then back out: without sharing this would hold
      // steps × depth frame copies.
      final r = recordTrace(_factorial(op: BinaryOp.add), {'n': const NumValue(150)}, const RunLimits(maxDepth: 200, maxOps: 1000000));
      expect(r.result.kind, ResultKind.correct);
      expect(r.complete, isTrue);
      final distinct = Set<TraceFrameSnapshot>.identity();
      for (final step in r.steps) {
        distinct.addAll(step.frames);
      }
      expect(r.steps.map((s) => s.depth).reduce((a, b) => a > b ? a : b), 151);
      expect(distinct.length, lessThanOrEqualTo(r.steps.length));

      // A run that never ends on its own is cut by its operation budget; the
      // recording keeps the first window and nothing else.
      final spin = _program([
        _set('x', _n(0)),
        WhileStmt(cond: const LitExpr(true, type: ValueType.boolean), body: [IncStmt(const VarLValue('x'))], srcBlockId: 'w'),
      ]);
      final long = recordTrace(spin, const {}, const RunLimits(maxOps: 300000));
      expect(long.result.kind, ResultKind.operationLimit);
      expect(long.steps, hasLength(TraceLimits.standard.maxSteps));
      expect(long.totalSteps, greaterThan(100000));
      // …and the end of it can be asked for.
      final end = recordTrace(spin, const {}, const RunLimits(maxOps: 300000), from: long.totalSteps - 3);
      expect([for (final s in end.steps) s.kind].last, TraceKinds.halt);
      expect(end.steps, hasLength(3));
    });
  });

  group('cases', () {
    Puzzle shipped(String world, String id) =>
        parsePuzzleJson(File('../../assets/puzzles/$world/$id.json').readAsStringSync());
    Program reference(String world, String id, Puzzle puzzle) {
      final json = jsonDecode(File('../../content/references/$world/$id.json').readAsStringSync()) as Map<String, Object?>;
      final graph = BlockGraph.fromJson(Map<String, dynamic>.from(json['solution']! as Map));
      return const DefaultEngine().lower(graph, puzzle).program!;
    }

    test('a visible case traces exactly as the runner graded it', () {
      for (final (world, id) in [('world_02', 'smallest_cart'), ('world_12', 'power_steps'), ('world_10', 'fewest_rides')]) {
        final puzzle = shipped(world, id);
        final program = reference(world, id, puzzle);
        final suite = const TestRunner().run(program, puzzle);
        expect(puzzle.visibleTests, isNotEmpty);
        for (final graded in suite.visible) {
          final r = traceVisibleCase(program, puzzle, graded.id)!;
          expect(r.result.metrics.ops, graded.run.metrics.ops, reason: '$id ${graded.id}');
          expect(r.result.metrics.peakAlloc, graded.run.metrics.peakAlloc);
          expect(r.result.metrics.peakDepth, graded.run.metrics.peakDepth);
          expect(r.result.kind, ResultKind.correct);
          expect(r.steps.first.kind, TraceKinds.start);
          expect(r.steps.first.frames.single.vars.keys, containsAll(puzzle.io.inputs.map((i) => i.name)));
        }
      }
    });

    test('a hidden case cannot be traced, by its id or any other way in', () {
      for (final (world, id) in [('world_02', 'smallest_cart'), ('world_12', 'power_steps')]) {
        final puzzle = shipped(world, id);
        final program = reference(world, id, puzzle);
        expect(puzzle.hiddenTests, isNotEmpty);
        for (final hidden in puzzle.hiddenTests) {
          // Only meaningful when no visible case shares the id.
          if (puzzle.visibleTests.any((v) => v.id == hidden.id)) continue;
          expect(traceVisibleCase(program, puzzle, hidden.id), isNull, reason: '$id ${hidden.id}');
        }
        expect(traceVisibleCase(program, puzzle, 'no-such-case'), isNull);
      }
    });
  });
}
