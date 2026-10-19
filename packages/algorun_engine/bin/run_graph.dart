import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';

/// Stdin/stdout runner for one BlockGraph batch.
///
/// Protocol 1. The machine-readable result is a single JSON object on stdout.
/// Diagnostics go to stderr and are not part of the result. This program does
/// not grade hidden puzzle tests and does not choose among candidates.
Future<void> main() async {
  final raw = await stdin.transform(utf8.decoder).join();
  Map<String, Object?> response;
  try {
    response = runGraphRequest(raw);
  } on Object catch (error, stack) {
    stderr.writeln('run_graph failed: $error');
    stderr.writeln(stack);
    response = {
      'protocol': 1,
      'status': 'bridge_error',
      'message': '$error',
    };
  }
  stdout.writeln(jsonEncode(response));
  exitCode = response['status'] == 'bad_request' ? 2 : 0;
}

/// Decodes [raw] and runs every program. Never throws for a caller mistake.
Map<String, Object?> runGraphRequest(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    return _bad('Request JSON could not be read: ${error.message}');
  }
  if (decoded is! Map) return _bad('Request JSON must be an object.');
  final request = Map<String, Object?>.from(decoded);
  if (request['protocol'] != 1) return _bad('protocol must be 1.');

  final io = _io(request['io']);
  if (io is String) return _bad(io);
  final allow = _allow(request['allow']);
  if (allow is String) return _bad(allow);
  final limits = _limits(request['limits']);
  if (limits is String) return _bad(limits);
  final cases = _cases(request['cases'], (io as IoSpec).inputs);
  if (cases is String) return _bad(cases);
  final programs = request['programs'];
  if (programs is! List) return _bad('programs must be a list.');

  final puzzle = _puzzle(io, allow as Set<String>, limits as RunLimits);
  final engine = const DefaultEngine();
  final reports = <Map<String, Object?>>[];
  for (final item in programs) {
    if (item is! Map) {
      reports.add({
        'id': null,
        'status': 'invalid_program',
        'errors': [
          {'code': 'malformed_graph', 'message': 'A program must be an object.'},
        ],
      });
      continue;
    }
    reports.add(_one(engine, puzzle, Map<String, Object?>.from(item), cases as List<_Case>, limits));
  }
  return {
    'protocol': 1,
    'status': 'ok',
    'programs': reports,
  };
}

Map<String, Object?> _bad(String message) => {
      'protocol': 1,
      'status': 'bad_request',
      'message': message,
    };

final class _Case {
  const _Case(this.id, this.input);
  final String id;
  final Map<String, RuntimeValue> input;
}

Map<String, Object?> _one(
  DefaultEngine engine,
  Puzzle puzzle,
  Map<String, Object?> item,
  List<_Case> cases,
  RunLimits limits,
) {
  final id = item['id'];
  final graphRaw = item['graph'];
  if (id is! String || id.isEmpty) {
    return {
      'id': id,
      'status': 'invalid_program',
      'errors': [
        {'code': 'malformed_graph', 'message': 'A program needs an id.'},
      ],
    };
  }
  if (graphRaw is! Map) {
    return {
      'id': id,
      'status': 'invalid_program',
      'errors': [
        {'code': 'malformed_graph', 'message': 'A program needs a graph object.'},
      ],
    };
  }
  final BlockGraph graph;
  try {
    graph = BlockGraph.fromJson(Map<String, dynamic>.from(graphRaw));
  } on FormatException catch (error) {
    return {
      'id': id,
      'status': 'invalid_program',
      'errors': [
        {'code': 'malformed_graph', 'message': error.message},
      ],
    };
  }
  final lowered = engine.lower(graph, puzzle);
  if (!lowered.ok || lowered.program == null) {
    return {
      'id': id,
      'status': 'invalid_program',
      'errors': [
        for (final error in lowered.errors)
          {
            'code': error.code,
            'message': error.message,
            if (error.blockId != null) 'blockId': error.blockId,
            if (error.port != null) 'port': error.port,
          },
      ],
    };
  }
  final program = lowered.program!;
  final caseReports = <Map<String, Object?>>[];
  for (final testCase in cases) {
    final result = engine.run(program, testCase.input, limits);
    caseReports.add({
      'id': testCase.id,
      'status': _status(result.kind),
      if (result.output != null) 'output': valueToJson(result.output!),
      'ops': result.metrics.ops,
      if (result.message != null) 'message': result.message,
    });
  }
  return {
    'id': id,
    'status': 'ok',
    'cases': caseReports,
  };
}

