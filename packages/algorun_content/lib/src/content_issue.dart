enum Severity { error, warning }

/// One finding. [file] is relative to the puzzles root (`world_01/x.json`) or
/// the manifest name; [path] points into the JSON, `''` for the whole file.
final class ContentIssue {
  const ContentIssue(this.severity, this.file, this.path, this.message);

  final Severity severity;
  final String file;
  final String path;
  final String message;

  bool get isError => severity == Severity.error;

  @override
  String toString() {
    final where = path.isEmpty ? file : '$file $path';
    return '${severity.name.toUpperCase()} $where: $message';
  }
}

final class ContentReport {
  const ContentReport(this.issues, {this.puzzleCount = 0});

  final List<ContentIssue> issues;

  /// Puzzles that passed the schema.
  final int puzzleCount;

  bool get ok => !issues.any((i) => i.isError);

  Iterable<ContentIssue> get errors => issues.where((i) => i.isError);
  Iterable<ContentIssue> get warnings => issues.where((i) => !i.isError);
}

/// A puzzle file: its path relative to the puzzles root, and its text.
final class ContentFile {
  const ContentFile(this.path, this.source);

  final String path;
  final String source;
}
