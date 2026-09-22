import 'dart:convert';

import '../blocks/catalog.dart';
import '../runner/validators.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../runtime/value_json.dart';
import '../types/parse_type.dart';
import '../types/value_type.dart';
import 'puzzle.dart';
import 'world.dart';

export '../types/parse_type.dart' show parseValueType;

/// The closed puzzle schema. The game and the offline content validator read
/// puzzles through this one file, so there is exactly one definition of what a
/// puzzle is.
///
/// Policy:
///
/// * Every field is listed below. An unknown field is an error, at every
///   level. The one open door is `meta`, which holds flat string / number /
///   boolean values the engine never reads.
/// * Puzzle JSON is data. Validators are names from a closed registry;
///   fixtures are canonical values (`runtime/value_json.dart`). Nothing is ever
///   evaluated, so there is no field that could carry code.
/// * Fixtures are decoded once, against the declared io types, while the
///   puzzle is read. A puzzle that could not be graded never loads.
///
/// Reading collects every problem it finds, each with a path such as
/// `fixtures.visible[0].in.nums[2]`, instead of stopping at the first.
const puzzleFields = {
  'id',
  'version',
  'title',
  'world',
  'chapter',
  'tier',
  'mode',
  'concepts',
  'prerequisites',
  'story',
  'io',
  'constraints',
  'blocks',
  'limits',
  'scoring',
  'hints',
  'validators',
  'fixtures',
  'edgeCases',
  'verdictSource',
  'variables',
  'meta',
};

/// Budget ceilings. A puzzle past them could freeze a phone, so it is content
/// error, not a harder puzzle.
const maxOpsCeiling = 10000000;
const maxDepthCeiling = 10000;
const maxAllocCeiling = 1000000;
const maxBlocksCeiling = 500;

/// One schema problem. [path] points into the JSON, `''` for the file itself.
final class SchemaIssue {
  const SchemaIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// Content that does not follow the schema. Carries every issue found.
final class SchemaException extends FormatException {
  SchemaException(this.issues) : super(issues.join('\n'));

  final List<SchemaIssue> issues;

  @override
  String toString() =>
      'Invalid content:\n${issues.map((i) => '  $i').join('\n')}';
}

/// A puzzle read without throwing. [puzzle] is set exactly when [issues] is
/// empty.
final class PuzzleRead {
  const PuzzleRead(this.puzzle, this.issues);

  final Puzzle? puzzle;
  final List<SchemaIssue> issues;

  bool get ok => puzzle != null;
}

/// A worlds manifest read without throwing.
final class WorldsRead {
  const WorldsRead(this.manifest, this.issues);

  final WorldsManifest? manifest;
  final List<SchemaIssue> issues;

