#!/usr/bin/env bash
# Phone / web parity of the engine (L3). Runs every reference solution in
# content/references against every case of its puzzle on the three targets the
# game is built for — the Dart VM (the phone), dart2js and dart2wasm (the web)
# — and compares one digest of every output, operation count, memory peak and
# depth. Needs dart, python3 and node on PATH. Nothing is written to the
# repository: the generated test lives in a temporary directory.
#
#   tool/web_parity.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/test"
cat > "$WORK/pubspec.yaml" <<YAML
name: parity
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  algorun_engine:
    path: $ROOT/packages/algorun_engine
dev_dependencies:
  test: any
YAML

python3 - "$ROOT" "$WORK/test/parity_test.dart" <<'PY'
import glob, json, os, sys
root, out = sys.argv[1], sys.argv[2]
def dart(text):  # a Dart string literal
    return json.dumps(text).replace('$', '\\$')
items = []
for ref in sorted(glob.glob(root + '/content/references/*/*.json')):
    world = os.path.basename(os.path.dirname(ref))
    reference = json.load(open(ref))
    puzzle = '%s/assets/puzzles/%s/%s.json' % (root, world, reference['puzzle'])
    if os.path.exists(puzzle):
        items.append((reference['puzzle'], open(puzzle).read(), json.dumps(reference['solution'])))
with open(out, 'w') as f:
    f.write("""import 'dart:convert';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

const _items = <(String, String, String)>[
""")
    for item in items:
        f.write('  (%s, %s, %s),\n' % tuple(dart(x) for x in item))
    f.write(r"""];

void main() {
  test('digest', () {
    const engine = DefaultEngine();
    var digest = 0, cases = 0;
    for (final (id, puzzleJson, solutionJson) in _items) {
      final puzzle = parsePuzzleJson(puzzleJson);
      final graph = BlockGraph.fromJson(Map<String, dynamic>.from(jsonDecode(solutionJson) as Map));
      final lowered = engine.lower(graph, puzzle);
      expect(lowered.ok, isTrue, reason: id);
      for (final c in puzzle.allTests) {
        final r = engine.run(lowered.program!, c.input,
            RunLimits(maxOps: puzzle.opsBudgetFor(c), maxDepth: puzzle.limits.maxDepth, maxAlloc: puzzle.limits.maxAlloc));
        expect(r.kind, ResultKind.correct, reason: '$id ${c.id} ${r.message}');
        expect(compareOutputs(puzzle.outputValidator, r.output!, c.output), isTrue, reason: '$id ${c.id}');
        final line = '$id ${c.id} ${jsonEncode(valueToJson(r.output!))} ${r.metrics.ops} ${r.metrics.peakAlloc} ${r.metrics.peakDepth}';
        for (final unit in line.codeUnits) {
          digest = (digest * 31 + unit) % 1000000007;
        }
        cases++;
      }
    }
    // ignore: avoid_print
    print('PARITY programs ${_items.length} cases $cases digest $digest');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
""")
PY

cd "$WORK"
dart pub get >/dev/null
declare -A seen
fail=0
for target in "-p vm" "-p node" "-p node -c dart2wasm"; do
  # shellcheck disable=SC2086
  line="$(dart test $target test/parity_test.dart 2>&1 | grep -m1 '^PARITY' || true)"
  if [ -z "$line" ]; then
    echo "dart test $target: FAILED (run it in $WORK to see why)"
    fail=1
    continue
  fi
  echo "dart test $target: $line"
  seen["$line"]=1
done
if [ "$fail" -ne 0 ] || [ "${#seen[@]}" -ne 1 ]; then
  echo "NOT IDENTICAL across targets"
  trap - EXIT
  echo "kept: $WORK"
  exit 1
fi
echo "identical on the Dart VM, dart2js and dart2wasm"
