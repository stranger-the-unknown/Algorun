import 'dart:math';

import 'oracle.dart';

// Milestone L3, world 15: text, SORT, COPY, deques and pairs. The references
// use the new blocks; these answers are read off the stories with Dart's own
// lists and strings. Text is compared by Unicode code point, as the language
// does, never by Dart's UTF-16 `compareTo`.

String _text(Object? json) => json! as String;

List<String> _texts(Object? json) => [for (final v in json! as List<Object?>) v! as String];

List<int> _letters(String text) => text.runes.toList();

/// Dictionary order by code point: negative when [a] comes first.
int _byCodePoint(String a, String b) {
  final x = _letters(a);
  final y = _letters(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return x.length - y.length;
}

String _randomText(Random r, String alphabet, int min, int max) {
  final letters = _letters(alphabet);
  return String.fromCharCodes([
    for (var i = between(r, min, max); i > 0; i--) letters[r.nextInt(letters.length)],
  ]);
}

Object? _pair(Object? first, Object? second) => {'type': 'pair', 'first': first, 'second': second};

// Letter Tally — cut the sign into its letters and count the matching ones.
Object? letterTally(Map<String, Object?> input) {
  final letter = _letters(_text(input['letter'])).single;
  return _letters(_text(input['sign'])).where((c) => c == letter).length;
}

Map<String, Object?> letterTallySample(Random r) => {
      'sign': _randomText(r, 'abAB cç', 0, 12),
      'letter': _randomText(r, 'abAB cç', 1, 1),
    };

// Seat Label — the row, a dash, the seat padded to two digits.
Object? seatLabel(Map<String, Object?> input) =>
    '${_text(input['row'])}-${integer(input['seat']).toString().padLeft(2, '0')}';

Map<String, Object?> seatLabelSample(Random r) => {
      'row': _randomText(r, 'ABCDEFGHJK', 1, 1),
      'seat': between(r, 1, 99),
    };

// Mirror Sign — the letters, last one first.
Object? mirrorSign(Map<String, Object?> input) => String.fromCharCodes(_letters(_text(input['sign'])).reversed);

Map<String, Object?> mirrorSignSample(Random r) => {'sign': _randomText(r, 'abc dEş7', 0, 10)};

// Smudged Tickets — a ticket counts when it is digits with an optional minus.
Object? smudgedTickets(Map<String, Object?> input) {
  final whole = RegExp(r'^-?[0-9]+$');
  var total = 0;
  for (final ticket in _texts(input['tickets'])) {
    if (whole.hasMatch(ticket)) total += int.parse(ticket);
  }
  return total;
}

Map<String, Object?> smudgedTicketsSample(Random r) => {
      'tickets': [for (var i = between(r, 0, 7); i > 0; i--) _randomText(r, '0123456789-a ', 0, 4)],
    };

// Middle Child — line them up by height and count in from the short end.
Object? middleChild(Map<String, Object?> input) {
  final row = ints(input['heights'])..sort();
  final shorterNeighbours = (row.length - 1) ~/ 2;
  return row[shorterNeighbours];
}

Map<String, Object?> middleChildSample(Random r) => {'heights': randomInts(r, between(r, 1, 9), 90, 160)};

// Out of Place — write the register in dictionary order next to the seats.
Object? outOfPlace(Map<String, Object?> input) {
  final seats = _texts(input['names']);
  final register = [...seats]..sort(_byCodePoint);
  var moved = 0;
  for (var i = 0; i < seats.length; i++) {
    if (seats[i] != register[i]) moved++;
  }
  return moved;
}

Map<String, Object?> outOfPlaceSample(Random r) => {
      'names': [for (var i = between(r, 0, 7); i > 0; i--) _randomText(r, 'abc', 1, 3)],
    };

// Zigzag Queue — without a line at all: everyone who came second, fourth, …
// stands in front, the latest of them first; the others follow in the order
// they came.
Object? zigzagQueue(Map<String, Object?> input) {
  final arrivals = ints(input['arrivals']);
  return [
    for (var i = arrivals.length - 1; i >= 0; i--)
      if (i.isOdd) arrivals[i],
    for (var i = 0; i < arrivals.length; i++)
      if (i.isEven) arrivals[i],
  ];
}

Map<String, Object?> zigzagQueueSample(Random r) => {'arrivals': randomInts(r, between(r, 0, 9), 1, 99)};

// Two Doors — the tram as a plain list, front first.
Object? twoDoors(Map<String, Object?> input) {
  final tram = <int>[];
  for (final move in ints(input['moves'])) {
    if (move > 0) {
      tram.add(move);
    } else if (tram.isNotEmpty) {
      if (move == 0) {
        tram.removeAt(0);
      } else {
        tram.removeLast();
      }
    }
  }
  return tram;
}

Map<String, Object?> twoDoorsSample(Random r) => {
      'moves': [for (var i = between(r, 0, 12); i > 0; i--) r.nextInt(5) < 3 ? between(r, 1, 99) : -r.nextInt(2)],
    };

List<(String, int)> _results(Object? json) => [
      for (final v in (json! as List<Object?>).cast<Map<String, Object?>>())
        (v['first']! as String, integer(v['second'])),
    ];

// Top Scorer — find the top score first, then the first name that has it.
Object? topScorer(Map<String, Object?> input) {
  final results = _results(input['results']);
  final top = results.map((r) => r.$2).reduce(max);
  return results.firstWhere((r) => r.$2 == top).$1;
}

Map<String, Object?> topScorerSample(Random r) => {
      'results': [
        for (var i = between(r, 1, 7); i > 0; i--) _pair(_randomText(r, 'abcde', 1, 3), between(r, -3, 6)),
      ],
    };

// Pass List — every candidate at or above the mark, as (name, score).
Object? passList(Map<String, Object?> input) {
  final names = _texts(input['names']);
  final scores = ints(input['scores']);
  final mark = integer(input['mark']);
  return [
    for (var i = 0; i < names.length; i++)
      if (scores[i] >= mark) _pair(names[i], scores[i]),
  ];
}

Map<String, Object?> passListSample(Random r) {
  final n = between(r, 0, 7);
  return {
    'names': [for (var i = 0; i < n; i++) _randomText(r, 'abcde', 1, 3)],
    'scores': randomInts(r, n, 0, 10),
    'mark': between(r, 0, 10),
  };
}

const Map<String, Oracle> l3Oracles = {
  'letter_tally': Oracle(id: 'letter_tally', solve: letterTally, sample: letterTallySample),
  'seat_label': Oracle(id: 'seat_label', solve: seatLabel, sample: seatLabelSample),
  'mirror_sign': Oracle(id: 'mirror_sign', solve: mirrorSign, sample: mirrorSignSample),
  'smudged_tickets': Oracle(id: 'smudged_tickets', solve: smudgedTickets, sample: smudgedTicketsSample),
  'middle_child': Oracle(id: 'middle_child', solve: middleChild, sample: middleChildSample),
  'out_of_place': Oracle(id: 'out_of_place', solve: outOfPlace, sample: outOfPlaceSample),
  'zigzag_queue': Oracle(id: 'zigzag_queue', solve: zigzagQueue, sample: zigzagQueueSample),
  'two_doors': Oracle(id: 'two_doors', solve: twoDoors, sample: twoDoorsSample),
  'top_scorer': Oracle(id: 'top_scorer', solve: topScorer, sample: topScorerSample),
  'pass_list': Oracle(id: 'pass_list', solve: passList, sample: passListSample),
};
