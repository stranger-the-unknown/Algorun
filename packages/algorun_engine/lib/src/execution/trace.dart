import 'dart:convert';

import '../ast/ir.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import 'engine.dart';
import 'interpreter.dart';
import 'run_result.dart';

/// A recorded run, step by step (T1): what the step-through screen shows.
///
/// [recordTrace] runs a program once with a [TraceSink] that copies, at every
/// step, the names of every open frame and the collections they reach. The
/// copies are immutable and shared: a list that did not change between two
/// steps is stored once, so a recording costs what the program changed, not
/// steps × data.
///
/// Long runs are recorded a window at a time ([TraceLimits]). A recording
/// always knows how many steps the whole run has ([TraceRecording.totalSteps])
/// and holds a contiguous slice of them; asking for another slice runs the
/// program again from the start, which is exact because the interpreter is
/// deterministic. Memory and time per window are bounded whatever the program
/// does.

/// How much one [recordTrace] call may keep.
final class TraceLimits {
  const TraceLimits({this.maxSteps = 2000, this.maxCells = 1500000});

  /// Steps kept in one window.
  final int maxSteps;

  /// Values looked at or copied while recording one window (a list of 100
  /// numbers costs 100 at every step it is reachable). The window closes at
  /// the step that passes this, however few steps that is — but never before
  /// its first step.
  final int maxCells;

  static const standard = TraceLimits();
}

/// A value as it stood at one step.
sealed class TraceValue {
  const TraceValue();
}

/// NOTHING.
final class TraceNothing extends TraceValue {
  const TraceNothing();

  @override
  bool operator ==(Object other) => other is TraceNothing;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'nothing';
}

final class TraceNumber extends TraceValue {
  const TraceNumber(this.value);
  final num value;

  @override
  bool operator ==(Object other) => other is TraceNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

final class TraceBool extends TraceValue {
  const TraceBool(this.value);
  final bool value;

  @override
  bool operator ==(Object other) => other is TraceBool && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

final class TraceText extends TraceValue {
  const TraceText(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is TraceText && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '"$value"';
}

/// A collection, node or graph: look it up with [TraceRecording.objectAt].
/// Two names holding the same [id] hold the same thing.
final class TraceRef extends TraceValue {
  const TraceRef(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is TraceRef && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => '#$id';
}

/// A kind of value this recorder was not written for (a later language
/// addition): its display text, so a screen can still show it.
final class TraceUnknown extends TraceValue {
  const TraceUnknown(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is TraceUnknown && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}

/// What a [TraceSequence] is.
enum TraceShape { array, set, stack, queue, deque, minHeap, maxHeap }

/// The content of a collection, node or graph at one step. Immutable.
sealed class TraceObject {
  const TraceObject();

  /// How many values this holds (for a budget, and for "n items").
  int get size;
}

/// A list, set, stack, queue, deque or heap.
///
/// A stack's top is the last item; a queue's and a deque's front is the first.
/// A heap is listed in the order TAKE TOP would give its numbers.
final class TraceSequence extends TraceObject {
  const TraceSequence(this.shape, this.items);
  final TraceShape shape;
  final List<TraceValue> items;

  @override
  int get size => items.length;
}

final class TraceEntry {
  const TraceEntry(this.key, this.value);
  final TraceValue key;
  final TraceValue value;
}

/// A map, in insertion order.
final class TraceMap extends TraceObject {
  const TraceMap(this.entries);
  final List<TraceEntry> entries;

  @override
  int get size => entries.length;
}

/// One linked-list node. [next] is a [TraceRef] or [TraceNothing].
final class TraceListNode extends TraceObject {
  const TraceListNode(this.value, this.next);
  final num value;
  final TraceValue next;

  @override
  int get size => 1;
}

/// One tree node. [left] and [right] are a [TraceRef] or [TraceNothing].
final class TraceTreeNode extends TraceObject {
  const TraceTreeNode(this.value, this.left, this.right);
  final num value;
  final TraceValue left;
  final TraceValue right;

  @override
  int get size => 1;
}

/// A graph: who each node leads to, and the nodes marked visited so far (in
/// the order they were marked).
final class TraceGraph extends TraceObject {
  const TraceGraph(this.adjacency, this.visited);
  final Map<num, List<num>> adjacency;
  final List<num> visited;

