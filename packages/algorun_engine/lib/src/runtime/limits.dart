/// Deterministic execution budgets. Wall-clock time is a UI watchdog only —
/// it is not a puzzle grade. Complexity is *not* a static Big-O analyzer.
final class RunLimits {
  const RunLimits({
    this.maxOps = 100000,
    this.maxDepth = 256,
    this.maxAlloc = 10000,
    this.maxArrayLen = 10000,
    this.maxMapSize = 10000,
  });

  final int maxOps;
  final int maxDepth;
  final int maxAlloc;
  final int maxArrayLen;
  final int maxMapSize;

  static const standard = RunLimits();
}

final class RunMetrics {
  const RunMetrics({
    this.ops = 0,
    this.peakAlloc = 0,
    this.peakDepth = 0,
    this.blocks = 0,
    this.hintsUsed = 0,
  });

  final int ops;
  final int peakAlloc;
  final int peakDepth;
  final int blocks;
  final int hintsUsed;

  static const zero = RunMetrics();
}

/// Performance target stored on a puzzle. Grading in v1 uses [maxOps] /
/// [maxAlloc] / [maxDepth] against a run. Empirical Big-O fitting is a later
/// milestone and must not be presented as a proof.
final class PerformanceTarget {
  const PerformanceTarget({
    required this.maxOps,
    this.maxDepth = 256,
    this.maxAlloc = 10000,
    this.notes,
  });

  final int maxOps;
  final int maxDepth;
  final int maxAlloc;
  final String? notes;

  RunLimits get asLimits => RunLimits(
        maxOps: maxOps,
        maxDepth: maxDepth,
        maxAlloc: maxAlloc,
      );
}
