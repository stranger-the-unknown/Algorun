import 'dart:convert';
import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// L3: what the editor replay (level 3) allows for the blocks taken from
/// algorun-lang. A TEXT holds only a text the puzzle offers, because the
/// editor has no keyboard; COPY carries its two names.
const _root = '../..';

Puzzle _puzzle(String id) => parsePuzzleJson(File('$_root/assets/puzzles/world_15/$id.json').readAsStringSync());

Map<String, dynamic> _solution(String id) =>
    (jsonDecode(File('$_root/content/references/world_15/$id.json').readAsStringSync()) as Map<String, dynamic>)['solution']
        as Map<String, dynamic>;

/// The reference of [id] with the first [catalogId] block's literals replaced.
BlockGraph _edited(String id, String catalogId, Map<String, Object?> literals) {
  final json = jsonDecode(jsonEncode(_solution(id))) as Map<String, dynamic>;
  final block = (json['blocks'] as Map<String, dynamic>).values.firstWhere((b) => (b as Map)['catalogId'] == catalogId) as Map;
  block['literals'] = literals;
  return BlockGraph.fromJson(json);
}

List<String> _replay(String id, BlockGraph graph) =>
    [for (final i in replayInEditor(graph, _puzzle(id))) '${i.path}: ${i.message}'];

void main() {
  test('the world 15 references replay as shipped', () {
    for (final id in ['seat_label', 'mirror_sign', 'out_of_place', 'two_doors', 'pass_list']) {
      expect(_replay(id, BlockGraph.fromJson(_solution(id))), isEmpty, reason: id);
    }
  });

  test('a TEXT the puzzle does not offer cannot be placed', () {
    final issues = _replay('seat_label', _edited('seat_label', BlockIds.litStr, {'value': '/'}));
    expect(issues, hasLength(1));
    expect(issues.single, contains('literals.value'));
    expect(issues.single, contains('TEXT offers only the empty text and the puzzle\'s blocks.texts; "/" is not one of them.'));
  });

  test('the empty text is always offered; a text of the puzzle is', () {
    expect(_replay('seat_label', _edited('seat_label', BlockIds.litStr, {'value': ''})), isEmpty);
    expect(_replay('seat_label', _edited('seat_label', BlockIds.litStr, {'value': '0'})), isEmpty);
    expect(_replay('mirror_sign', _edited('mirror_sign', BlockIds.litStr, {'value': 'x'})), isNotEmpty,
        reason: 'mirror_sign lists no texts');
  });

  test('COPY sets its two names and nothing else', () {
    expect(_replay('out_of_place', _edited('out_of_place', BlockIds.varCopy, {'name': 'register', 'from': 'names'})), isEmpty);
    final issues = _replay(
      'out_of_place',
      _edited('out_of_place', BlockIds.varCopy, {'name': 'register', 'from': 'names', 'deep': false}),
    );
    expect(issues.single, contains('The editor cannot set "deep" on COPY.'));
  });

  test('the capability audit lets text, sorting, pairs and deques through; bits stay blocked', () {
    final capabilities = Capabilities.parse(File('$_root/content/capabilities.json').readAsStringSync());
    for (final family in ['strings', 'sorting_builtin', 'pairs_tuples', 'deque', 'monotonic_deque']) {
      expect(capabilities.families[family]!.status, CapabilityStatus.supported, reason: family);
    }
    expect(capabilities.families['bit_manipulation']!.status, CapabilityStatus.blocked);
  });
}
