import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'theme/app_theme.dart';

/// The worlds and puzzles could not be loaded (in the browser: the network).
/// Says so in words and offers to try again.
class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      key: const Key('load-failed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.loadFailed, style: TextStyle(color: context.palette.danger, height: 1.45)),
        const SizedBox(height: AppSpace.s3),
        OutlinedButton(
          key: const Key('load-retry'),
          onPressed: onRetry,
          child: Text(l.tryAgain),
        ),
      ],
    );
  }
}