  bool get ok => manifest != null;
}

/// Read a puzzle, collecting every schema issue. Never throws.
PuzzleRead readPuzzleJson(String source) {
  final decoded = _decode(source);
  if (decoded.issue != null) return PuzzleRead(null, [decoded.issue!]);
  final json = decoded.json;
  if (json is! Map<String, Object?>) {
    return const PuzzleRead(null, [SchemaIssue('', 'A puzzle is a JSON object.')]);
  }
  return readPuzzleMap(json);
}

/// Read an already decoded puzzle object. Never throws.
PuzzleRead readPuzzleMap(Map<String, Object?> json) {
  final reader = _Reader();
  final puzzle = _PuzzleSchema(reader).read(json);
  if (reader.issues.isNotEmpty || puzzle == null) {
    return PuzzleRead(null, reader.issues);
  }
  return PuzzleRead(puzzle, const []);
}

/// Read a puzzle or throw [SchemaException] with every issue.
Puzzle parsePuzzleJson(String source) {
  final read = readPuzzleJson(source);
  if (!read.ok) throw SchemaException(read.issues);
  return read.puzzle!;
}

/// Read a decoded puzzle object or throw [SchemaException].
Puzzle parsePuzzleMap(Map<String, Object?> json) {
  final read = readPuzzleMap(json);
  if (!read.ok) throw SchemaException(read.issues);
  return read.puzzle!;
}

/// Read a worlds manifest, collecting every schema issue. Never throws.
WorldsRead readWorldsJson(String source) {
  final decoded = _decode(source);
  if (decoded.issue != null) return WorldsRead(null, [decoded.issue!]);
  final json = decoded.json;
  if (json is! Map<String, Object?>) {
    return const WorldsRead(null, [SchemaIssue('', 'A worlds manifest is a JSON object.')]);
  }
  final reader = _Reader();
  final manifest = _readWorlds(reader, json);
  if (reader.issues.isNotEmpty || manifest == null) {
    return WorldsRead(null, reader.issues);
  }
  return WorldsRead(manifest, const []);
}

/// Read a worlds manifest or throw [SchemaException].
WorldsManifest parseWorldsJson(String source) {
  final read = readWorldsJson(source);
  if (!read.ok) throw SchemaException(read.issues);
  return read.manifest!;
}

({Object? json, SchemaIssue? issue}) _decode(String source) {
  try {
    return (json: jsonDecode(source), issue: null);
  } on FormatException catch (e) {
    return (json: null, issue: SchemaIssue('', 'Not valid JSON: ${e.message}'));
  }
}

// --- puzzle ------------------------------------------------------------------

final _identifier = RegExp(r'^[a-z][a-z0-9_]*$');
const _identifierHint = 'lower_snake_case';
final _name = RegExp(r'^[a-z][A-Za-z0-9_]*$');
const _nameHint = 'a name that starts with a lowercase letter';
final _caseId = RegExp(r'^[A-Za-z0-9_-]+$');
const _caseIdHint = 'letters, digits, "_" or "-"';

/// Validators that do not care about order, for `io.output.order: "any"`.
const _orderFree = {
  ValidatorId.unorderedArray,
  ValidatorId.setEqual,
  ValidatorId.unorderedPairs,
};

final class _PuzzleSchema {
  _PuzzleSchema(this.r);

  final _Reader r;

  Puzzle? read(Map<String, Object?> m) {
    r.closed(m, puzzleFields, '');
    final id = r.string(m, 'id', '', required: true, pattern: _identifier, hint: _identifierHint);
    final version = r.integer(m, 'version', '', min: 1) ?? 1;
    final title = r.string(m, 'title', '', required: true);
    final world = r.string(m, 'world', '', required: true, pattern: _identifier, hint: _identifierHint);
    final chapter = r.string(m, 'chapter', '', pattern: _identifier, hint: _identifierHint) ?? '';
    final tier = r.integer(m, 'tier', '', required: true, min: 1, max: 5);
    final mode = r.choice(m, 'mode', '', {for (final v in PuzzleMode.values) v.name: v}, required: true);
    final concepts = r.strings(m, 'concepts', '', pattern: _identifier, hint: _identifierHint) ?? const [];
    final prerequisites =
        r.strings(m, 'prerequisites', '', pattern: _identifier, hint: _identifierHint) ?? const [];
    final story = r.string(m, 'story', '', required: true);
    final io = _io(m);
    final constraints = _constraints(m);
    final blocks = _blocks(m);
    final limits = _limits(m);
    final scoring = _scoring(m);
    final hints = r.strings(m, 'hints', '') ?? const [];
    final validator = _validator(m, io);
    final fixtures = _fixtures(m, io);
    final edgeCases = r.strings(m, 'edgeCases', '') ?? const [];
    final verdict = r.choice(m, 'verdictSource', '', {for (final v in VerdictSource.values) v.name: v}) ??
        VerdictSource.local;
    final pool = _pool(m, io);
    final meta = _meta(m);

    if (id == null ||
        title == null ||
        world == null ||
        tier == null ||
        mode == null ||
        story == null ||
        io == null ||
        blocks == null ||
        limits == null ||
        validator == null ||
        fixtures == null ||
        pool == null) {
      return null;
    }
    return Puzzle(
      id: id,
      version: version,
      title: title,
      world: world,
      chapter: chapter,
      tier: PuzzleTier.values[tier - 1],
      mode: mode,
      concepts: concepts,
      prerequisites: prerequisites,
      story: story,
      io: io,
      constraints: constraints,
      blocks: blocks,
      limits: limits,
      scoring: scoring,
      hints: hints,
      outputValidator: validator,
      visibleTests: fixtures.visible,
      hiddenTests: fixtures.hidden,
      edgeCases: edgeCases,
      verdictSource: verdict,
      variablePool: pool,
      meta: meta,
    );
  }

