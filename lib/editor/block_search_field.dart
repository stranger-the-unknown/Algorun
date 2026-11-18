import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../shared/theme/app_theme.dart';

/// The one text field of the editor (E1): a block search box. It is only
/// built after the player asks for it (the search button), so programming
/// itself still never opens the keyboard.
final class BlockSearchField extends StatefulWidget {
  const BlockSearchField({
    super.key,
    required this.onChanged,
    required this.onClose,
    this.autofocus = true,
  });

  final ValueChanged<String> onChanged;

  /// Leaves the search: the caller clears its query and hides the field.
  final VoidCallback onClose;
  final bool autofocus;

  @override
  State<BlockSearchField> createState() => _BlockSearchFieldState();
}

class _BlockSearchFieldState extends State<BlockSearchField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: _text,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: 1,
      style: TextStyle(color: palette.fg, fontSize: 15),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: l.searchBlocks,
        hintStyle: TextStyle(color: palette.muted, fontSize: 15),
        filled: true,
        fillColor: palette.subtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        prefixIcon: Icon(Icons.search, size: 20, color: palette.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: IconButton(
          tooltip: l.closeSearch,
          onPressed: widget.onClose,
          icon: Icon(Icons.close, size: 20, color: palette.muted),
        ),
        enabledBorder: border(palette.borderStrong),
        focusedBorder: border(palette.accent, 2),
      ),
    );
  }
}
