import 'package:algorun_engine/algorun_engine.dart';

import 'prog.dart';

part 'ms14_part1.dart';
part 'ms14_part2.dart';

/// A reference program and the wrong or slow programs that prove its traps.
final class Built {
  const Built(this.solution, this.rejects);

  final BlockGraph solution;
  final List<Reject> rejects;
}

final class Reject {
  const Reject(this.name, this.expect, this.graph);

  final String name;
  final String expect;
  final BlockGraph graph;
}

Prog prog(Map<String, String> inputs, Map<String, String> pool) => Prog(inputs: inputs, pool: pool);

final Map<String, Built Function()> ms14Builders = {
  'first_descent': firstDescent,
  'second_highest': secondHighest,
  'even_prefixes': evenPrefixes,
  'nested_distinct': nestedDistinct,
  'max_product_two': maxProductTwo,
  'pair_sum_count': pairSumCount,
  'same_value_span': sameValueSpan,
  'shared_values': sharedValues,
  'exact_gaps': exactGaps,
  'pairs_under': pairsUnder,
  'sorted_union': sortedUnion,
  'closest_gap': closestGap,
  'windows_at_least': windowsAtLeast,
  'one_dropout': oneDropout,
  'peak_windows': peakWindows,
  'counter_sum': counterSum,
  'josephus_line': josephusLine,
  'ticket_minutes': ticketMinutes,
  'stack_sorted': stackSorted,
  'tail_lamp': tailLamp,
  'cold_cars': coldCars,
  'named_car': namedCar,
  'end_gap': endGap,
  'rising_links': risingLinks,
  'left_vine': leftVine,
  'right_marks': rightMarks,
  'lone_tree': loneTree,
  'node_census': nodeCensus,
  'leaf_census': leafCensus,
  'lowest_leaf': lowestLeaf,
  'platform_doors': platformDoors,
  'direct_hop': directHop,
  'silent_stops': silentStops,
  'scout_reach': scoutReach,
  'scout_last': scoutLast,
  'biggest_patch': biggestPatch,
  'source_radius': sourceRadius,
  'last_layer': lastLayer,
  'cookie_gifts': cookieGifts,
  'dock_overlap': dockOverlap,
  'leap_reach': leapReach,
  'plank_ways': plankWays,
  'step_toll': stepToll,
  'aisle_cost': aisleCost,
  'open_lanes': openLanes,
  'diagonal_haul': diagonalHaul,
  'pack_bins': packBins,
};