  IoSpec? _io(Map<String, Object?> m) {
    final io = r.object(m, 'io', '', required: true);
    if (io == null) return null;
    r.closed(io, const {'inputs', 'output'}, 'io');

    final inputs = <IoBinding>[];
    var inputsOk = true;
    final rawInputs = r.list(io, 'inputs', 'io', required: true);
    if (rawInputs == null) inputsOk = false;
    final names = <String>{};
    for (final (i, item) in (rawInputs ?? const <Object?>[]).indexed) {
      final binding = _binding(item, 'io.inputs[$i]', names, fixture: true);
      if (binding == null) {
        inputsOk = false;
      } else {
        inputs.add(binding);
      }
    }

    final output = r.object(io, 'output', 'io', required: true);
    ValueType? outputType;
    var orderMatters = true;
    if (output != null) {
      r.closed(output, const {'type', 'order'}, 'io.output');
      outputType = r.valueType(output, 'type', 'io.output', required: true, fixture: true);
      final order = r.choice(output, 'order', 'io.output', const {'exact': 'exact', 'any': 'any'});
      orderMatters = order != 'any';
    }
    if (!inputsOk || outputType == null) return null;
    return IoSpec(inputs: inputs, output: outputType, outputOrderMatters: orderMatters);
  }

  IoBinding? _binding(Object? item, String at, Set<String> names, {required bool fixture}) {
    if (item is! Map<String, Object?>) {
      r.issue(at, 'Must be {"name": …, "type": …}.');
      return null;
    }
    r.closed(item, const {'name', 'type'}, at);
    final name = r.string(item, 'name', at, required: true, pattern: _name, hint: _nameHint);
    final type = r.valueType(item, 'type', at, required: true, fixture: fixture);
    if (name != null && !names.add(name)) {
      r.issue('$at.name', 'The name "$name" is already used.');
      return null;
    }
    if (name == null || type == null) return null;
    return IoBinding(name: name, type: type);
  }

  ConstraintSpec _constraints(Map<String, Object?> m) {
    final c = r.object(m, 'constraints', '');
    if (c == null) return const ConstraintSpec();
    r.closed(c, const {'n', 'notes'}, 'constraints');
    int? min;
    int? max;
    final n = r.object(c, 'n', 'constraints');
    if (n != null) {
      r.closed(n, const {'min', 'max'}, 'constraints.n');
      min = r.integer(n, 'min', 'constraints.n', min: 0);
      max = r.integer(n, 'max', 'constraints.n', min: 0);
      if (min != null && max != null && min > max) {
        r.issue('constraints.n', 'min ($min) is larger than max ($max).');
      }
    }
    return ConstraintSpec(
      nMin: min,
      nMax: max,
      notes: r.strings(c, 'notes', 'constraints') ?? const [],
    );
  }