String _status(ResultKind kind) => switch (kind) {
      ResultKind.correct => 'ok',
      ResultKind.operationLimit => 'operation_limit',
      ResultKind.memoryLimit => 'memory_limit',
      ResultKind.depthLimit => 'depth_limit',
      ResultKind.timeLimit => 'time_limit',
      ResultKind.runtimeError => 'runtime_error',
      ResultKind.invalidProgram => 'invalid_program',
      ResultKind.wrongAnswer => 'runtime_error',
    };

Object? _io(Object? raw) {
  if (raw is! Map) return 'io must be an object.';
  final inputsRaw = raw['inputs'];
  final outputRaw = raw['output'];
  if (inputsRaw is! List || inputsRaw.isEmpty) return 'io.inputs must be a non-empty list.';
  if (outputRaw is! String || outputRaw.isEmpty) return 'io.output must be a type.';
  try {
    final inputs = <IoBinding>[];
    for (final item in inputsRaw) {
      if (item is! Map) return 'Each input must be an object.';
      final name = item['name'];
      final type = item['type'];
      if (name is! String || name.isEmpty) return 'Each input needs a name.';
      if (type is! String || type.isEmpty) return 'Each input needs a type.';
      inputs.add(IoBinding(name: name, type: parseValueType(type)));
    }
    return IoSpec(inputs: inputs, output: parseValueType(outputRaw));
  } on FormatException catch (error) {
    return 'io type is not valid: ${error.message}';
  }
}

Object? _allow(Object? raw) {
  if (raw is! List || raw.isEmpty) return 'allow must be a non-empty list of block ids.';
  final allow = <String>{};
  for (final id in raw) {
    if (id is! String || !BlockIds.exists(id)) return 'Unknown block in allow: $id';
    allow.add(id);
  }
  return allow;
}

Object? _limits(Object? raw) {
  var maxOps = 10000;
  var maxDepth = 64;
  var maxAlloc = 1000;
  if (raw == null) {
    return RunLimits(maxOps: maxOps, maxDepth: maxDepth, maxAlloc: maxAlloc);
  }
  if (raw is! Map) return 'limits must be an object.';
  final ops = raw['maxOps'];
  final depth = raw['maxDepth'];
  final alloc = raw['maxAlloc'];
  if (ops != null) {
    if (ops is! int || ops < 0) return 'limits.maxOps must be a non-negative integer.';
    maxOps = ops;
  }
  if (depth != null) {
    if (depth is! int || depth < 0) return 'limits.maxDepth must be a non-negative integer.';
    maxDepth = depth;
  }
  if (alloc != null) {
    if (alloc is! int || alloc < 0) return 'limits.maxAlloc must be a non-negative integer.';
    maxAlloc = alloc;
  }
  return RunLimits(maxOps: maxOps, maxDepth: maxDepth, maxAlloc: maxAlloc);
}

Object? _cases(Object? raw, List<IoBinding> inputs) {
  if (raw is! List) return 'cases must be a list.';
  final cases = <_Case>[];
  for (final item in raw) {
    if (item is! Map) return 'Each case must be an object.';
    final id = item['id'];
    final input = item['input'];
    if (id is! String || id.isEmpty) return 'Each case needs an id.';
    if (input is! Map) return 'Case $id needs an input object.';
    try {
      final values = <String, RuntimeValue>{};
      for (final binding in inputs) {
        if (!input.containsKey(binding.name)) return 'Case $id is missing ${binding.name}.';
        values[binding.name] = valueFromJson(input[binding.name], type: binding.type);
      }
      cases.add(_Case(id, values));
    } on FixtureFormatException catch (error) {
      return 'Case $id input is not valid: $error';
    }
  }
  return cases;
}

Puzzle _puzzle(Object? io, Set<String> allow, RunLimits limits) {
  return Puzzle(
    id: 'run-graph',
    title: 'run-graph',
    world: 'bridge',
    mode: PuzzleMode.build,
    tier: PuzzleTier.t1,
    story: '',
    io: io as IoSpec,
    blocks: BlockPolicy(allow: allow),
    limits: PerformanceTarget(
      maxOps: limits.maxOps,
      maxDepth: limits.maxDepth,
      maxAlloc: limits.maxAlloc,
    ),
    visibleTests: const [],
    hiddenTests: const [],
    outputValidator: ValidatorId.equal,
  );
}