  @override
  int get size => adjacency.length;
}

/// One frame at one step: its names in the order they first got a value.
final class TraceFrameSnapshot {
  const TraceFrameSnapshot({
    required this.serial,
    required this.function,
    required this.vars,
    this.blockId,
  });

  /// See [TraceFrame.serial].
  final int serial;
  final String function;
  final String? blockId;
  final Map<String, TraceValue> vars;
}

/// One step of a recorded run.
final class TraceStep {
  const TraceStep({
    required this.index,
    required this.opIndex,
    required this.kind,
    required this.frames,
    this.blockId,
    this.value,
    this.message,
    this.changed = const {},
    this.changedObjects = const {},
  });

  /// Position in the whole run, from 0.
  final int index;

  /// Operations counted when the step finished: what the result screen calls
  /// steps used.
  final int opIndex;

  /// One of [TraceKinds].
  final String kind;

  /// The block that ran (for [TraceKinds.halt], the block that failed).
  final String? blockId;

  /// The call stack, outermost first; the last one is running.
  final List<TraceFrameSnapshot> frames;

  /// What the step worked out: a condition's answer, a RETURN's value.
  final TraceValue? value;

  /// Why the run stopped ([TraceKinds.halt]).
  final String? message;

  /// Names of the running frame that were bound or rebound in this step.
  /// A frame that was just entered lists all of its names.
  final Set<String> changed;

  /// Collections, nodes and graphs whose content changed in this step
  /// ([TraceRef.id]s).
  final Set<int> changedObjects;

  int get depth => frames.length;
}

/// A window of a run's steps, with the content of everything they refer to.
final class TraceRecording {
  TraceRecording._({
    required this.result,
    required this.totalSteps,
    required this.firstStep,
    required this.steps,
    required this.cutByCells,
    required Map<int, _History> histories,
  }) : _histories = histories; // ignore: prefer_initializing_formals

  /// The run's result: exactly what the same run gives without a trace.
  final RunResult result;

  /// Steps in the whole run, recorded or not.
  final int totalSteps;

  /// [TraceStep.index] of `steps.first`.
  final int firstStep;

  /// The recorded window: steps `firstStep` … `firstStep + steps.length - 1`.
  final List<TraceStep> steps;

  /// The window closed early because it reached [TraceLimits.maxCells].
  final bool cutByCells;

  final Map<int, _History> _histories;

  /// One past the last recorded step.
  int get endStep => firstStep + steps.length;

  /// Every step of the run is in [steps].
  bool get complete => firstStep == 0 && steps.length == totalSteps;

  bool holds(int stepIndex) => stepIndex >= firstStep && stepIndex < endStep;

  /// The step at run position [stepIndex], if this window holds it.
  TraceStep? stepAt(int stepIndex) => holds(stepIndex) ? steps[stepIndex - firstStep] : null;

  /// What [id] held at step [stepIndex] (a position inside this window).
  TraceObject? objectAt(int id, int stepIndex) {
    final history = _histories[id];
    if (history == null) return null;
    final at = history.versionAt(stepIndex);
    return at < 0 ? null : history.versions[at];
  }