  BlockPolicy? _blocks(Map<String, Object?> m) {
    final b = r.object(m, 'blocks', '', required: true);
    if (b == null) return null;
    r.closed(b, const {'allow', 'forbid', 'maxBlocks'}, 'blocks');
    final allow = r.strings(b, 'allow', 'blocks', required: true);
    final forbid = r.strings(b, 'forbid', 'blocks') ?? const [];
    if (allow != null && allow.isEmpty) {
      r.issue('blocks.allow', 'Must list at least one block.');
    }
    for (final (i, id) in (allow ?? const <String>[]).indexed) {
      if (!BlockIds.exists(id)) r.issue('blocks.allow[$i]', 'Unknown block "$id".');
    }
    for (final (i, id) in forbid.indexed) {
      if (!BlockIds.exists(id)) {
        r.issue('blocks.forbid[$i]', 'Unknown block "$id".');
      } else if (allow != null && allow.contains(id)) {
        r.issue('blocks.forbid[$i]', '"$id" is also in blocks.allow.');
      }
    }
    final maxBlocks = r.integer(b, 'maxBlocks', 'blocks', min: 1, max: maxBlocksCeiling);
    if (allow == null || allow.isEmpty) return null;
    return BlockPolicy(allow: allow.toSet(), forbid: forbid.toSet(), maxBlocks: maxBlocks);
  }

  PerformanceTarget? _limits(Map<String, Object?> m) {
    final l = r.object(m, 'limits', '', required: true);
    if (l == null) return null;
    r.closed(l, const {'maxOps', 'maxDepth', 'maxAlloc', 'notes'}, 'limits');
    final maxOps = r.integer(l, 'maxOps', 'limits', required: true, min: 1, max: maxOpsCeiling);
    final maxDepth = r.integer(l, 'maxDepth', 'limits', min: 1, max: maxDepthCeiling);
    final maxAlloc = r.integer(l, 'maxAlloc', 'limits', min: 1, max: maxAllocCeiling);
    final notes = r.string(l, 'notes', 'limits');
    if (maxOps == null) return null;
    return PerformanceTarget(
      maxOps: maxOps,
      maxDepth: maxDepth ?? 256,
      maxAlloc: maxAlloc ?? 10000,
      notes: notes,
    );
  }

  ScoringSpec _scoring(Map<String, Object?> m) {
    final s = r.object(m, 'scoring', '');
    if (s == null) return const ScoringSpec();
    r.closed(s, const {'blockBudget', 'hintPenalty'}, 'scoring');
    return ScoringSpec(
      blockBudget: r.integer(s, 'blockBudget', 'scoring', min: 1, max: maxBlocksCeiling),
      hintPenalty: r.boolean(s, 'hintPenalty', 'scoring') ?? true,
    );
  }

  ValidatorId? _validator(Map<String, Object?> m, IoSpec? io) {
    final v = r.object(m, 'validators', '');
    if (v == null && m.containsKey('validators')) return null;
    ValidatorId id = ValidatorId.equal;
    if (v != null) {
      r.closed(v, const {'output'}, 'validators');
      final named = r.choice(
        v,
        'output',
        'validators',
        {for (final id in ValidatorId.values) id.name: id},
      );
      if (named == null && v.containsKey('output')) return null;
      id = named ?? ValidatorId.equal;
    }
    if (io != null) {
      if (!validatorAccepts(id, io.output)) {
        r.issue(
          'validators.output',
          '"${id.name}" needs ${validatorNeeds(id)}, but io.output is ${io.output}.',
        );
      }
      if (!io.outputOrderMatters && !_orderFree.contains(id)) {
        r.issue(
          'io.output.order',
          '"any" needs an order-free validator: '
          '${_orderFree.map((e) => e.name).join(', ')}.',
        );
      }
    }
    return id;
  }

  ({List<TestCase> visible, List<TestCase> hidden})? _fixtures(
    Map<String, Object?> m,
    IoSpec? io,
  ) {
    final f = r.object(m, 'fixtures', '', required: true);
    if (f == null) return null;
    r.closed(f, const {'visible', 'hidden'}, 'fixtures');
    final ids = <String>{};
    final visible = _cases(f, 'visible', io, ids);
    final hidden = _cases(f, 'hidden', io, ids);
    if (visible == null || hidden == null) return null;
    return (visible: visible, hidden: hidden);
  }

