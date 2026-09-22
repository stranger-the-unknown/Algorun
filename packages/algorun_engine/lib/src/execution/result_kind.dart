/// Closed set of run outcomes. Never "syntax error".
enum ResultKind {
  correct,
  wrongAnswer,
  timeLimit,
  operationLimit,
  memoryLimit,
  invalidProgram,
  runtimeError,
}

extension ResultKindLabel on ResultKind {
  String get label => switch (this) {
        ResultKind.correct => 'Correct',
        ResultKind.wrongAnswer => 'Wrong Answer',
        ResultKind.timeLimit => 'Time Limit',
        ResultKind.operationLimit => 'Operation Limit',
        ResultKind.memoryLimit => 'Memory Limit',
        ResultKind.invalidProgram => 'Invalid Program',
        ResultKind.runtimeError => 'Runtime Error',
      };
}
