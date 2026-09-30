import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';

/// Category accent is a 3px strip, never a candy fill.
abstract final class EditorTheme {
  static Color strip(BuildContext context, BlockCategory category) {
    final p = context.palette;
    return switch (category) {
      BlockCategory.control => p.stripControl,
      BlockCategory.value => p.stripValue,
      BlockCategory.logic => p.stripLogic,
      BlockCategory.math => p.stripMath,
      BlockCategory.collection => p.stripCollection,
      BlockCategory.structure => p.stripStructure,
    };
  }

  static Color surface(BuildContext context, BlockRole role) {
    return switch (role) {
      BlockRole.statement || BlockRole.elseClause => context.palette.elevated,
      BlockRole.expression => context.palette.subtle,
    };
  }
}