  List<TestCase>? _cases(
    Map<String, Object?> fixtures,
    String key,
    IoSpec? io,
    Set<String> ids,
  ) {
    final raw = r.list(fixtures, key, 'fixtures', required: true);
    if (raw == null) return null;
    if (raw.isEmpty) {
      r.issue('fixtures.$key', 'Needs at least one case.');
      return null;
    }
    final out = <TestCase>[];
    var ok = true;
    for (final (i, item) in raw.indexed) {
      final at = 'fixtures.$key[$i]';
      final testCase = _case(item, at, io, ids, visible: key == 'visible');
      if (testCase == null) {
        ok = false;
      } else {
        out.add(testCase);
      }
    }
    return ok ? out : null;
  }

  TestCase? _case(
    Object? item,
    String at,
    IoSpec? io,
    Set<String> ids, {
    required bool visible,
  }) {
    if (item is! Map<String, Object?>) {
      r.issue(at, 'A case is {"id": …, "in": {…}, "out": …}.');
      return null;
    }
    r.closed(item, const {'id', 'in', 'out'}, at);
    final id = r.string(item, 'id', at, required: true, pattern: _caseId, hint: _caseIdHint);
    if (id != null && !ids.add(id)) {
      r.issue('$at.id', 'The case id "$id" is already used.');
    }
    final given = r.object(item, 'in', at, required: true);
    if (!item.containsKey('out')) {
      r.issue('$at.out', 'Required. Use null for an empty answer.');
    }

    final input = <String, RuntimeValue>{};
    var ok = id != null && given != null && item.containsKey('out');
    if (given != null) {
      if (io != null) {
        final declared = {for (final b in io.inputs) b.name};
        for (final key in given.keys) {
          if (!declared.contains(key)) {
            r.issue('$at.in.$key', 'Not an input of this puzzle.');
            ok = false;
          }
        }
        for (final binding in io.inputs) {
          if (!given.containsKey(binding.name)) {
            r.issue('$at.in.${binding.name}', 'Missing input (${binding.type}).');
            ok = false;
            continue;
          }
          final value = _value(given[binding.name], binding.type, '$at.in.${binding.name}');
          if (value == null) {
            ok = false;
          } else {
            input[binding.name] = value;
          }
        }
      } else {
        // The io is broken, but the fixture's own format is still worth checking.
        for (final entry in given.entries) {
          _value(entry.value, null, '$at.in.${entry.key}');
        }
        ok = false;
      }
    }
    final output = item.containsKey('out') ? _value(item['out'], io?.output, '$at.out') : null;
    if (!ok || output == null || io == null) return null;
    return TestCase(id: id!, input: input, output: output, visible: visible);
  }

  RuntimeValue? _value(Object? json, ValueType? type, String path) {
    try {
      return valueFromJson(json, type: type);
    } on FixtureFormatException catch (e) {
      r.issue(path + e.path.substring(1), e.message);
      return null;
    }
  }

  List<IoBinding>? _pool(Map<String, Object?> m, IoSpec? io) {
    final v = r.object(m, 'variables', '');
    if (v == null) return m.containsKey('variables') ? null : const [];
    r.closed(v, const {'pool'}, 'variables');
    final raw = r.list(v, 'pool', 'variables') ?? const <Object?>[];
    final names = <String>{};
    final givens = {for (final b in io?.inputs ?? const <IoBinding>[]) b.name};
    final pool = <IoBinding>[];
    var ok = true;
    for (final (i, item) in raw.indexed) {
      final at = 'variables.pool[$i]';
      final binding = _binding(item, at, names, fixture: false);
      if (binding == null) {
        ok = false;
        continue;
      }
      if (givens.contains(binding.name)) {
        r.issue('$at.name', '"${binding.name}" is already an input.');
        ok = false;
        continue;
      }
      pool.add(binding);
    }
    return ok ? pool : null;
  }

  Map<String, Object> _meta(Map<String, Object?> m) {
    final meta = r.object(m, 'meta', '');
    if (meta == null) return const {};
    final out = <String, Object>{};
    for (final entry in meta.entries) {
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        out[entry.key] = value!;
      } else {
        r.issue('meta.${entry.key}', 'meta holds only text, numbers and true/false.');
      }
    }
    return out;
  }
}

