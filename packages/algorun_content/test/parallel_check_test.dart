import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:test/test.dart';

List<ContentFile> _files(String dir, {bool Function(String path)? where}) {
  final root = Directory(dir);
  return [
    for (final f in root.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.json'))
        if (f.absolute.uri.path.substring(root.absolute.uri.path.length) case final path
            when where == null || where(path))
          ContentFile(path, f.readAsStringSync()),
  ];
}

String _text(ContentReport report) => [
      ...report.issues,
      for (final v in report.verdicts) '${v.file} ${v.accepted} ${v.failed.toList()..sort()}',
      report.puzzleCount,
    ].join('\n');

void main() {
  // Two worlds are enough to deal jobs to several isolates and keep the test
  // short: Foundations (starter programs, M1) and Text, Sorting & Pairs (L3).
  bool some(String path) => path.startsWith('world_01/') || path.startsWith('world_15/');
  final puzzles = _files('../../assets/puzzles', where: some);
  final references = _files('../../content/references', where: some);
  final capabilities = File('../../content/capabilities.json').readAsStringSync();
  const validator = ContentValidator();

  List<ReferenceJob> jobs() => validator.referenceJobs(
        puzzles: puzzles,
        references: references,
        capabilitiesSource: capabilities,
      );

  ContentReport report([Map<String, ReferenceOutcome>? outcomes]) => validator.validateContent(
        puzzles: puzzles,
        references: references,
        capabilitiesSource: capabilities,
        referenceOutcomes: outcomes,
      );

  test('there is one job for every puzzle with a reference file, in id order', () {
    final ids = [for (final job in jobs()) job.puzzle.id];
    expect(ids, hasLength(references.length));
    expect(ids, [...ids]..sort());
    expect(jobs().first.file, startsWith('references/world_'));
  });

  test('no references, no jobs', () {
    expect(validator.referenceJobs(puzzles: puzzles), isEmpty);
  });

  test('checks made on several isolates give the report one isolate gives', () async {
    final plain = report();
    expect(plain.errors, isEmpty, reason: plain.errors.join('\n'));
    final outcomes = await checkReferencesInParallel(jobs(), workers: 4);
    expect(outcomes.keys, unorderedEquals([for (final job in jobs()) job.puzzle.id]));
    expect(_text(report(outcomes)), _text(plain));
  });

  test('one worker is the plain path', () async {
    final outcomes = await checkReferencesInParallel(jobs().take(3).toList(), workers: 1);
    expect(outcomes, hasLength(3));
  });

  test('a puzzle that has no outcome is still checked', () async {
    final all = jobs();
    final half = await checkReferencesInParallel(all.take(all.length ~/ 2).toList(), workers: 2);
    expect(_text(report(half)), _text(report()));
  });

  test('a failing reference fails the same way from another isolate', () async {
    final broken = [
      for (final r in references)
        if (r.path == 'world_01/warm_readings.json') ContentFile(r.path, '{"puzzle": "warm_readings"}') else r,
    ];
    ContentReport run([Map<String, ReferenceOutcome>? outcomes]) => validator.validateContent(
          puzzles: puzzles,
          references: broken,
          capabilitiesSource: capabilities,
          referenceOutcomes: outcomes,
        );
    final plain = run();
    expect(plain.errors, isNotEmpty);
    final outcomes = await checkReferencesInParallel(
      validator.referenceJobs(puzzles: puzzles, references: broken, capabilitiesSource: capabilities),
      workers: 3,
    );
    expect(_text(run(outcomes)), _text(plain));
  });

  test('--jobs needs a number', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/validate.dart', '../../assets/puzzles', '--jobs', 'many'],
    );
    expect(result.exitCode, 64);
    expect('${result.stderr}', contains('--jobs needs a whole number'));
  });
}
