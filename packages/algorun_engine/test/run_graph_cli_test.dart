import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/run_graph.dart';

const _allow = [
  'ctrl.foreach',
  'ctrl.if',
  'ctrl.return',
  'var.set',
  'var.get',
  'lit.num',
  'cmp.gt',
  'arr.get',
];

Map<String, Object?> _block(
  String id,
  String catalogId, {
  Map<String, Object?> slots = const {},
  Map<String, Object?> literals = const {},
}) {
  return {
    'id': id,
    'catalogId': catalogId,
    'slots': slots,
    'literals': literals,
    'x': 0,
    'y': 0,
    'collapsed': false,
  };
}

/// SET best = 0; FOR EACH v IN values { IF v > best THEN SET best = v }; RETURN best
Map<String, Object?> _maxGraph() {
  return {
    'blocks': {
      'lit-init': _block('lit-init', 'lit.num', literals: {'value': 0}),
      'set-init': _block(
        'set-init',
        'var.set',
        slots: {'value': {'ref': 'lit-init'}},
        literals: {'name': 'best'},
      ),
      'get-values': _block('get-values', 'var.get', literals: {'name': 'values'}),
      'get-v': _block('get-v', 'var.get', literals: {'name': 'v'}),
      'get-best': _block('get-best', 'var.get', literals: {'name': 'best'}),
      'cond': _block(
        'cond',
        'cmp.gt',
        slots: {
          'left': {'ref': 'get-v'},
          'right': {'ref': 'get-best'},
        },
      ),
      'get-v-update': _block('get-v-update', 'var.get', literals: {'name': 'v'}),
      'set-update': _block(
        'set-update',
        'var.set',
        slots: {'value': {'ref': 'get-v-update'}},
        literals: {'name': 'best'},
      ),
      'branch': _block(
        'branch',
        'ctrl.if',
        slots: {
          'condition': {'ref': 'cond'},
          'then': {'list': ['set-update']},
        },
      ),
      'loop': _block(
        'loop',
        'ctrl.foreach',
        slots: {
          'collection': {'ref': 'get-values'},
          'body': {'list': ['branch']},
        },
        literals: {'name': 'v'},
      ),
      'get-return': _block('get-return', 'var.get', literals: {'name': 'best'}),
      'ret': _block(
        'ret',
        'ctrl.return',
        slots: {'value': {'ref': 'get-return'}},
      ),
    },
    'entryIds': ['set-init', 'loop', 'ret'],
    'variables': {'best': 'num'},
  };
}

Map<String, Object?> _request({
  required List<Map<String, Object?>> programs,
  List<Map<String, Object?>>? cases,
  Map<String, Object?>? limits,
  List<String>? allow,
}) {
  return {
    'protocol': 1,
    'io': {
      'inputs': [
        {'name': 'values', 'type': 'array<num>'},
      ],
      'output': 'num',
    },
    'allow': allow ?? _allow,
    'limits': limits,
    'cases': cases ??
        [
          {
            'id': 'sample',
            'input': {
              'values': [1, 3, 2],
            },
          },
        ],
    'programs': programs,
  };
}

Map<String, Object?> _run(Map<String, Object?> request) {
  return runGraphRequest(jsonEncode(request));
}

void main() {
  test('a real graph runs on a caller-supplied input', () {
    final response = _run(_request(programs: [
      {'id': 'max', 'graph': _maxGraph()},
    ]));
    expect(response['status'], 'ok');
    final programs = response['programs'] as List<Object?>;
    final program = programs.single as Map<String, Object?>;
    expect(program['status'], 'ok');
    final cases = program['cases'] as List<Object?>;
    final result = cases.single as Map<String, Object?>;
    expect(result['status'], 'ok');
    expect(result['output'], 3);
  });

  test('an empty graph is an invalid program and is not run', () {
    final response = _run(_request(programs: [
      {
        'id': 'empty',
        'graph': {'blocks': {}, 'entryIds': [], 'variables': {}},
      },
    ]));
    expect(response['status'], 'ok');
    final program = (response['programs'] as List<Object?>).single as Map<String, Object?>;
    expect(program['status'], 'invalid_program');
    expect(program.containsKey('cases'), isFalse);
  });

  test('a tiny operation budget stops the run', () {
    final response = _run(_request(
      programs: [
        {'id': 'max', 'graph': _maxGraph()},
      ],
      limits: {'maxOps': 1, 'maxDepth': 64, 'maxAlloc': 1000},
    ));
    final program = (response['programs'] as List<Object?>).single as Map<String, Object?>;
    final result = (program['cases'] as List<Object?>).single as Map<String, Object?>;
    expect(result['status'], 'operation_limit');
    expect(result.containsKey('output'), isFalse);
  });

  test('depth zero stops before the body runs', () {
    final response = _run(_request(
      programs: [
        {'id': 'max', 'graph': _maxGraph()},
      ],
      limits: {'maxOps': 1000, 'maxDepth': 0, 'maxAlloc': 1000},
    ));
    final program = (response['programs'] as List<Object?>).single as Map<String, Object?>;
    final result = (program['cases'] as List<Object?>).single as Map<String, Object?>;
    expect(result['status'], 'depth_limit');
  });

  test('reading past the end of the list is a runtime error', () {
    final graph = {
      'blocks': {
        'values': _block('values', 'var.get', literals: {'name': 'values'}),
        'index': _block('index', 'lit.num', literals: {'value': 5}),
        'read': _block(
          'read',
          'arr.get',
          slots: {
            'array': {'ref': 'values'},
            'index': {'ref': 'index'},
          },
        ),
        'ret': _block('ret', 'ctrl.return', slots: {'value': {'ref': 'read'}}),
      },
      'entryIds': ['ret'],
      'variables': <String, String>{},
    };
    final response = _run(_request(programs: [
      {'id': 'oob', 'graph': graph},
    ]));
    final program = (response['programs'] as List<Object?>).single as Map<String, Object?>;
    final result = (program['cases'] as List<Object?>).single as Map<String, Object?>;
    expect(result['status'], 'runtime_error');
  });

  test('the CLI writes one JSON object to stdout and keeps the trace off it', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/run_graph.dart'],
      workingDirectory: Directory.current.path,
    );
    process.stdin.write(jsonEncode(_request(programs: [
      {'id': 'max', 'graph': _maxGraph()},
    ])));
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    final err = await process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    expect(code, 0, reason: err);
    final line = out.trim();
    expect(line.startsWith('{'), isTrue);
    expect(line.contains('\n'), isFalse);
    final decoded = jsonDecode(line) as Map<String, Object?>;
    expect(decoded['status'], 'ok');
    expect(err.contains('"output"'), isFalse);
  });
}
