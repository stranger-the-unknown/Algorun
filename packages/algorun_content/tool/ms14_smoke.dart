import 'ms14_build.dart';

void main() {
  var failed = 0;
  for (final e in ms14Builders.entries) {
    try {
      final b = e.value();
      print('${e.key} blocks ${b.solution.blocks.length} rejects ${b.rejects.length}');
    } catch (err) {
      failed++;
      print('FAIL ${e.key} $err');
    }
  }
  if (failed != 0) {
    print('$failed failed');
  }
}
