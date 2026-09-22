import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  const validator = ContentValidator();

  test('accepts a well-formed puzzle', () {
    final puzzle = parsePuzzleJson(_ok);
    final report = validator.validatePuzzle(puzzle);
    expect(report.ok, isTrue);
  });

  test('rejects unknown allowed block', () {
    final puzzle = parsePuzzleJson(
      _ok.replaceAll('arr.len', 'not.real'),
    );
    final report = validator.validatePuzzle(puzzle);
    expect(report.ok, isFalse);
    expect(report.issues.first.message, contains('not.real'));
  });

  test('world listing a missing puzzle fails', () {
    final worlds = parseWorldsJson('''
{"worlds":[{"id":"world_01","title":"Foundations","index":1,"puzzles":["missing"]}]}
''');
    final report = validator.validateWorlds(worlds, {'other'});
    expect(report.ok, isFalse);
  });
}

const _ok = '''
{
  "id": "ms1_contract_probe",
  "title": "Contract Probe",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "Engine fixture.",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": ["var.set", "var.get", "ctrl.return", "arr.len"] },
  "limits": { "maxOps": 10000 },
  "hints": ["probe"],
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1] }, "out": 1 }],
    "hidden": [{ "id": "h1", "in": { "nums": [2] }, "out": 2 }]
  }
}
''';
