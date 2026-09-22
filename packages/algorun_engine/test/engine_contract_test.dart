import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Puzzle _puzzle() {
  return parsePuzzleJson('''
{
  "id": "p",
  "title": "P",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "s",
  "io": {
    "inputs": [{ "name": "x", "type": "num" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": ["var.set", "ctrl.return"], "maxBlocks": 2 },
  "limits": { "maxOps": 100 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "x": 1 }, "out": 1 }],
    "hidden": [{ "id": "h1", "in": { "x": 2 }, "out": 2 }]
  }
}
''');
}

void main() {
  const engine = DefaultEngine();

  test('empty graph is invalid', () {
    final report = engine.validate(BlockGraph.empty, _puzzle());
    expect(report.ok, isFalse);
    expect(report.messages.first.code, 'empty_program');
  });

  test('disallowed block is rejected', () {
    const graph = BlockGraph(
      blocks: {
        'a': BlockInstance(id: 'a', catalogId: BlockIds.graphNeighbors),
      },
      entryIds: ['a'],
    );
    final report = engine.validate(graph, _puzzle());
    expect(report.messages.any((m) => m.code == 'block_not_allowed'), isTrue);
  });

  test('allowed block within budget is accepted', () {
    const graph = BlockGraph(
      blocks: {
        'a': BlockInstance(id: 'a', catalogId: BlockIds.ctrlReturn),
      },
      entryIds: ['a'],
    );
    final report = engine.validate(graph, _puzzle());
    expect(report.ok, isTrue);
  });

  test('block budget is enforced', () {
    const graph = BlockGraph(
      blocks: {
        'a': BlockInstance(id: 'a', catalogId: BlockIds.varSet),
        'b': BlockInstance(id: 'b', catalogId: BlockIds.ctrlReturn),
        'c': BlockInstance(id: 'c', catalogId: BlockIds.varSet),
      },
    );
    final report = engine.validate(graph, _puzzle());
    expect(report.messages.any((m) => m.code == 'block_budget'), isTrue);
  });

  test('empty lower fails safely; a program with no entry cannot run', () {
    final lowered = engine.lower(BlockGraph.empty, _puzzle());
    expect(lowered.ok, isFalse);
    expect(lowered.errors.first.code, 'empty_program');
    final run = engine.run(Program.empty, const {}, RunLimits.standard);
    expect(run.kind, ResultKind.invalidProgram);
    expect(run.message, 'This program has no starting point.');
  });

  test('the test runner is still Milestone 6', () {
    final suite = engine.runTests(Program.empty, _puzzle());
    expect(suite.kind, ResultKind.invalidProgram);
    expect(suite.message, contains('Milestone 6'));
  });

  test('unordered validator matches permuted index pairs', () {
    final a = valueFromJson([0, 1]);
    final b = valueFromJson([1, 0]);
    expect(compareOutputs(ValidatorId.unorderedArray, a, b), isTrue);
    expect(compareOutputs(ValidatorId.equal, a, b), isFalse);
  });
}