  /// What [id] held just before step [stepIndex] changed it; null when that
  /// step did not change it (or first made it).
  TraceObject? objectBefore(int id, int stepIndex) {
    final history = _histories[id];
    if (history == null) return null;
    final at = history.versionAt(stepIndex);
    if (at <= 0 || history.steps[at] != stepIndex) return null;
    return history.versions[at - 1];
  }
}

/// Run [program] over [input] under [limits] and record its steps from run
/// position [from] on, as many as [traceLimits] allows.
///
/// The run itself is the ordinary one: [TraceRecording.result] equals what
/// [runProgram] returns for the same arguments, operation for operation.
TraceRecording recordTrace(
  Program program,
  Map<String, RuntimeValue> input,
  RunLimits limits, {
  int from = 0,
  TraceLimits traceLimits = TraceLimits.standard,
}) {
  final recorder = _Recorder(from < 0 ? 0 : from, traceLimits);
  final result = runProgram(program, input, limits, trace: recorder.add);
  return TraceRecording._(
    result: result,
    totalSteps: recorder.count,
    firstStep: recorder.steps.isEmpty ? recorder.count : recorder.steps.first.index,
    steps: List.unmodifiable(recorder.steps),
    cutByCells: recorder.cutByCells,
    histories: recorder.histories,
  );
}

/// Which positions of [after] to point out as new or changed, given what the
/// collection held one step earlier.
///
/// An item added at either end marks only that item; an item taken from
/// either end marks nothing (the others did not change, they moved); a set or
/// a heap marks the members it did not have before. Anything else marks the
/// positions whose value differs.
Set<int> changedPositions(TraceSequence before, TraceSequence after) {
  final a = before.items;
  final b = after.items;
  if (after.shape == TraceShape.set || after.shape == TraceShape.minHeap || after.shape == TraceShape.maxHeap) {
    // Members the collection gained, counting repeats (a heap may hold a
    // number twice).
    final had = <TraceValue, int>{};
    for (final item in a) {
      had[item] = (had[item] ?? 0) + 1;
    }
    final out = <int>{};
    for (var i = 0; i < b.length; i++) {
      final left = had[b[i]] ?? 0;
      if (left == 0) {
        out.add(i);
      } else {
        had[b[i]] = left - 1;
      }
    }
    return out;
  }
  bool sameRun(int aStart, int bStart, int length) {
    for (var i = 0; i < length; i++) {
      if (a[aStart + i] != b[bStart + i]) return false;
    }
    return true;
  }

  if (b.length > a.length) {
    final extra = b.length - a.length;
    if (sameRun(0, 0, a.length)) return {for (var i = a.length; i < b.length; i++) i};
    if (sameRun(0, extra, a.length)) return {for (var i = 0; i < extra; i++) i};
  } else if (b.length < a.length) {
    final gone = a.length - b.length;
    if (sameRun(0, 0, b.length) || sameRun(gone, 0, b.length)) return const {};
  }
  return {
    for (var i = 0; i < b.length; i++)
      if (i >= a.length || a[i] != b[i]) i,
  };
}

/// Which keys of [after] are new or hold a different value than in [before]
/// (positions in [TraceMap.entries]).
Set<int> changedEntries(TraceMap before, TraceMap after) {
  final had = {for (final entry in before.entries) entry.key: entry.value};
  return {
    for (var i = 0; i < after.entries.length; i++)
      if (!had.containsKey(after.entries[i].key) || had[after.entries[i].key] != after.entries[i].value) i,
  };
}

/// The versions of one object inside a window: `versions[i]` holds from step
/// `steps[i]` until the next one.
final class _History {
  _History(this.id);

  /// The [TraceRef.id] this is the history of.
  final int id;
  final List<int> steps = [];
  final List<TraceObject> versions = [];

  /// The live value, kept only while recording.
  RuntimeValue? live;

  /// A heap's own order when it was last copied (its snapshot is sorted).
  List<num>? rawHeap;

  /// The step this was last looked at, so one step visits it once.
  int seenAt = -1;

  /// Index of the version in effect at [stepIndex], or -1 before the first.
  int versionAt(int stepIndex) {
    var low = 0;
    var high = steps.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (steps[mid] <= stepIndex) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }
}

final class _Recorder {
  _Recorder(this.from, this.limits);

  final int from;
  final TraceLimits limits;

  final List<TraceStep> steps = [];
  final Map<int, _History> histories = {};

  /// Events seen: after the run, the run's length in steps.
  int count = 0;
  bool cutByCells = false;

  // Recorder-local identity: the interpreter's own ids are not unique for
  // fixture values, and identity is what "the same list" means.
  Map<RuntimeValue, int>? _ids = Map.identity();
  int _nextId = 1;

  bool _closed = false;
  int _cells = 0;

  /// The frames of the last step looked at (the base step or a recorded one).
  List<TraceFrameSnapshot> _lastFrames = const [];
  final List<_History> _queue = [];
  Set<int>? _changedObjects;

  void add(TraceEvent event) {
    final index = count++;
    if (_closed || index < from - 1) return;
    final isBase = index == from - 1;
    _changedObjects = null;

    final frames = <TraceFrameSnapshot>[];
    var changed = const <String>{};
    for (var depth = 0; depth < event.frames.length; depth++) {
      final live = event.frames[depth];
      final before = depth < _lastFrames.length && _lastFrames[depth].serial == live.serial
          ? _lastFrames[depth]
          : null;
      final top = depth == event.frames.length - 1;
      final names = top && !isBase && event.kind != TraceKinds.start ? <String>{} : null;
      frames.add(_frame(live, before, names));
      if (names != null && names.isNotEmpty) changed = names;
    }
    final value = event.value;
    final shown = value == null ? null : _value(value, null);
    _drain(index, isBase);
    _lastFrames = frames;
    if (isBase) return;

    steps.add(TraceStep(
      index: index,
      opIndex: event.opIndex,
      kind: event.kind,
      blockId: event.blockId,
      frames: List.unmodifiable(frames),
      value: shown,
      message: event.message,
      changed: changed,
      changedObjects: _changedObjects ?? const {},
    ));
    if (steps.length >= limits.maxSteps) {
      _close();
    } else if (_cells >= limits.maxCells) {
      cutByCells = true;
      _close();
    }
  }

