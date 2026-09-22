import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  group('compatible connections', () {
    test('bool expression into IF condition', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final lit = _add(h, BlockIds.litBool);
      expect(_connect(h, lit, 'out', iff, 'condition').ok, isTrue);
    });

    test('num expression into ARRAY.GET index', () {
      final h = _hist();
      final get = _add(h, BlockIds.arrGet);
      final lit = _add(h, BlockIds.litNum);
      expect(_connect(h, lit, 'out', get, 'index').ok, isTrue);
    });

    test('WHILE condition accepts bool', () {
      final h = _hist();
      final w = _add(h, BlockIds.ctrlWhile);
      final lit = _add(h, BlockIds.litBool);
      expect(_connect(h, lit, 'out', w, 'condition').ok, isTrue);
    });

    test('SET.value matches declared variable type', () {
      final h = _hist(variables: {'x': ValueType.number});
      final set = _add(h, BlockIds.varSet, literals: {'name': 'x'});
      final numLit = _add(h, BlockIds.litNum);
      expect(_connect(h, numLit, 'out', set, 'value').ok, isTrue);
    });
  });

  group('incompatible connections', () {
    test('num does not fit IF condition', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final lit = _add(h, BlockIds.litNum);
      final r = _connect(h, lit, 'out', iff, 'condition');
      expect(r.ok, isFalse);
      expect(r.decision.code, 'type_mismatch');
      expect(r.decision.message, 'This block needs a condition.');
    });

    test('bool does not fit ARRAY.GET index', () {
      final h = _hist();
      final get = _add(h, BlockIds.arrGet);
      final lit = _add(h, BlockIds.litBool);
      expect(_connect(h, lit, 'out', get, 'index').ok, isFalse);
    });

    test('SET.value rejects the wrong variable type', () {
      final h = _hist(variables: {'x': ValueType.number});
      final set = _add(h, BlockIds.varSet, literals: {'name': 'x'});
      final lit = _add(h, BlockIds.litBool);
      expect(_connect(h, lit, 'out', set, 'value').ok, isFalse);
    });

    test('undefined variable cannot receive a value', () {
      final h = _hist();
      final set = _add(h, BlockIds.varSet, literals: {'name': 'ghost'});
      final lit = _add(h, BlockIds.litNum);
      final r = _connect(h, lit, 'out', set, 'value');
      expect(r.ok, isFalse);
      expect(r.decision.code, 'undefined_variable');
    });

    test('input-to-input is the wrong direction', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final get = _add(h, BlockIds.arrGet);
      final d = GraphTyping.canConnect(
        h.current,
        from: PortRef(get, 'index'),
        to: PortRef(iff, 'condition'),
      );
      expect(d.allowed, isFalse);
      expect(d.code, 'wrong_direction');
    });
  });

  group('nullable vs non-nullable', () {
    test('null fits a nullable hole and not a condition', () {
      final h = _hist();
      final n = _add(h, BlockIds.litNull);
      final setNext = _add(h, BlockIds.llSetNext);
      expect(_connect(h, n, 'out', setNext, 'next').ok, isTrue);
      final iff = _add(h, BlockIds.ctrlIf);
      expect(_connect(h, n, 'out', iff, 'condition').ok, isFalse);
    });

    test('nullable node does not fit a required node hole', () {
      final h = _hist();
      final next = _add(h, BlockIds.llNext);
      final val = _add(h, BlockIds.llValue);
      expect(_connect(h, next, 'out', val, 'node').ok, isFalse);
    });
  });

  group('array generic compatibility', () {
    test('GET output follows the connected array element type', () {
      final h = _hist();
      final arr = _add(h, BlockIds.newArray, literals: {'of': 'num'});
      final get = _add(h, BlockIds.arrGet);
      expect(_connect(h, arr, 'out', get, 'array').ok, isTrue);
      expect(GraphTyping.resolveOutput(h.current, get), ValueType.number);
      final iff = _add(h, BlockIds.ctrlIf);
      expect(_connect(h, get, 'out', iff, 'condition').ok, isFalse);
      final add = _add(h, BlockIds.arithAdd);
      expect(_connect(h, get, 'out', add, 'left').ok, isTrue);
    });

    test('array<num> value does not fit an array<bool> hole', () {
      final h = _hist();
      final nums = _add(h, BlockIds.newArray, literals: {'of': 'num'});
      final app = _add(h, BlockIds.arrAppend);
      expect(_connect(h, nums, 'out', app, 'array').ok, isTrue);
      final flag = _add(h, BlockIds.litBool);
      expect(_connect(h, flag, 'out', app, 'value').ok, isFalse);
    });
  });

  group('statement nesting', () {
    test('break is rejected outside a loop', () {
      final h = _hist();
      final br = _add(h, BlockIds.ctrlBreak);
      expect(_attach(h, br, PortRef.mainBody).ok, isFalse);
      final w = _add(h, BlockIds.ctrlWhile);
      expect(_attach(h, br, PortRef(w, 'body')).ok, isTrue);
    });

    test('instructions nest in IF then and WHILE body', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final w = _add(h, BlockIds.ctrlWhile);
      final ret = _add(h, BlockIds.ctrlReturn);
      expect(_attach(h, ret, PortRef(iff, 'then')).ok, isTrue);
      final ret2 = _add(h, BlockIds.ctrlReturn);
      expect(_attach(h, ret2, PortRef(w, 'body')).ok, isTrue);
    });

    test('values cannot sit in a statement stack', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final lit = _add(h, BlockIds.litNum);
      final d = GraphTyping.canConnect(
        h.current,
        from: PortRef(lit, 'out'),
        to: PortRef(iff, 'then'),
      );
      expect(d.allowed, isFalse);
      expect(d.code, 'wrong_kind');
    });

    test('instructions cannot sit in a value hole', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final ret = _add(h, BlockIds.ctrlReturn);
      final d = GraphTyping.canConnect(
        h.current,
        from: PortRef(ret, 'stmt'),
        to: PortRef(iff, 'condition'),
      );
      expect(d.allowed, isFalse);
      expect(d.code, 'wrong_kind');
    });
  });

  group('IF/ELSE structural rules', () {
    test('ELSE only fits the IF else port', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final els = _add(h, BlockIds.ctrlElse);
      expect(
        h.apply(ConnectCommand(
          from: PortRef(els, 'clause'),
          to: PortRef(iff, 'else'),
        )).ok,
        isTrue,
      );
      final w = _add(h, BlockIds.ctrlWhile);
      final els2 = _add(h, BlockIds.ctrlElse);
      expect(
        h.apply(ConnectCommand(
          from: PortRef(els2, 'clause'),
          to: PortRef(w, 'body'),
        )).ok,
        isFalse,
      );
    });

    test('a normal instruction cannot occupy the ELSE port', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final ret = _add(h, BlockIds.ctrlReturn);
      expect(_attach(h, ret, PortRef(iff, 'else')).ok, isFalse);
    });

    test('THEN and ELSE hold independent stacks', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final els = _add(h, BlockIds.ctrlElse);
      expect(
        h.apply(ConnectCommand(
          from: PortRef(els, 'clause'),
          to: PortRef(iff, 'else'),
        )).ok,
        isTrue,
      );
      final a = _add(h, BlockIds.ctrlReturn);
      final b = _add(h, BlockIds.ctrlReturn);
      expect(_attach(h, a, PortRef(iff, 'then')).ok, isTrue);
      expect(_attach(h, b, PortRef(els, 'body')).ok, isTrue);
    });
  });

  group('duplicate and disconnect', () {
    test('duplicate plug into a filled hole is rejected', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final a = _add(h, BlockIds.litBool);
      final b = _add(h, BlockIds.litBool);
      expect(_connect(h, a, 'out', iff, 'condition').ok, isTrue);
      expect(_connect(h, b, 'out', iff, 'condition').ok, isFalse);
    });

    test('a block cannot attach in two places', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final w = _add(h, BlockIds.ctrlWhile);
      final ret = _add(h, BlockIds.ctrlReturn);
      expect(_attach(h, ret, PortRef(iff, 'then')).ok, isTrue);
      expect(_attach(h, ret, PortRef(w, 'body')).ok, isFalse);
    });

    test('disconnect frees the hole', () {
      final h = _hist();
      final iff = _add(h, BlockIds.ctrlIf);
      final a = _add(h, BlockIds.litBool);
      final b = _add(h, BlockIds.litBool);
      expect(_connect(h, a, 'out', iff, 'condition').ok, isTrue);
      expect(h.apply(DisconnectCommand(a)).ok, isTrue);
      expect(_connect(h, b, 'out', iff, 'condition').ok, isTrue);
    });
  });
}

GraphHistory _hist({Map<String, ValueType> variables = const {}}) =>
    GraphHistory(BlockGraph(blocks: const {}, variables: variables));

String _add(
  GraphHistory h,
  String catalogId, {
  Map<String, Object?> literals = const {},
}) {
  final before = h.current.blocks.keys.toSet();
  final r = h.apply(AddBlockCommand(catalogId: catalogId, literals: literals));
  expect(r.ok, isTrue, reason: r.decision.message);
  return r.graph.blocks.keys.firstWhere((k) => !before.contains(k));
}

GraphMutationResult _connect(
  GraphHistory h,
  String from,
  String fromPort,
  String to,
  String toPort,
) {
  return h.apply(ConnectCommand(
    from: PortRef(from, fromPort),
    to: PortRef(to, toPort),
  ));
}

GraphMutationResult _attach(GraphHistory h, String blockId, PortRef to) {
  return h.apply(AttachStatementCommand(blockId: blockId, to: to));
}
