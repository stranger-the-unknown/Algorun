import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

final class ResultsArgs {
  const ResultsArgs({
    required this.puzzle,
    required this.validation,
    required this.suite,
  });

  final Puzzle puzzle;
  final ValidationReport validation;
  final SuiteResult suite;
}

final class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as ResultsArgs?;
    if (args == null) {
      return const Scaffold(body: Center(child: Text('No result.')));
    }
    final kind = args.suite.kind;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind.label.toUpperCase(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: kind == ResultKind.correct ? AppColors.ok : AppColors.warn,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            Text(
              args.suite.message ??
                  (args.validation.ok
                      ? 'No message.'
                      : args.validation.messages.first.message),
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: AppSpace.s5),
            for (final m in args.validation.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: Text(
                  m.message,
                  style: const TextStyle(color: AppColors.fg),
                ),
              ),
            const Spacer(),
            const Text(
              'Hidden tests are not listed here.',
              style: TextStyle(color: AppColors.faint, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.s4),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK TO PUZZLE'),
            ),
          ],
        ),
      ),
    );
  }
}
