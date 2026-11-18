import 'package:algorun/state/trace_session.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/trace_fixtures.dart';

/// T1: where the player is in a run — moving, windows of a long run, and the
/// door that only opens for visible cases.
void main() {
  const engine = DefaultEngine();

  TraceSession session(BlockGraph graph, {int maxOps = 400, TraceLimits limits = TraceLimits.standard}) {
    final puzzle = sumPuzzle(maxOps: maxOps);
    return TraceSession.forCase(engine.lower(graph, puzzle).program!, puzzle, 'v1', limits: limits)!;
  }

  test('a session opens for a visible case only', () {
    final puzzle = sumPuzzle();
    final program = engine.lower(sumProgram(), puzzle).program!;
    expect(TraceSession.forCase(program, puzzle, 'v1'), isNotNull);
    expect(TraceSession.forCase(program, puzzle, 'h1'), isNull);
    expect(TraceSession.forCase(program, puzzle, 'nope'), isNull);
  });

  test('moves one step at a time and stays inside the run', () {
    final s = session(sumProgram());
    var changes = 0;
    s.addListener(() => changes++);
    expect(s.total, 8);
    expect(s.position, 0);
    expect(s.atStart, isTrue);
    expect(s.windowed, isFalse);

    s.previous();
    expect(s.position, 0);
    expect(changes, 0, reason: 'nothing moved, nothing to redraw');

    s.next();
    expect(s.position, 1);
    expect(s.step!.kind, TraceKinds.assign);
    s.goTo(99);
    expect(s.position, 7);
    expect(s.atEnd, isTrue);
    s.next();
    expect(s.position, 7);
    s.first();
    expect(s.position, 0);
    s.last();
    expect(s.step!.kind, TraceKinds.returnStep);
    expect(s.reloads, 0, reason: 'a short run is recorded once');
    s.dispose();
  });

  test('the frame on show is the running one until the player picks another, and again after a step', () {
    final puzzle = shippedPuzzleFile('world_12', 'rabbit_months');
    final graph = brokenReference('world_12', 'rabbit_months', const {});
    final s = TraceSession.forCase(engine.lower(graph, puzzle).program!, puzzle, 'v1')!;
    s.goTo(3);
    expect(s.step!.frames, hasLength(2));
    expect(s.frameIndex, 1);
    s.selectFrame(0);
    expect(s.frameIndex, 0);
    s.next();
    expect(s.frameIndex, s.step!.frames.length - 1);
    s.dispose();
  });

  test('a long run is held a window at a time, forward and back, and every step can be reached', () {
    const limits = TraceLimits(maxSteps: 16);
    final s = session(spinProgram(), maxOps: 500, limits: limits);
    final whole = session(spinProgram(), maxOps: 500, limits: const TraceLimits(maxSteps: 100000));
    expect(whole.windowed, isFalse);
    expect(s.windowed, isTrue);
    expect(s.total, whole.total);
    expect(s.recording.steps, hasLength(16));

    // Forward through three windows.
    for (var i = 1; i < 40; i++) {
      s.next();
      expect(s.position, i);
      expect(s.step!.opIndex, whole.recording.stepAt(i)!.opIndex);
      expect(s.recording.steps.length, lessThanOrEqualTo(16));
    }
    expect(s.reloads, 2);

    // To the end: the failure, with the steps before it in the same window.
    s.last();
    expect(s.step!.kind, TraceKinds.halt);
    final before = s.reloads;
    for (var i = 0; i < 15; i++) {
      s.previous();
    }
    expect(s.reloads, before, reason: 'the window that holds the end holds the steps before it');
    s.previous();
    expect(s.reloads, before + 1);
    expect(s.step!.opIndex, whole.recording.stepAt(s.position)!.opIndex);

    // A jump into the middle.
    s.goTo(100);
    expect(s.position, 100);
    expect(s.step!.index, 100);
    expect(s.holds(100), isTrue);
    expect(s.holds(0), isFalse);
    s.dispose();
    whole.dispose();
  });

  test('a window that closes early on the values it holds still reaches every step', () {
    // One value looked at per window: each window is a single step.
    final s = session(sumProgram(), limits: const TraceLimits(maxSteps: 50, maxCells: 1));
    expect(s.recording.steps, hasLength(1));
    for (var i = 1; i < s.total; i++) {
      s.next();
      expect(s.step!.index, i);
    }
    for (var i = s.total - 2; i >= 0; i--) {
      s.previous();
      expect(s.step!.index, i);
    }
    s.dispose();
  });
}
