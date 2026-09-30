import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';

/// The largest number the pad enters (the content pipeline checks the same
/// limit for reference programs).
const padNumberLimit = 999999;

/// Number pad, yes / no and name pickers. No TextField, no system keyboard:
/// the pad is the game's own number keyboard.
abstract final class LiteralSheet {
  static Future<void> showNumber(
    BuildContext context,
    EditorController controller,
    String blockId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.elevated,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        width: double.infinity,
        child: NumberPad(controller: controller, blockId: blockId),
      ),
    );
  }

  static Future<void> showBool(
    BuildContext context,
    EditorController controller,
    String blockId,
  ) {
    final current = controller.graph.blocks[blockId]?.literals['value'] == true;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.elevated,
      builder: (context) {
        final l = context.l10n;
        Widget choice(bool value, String label) {
          final selected = current == value;
          return Expanded(
            child: Semantics(
              selected: selected,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: selected ? context.palette.subtle : null,
                  side: BorderSide(
                    color: selected ? context.palette.accent : context.palette.borderStrong,
                    width: selected ? 2 : 1,
                  ),
                ),
                onPressed: () {
                  controller.setLiteral(blockId, 'value', value);
                  Navigator.pop(context);
                },
                icon: Icon(selected ? Icons.check : Icons.circle_outlined, size: 18),
                label: Text(selected ? '$label · ${l.languageSelected}' : label),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                choice(true, 'TRUE'),
                const SizedBox(width: 12),
                choice(false, 'FALSE'),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showVariable(
    BuildContext context,
    EditorController controller, {
    required String blockId,
    required String key,
    required List<String> names,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.elevated,
      builder: (_) => SizedBox(
        width: double.infinity,
        child: _VariableChips(
          controller: controller,
          blockId: blockId,
          nameKey: key,
          names: names,
        ),
      ),
    );
  }
}

/// The game's number keyboard.
///
/// It opens with the current number **selected**: the first digit typed
/// replaces it (45 → type 4, 4 → 44). ⌫ deletes the last digit (on a
/// selected number it clears it), CLEAR empties it in one tap, and tapping
/// the number selects it all again. The sign key flips the sign; the number
/// shows its sign and a "negative" tag, so the state never depends on
/// colour.
final class NumberPad extends StatefulWidget {
  const NumberPad({super.key, required this.controller, required this.blockId});
  final EditorController controller;
  final String blockId;

  @override
  State<NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<NumberPad> {
  /// The digits typed, without sign; empty means nothing typed yet.
  late String _digits;
  bool _negative = false;

  /// The whole number is selected: the next digit replaces it.
  bool _selected = true;

  @override
  void initState() {
    super.initState();
    final raw = widget.controller.graph.blocks[widget.blockId]?.literals['value'];
    final n = raw is int ? raw : int.tryParse('$raw') ?? 0;
    _negative = n < 0;
    _digits = '${n.abs()}';
  }

  int get _value {
    final n = _digits.isEmpty ? 0 : int.parse(_digits);
    return _negative ? -n : n;
  }

  void _digit(int d) => setState(() {
        final base = _selected ? '' : _digits;
        _selected = false;
        final next = base == '0' ? '$d' : '$base$d';
        if (next.length <= 6 && int.parse(next) <= padNumberLimit) _digits = next;
      });

  void _backspace() => setState(() {
        if (_selected) {
          _digits = '';
        } else if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
        _selected = false;
      });

  void _clear() => setState(() {
        _digits = '';
        _negative = false;
        _selected = false;
      });

  void _sign() => setState(() {
        _negative = !_negative;
        _selected = false;
      });

  void _done() {
    widget.controller.setLiteral(widget.blockId, 'value', _value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shown = _digits.isEmpty ? '0' : _digits;
    final text = _negative ? '−$shown' : shown;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: l.padValueSemantics(_negative ? '-$shown' : shown),
              hint: _selected ? l.padSelectedHint : l.padEditHint,
              excludeSemantics: true,
              child: InkWell(
                key: const Key('pad-display'),
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => setState(() => _selected = true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.palette.bg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _selected ? context.palette.accent : context.palette.borderStrong,
                      width: _selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              // A selection highlight, like a text field's.
                              color: _selected ? context.palette.accent.withValues(alpha: 0.28) : null,
                              child: Text(
                                text,
                                key: const Key('pad-value'),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: _digits.isEmpty && !_selected ? context.palette.muted : context.palette.fg,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                          if (_negative) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.palette.borderStrong),
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(l.padNegative, style: TextStyle(fontSize: 12, color: context.palette.muted)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selected ? l.padSelectedHint : l.padEditHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['±', '0', '⌫'],
            ])
              Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _PadKey(
                          key: Key('pad-$key'),
                          label: key == '±' ? '+/−' : key,
                          semantics: switch (key) {
                            '±' => l.changeSign,
                            '⌫' => l.deleteDigit,
                            _ => key,
                          },
                          icon: key == '⌫' ? Icons.backspace_outlined : null,
                          onTap: switch (key) {
                            '±' => _sign,
                            '⌫' => _backspace,
                            _ => () => _digit(int.parse(key)),
                          },
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Tooltip(
                      message: l.clearNumber,
                      child: OutlinedButton(
                        key: const Key('pad-clear'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _clear,
                        child: Text(l.padClear),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilledButton(
                      key: const Key('pad-done'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _done,
                      child: Text(l.padDone),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({super.key, required this.label, required this.semantics, required this.onTap, this.icon});

  final String label;
  final String semantics;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: icon == null
          ? Text(
              label,
              semanticsLabel: semantics,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            )
          : Icon(icon, semanticLabel: semantics),
    );
  }
}

class _VariableChips extends StatelessWidget {
  const _VariableChips({
    required this.controller,
    required this.blockId,
    required this.nameKey,
    required this.names,
  });

  final EditorController controller;
  final String blockId;
  final String nameKey;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = controller.graph.blocks[blockId]?.literals[nameKey];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.chooseName,
              style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
            const SizedBox(height: 2),
            Text(
              l.namesFromPuzzle,
              style: TextStyle(color: context.palette.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in names)
                  ActionChip(
                    avatar: name == current ? const Icon(Icons.check, size: 18) : null,
                    label: Text(name),
                    onPressed: () {
                      controller.setLiteral(blockId, nameKey, name);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
