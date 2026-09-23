import 'dart:io';

import 'package:algorun_content/algorun_content.dart';

/// Offline CLI — the content pipeline:
///
///     dart run packages/algorun_content/bin/validate.dart
///         <puzzles_dir> [worlds.json] [references_dir] [--coverage <out.json>]
///
/// Validates every `.json` file under `puzzles_dir` against the closed puzzle
/// schema, then the set as a whole (duplicate ids, file locations, world
/// membership), runs every reference solution under `references_dir` through
/// the editor replay, the real test runner and its independent oracle, checks
/// that every listed puzzle is reachable, and compares the corpus for
/// redundancy and coverage. `capabilities.json` and `coverage_targets.json`
/// are read from the directory that holds `references_dir` when they exist.
///
/// Prints every finding with its level, one ACCEPTED / REJECTED line per
/// puzzle, and a summary. `--coverage` writes the coverage matrix. Exits 1
/// when there is any error. Output order is stable.
void main(List<String> arguments) {
  final args = [...arguments];
  String? coverageOut;
  final flag = args.indexOf('--coverage');
  if (flag >= 0) {
    if (flag + 1 >= args.length) {
      stderr.writeln('--coverage needs a file');
      exitCode = 64;
      return;
    }
    coverageOut = args[flag + 1];
    args.removeRange(flag, flag + 2);
  }
  if (args.isEmpty) {
    stderr.writeln('usage: validate <puzzles_dir> [worlds.json] [references_dir] [--coverage <out.json>]');
    exitCode = 64;
    return;
  }
  final root = Directory(args[0]);
  if (!root.existsSync()) {
    stderr.writeln('Not a directory: ${args[0]}');
    exitCode = 2;
    return;
  }

  String? worldsSource;
  String? worldsPath;
  var worldsName = 'worlds.json';
  if (args.length >= 2) {
    final worlds = File(args[1]);
    if (!worlds.existsSync()) {
      stderr.writeln('Not a file: ${args[1]}');
      exitCode = 2;
      return;
    }
    worldsSource = worlds.readAsStringSync();
    worldsPath = worlds.absolute.uri.path;
    worldsName = worlds.uri.pathSegments.last;
  }

  final rootPath = root.absolute.uri.path;
  final files = <ContentFile>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final absolute = entity.absolute.uri.path;
    // A manifest kept next to the puzzles is not a puzzle.
    if (absolute == worldsPath || entity.uri.pathSegments.last == 'worlds.json') {
      continue;
    }
    files.add(ContentFile(absolute.substring(rootPath.length), entity.readAsStringSync()));
  }

  List<ContentFile>? references;
  var referencesLabel = 'references';
  String? capabilities;
  String? targets;
  if (args.length >= 3) {
    final dir = Directory(args[2]);
    if (!dir.existsSync()) {
      stderr.writeln('Not a directory: ${args[2]}');
      exitCode = 2;
      return;
    }
    referencesLabel = args[2].replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    references = _jsonFiles(dir);
    final content = dir.absolute.parent;
    String? sibling(String name) {
      final file = File('${content.path}${Platform.pathSeparator}$name');
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    capabilities = sibling('capabilities.json');
    targets = sibling('coverage_targets.json');
  }

  final report = const ContentValidator().validateContent(
    puzzles: files,
    worldsSource: worldsSource,
    worldsFile: worldsName,
    references: references,
    referencesLabel: referencesLabel,
    capabilitiesSource: capabilities,
    targetsSource: targets,
  );
  for (final issue in report.issues) {
    stdout.writeln(issue);
  }
  var accepted = 0;
  var probes = 0;
  for (final verdict in report.verdicts) {
    if (!verdict.campaign) {
      probes++;
      if (verdict.accepted) continue;
    }
    if (verdict.accepted) {
      accepted++;
      stdout.writeln('ACCEPTED ${verdict.file}');
    } else {
      final levels = (verdict.failed.toList()..sort()).map((l) => 'L$l ${Level.names[l]}').join(', ');
      stdout.writeln('REJECTED ${verdict.file} at $levels');
    }
  }
  final campaign = report.verdicts.length - probes;
  if (report.coverage != null) {
    final tiers = (report.coverage!['tiers']! as Map<String, Object?>).entries.map((e) => '${e.key}:${e.value}');
    final gaps = (report.coverage!['gaps']! as List).length;
    stdout.writeln('PIPELINE $accepted of $campaign campaign puzzle(s) accepted, $probes probe(s) checked · '
        'tiers ${tiers.join(' ')} · $gaps coverage gap(s)');
  }
  if (coverageOut != null && report.coverage != null) {
    File(coverageOut).writeAsStringSync(coverageJson(report.coverage!));
    stdout.writeln('COVERAGE written to $coverageOut');
  }
  final errors = report.errors.length;
  final warnings = report.warnings.length;
  final warningNote = warnings == 0 ? '' : ', $warnings warning(s)';
  if (errors > 0) {
    stdout.writeln('FAILED $errors error(s)$warningNote');
    exitCode = 1;
  } else {
    stdout.writeln('OK ${report.puzzleCount} puzzle(s)$warningNote');
  }
}

List<ContentFile> _jsonFiles(Directory root) {
  final rootPath = root.absolute.uri.path;
  return [
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.json'))
        ContentFile(
          entity.absolute.uri.path.substring(rootPath.length),
          entity.readAsStringSync(),
        ),
  ];
}
