import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import 'theme/app_theme.dart';

/// A small label for a puzzle that does not start from an empty editor (M1):
/// COMPLETE, REPAIR or PREDICT. It says the mode in words; its tooltip says
/// what the mode asks.
final class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key, required this.mode});
  final PuzzleMode mode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final badge = Container(
      key: Key('mode-badge-${mode.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.borderStrong),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        l.upper(modeText(mode, l)),
        style: TextStyle(color: context.palette.muted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    );
    final help = modeHelp(mode, l);
    return help == null ? badge : Tooltip(message: help, child: badge);
  }
}
