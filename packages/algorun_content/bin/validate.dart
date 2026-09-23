import 'dart:io';

import 'package:algorun_content/algorun_content.dart';

/// Offline CLI:
///
///     dart run packages/algorun_content/bin/validate.dart
///         <puzzles_dir> [worlds.json] [references_dir]
///
/// Validates every `.json` file under `puzzles_dir` against the closed puzzle
/// schema, then the set as a whole (duplicate ids, file locations, world
/// membership), then runs every reference solution under `references_dir`
/// through the real test runner. Exits 1 when there is any error. Output
/// order is stable.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: validate <puzzles_dir> [worlds.json] [references_dir]');
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
  if (args.length >= 3) {
    final dir = Directory(args[2]);
    if (!dir.existsSync()) {
      stderr.writeln('Not a directory: ${args[2]}');
      exitCode = 2;
      return;
    }
    referencesLabel = args[2].replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    references = _jsonFiles(dir);
  }

  final report = const ContentValidator().validateContent(
    puzzles: files,
    worldsSource: worldsSource,
    worldsFile: worldsName,
    references: references,
    referencesLabel: referencesLabel,
  );
  for (final issue in report.issues) {
    stdout.writeln(issue);
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
