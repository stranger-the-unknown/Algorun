// Runs the algorun-lang conformance suite against this engine (L3).
//
// The suite lives in the `stranger-the-unknown/algorun-lang` repository
// (`conformance/`, format in its README); it is not copied here. Point this
// tool at a clone:
//
//   dart run tool/conformance.dart <algorun-lang>/conformance \
//       [--known tool/conformance_known.txt]
//
// Every case is run and its whole expectation compared: status, output, ops,
// peakAlloc, peakDepth, message and blockId; lowering cases compare the
// errors; every stored program must also survive `Program.fromJson` →
// `toJson` unchanged.
//
// `--known` names the cases where the game is known to differ from
// algorun-lang, one per line: `<file relative to the suite>[#<case id>]`,
// then the reason. A known case must really differ: one that starts to agree
// is reported, so the list cannot go stale. Files with `parseError` belong to
// the text form, which the game does not have, and are counted as not run.
//
// Exit code 0 when every case outside the list agrees and every case inside
// it differs.
import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';

Future<void> main(List<String> args) async {
  final known = <String, String>{};
  final roots = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--known') {
      known.addAll(_readKnown(args[++i]));
    } else {
      roots.add(args[i]);
    }
  }
  if (roots.length != 1) {
    stderr.writeln(
      'usage: conformance.dart <conformance dir> [--known <file>]',
    );
    exit(64);
  }
  exit(_check(roots.single, known));
}

Map<String, String> _readKnown(String path) {
  final out = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#')) continue;
    final space = text.indexOf(RegExp(r'\s'));
    out[space < 0 ? text : text.substring(0, space)] = space < 0
        ? ''
        : text.substring(space).trim();
  }
  return out;
}

Map<String, Object?> _runCase(
  Map<String, dynamic> doc,
  Map<String, dynamic> c,
) {
  final program = Program.fromJson(
    Map<String, dynamic>.from(doc['program'] as Map),
  );
  final inputs = [
    for (final i in doc['inputs'] as List) Map<String, dynamic>.from(i as Map),
  ];
  final lim = Map<String, dynamic>.from((doc['limits'] ?? {}) as Map);
  final limits = RunLimits(
    maxOps: (c['maxOps'] ?? lim['maxOps'] ?? 100000) as int,
    maxDepth: (lim['maxDepth'] ?? 256) as int,
    maxAlloc: (lim['maxAlloc'] ?? 10000) as int,
    maxArrayLen: (lim['maxArrayLen'] ?? 10000) as int,
    maxMapSize: (lim['maxMapSize'] ?? 10000) as int,
  );
  final input = <String, RuntimeValue>{
    for (final i in inputs)
      i['name'] as String: valueFromJson(
        (c['input'] as Map)[i['name']],
        type: parseValueType(i['type'] as String),
      ),
  };
  final r = Interpreter(program, limits: limits).run(input);
  return {
    'status': r.kind.name,
    if (r.output != null) 'output': valueToJson(r.output!),
    'ops': r.metrics.ops,
    'peakAlloc': r.metrics.peakAlloc,
    'peakDepth': r.metrics.peakDepth,
    if (r.message != null) 'message': r.message,
    if (r.blockId != null) 'blockId': r.blockId,
  };
}

Map<String, Object?> _lowerCase(Map<String, dynamic> doc) {
  final io = IoSpec(
    inputs: [
      for (final i in doc['inputs'] as List)
        IoBinding(
          name: i['name'] as String,
          type: parseValueType(i['type'] as String),
        ),
    ],
    output: parseValueType(doc['output'] as String),
  );
  final puzzle = Puzzle(
    id: 'lower',
    title: 'lower',
    world: 'conformance',
    mode: PuzzleMode.build,
    tier: PuzzleTier.t1,
    story: '',
    io: io,
    blocks: BlockPolicy(allow: BlockIds.all),
    limits: const PerformanceTarget(maxOps: 100000),
    visibleTests: const [],
    hiddenTests: const [],
    outputValidator: ValidatorId.equal,
  );
  final graph = BlockGraph.fromJson(
    Map<String, dynamic>.from(doc['graph'] as Map),
  );
  final r = const DefaultEngine().lower(graph, puzzle);
  if (!r.ok || r.program == null) {
    return {
      'ok': false,
      'errors': [
        for (final e in r.errors)
          {
            'code': e.code,
            'message': e.message,
            if (e.blockId != null) 'blockId': e.blockId,
          },
      ],
    };
  }
  return {'ok': true};
}

int _check(String root, Map<String, String> known) {
  final base = Directory(root).absolute.path;
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var agree = 0, differ = 0, notRun = 0;
  final problems = <String>[];
  final unused = known.keys.toSet();
  final perDir = <String, List<int>>{};

  void record(String file, String? caseId, bool same, String detail) {
    final key = caseId == null ? file : '$file#$caseId';
    final expected = known.containsKey(key) || known.containsKey(file);
    unused
      ..remove(key)
      ..remove(file);
    final counts = perDir.putIfAbsent(file.split('/').first, () => [0, 0]);
    if (same) {
      counts[0]++;
      agree++;
      // A whole-file entry covers cases that may individually agree.
      if (known.containsKey(key)) problems.add('KNOWN CASE NOW AGREES $key');
    } else {
      counts[1]++;
      differ++;
      if (!expected) problems.add('DIFFERS $key\n$detail');
    }
  }

  for (final f in files) {
    final file = f.absolute.path.substring(base.length + 1);
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    if (doc.containsKey('parseError')) {
      notRun++;
      continue;
    }
    if (doc.containsKey('graph')) {
      final got = jsonEncode(_lowerCase(doc));
      final want = jsonEncode(doc['lowerExpect']);
      record(file, 'lower', got == want, '  want $want\n  got  $got');
      if (doc['program'] == null) continue;
    }
    final ir = jsonEncode(doc['program']);
    String again;
    try {
      again = Program.fromJson(Map<String, dynamic>.from(doc['program'] as Map))
          .toJsonString();
    } on Object catch (e) {
      again = 'THROWS $e';
    }
    if (again.startsWith('THROWS') || jsonEncode(jsonDecode(again)) != ir) {
      record(
        file,
        'roundtrip',
        false,
        '  IR JSON does not round-trip: ${again.split('\n').first}',
      );
      continue;
    }
    for (final c in doc['cases'] as List) {
      final m = c as Map<String, dynamic>;
      final want = jsonEncode(m['expect']);
      String got;
      try {
        got = jsonEncode(_runCase(doc, m));
      } on Object catch (e) {
        got = 'THROWS $e';
      }
      record(file, m['id'] as String, got == want, '  want $want\n  got  $got');
    }
  }

  for (final entry in perDir.entries) {
    stdout.writeln(
      '${entry.key.padRight(6)} agree ${entry.value[0]}, differ ${entry.value[1]}',
    );
  }
  for (final key in unused) {
    problems.add('KNOWN ENTRY MATCHES NOTHING $key');
  }
  problems.forEach(stderr.writeln);
  stdout.writeln(
    'conformance: ${files.length} files, $agree cases agree, $differ differ '
    '(${differ - problems.where((p) => p.startsWith('DIFFERS')).length} known), '
    '$notRun text-form files not run, ${problems.length} problem(s)',
  );
  return problems.isEmpty ? 0 : 1;
}