// --- worlds -----------------------------------------------------------------

WorldsManifest? _readWorlds(_Reader r, Map<String, Object?> m) {
  r.closed(m, const {'worlds'}, '');
  final raw = r.list(m, 'worlds', '', required: true);
  if (raw == null) return null;
  final worlds = <WorldDef>[];
  final ids = <String>{};
  final indexes = <int>{};
  final listed = <String, String>{};
  var ok = true;
  for (final (i, item) in raw.indexed) {
    final at = 'worlds[$i]';
    if (item is! Map<String, Object?>) {
      r.issue(at, 'A world is an object.');
      ok = false;
      continue;
    }
    r.closed(item, const {'id', 'title', 'index', 'concepts', 'prerequisites', 'puzzles'}, at);
    final id = r.string(item, 'id', at, required: true, pattern: _identifier, hint: _identifierHint);
    final title = r.string(item, 'title', at, required: true);
    final index = r.integer(item, 'index', at, required: true, min: 1);
    final concepts = r.strings(item, 'concepts', at, pattern: _identifier, hint: _identifierHint);
    final prerequisites = r.strings(item, 'prerequisites', at, pattern: _identifier, hint: _identifierHint);
    final puzzles = r.strings(item, 'puzzles', at, pattern: _identifier, hint: _identifierHint);
    if (id != null && !ids.add(id)) r.issue('$at.id', 'Duplicate world id "$id".');
    if (index != null && !indexes.add(index)) r.issue('$at.index', 'Duplicate world index $index.');
    for (final (j, puzzle) in (puzzles ?? const <String>[]).indexed) {
      final owner = listed[puzzle];
      if (owner != null && owner != id) {
        r.issue('$at.puzzles[$j]', 'Puzzle "$puzzle" is already listed by $owner.');
      }
      listed[puzzle] = id ?? at;
    }
    if (id == null || title == null || index == null) {
      ok = false;
      continue;
    }
    worlds.add(WorldDef(
      id: id,
      title: title,
      index: index,
      puzzleIds: puzzles ?? const [],
      concepts: concepts ?? const [],
      prerequisites: prerequisites ?? const [],
    ));
  }
  return ok ? WorldsManifest(worlds) : null;
}

// --- reader -----------------------------------------------------------------

/// Field names that suggest someone is trying to put behavior in content.
const _codeLike = {
  'callback',
  'check',
  'code',
  'eval',
  'expr',
  'expression',
  'function',
  'generate',
  'generator',
  'predicate',
  'script',
  'source',
};

/// Typed field access that records an issue instead of throwing.
final class _Reader {
  final issues = <SchemaIssue>[];

  void issue(String path, String message) => issues.add(SchemaIssue(path, message));

  String _at(String path, String key) => path.isEmpty ? key : '$path.$key';

  void closed(Map<String, Object?> m, Set<String> allowed, String path) {
    for (final key in m.keys) {
      if (allowed.contains(key)) continue;
      if (_codeLike.contains(key.toLowerCase())) {
        issue(
          _at(path, key),
          'Puzzle JSON is data only; "$key" is not supported. Validators are '
          'names from the registry and fixtures are values, never code.',
        );
      } else {
        issue(_at(path, key), 'Unknown field "$key". Allowed here: ${allowed.join(', ')}.');
      }
    }
  }

  Map<String, Object?>? object(Map<String, Object?> m, String key, String path, {bool required = false}) {
    final at = _at(path, key);
    if (!m.containsKey(key)) {
      if (required) issue(at, 'Required.');
      return null;
    }
    final value = m[key];
    if (value is! Map<String, Object?>) {
      issue(at, 'Must be an object.');
      return null;
    }
    return value;
  }

  List<Object?>? list(Map<String, Object?> m, String key, String path, {bool required = false}) {
    final at = _at(path, key);
    if (!m.containsKey(key)) {
      if (required) issue(at, 'Required.');
      return null;
    }
    final value = m[key];
    if (value is! List<Object?>) {
      issue(at, 'Must be a list.');
      return null;
    }
    return value;
  }

