import 'dart:math';

import 'oracle.dart';

// Middle Car — the values as a list, then the middle position.
Object? middleCar(Map<String, Object?> input) {
  final values = chainValues(input['head']);
  return values[values.length ~/ 2];
}

Map<String, Object?> middleCarSample(Random r) => {'head': chainJson(randomInts(r, between(r, 1, 10), -5, 5))};

// Loop Detector — the fixture itself says where the last piece points.
Object? loopDetector(Map<String, Object?> input) => chainCycle(input['head']) != null;

Map<String, Object?> loopDetectorSample(Random r) {
  final values = randomInts(r, between(r, 0, 8), 0, 3);
  if (values.isEmpty) return {'head': null};
  return {
    'head': {
      'type': 'listNode',
      'values': values,
      if (r.nextBool()) 'cycleTo': r.nextInt(values.length),
    },
  };
}

// Reverse the Train — the values reversed.
Object? reverseTrain(Map<String, Object?> input) => chainJson(chainValues(input['head']).reversed.toList());

Map<String, Object?> reverseTrainSample(Random r) => {'head': chainJson(randomInts(r, between(r, 0, 10), -5, 5))};

// Drop the Faulty Cars — the values filtered.
Object? dropFaultyCars(Map<String, Object?> input) {
  final bad = integer(input['bad']);
  return chainJson(chainValues(input['head']).where((v) => v != bad).toList());
}

Map<String, Object?> dropFaultyCarsSample(Random r) =>
    {'head': chainJson(randomInts(r, between(r, 0, 10), 0, 3)), 'bad': between(r, 0, 3)};

const listOracles = {
  'middle_car': Oracle(id: 'middle_car', solve: middleCar, sample: middleCarSample),
  'loop_detector': Oracle(id: 'loop_detector', solve: loopDetector, sample: loopDetectorSample),
  'reverse_train': Oracle(id: 'reverse_train', solve: reverseTrain, sample: reverseTrainSample),
  'drop_faulty_cars': Oracle(id: 'drop_faulty_cars', solve: dropFaultyCars, sample: dropFaultyCarsSample),
};
