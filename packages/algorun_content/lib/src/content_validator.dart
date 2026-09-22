import 'package:algorun_engine/algorun_engine.dart';

final class ContentIssue {
  const ContentIssue(this.severity, this.message);
  final String severity;
  final String message;
}

final class ContentReport {
  const ContentReport(this.issues);
  final List<ContentIssue> issues;
  bool get ok => issues.where((i) => i.severity == 'error').isEmpty;
}

/// Structural checks for a puzzle file. Does not execute player programs.
///
/// Reference-solution execution is Milestone 7+. This validator exists so
/// generated content cannot enter the game until it is well-formed, allowlisted,
/// and has both visible and hidden tests.
final class ContentValidator {
  const ContentValidator();

  ContentReport validatePuzzle(Puzzle puzzle) {
    final issues = <ContentIssue>[];
    if (puzzle.blocks.allow.isEmpty) {
      issues.add(const ContentIssue('error', 'blocks.allow must not be empty.'));
    }
    for (final id in puzzle.blocks.allow) {
      if (!BlockIds.exists(id)) {
        issues.add(ContentIssue('error', 'Unknown allowed block: $id'));
      }
    }
    for (final id in puzzle.blocks.forbid) {
      if (!BlockIds.exists(id)) {
        issues.add(ContentIssue('error', 'Unknown forbidden block: $id'));
      }
    }
    if (puzzle.visibleTests.isEmpty) {
      issues.add(const ContentIssue('error', 'Need at least one visible test.'));
    }
    if (puzzle.hiddenTests.isEmpty) {
      issues.add(const ContentIssue('error', 'Need at least one hidden test.'));
    }
    if (puzzle.limits.maxOps <= 0) {
      issues.add(const ContentIssue('error', 'limits.maxOps must be positive.'));
    }
    try {
      parseValidatorId(puzzle.outputValidator);
    } on FormatException catch (e) {
      issues.add(ContentIssue('error', e.message));
    }
    if (puzzle.story.trim().isEmpty) {
      issues.add(const ContentIssue('error', 'Story must not be empty.'));
    }
    if (puzzle.hints.isEmpty) {
      issues.add(const ContentIssue('warn', 'No hints provided.'));
    }
    return ContentReport(issues);
  }

  ContentReport validateWorlds(WorldsManifest manifest, Set<String> puzzleIds) {
    final issues = <ContentIssue>[];
    final seen = <String>{};
    for (final world in manifest.worlds) {
      if (!seen.add(world.id)) {
        issues.add(ContentIssue('error', 'Duplicate world ${world.id}'));
      }
      for (final id in world.puzzleIds) {
        if (!puzzleIds.contains(id)) {
          issues.add(ContentIssue('error', 'World ${world.id} lists missing puzzle $id'));
        }
      }
    }
    return ContentReport(issues);
  }
}