  /// Nothing more is recorded: let go of the program's values.
  void _close() {
    _closed = true;
    _ids = null;
    _queue.clear();
    for (final history in histories.values) {
      history.live = null;
      history.rawHeap = null;
    }
  }

  TraceFrameSnapshot _frame(TraceFrame live, TraceFrameSnapshot? before, Set<String>? changed) {
    final old = before?.vars;
    var same = old != null && old.length == live.vars.length;
    final vars = <String, TraceValue>{};
    for (final entry in live.vars.entries) {
      _cells++;
      final was = old?[entry.key];
      final now = _value(entry.value, was);
      vars[entry.key] = now;
      if (!identical(now, was)) {
        same = false;
        changed?.add(entry.key);
      }
    }
    if (same) return before!;
    return TraceFrameSnapshot(
      serial: live.serial,
      function: live.function,
      blockId: live.blockId,
      vars: Map.unmodifiable(vars),
    );
  }

  /// [value] as a snapshot; [was] itself when it still says the same thing,
  /// so unchanged values are shared and compare by identity.
  TraceValue _value(RuntimeValue value, TraceValue? was) {
    if (value is NilValue) return was is TraceNothing ? was : const TraceNothing();
    if (value is NumValue) {
      return was is TraceNumber && was.value == value.value ? was : TraceNumber(value.value);
    }
    if (value is BoolValue) {
      return was is TraceBool && was.value == value.value ? was : TraceBool(value.value);
    }
    if (value is StrValue) {
      return was is TraceText && was.value == value.value ? was : TraceText(value.value);
    }
    if (_tracked(value)) {
      final ids = _ids!;
      var id = ids[value];
      if (id == null) {
        id = _nextId++;
        ids[value] = id;
        histories[id] = _History(id)..live = value;
      }
      final history = histories[id]!;
      if (history.seenAt != count) {
        history.seenAt = count;
        _queue.add(history);
      }
      return was is TraceRef && was.id == id ? was : TraceRef(id);
    }
    // A value kind added after this recorder was written.
    final text = _display(value);
    return was is TraceUnknown && was.text == text ? was : TraceUnknown(text);
  }

  static bool _tracked(RuntimeValue value) =>
      value is ArrayValue ||
      value is MapValue ||
      value is SetValue ||
      value is StackValue ||
      value is QueueValue ||
      value is DequeValue ||
      value is HeapValue ||
      value is ListNodeValue ||
      value is TreeNodeValue ||
      value is GraphValue;

  static String _display(RuntimeValue value) {
    try {
      return jsonEncode(value.toJson());
    } on Object {
      return '${value.type}';
    }
  }

  /// Look at everything the step reached, once each, and store a new version
  /// of whatever changed. A worklist, not recursion: a linked list may be
  /// thousands of nodes long.
  void _drain(int index, bool isBase) {
    for (var i = 0; i < _queue.length; i++) {
      final history = _queue[i];
      final before = history.versions.isEmpty ? null : history.versions.last;
      final now = _object(history, before);
      if (identical(now, before)) continue;
      history.steps.add(index);
      history.versions.add(now);
      // A thing seen for the first time did not change: it arrived, and the
      // name that holds it says so.
      if (before != null && !isBase) (_changedObjects ??= {}).add(history.id);
    }
    _queue.clear();
  }

