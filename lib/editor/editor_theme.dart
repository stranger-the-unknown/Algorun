import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';

/// Category accent is a 3px strip, never a candy fill.
abstract final class EditorTheme {
  static Color strip(BlockCategory category) {
    return switch (category) {
      BlockCategory.control => const Color(0xFF6B8AA8),
      BlockCategory.value => const Color(0xFF8A8A92),
      BlockCategory.logic => const Color(0xFF5E8A84),
      BlockCategory.math => const Color(0xFF9A9AA3),
      BlockCategory.collection => const Color(0xFF8A8070),
      BlockCategory.structure => const Color(0xFF7A7E8A),
    };
  }

  static Color surface(BlockRole role) {
    return switch (role) {
      BlockRole.statement || BlockRole.elseClause => AppColors.elevated,
      BlockRole.expression => AppColors.subtle,
    };
  }
}