  String? string(
    Map<String, Object?> m,
    String key,
    String path, {
    bool required = false,
    RegExp? pattern,
    String? hint,
  }) {
    final at = _at(path, key);
    if (!m.containsKey(key)) {
      if (required) issue(at, 'Required.');
      return null;
    }
    final value = m[key];
    if (value is! String) {
      issue(at, 'Must be text.');
      return null;
    }
    if (value.trim().isEmpty) {
      issue(at, 'Must not be empty.');
      return null;
    }
    if (pattern != null && !pattern.hasMatch(value)) {
      issue(at, 'Must be $hint, got "$value".');
      return null;
    }
    return value;
  }

  int? integer(
    Map<String, Object?> m,
    String key,
    String path, {
    bool required = false,
    int? min,
    int? max,
  }) {
    final at = _at(path, key);
    if (!m.containsKey(key)) {
      if (required) issue(at, 'Required.');
      return null;
    }
    final value = m[key];
    if (value is! int) {
      issue(at, 'Must be a whole number.');
      return null;
    }
    if ((min != null && value < min) || (max != null && value > max)) {
      final range = max == null ? 'at least $min' : 'from $min to $max';
      issue(at, 'Must be $range, got $value.');
      return null;
    }
    return value;
  }

  bool? boolean(Map<String, Object?> m, String key, String path) {
    if (!m.containsKey(key)) return null;
    final value = m[key];
    if (value is! bool) {
      issue(_at(path, key), 'Must be true or false.');
      return null;
    }
    return value;
  }

  T? choice<T>(
    Map<String, Object?> m,
    String key,
    String path,
    Map<String, T> options, {
    bool required = false,
  }) {
    final at = _at(path, key);
    if (!m.containsKey(key)) {
      if (required) issue(at, 'Required.');
      return null;
    }
    final value = m[key];
    final picked = value is String ? options[value] : null;
    if (picked == null) {
      issue(at, 'Must be one of ${options.keys.join(', ')}, got ${jsonEncode(value)}.');
    }
    return picked;
  }

  List<String>? strings(
    Map<String, Object?> m,
    String key,
    String path, {
    bool required = false,
    RegExp? pattern,
    String? hint,
  }) {
    final raw = list(m, key, path, required: required);
    if (raw == null) return null;
    final at = _at(path, key);
    final out = <String>[];
    final seen = <String>{};
    var ok = true;
    for (final (i, item) in raw.indexed) {
      if (item is! String || item.trim().isEmpty) {
        issue('$at[$i]', 'Must be non-empty text.');
        ok = false;
      } else if (pattern != null && !pattern.hasMatch(item)) {
        issue('$at[$i]', 'Must be $hint, got "$item".');
        ok = false;
      } else if (!seen.add(item)) {
        issue('$at[$i]', '"$item" is listed twice.');
        ok = false;
      } else {
        out.add(item);
      }
    }
    return ok ? out : null;
  }

  ValueType? valueType(
    Map<String, Object?> m,
    String key,
    String path, {
    bool required = false,
    required bool fixture,
  }) {
    final spec = string(m, key, path, required: required);
    if (spec == null) return null;
    final at = _at(path, key);
    final ValueType type;
    try {
      type = parseValueType(spec);
    } on FormatException catch (e) {
      issue(at, '${e.message}.');
      return null;
    }
    final problem = fixture ? fixtureTypeProblem(type) : _poolTypeProblem(type);
    if (problem != null) {
      issue(at, problem);
      return null;
    }
    return type;
  }
}

String? _poolTypeProblem(ValueType type) {
  if (type.atom == TypeAtom.voidType) return 'void is not a value.';
  for (final inner in [type.param, type.param2]) {
    if (inner != null) {
      final problem = _poolTypeProblem(inner);
      if (problem != null) return problem;
    }
  }
  return null;
}
