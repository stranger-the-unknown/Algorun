import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';

/// Offline CLI: dart run algorun_content:validate puzzles_dir [worlds.json]
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run algorun_content:validate <puzzles_dir> [worlds.json]');
    exitCode = 64;
    return;
  }
  const validator = ContentValidator();
  var failed = false;
  final puzzleIds = <String>{};
  final dir = Directory(args[0]);
  if (!dir.existsSync()) {
    stderr.writeln('Not a directory: ${args[0]}');
    exitCode = 2;
    return;
  }
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    if (entity.uri.pathSegments.last == 'worlds.json') continue;
    try {
      final puzzle = parsePuzzleJson(entity.readAsStringSync());
      puzzleIds.add(puzzle.id);
      final report = validator.validatePuzzle(puzzle);
      for (final issue in report.issues) {
        stdout.writeln('${issue.severity.toUpperCase()} ${entity.path}: ${issue.message}');
        if (issue.severity == 'error') failed = true;
      }
    } on FormatException catch (e) {
      stdout.writeln('ERROR ${entity.path}: $e');
      failed = true;
    }
  }
  if (args.length >= 2) {
    final worlds = parseWorldsJson(File(args[1]).readAsStringSync());
    final report = validator.validateWorlds(worlds, puzzleIds);
    for (final issue in report.issues) {
      stdout.writeln('${issue.severity.toUpperCase()} worlds: ${issue.message}');
      if (issue.severity == 'error') failed = true;
    }
  }
  if (failed) {
    exitCode = 1;
  } else {
    stdout.writeln('OK ${puzzleIds.length} puzzle(s)');
  }
}
