import 'dart:convert';
import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:test/test.dart';

const _validator = ContentValidator();

String _puzzle({
  String id = 'p1',
  String world = 'world_01',
  String allow = '["ctrl.return", "arr.len", "var.get"]',
  String hints = '["Count them."]',
  String visibleIn = '{ "nums": [1, 2, 3] }',
  String extra = '',
}) =>
    '''
{
  "id": "$id",
  "title": "Probe",
  "world": "$world",
  "tier": 1,
  "mode": "build",
  "story": "Count the numbers.",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": $allow },
  "limits": { "maxOps": 1000 },
  "hints": $hints,
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": $visibleIn, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }$extra
}
''';

String _worlds(Map<String, List<String>> puzzles) => jsonEncode({
      'worlds': [
        for (final (i, entry) in puzzles.entries.indexed)
          {
            'id': entry.key,
            'title': entry.key,
            'index': i + 1,
            'concepts': ['c${i + 1}'],
            'puzzles': entry.value,
          },
      ],
    });

bool _has(ContentReport report, Severity severity, String file, String path, String fragment) {
  return report.issues.any((i) =>
      i.severity == severity &&
      i.file == file &&
      i.path == path &&
      i.message.contains(fragment));
}

void main() {
  group('shipped content', () {
    test('every current asset passes', () {
      final root = Directory('../../assets/puzzles');
      final files = [
        for (final f in root.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.json'))
            ContentFile(
              f.absolute.uri.path.substring(root.absolute.uri.path.length),
              f.readAsStringSync(),
            ),
      ];
      final report = _validator.validateContent(
        puzzles: files,
        worldsSource: File('../../assets/worlds.json').readAsStringSync(),
      );
      expect(report.errors, isEmpty, reason: report.issues.join('\n'));
      expect(report.puzzleCount, 2);
    });
  });

  group('one puzzle', () {
    test('accepts a well-formed puzzle', () {
      final report = _validator.validatePuzzleSource(_puzzle());
      expect(report.ok, isTrue);
      expect(report.issues, isEmpty);
      expect(report.puzzleCount, 1);
    });

    test('rejects an unknown block with where and why', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(allow: '["ctrl.return", "not.real"]'),
        file: 'world_01/p1.json',
      );
      expect(report.ok, isFalse);
      expect(_has(report, Severity.error, 'world_01/p1.json', 'blocks.allow[1]', 'Unknown block "not.real"'), isTrue);
    });

    test('missing hints is advice, not an error', () {
      final report = _validator.validatePuzzleSource(_puzzle(hints: '[]'));
      expect(report.ok, isTrue);
      expect(_has(report, Severity.warning, 'puzzle.json', 'hints', 'No hints'), isTrue);
    });

    test('unplayable function blocks are flagged', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(allow: '["ctrl.return", "fn.call"]'),
      );
      expect(report.ok, isTrue);
      expect(report.warnings.single.message, contains('fn.call'));
    });

    test('a malformed fixture fails with a path into the value', () {
      final report = _validator.validatePuzzleSource(
        _puzzle(visibleIn: '{ "nums": [1, "two", 3] }'),
      );
      expect(report.ok, isFalse);
      expect(_has(report, Severity.error, 'puzzle.json', 'fixtures.visible[0].in.nums[1]', 'Expected num'), isTrue);
    });
  });

  group('the content set', () {
    test('duplicate puzzle ids', () {
      final report = _validator.validateContent(puzzles: [
        ContentFile('world_01/p1.json', _puzzle()),
        ContentFile('world_01/copy.json', _puzzle()),
      ]);
      expect(_has(report, Severity.error, 'world_01/p1.json', 'id', 'also used by world_01/copy.json'), isTrue);
    });

    test('a puzzle must sit where the game loads it from', () {
      final report = _validator.validateContent(puzzles: [
        ContentFile('world_02/p1.json', _puzzle()),
      ]);
      expect(_has(report, Severity.error, 'world_02/p1.json', '', 'loads this puzzle from world_01/p1.json'), isTrue);
    });

    test('a world that lists a missing puzzle', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({
          'world_01': ['p1', 'ghost'],
        }),
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[0].puzzles[1]', 'no valid puzzle has that id'), isTrue);
    });

    test('a puzzle whose world does not exist', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_09/p1.json', _puzzle(world: 'world_09'))],
        worldsSource: _worlds({'world_01': []}),
      );
      expect(_has(report, Severity.error, 'world_09/p1.json', 'world', 'not in the worlds manifest'), isTrue);
    });

    test('a puzzle listed by the wrong world', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({
          'world_01': [],
          'world_02': ['p1'],
        }),
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[1].puzzles[0]', 'belongs to world_01'), isTrue);
    });

    test('a puzzle no world lists is a warning', () {
      final report = _validator.validateContent(
        puzzles: [ContentFile('world_01/p1.json', _puzzle())],
        worldsSource: _worlds({'world_01': []}),
      );
      expect(report.ok, isTrue);
      expect(_has(report, Severity.warning, 'world_01/p1.json', '', 'no player can reach it'), isTrue);
    });

    test('a malformed manifest', () {
      final report = _validator.validateContent(
        puzzles: const [],
        worldsSource: '{"worlds": [{"id": "world_01", "title": "A"}]}',
      );
      expect(_has(report, Severity.error, 'worlds.json', 'worlds[0].index', 'Required'), isTrue);
    });

    test('the report does not depend on file order', () {
      final files = [
        ContentFile('world_01/b.json', _puzzle(id: 'b', allow: '["nope.x"]')),
        ContentFile('world_01/a.json', _puzzle(id: 'a', hints: '[]')),
      ];
      final forward = _validator.validateContent(puzzles: files);
      final backward = _validator.validateContent(puzzles: files.reversed.toList());
      expect(
        forward.issues.map((i) => '$i').toList(),
        backward.issues.map((i) => '$i').toList(),
      );
    });
  });

  group('command line', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('algorun_content_'));
    tearDown(() => temp.deleteSync(recursive: true));

    Future<ProcessResult> validate(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'bin/validate.dart', ...args],
        );

    test('the shipped assets pass', () async {
      final result = await validate(['../../assets/puzzles', '../../assets/worlds.json']);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect('${result.stdout}', contains('OK 2 puzzle(s)'));
    });

    test('malformed temporary fixtures fail with useful errors', () async {
      Directory('${temp.path}/world_01').createSync();
      File('${temp.path}/world_01/p1.json').writeAsStringSync(
        _puzzle(
          visibleIn: '{ "nums": "hello" }',
          extra: ',\n  "generator": "random(10)"',
        ),
      );
      File('${temp.path}/worlds.json').writeAsStringSync(_worlds({
        'world_01': ['p1'],
      }));
      final result = await validate([temp.path, '${temp.path}/worlds.json']);
      final out = '${result.stdout}';
      expect(result.exitCode, 1, reason: out);
      expect(out, contains('ERROR world_01/p1.json fixtures.visible[0].in.nums: Expected array<num>, got the text "hello".'));
      expect(out, contains('ERROR world_01/p1.json generator: Puzzle JSON is data only'));
      // The world now points at a puzzle that did not load, which is its own error.
      expect(out, contains('ERROR worlds.json worlds[0].puzzles[0]: Lists "p1", but no valid puzzle has that id.'));
      expect(out, contains('FAILED 3 error(s)'));
    });
  });
}
