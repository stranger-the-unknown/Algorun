import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

import '../tool/run_digest.dart';

/// T1: tracing must not change a run.
///
/// Every reference solution and every reject in `content/references` is run
/// on every fixture of its puzzle, visible and hidden, under the test
/// runner's limits — three ways: with no sink, with a sink that only counts,
/// and through [recordTrace]. All three must report the same verdict,
/// operations, peak memory, peak depth, output, failing block and message.
///
/// The untraced results are then compared with `golden/pre_t1_runs.json`,
/// which the engine at commit 4fbbfed (before T1 touched the interpreter)
/// wrote with the same `tool/run_digest.dart`. A puzzle whose files were
/// edited since is skipped: its fingerprint no longer says anything about the
/// engine.
void main() {
  test('every corpus run is the same untraced, traced, and as it was before T1', () {
    var runs = 0;
    var events = 0;
    var recorded = 0;
    final now = digestCorpus(
      run: (program, input, limits) {
        final plain = runProgram(program, input, limits);
        final counted = runProgram(program, input, limits, trace: (_) => events++);
        final recording = recordTrace(program, input, limits);
        final line = runLine('', '', plain);
        expect(runLine('', '', counted), line);
        expect(runLine('', '', recording.result), line);
        // A trace is at most one step per operation, plus the start and the
        // failure.
        expect(recording.totalSteps, lessThanOrEqualTo(plain.metrics.ops + 2));
        runs++;
        recorded += recording.steps.length;
        return plain;
      },
    );
    expect(runs, greaterThan(1000));
    expect(events, greaterThan(runs));
    expect(recorded, greaterThan(runs));

    final golden = (jsonDecode(File('test/golden/pre_t1_runs.json').readAsStringSync()) as Map<String, Object?>)
        .cast<String, Map<String, Object?>>();
    var compared = 0;
    final edited = <String>[];
    for (final entry in golden.entries) {
      final current = now[entry.key];
      if (current == null || current['source'] != entry.value['source']) {
        edited.add(entry.key);
        continue;
      }
      compared++;
      expect(current['runs'], entry.value['runs'], reason: entry.key);
      expect(current['digest'], entry.value['digest'], reason: '${entry.key}: a run differs from the pre-T1 engine');
    }
    if (edited.isNotEmpty) {
      printOnFailure('edited since the golden was written, not compared: ${edited.join(', ')}');
    }
    // Most of the corpus must still be the corpus the golden was written on.
    expect(compared, greaterThan(golden.length ~/ 2));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