  TraceObject _object(_History history, TraceObject? before) {
    final live = history.live!;
    if (live is ArrayValue) return _sequence(TraceShape.array, live.elements, before);
    if (live is SetValue) return _sequence(TraceShape.set, live.members.values, before);
    if (live is StackValue) return _sequence(TraceShape.stack, live.items, before);
    if (live is QueueValue) return _sequence(TraceShape.queue, live.items, before);
    if (live is DequeValue) return _sequence(TraceShape.deque, live.items, before);
    if (live is HeapValue) return _heap(history, live, before);
    if (live is MapValue) return _map(live, before);
    if (live is ListNodeValue) {
      _cells++;
      final was = before is TraceListNode ? before : null;
      final nextLive = live.next;
      final next = _value(nextLive ?? const NilValue(), was?.next);
      if (was != null && was.value == live.value && identical(next, was.next)) return was;
      return TraceListNode(live.value, next);
    }
    if (live is TreeNodeValue) {
      _cells++;
      final was = before is TraceTreeNode ? before : null;
      final left = _value(live.left ?? const NilValue(), was?.left);
      final right = _value(live.right ?? const NilValue(), was?.right);
      if (was != null && was.value == live.value && identical(left, was.left) && identical(right, was.right)) {
        return was;
      }
      return TraceTreeNode(live.value, left, right);
    }
    return _graph(live as GraphValue, before);
  }

  TraceObject _sequence(TraceShape shape, Iterable<RuntimeValue> live, TraceObject? before) {
    final was = before is TraceSequence ? before.items : null;
    var same = was != null;
    final items = <TraceValue>[];
    var i = 0;
    for (final value in live) {
      final old = was != null && i < was.length ? was[i] : null;
      final now = _value(value, old);
      if (!identical(now, old)) same = false;
      items.add(now);
      i++;
    }
    _cells += i + 1;
    if (same && was!.length == i) return before!;
    return TraceSequence(shape, List.unmodifiable(items));
  }

  TraceObject _heap(_History history, HeapValue live, TraceObject? before) {
    final raw = history.rawHeap;
    final items = live.items;
    _cells += items.length + 1;
    var same = before != null && raw != null && raw.length == items.length;
    if (same) {
      for (var i = 0; i < items.length; i++) {
        if (raw[i] != items[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) return before!;
    history.rawHeap = List.of(items);
    return TraceSequence(
      live.isMax ? TraceShape.maxHeap : TraceShape.minHeap,
      List.unmodifiable([for (final n in live.inTakeOrder()) TraceNumber(n)]),
    );
  }

  TraceObject _map(MapValue live, TraceObject? before) {
    final was = before is TraceMap ? before.entries : null;
    var same = was != null && was.length == live.entries.length;
    final entries = <TraceEntry>[];
    var i = 0;
    for (final entry in live.entries.entries) {
      final old = was != null && i < was.length ? was[i] : null;
      final key = _key(entry.key, old?.key);
      final value = _value(entry.value, old?.value);
      if (old != null && identical(key, old.key) && identical(value, old.value)) {
        entries.add(old);
      } else {
        same = false;
        entries.add(TraceEntry(key, value));
      }
      i++;
    }
    _cells += i + 1;
    if (same) return before!;
    return TraceMap(List.unmodifiable(entries));
  }

  TraceValue _key(Object key, TraceValue? was) {
    if (key is num) return was is TraceNumber && was.value == key ? was : TraceNumber(key);
    if (key is bool) return was is TraceBool && was.value == key ? was : TraceBool(key);
    if (key is String) return was is TraceText && was.value == key ? was : TraceText(key);
    final text = '$key';
    return was is TraceUnknown && was.text == text ? was : TraceUnknown(text);
  }

  TraceObject _graph(GraphValue live, TraceObject? before) {
    final was = before is TraceGraph ? before : null;
    var cells = live.visited.length + 1;
    var sameEdges = was != null && was.adjacency.length == live.adjacency.length;
    for (final entry in live.adjacency.entries) {
      cells += entry.value.length + 1;
      if (!sameEdges) continue;
      final old = was!.adjacency[entry.key];
      if (old == null || old.length != entry.value.length) {
        sameEdges = false;
        continue;
      }
      for (var i = 0; i < old.length; i++) {
        if (old[i] != entry.value[i]) {
          sameEdges = false;
          break;
        }
      }
    }
    _cells += cells;
    var sameVisited = was != null && was.visited.length == live.visited.length;
    if (sameVisited) {
      var i = 0;
      for (final node in live.visited) {
        if (was.visited[i] != node) {
          sameVisited = false;
          break;
        }
        i++;
      }
    }
    if (sameEdges && sameVisited) return was!;
    return TraceGraph(
      sameEdges
          ? was!.adjacency
          : Map.unmodifiable({
              for (final entry in live.adjacency.entries) entry.key: List<num>.unmodifiable(entry.value),
            }),
      sameVisited ? was!.visited : List.unmodifiable(live.visited),
    );
  }
}
