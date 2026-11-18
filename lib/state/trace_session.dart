import 'dart:async';
import 'dart:math' as math;

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/foundation.dart';

/// Records the steps of one run from run position `from` on.
typedef TraceLoader = TraceRecording Function(int from);

/// Where the player is in a recorded run (T1): the position, play / pause and
/// its speed, and which call's values are on show.
///
/// A long run is held one window at a time. Moving past either end of the
/// window records the next one ([TraceLoader] runs the program again), so the
/// player steps through the whole run without the whole run ever being in
/// memory.
final class TraceSession extends ChangeNotifier {
  TraceSession(this._load, {this.windowSteps = 2000}) : _recording = _load(0);

  /// The session for one visible case of [puzzle]; null when [caseId] is not
  /// a visible case (a hidden case is never traced).
  static TraceSession? forCase(
    Program program,
    Puzzle puzzle,
    String caseId, {
    TraceLimits limits = TraceLimits.standard,
  }) {
    if (traceVisibleCase(program, puzzle, caseId, traceLimits: const TraceLimits(maxSteps: 1, maxCells: 1)) == null) {
      return null;
    }
    return TraceSession(
      (from) => traceVisibleCase(program, puzzle, caseId, from: from, traceLimits: limits)!,
      windowSteps: limits.maxSteps,
    );
  }

  /// Steps a second, slowest first. The second one is "1×".
  static const speeds = [1, 2, 4, 8];
  static const speedLabels = ['0.5×', '1×', '2×', '4×'];

  final TraceLoader _load;

  /// How many steps a window is asked to hold.
  final int windowSteps;

  TraceRecording _recording;
  int _position = 0;
  int? _frame;
  int _speed = 1;
  Timer? _timer;

  /// How many windows were recorded after the first (tests, diagnostics).
  int reloads = 0;

  TraceRecording get recording => _recording;

  /// Steps in the whole run.
  int get total => _recording.totalSteps;

  /// The step on show, from 0.
  int get position => _position;

  /// The step on show; null only for a run with no steps at all.
  TraceStep? get step => _recording.stepAt(_position);

  bool get atStart => _position <= 0;
  bool get atEnd => _position >= total - 1;

  /// The run is longer than one window.
  bool get windowed => !_recording.complete;

  bool get playing => _timer != null;
  int get speedIndex => _speed;
  String get speedLabel => speedLabels[_speed];

  /// The frame whose values are on show: the running one unless the player
  /// picked another. An index into [TraceStep.frames].
  int get frameIndex {
    final depth = step?.frames.length ?? 0;
    final picked = _frame;
    if (picked != null && picked < depth) return picked;
    return depth - 1;
  }

  void selectFrame(int index) {
    _frame = index;
    notifyListeners();
  }

  void next() => goTo(_position + 1);
  void previous() => goTo(_position - 1);
  void first() => goTo(0);
  void last() => goTo(total - 1);

  /// Show step [index] (clamped to the run), recording its window if needed.
  void goTo(int index) {
    final target = total == 0 ? 0 : index.clamp(0, total - 1);
    if (target == _position) return;
    if (!_recording.holds(target)) _reload(target);
    _position = target;
    _frame = null;
    notifyListeners();
  }

  /// Whether [index] can be shown without recording another window.
  bool holds(int index) => _recording.holds(index);

  void _reload(int target) {
    final int from;
    if (target == _recording.endStep) {
      // One step past the window: the next window starts there.
      from = target;
    } else if (target == _recording.firstStep - 1) {
      // One step before it: the window that ends there, so the next steps
      // back are already held.
      from = math.max(0, target - windowSteps + 1);
    } else {
      // A jump (the slider, first, last): room on both sides, and a jump to
      // the end holds the steps that led up to it.
      from = (target - windowSteps ~/ 2).clamp(0, math.max(0, total - windowSteps));
    }
    var recording = _load(from);
    // A window can close early (values looked at): then start it right at
    // the target.
    if (!recording.holds(target) && from != target) recording = _load(target);
    _recording = recording;
    reloads++;
  }

  void togglePlay() => playing ? pause() : play();

  void play() {
    if (playing || total <= 1) return;
    if (atEnd) goTo(0);
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ speeds[_speed]), (_) {
      next();
      if (atEnd) pause();
    });
    notifyListeners();
  }

  void pause() {
    if (!playing) return;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// The next speed, wrapping round to the slowest.
  void cycleSpeed() {
    _speed = (_speed + 1) % speeds.length;
    if (playing) {
      _timer?.cancel();
      _timer = null;
      play();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
