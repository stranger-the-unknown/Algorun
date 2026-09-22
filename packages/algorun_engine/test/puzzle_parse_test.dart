import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

const sample = '''
{
  "id": "ms1_contract_probe",
  "version": 1,
  "title": "Contract Probe",
  "world": "world_01",
  "chapter": "engine",
  "tier": 1,
  "mode": "build",
  "concepts": ["engine_contract"],
  "prerequisites": [],
  "story": "Engine fixture, not a campaign puzzle.",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "constraints": { "n": { "min": 1, "max": 100 } },
  "blocks": {
    "allow": ["var.set", "var.get", "ctrl.return", "arr.len"],
    "forbid": [],
    "maxBlocks": 8
  },
  "limits": { "maxOps": 10000, "maxDepth": 32, "maxAlloc": 1000 },
  "scoring": { "blockBudget": 8 },
  "hints": ["Not a real puzzle."],
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  },
  "edgeCases": ["single element"]
}
''';

void main() {
  test('parses a valid puzzle', () {
    final p = parsePuzzleJson(sample);
    expect(p.id, 'ms1_contract_probe');
    expect(p.blocks.allow, containsAll(['var.set', 'arr.len']));
    expect(p.blocks.allows('arr.len'), isTrue);
    expect(p.blocks.allows('graph.neighbors'), isFalse);
    expect(p.visibleTests, hasLength(1));
    expect(p.hiddenTests, hasLength(1));
    expect(p.limits.maxOps, 10000);
    expect(p.verdictSource, VerdictSource.local);
    expect(p.io.inputs.first.type, ValueType.array(ValueType.number));
  });

  test('parses a closed variable pool', () {
    final json = sample.replaceFirst(
      '"edgeCases": ["single element"]',
      '"edgeCases": ["single element"], "variables": { "pool": [{ "name": "i", "type": "num" }, { "name": "found", "type": "bool" }] }',
    );
    final p = parsePuzzleJson(json);
    expect(p.variablePool.map((v) => v.name), ['i', 'found']);
    expect(p.variablePool.last.type, ValueType.boolean);
  });

  test('rejects empty allowlist', () {
    expect(
      () => parsePuzzleJson(sample.replaceAll(
        '["var.set", "var.get", "ctrl.return", "arr.len"]',
        '[]',
      )),
      throwsFormatException,
    );
  });

  test('rejects missing hidden tests', () {
    expect(
      () => parsePuzzleJson(sample.replaceAll(
        '"hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]',
        '"hidden": []',
      )),
      throwsFormatException,
    );
  });
}
