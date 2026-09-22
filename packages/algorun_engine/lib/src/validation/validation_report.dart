final class ValidationMessage {
  const ValidationMessage({
    required this.code,
    required this.message,
    this.blockId,
    this.port,
  });

  final String code;
  final String message;
  final String? blockId;
  final String? port;
}

/// Semantic / game-facing validation. Never emits compiler syntax errors.
final class ValidationReport {
  const ValidationReport({this.messages = const []});

  final List<ValidationMessage> messages;

  bool get ok => messages.isEmpty;

  static const empty = ValidationReport();
}
