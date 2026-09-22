import 'dart:convert';

import '../types/parse_type.dart';
import '../types/value_type.dart';

/// Closed intermediate representation. The interpreter never sees a BlockGraph.
///
/// UI metadata (position, collapsed, selection) is not represented here.
final class Program {
  const Program({
    required this.functions,
    this.entry = 'main',
  });

  final List<FnDecl> functions;
  final String entry;

  static const empty = Program(functions: []);

  FnDecl? function(String name) {
    for (final fn in functions) {
      if (fn.name == name) return fn;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'entry': entry,
        'functions': [for (final f in functions) f.toJson()],
      };

  String toJsonString() => jsonEncode(toJson());

  static Program fromJson(Map<String, dynamic> json) {
    final entry = json['entry'] as String? ?? 'main';
    final raw = json['functions'];
    if (raw is! List) {
      throw const FormatException('Program needs a functions list.');
    }
    return Program(
      entry: entry,
      functions: [
        for (final item in raw)
          FnDecl.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  static Program fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Program JSON must be an object.');
    }
    return fromJson(Map<String, dynamic>.from(decoded));
  }
}

final class FnDecl {
  const FnDecl({
    required this.name,
    required this.params,
    required this.body,
    this.returnType,
    this.srcBlockId,
  });

  final String name;
  final List<Param> params;
  final List<Stmt> body;
  final ValueType? returnType;
  final String? srcBlockId;

  Map<String, Object?> toJson() => {
        'name': name,
        'params': [for (final p in params) p.toJson()],
        if (returnType != null) 'returnType': returnType.toString(),
        'body': [for (final s in body) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };

  static FnDecl fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Function needs a name.');
    }
    final paramsRaw = json['params'];
    final bodyRaw = json['body'];
    if (paramsRaw is! List || bodyRaw is! List) {
      throw const FormatException('Function needs params and body.');
    }
    return FnDecl(
      name: name,
      params: [
        for (final item in paramsRaw)
          Param.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      body: [
        for (final item in bodyRaw)
          Stmt.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      returnType: json['returnType'] is String
          ? parseValueType(json['returnType'] as String)
          : null,
      srcBlockId: json['src'] as String?,
    );
  }
}

final class Param {
  const Param(this.name, this.type);
  final String name;
  final ValueType type;

  Map<String, Object?> toJson() => {'name': name, 'type': type.toString()};

  static Param fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final type = json['type'];
    if (name is! String || type is! String) {
      throw const FormatException('Parameter needs name and type.');
    }
    return Param(name, parseValueType(type));
  }
}

sealed class Stmt {
  const Stmt({this.srcBlockId});
  final String? srcBlockId;

  Map<String, Object?> toJson();

  static Stmt fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String) {
      throw const FormatException('Statement is missing a kind.');
    }
    final src = json['src'] as String?;
    return switch (kind) {
      'seq' => SeqStmt(
          [
            for (final item in json['stmts'] as List)
              Stmt.fromJson(Map<String, dynamic>.from(item as Map)),
          ],
          srcBlockId: src,
        ),
      'if' => IfStmt(
          cond: Expr.fromJson(Map<String, dynamic>.from(json['cond'] as Map)),
          thenBody: _stmtList(json['then']),
          elseBody: json.containsKey('else') ? _stmtList(json['else']) : null,
          srcBlockId: src,
        ),
      'while' => WhileStmt(
          cond: Expr.fromJson(Map<String, dynamic>.from(json['cond'] as Map)),
          body: _stmtList(json['body']),
          srcBlockId: src,
        ),
      'forRange' => ForRangeStmt(
          loopVar: json['loopVar'] as String,
          start: Expr.fromJson(Map<String, dynamic>.from(json['start'] as Map)),
          end: Expr.fromJson(Map<String, dynamic>.from(json['end'] as Map)),
          step: json['step'] is Map
              ? Expr.fromJson(Map<String, dynamic>.from(json['step'] as Map))
              : null,
          body: _stmtList(json['body']),
          srcBlockId: src,
        ),
      'forEach' => ForEachStmt(
          itemVar: json['itemVar'] as String,
          indexVar: json['indexVar'] as String?,
          collection: Expr.fromJson(
            Map<String, dynamic>.from(json['collection'] as Map),
          ),
          body: _stmtList(json['body']),
          srcBlockId: src,
        ),
      'break' => BreakStmt(srcBlockId: src),
      'continue' => ContinueStmt(srcBlockId: src),
      'return' => ReturnStmt(
          value: json['value'] is Map
              ? Expr.fromJson(Map<String, dynamic>.from(json['value'] as Map))
              : null,
          srcBlockId: src,
        ),
      'assign' => AssignStmt(
          target: LValue.fromJson(
            Map<String, dynamic>.from(json['target'] as Map),
          ),
          value: Expr.fromJson(Map<String, dynamic>.from(json['value'] as Map)),
          srcBlockId: src,
        ),
      'inc' => IncStmt(
          LValue.fromJson(Map<String, dynamic>.from(json['target'] as Map)),
          srcBlockId: src,
        ),
      'dec' => DecStmt(
          LValue.fromJson(Map<String, dynamic>.from(json['target'] as Map)),
          srcBlockId: src,
        ),
      'expr' => ExprStmt(
          Expr.fromJson(Map<String, dynamic>.from(json['expr'] as Map)),
          srcBlockId: src,
        ),
      _ => throw FormatException('Unknown statement kind: $kind'),
    };
  }
}

