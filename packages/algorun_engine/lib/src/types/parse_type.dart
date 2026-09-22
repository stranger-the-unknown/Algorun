import 'value_type.dart';

ValueType parseValueType(String spec) {
  return _parseType(spec.trim());
}

ValueType _parseType(String s) {
  var body = s;
  var nullable = false;
  if (body.endsWith('?')) {
    nullable = true;
    body = body.substring(0, body.length - 1).trim();
  }
  final lt = body.indexOf('<');
  if (lt == -1) {
    return ValueType(_atom(body), nullable: nullable);
  }
  if (!body.endsWith('>')) {
    throw FormatException('Invalid type: $s');
  }
  final name = body.substring(0, lt);
  final inner = body.substring(lt + 1, body.length - 1);
  final args = _splitArgs(inner);
  final atom = _atom(name);
  if (atom == TypeAtom.map || atom == TypeAtom.pair) {
    if (args.length != 2) {
      throw FormatException('Type $name expects two parameters.');
    }
    return ValueType(
      atom,
      param: _parseType(args[0]),
      param2: _parseType(args[1]),
      nullable: nullable,
    );
  }
  if (args.length != 1) {
    throw FormatException('Type $name expects one parameter.');
  }
  return ValueType(
    atom,
    param: _parseType(args[0]),
    nullable: nullable,
  );
}

TypeAtom _atom(String name) {
  return switch (name) {
    'void' => TypeAtom.voidType,
    'num' => TypeAtom.number,
    'bool' => TypeAtom.boolean,
    'str' => TypeAtom.string,
    'null' => TypeAtom.nil,
    'array' => TypeAtom.array,
    'map' => TypeAtom.map,
    'set' => TypeAtom.set,
    'stack' => TypeAtom.stack,
    'queue' => TypeAtom.queue,
    'deque' => TypeAtom.deque,
    'heap' => TypeAtom.heap,
    'listNode' => TypeAtom.listNode,
    'treeNode' => TypeAtom.treeNode,
    'graph' => TypeAtom.graph,
    'pair' => TypeAtom.pair,
    _ => throw FormatException('Unknown type: $name'),
  };
}

List<String> _splitArgs(String inner) {
  final out = <String>[];
  final buf = StringBuffer();
  var depth = 0;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '<') depth++;
    if (ch == '>') depth--;
    if (ch == ',' && depth == 0) {
      out.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  final last = buf.toString().trim();
  if (last.isNotEmpty) out.add(last);
  return out;
}
