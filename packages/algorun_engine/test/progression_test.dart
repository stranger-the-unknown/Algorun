import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// The campaign unlock rules (MS11, shared since MS12 by the app and the
/// content validator).
WorldsManifest _manifest(List<(String, List<String>, List<String>, List<String>)> worlds) => WorldsManifest([
      for (final (i, (id, concepts, prerequisites, puzzles)) in worlds.indexed)
        WorldDef(
          id: id,
          title: id,
          index: i + 1,
          puzzleIds: puzzles,
          concepts: concepts,
          prerequisites: prerequisites,
        ),
    ]);

void main() {
  final chain = _manifest([
    ('w1', ['variables'], [], ['p1']),
    ('w2', ['arrays'], ['variables'], ['p2', 'p3']),
    ('w3', ['pointers'], ['arrays'], []),
    ('w4', ['windows'], ['pointers'], ['p4']),
  ]);

  test('nothing solved: only worlds without prerequisites open', () {
    final state = evaluateUnlocks(chain, const {}, const {});
    expect(state.openWorlds, {'w1'});
    expect(state.openPuzzles, {'p1'});
    expect(state.mastered, isEmpty);
    expect(state.missing['w2'], ['variables']);
    expect(state.missing['p4'], ['pointers']);
  });

  test('completing a world masters its concepts; an empty world completes as it opens', () {
    final state = evaluateUnlocks(chain, const {}, {'p1', 'p2', 'p3'});
    expect(state.completeWorlds, containsAll(['w1', 'w2', 'w3']));
    expect(state.mastered, containsAll(['variables', 'arrays', 'pointers']));
    expect(state.openPuzzles, containsAll(['p4']));
  });

  test('a world is not complete until every puzzle is solved', () {
    final state = evaluateUnlocks(chain, const {}, {'p1', 'p2'});
    expect(state.openWorlds, containsAll(['w1', 'w2']));
    expect(state.completeWorlds, {'w1'});
    expect(state.openWorlds, isNot(contains('w3')));
  });

  test("a puzzle's own prerequisites gate it, unless its world teaches them", () {
    final state = evaluateUnlocks(chain, const {
      'p2': ['arrays'],
      'p3': ['windows'],
    }, {'p1'});
    expect(state.openPuzzles, contains('p2'));
    expect(state.openPuzzles, isNot(contains('p3')));
    expect(state.missing['p3'], ['windows']);
  });

  test('a world with a solved puzzle stays open whatever its prerequisites', () {
    final state = evaluateUnlocks(chain, const {}, {'p4'});
    expect(state.openWorlds, contains('w4'));
    expect(state.openPuzzles, contains('p4'));
  });

  test('the order of worlds in the manifest does not matter', () {
    final reversed = WorldsManifest(chain.worlds.reversed.toList());
    final a = evaluateUnlocks(chain, const {}, {'p1', 'p2', 'p3'});
    final b = evaluateUnlocks(reversed, const {}, {'p1', 'p2', 'p3'});
    expect(b.openWorlds, a.openWorlds);
    expect(b.mastered, a.mastered);
  });
}
