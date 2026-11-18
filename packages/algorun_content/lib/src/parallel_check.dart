import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math' as math;

import 'reference_check.dart';

/// Makes the reference checks of [jobs] on up to [workers] isolates (every
/// processor when null) and returns each outcome under its puzzle's id, for
/// `ContentValidator.validateContent(referenceOutcomes: …)`.
///
/// A check depends on nothing but its job, so the report built from these
/// outcomes is the one a single isolate would have produced; only the time
/// differs. The jobs are dealt out round-robin: they arrive sorted by id, so
/// the heavy ones are spread, not clustered.
///
/// Offline tooling only (`dart:isolate`): the VM, never the app.
Future<Map<String, ReferenceOutcome>> checkReferencesInParallel(
  List<ReferenceJob> jobs, {
  ReferenceChecker checker = const ReferenceChecker(),
  int? workers,
}) async {
  final count = math.max(1, math.min(workers ?? Platform.numberOfProcessors, jobs.length));
  if (count == 1) {
    return {for (final job in jobs) job.puzzle.id: checker.run(job)};
  }
  final shards = List.generate(count, (_) => <ReferenceJob>[]);
  for (final (i, job) in jobs.indexed) {
    shards[i % count].add(job);
  }
  final done = await Future.wait([
    for (final shard in shards) Isolate.run(() => [for (final job in shard) (job.puzzle.id, checker.run(job))]),
  ]);
  return {
    for (final shard in done)
      for (final (id, outcome) in shard) id: outcome,
  };
}