List<Stmt> _stmtList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      Stmt.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

final class SeqStmt extends Stmt {
  const SeqStmt(this.stmts, {super.srcBlockId});
  final List<Stmt> stmts;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'seq',
        'stmts': [for (final s in stmts) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class IfStmt extends Stmt {
  const IfStmt({
    required this.cond,
    required this.thenBody,
    this.elseBody,
    super.srcBlockId,
  });
  final Expr cond;
  final List<Stmt> thenBody;
  final List<Stmt>? elseBody;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'if',
        'cond': cond.toJson(),
        'then': [for (final s in thenBody) s.toJson()],
        if (elseBody != null) 'else': [for (final s in elseBody!) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class WhileStmt extends Stmt {
  const WhileStmt({
    required this.cond,
    required this.body,
    super.srcBlockId,
  });
  final Expr cond;
  final List<Stmt> body;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'while',
        'cond': cond.toJson(),
        'body': [for (final s in body) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class ForRangeStmt extends Stmt {
  const ForRangeStmt({
    required this.loopVar,
    required this.start,
    required this.end,
    required this.body,
    this.step,
    super.srcBlockId,
  });
  final String loopVar;
  final Expr start;
  final Expr end;
  final Expr? step;
  final List<Stmt> body;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'forRange',
        'loopVar': loopVar,
        'start': start.toJson(),
        'end': end.toJson(),
        if (step != null) 'step': step!.toJson(),
        'body': [for (final s in body) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class ForEachStmt extends Stmt {
  const ForEachStmt({
    required this.itemVar,
    required this.collection,
    required this.body,
    this.indexVar,
    super.srcBlockId,
  });
  final String itemVar;
  final String? indexVar;
  final Expr collection;
  final List<Stmt> body;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'forEach',
        'itemVar': itemVar,
        if (indexVar != null) 'indexVar': indexVar,
        'collection': collection.toJson(),
        'body': [for (final s in body) s.toJson()],
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class BreakStmt extends Stmt {
  const BreakStmt({super.srcBlockId});

  @override
  Map<String, Object?> toJson() => {
        'kind': 'break',
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class ContinueStmt extends Stmt {
  const ContinueStmt({super.srcBlockId});

  @override
  Map<String, Object?> toJson() => {
        'kind': 'continue',
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class ReturnStmt extends Stmt {
  const ReturnStmt({this.value, super.srcBlockId});
  final Expr? value;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'return',
        if (value != null) 'value': value!.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class AssignStmt extends Stmt {
  const AssignStmt({
    required this.target,
    required this.value,
    super.srcBlockId,
  });
  final LValue target;
  final Expr value;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'assign',
        'target': target.toJson(),
        'value': value.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class IncStmt extends Stmt {
  const IncStmt(this.target, {super.srcBlockId});
  final LValue target;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'inc',
        'target': target.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class DecStmt extends Stmt {
  const DecStmt(this.target, {super.srcBlockId});
  final LValue target;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'dec',
        'target': target.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class ExprStmt extends Stmt {
  const ExprStmt(this.expr, {super.srcBlockId});
  final Expr expr;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'expr',
        'expr': expr.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

sealed class Expr {
  const Expr({required this.type, this.srcBlockId});
  final ValueType type;
  final String? srcBlockId;

  Map<String, Object?> toJson();

  static Expr fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind is! String) {
      throw const FormatException('Value is missing a kind.');
    }
    final type = parseValueType(json['type'] as String? ?? 'void');
    final src = json['src'] as String?;
    return switch (kind) {
      'lit' => LitExpr(json['value'], type: type, srcBlockId: src),
      'var' => VarExpr(json['name'] as String, type: type, srcBlockId: src),
      'null' => NullExpr(type: type, srcBlockId: src),
      'binary' => BinaryExpr(
          _binaryOp(json['op'] as String),
          Expr.fromJson(Map<String, dynamic>.from(json['left'] as Map)),
          Expr.fromJson(Map<String, dynamic>.from(json['right'] as Map)),
          type: type,
          srcBlockId: src,
        ),
      'unary' => UnaryExpr(
          _unaryOp(json['op'] as String),
          Expr.fromJson(Map<String, dynamic>.from(json['arg'] as Map)),
          type: type,
          srcBlockId: src,
        ),
      'call' => CallExpr(
          json['callee'] as String,
          [
            for (final item in json['args'] as List? ?? const [])
              Expr.fromJson(Map<String, dynamic>.from(item as Map)),
          ],
          type: type,
          srcBlockId: src,
        ),
      'index' => IndexExpr(
          Expr.fromJson(Map<String, dynamic>.from(json['collection'] as Map)),
          Expr.fromJson(Map<String, dynamic>.from(json['index'] as Map)),
          type: type,
          srcBlockId: src,
        ),
      'field' => FieldExpr(
          Expr.fromJson(Map<String, dynamic>.from(json['object'] as Map)),
          json['field'] as String,
          type: type,
          srcBlockId: src,
        ),
      'new' => NewExpr(
          _collKind(json['coll'] as String),
          args: [
            for (final item in json['args'] as List? ?? const [])
              Expr.fromJson(Map<String, dynamic>.from(item as Map)),
          ],
          type: type,
          srcBlockId: src,
        ),
      _ => throw FormatException('Unknown value kind: $kind'),
    };
  }
}

final class LitExpr extends Expr {
  const LitExpr(this.value, {required super.type, super.srcBlockId});
  final Object? value;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'lit',
        'value': value,
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class VarExpr extends Expr {
  const VarExpr(this.name, {required super.type, super.srcBlockId});
  final String name;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'var',
        'name': name,
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class NullExpr extends Expr {
  const NullExpr({super.type = ValueType.nil, super.srcBlockId});

  @override
  Map<String, Object?> toJson() => {
        'kind': 'null',
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

enum BinaryOp {
  add,
  sub,
  mul,
  div,
  mod,
  eq,
  ne,
  lt,
  le,
  gt,
  ge,
  and,
  or,
  min,
  max,

  /// Division rounded down to a whole number (Milestone 7).
  floorDiv,
}

enum UnaryOp { not, abs, neg }

final class BinaryExpr extends Expr {
  const BinaryExpr(
    this.op,
    this.left,
    this.right, {
    required super.type,
    super.srcBlockId,
  });
  final BinaryOp op;
  final Expr left;
  final Expr right;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'binary',
        'op': op.name,
        'left': left.toJson(),
        'right': right.toJson(),
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class UnaryExpr extends Expr {
  const UnaryExpr(this.op, this.arg, {required super.type, super.srcBlockId});
  final UnaryOp op;
  final Expr arg;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'unary',
        'op': op.name,
        'arg': arg.toJson(),
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class CallExpr extends Expr {
  const CallExpr(
    this.callee,
    this.args, {
    required super.type,
    super.srcBlockId,
  });
  final String callee;
  final List<Expr> args;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'call',
        'callee': callee,
        'args': [for (final a in args) a.toJson()],
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class IndexExpr extends Expr {
  const IndexExpr(
    this.collection,
    this.index, {
    required super.type,
    super.srcBlockId,
  });
  final Expr collection;
  final Expr index;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'index',
        'collection': collection.toJson(),
        'index': index.toJson(),
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class FieldExpr extends Expr {
  const FieldExpr(
    this.object,
    this.field, {
    required super.type,
    super.srcBlockId,
  });
  final Expr object;
  final String field;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'field',
        'object': object.toJson(),
        'field': field,
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

enum CollKind { array, map, set, stack, queue, deque }

final class NewExpr extends Expr {
  const NewExpr(
    this.kind, {
    this.args = const [],
    required super.type,
    super.srcBlockId,
  });
  final CollKind kind;
  final List<Expr> args;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'new',
        'coll': kind.name,
        'args': [for (final a in args) a.toJson()],
        'type': type.toString(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

sealed class LValue {
  const LValue({this.srcBlockId});
  final String? srcBlockId;

  Map<String, Object?> toJson();

  static LValue fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final src = json['src'] as String?;
    return switch (kind) {
      'var' => VarLValue(json['name'] as String, srcBlockId: src),
      'index' => IndexLValue(
          Expr.fromJson(Map<String, dynamic>.from(json['collection'] as Map)),
          Expr.fromJson(Map<String, dynamic>.from(json['index'] as Map)),
          srcBlockId: src,
        ),
      'field' => FieldLValue(
          Expr.fromJson(Map<String, dynamic>.from(json['object'] as Map)),
          json['field'] as String,
          srcBlockId: src,
        ),
      _ => throw FormatException('Unknown target kind: $kind'),
    };
  }
}

final class VarLValue extends LValue {
  const VarLValue(this.name, {super.srcBlockId});
  final String name;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'var',
        'name': name,
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class IndexLValue extends LValue {
  const IndexLValue(this.collection, this.index, {super.srcBlockId});
  final Expr collection;
  final Expr index;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'index',
        'collection': collection.toJson(),
        'index': index.toJson(),
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

final class FieldLValue extends LValue {
  const FieldLValue(this.object, this.field, {super.srcBlockId});
  final Expr object;
  final String field;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'field',
        'object': object.toJson(),
        'field': field,
        if (srcBlockId != null) 'src': srcBlockId,
      };
}

BinaryOp _binaryOp(String name) {
  for (final op in BinaryOp.values) {
    if (op.name == name) return op;
  }
  throw FormatException('Unknown operator: $name');
}

UnaryOp _unaryOp(String name) {
  for (final op in UnaryOp.values) {
    if (op.name == name) return op;
  }
  throw FormatException('Unknown operator: $name');
}

CollKind _collKind(String name) {
  for (final k in CollKind.values) {
    if (k.name == name) return k;
  }
  throw FormatException('Unknown collection: $name');
}
