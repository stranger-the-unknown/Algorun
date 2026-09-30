import 'batch2.dart';
import 'batch3.dart';
import 'arrays.dart';
import 'foundations.dart';
import 'graphs.dart';
import 'greedy_dp.dart';
import 'hashing.dart';
import 'lists.dart';
import 'oracle.dart';
import 'pointers.dart';
import 'stacks.dart';
import 'trees.dart';
import 'windows.dart';

/// Every oracle the content tooling knows, by id. A campaign puzzle's spec
/// names one of these.
const Map<String, Oracle> oracleRegistry = {
  ...foundationOracles,
  ...arrayOracles,
  ...hashingOracles,
  ...pointerOracles,
  ...windowOracles,
  ...stackOracles,
  ...listOracles,
  ...treeOracles,
  ...graphOracles,
  ...greedyDpOracles,
  ...batch2Oracles,
  ...batch3Oracles,
};
