import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'editor_controller.dart';

/// Number pad / chip pickers. No TextField. No system keyboard.
abstract final class LiteralSheet {
  static Future<void> showNumber(
    BuildContext context,
    EditorController controller,
    String blockId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _NumberPad(controller: controller, blockId: blockId),
    );
  }

  static Future<void> showBool(
    BuildContext context,
    EditorController controller,
    String blockId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      controller.setLiteral(blockId, 'value', true);
                      Navigator.pop(context);
                    },
                    child: const Text('TRUE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      controller.setLiteral(blockId, 'value', false);
                      Navigator.pop(context);
                    },
                    child: const Text('FALSE'),
                  ),
                ),
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
    bool allowCreate = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _VariableChips(
        controller: controller,
        blockId: blockId,
        nameKey: key,
        names: names,
        allowCreate: allowCreate,
      ),
    );
  }
}

class _NumberPad extends StatefulWidget {
  const _NumberPad({required this.controller, required this.blockId});
  final EditorController controller;
  final String blockId;

  @override
  State<_NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<_NumberPad> {
  late int _value;
  bool _negative = false;

  @override
  void initState() {
    super.initState();
    final raw =
        widget.controller.graph.blocks[widget.blockId]?.literals['value'];
    final n = raw is int ? raw : int.tryParse('$raw') ?? 0;
    _negative = n < 0;
    _value = n.abs();
  }

  int get _signed => _negative ? -_value : _value;

  void _digit(int d) {
    setState(() {
      _value = (_value * 10 + d).clamp(0, 999999);
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['±', '0', '⌫'],
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_signed',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            for (final row in keys)
              Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              if (key == '±') {
                                setState(() => _negative = !_negative);
                              } else if (key == '⌫') {
                                setState(() => _value = _value ~/ 10);
                              } else {
                                _digit(int.parse(key));
                              }
                            },
                            child: Text(key),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _value = (_value - 1).clamp(0, 999999);
                  }),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _value = (_value + 1).clamp(0, 999999);
                  }),
                  icon: const Icon(Icons.add),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    widget.controller.setLiteral(widget.blockId, 'value', _signed);
                    Navigator.pop(context);
                  },
                  child: const Text('DONE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VariableChips extends StatelessWidget {
  const _VariableChips({
    required this.controller,
    required this.blockId,
    required this.nameKey,
    required this.names,
    required this.allowCreate,
  });

  final EditorController controller;
  final String blockId;
  final String nameKey;
  final List<String> names;
  final bool allowCreate;

  @override
  Widget build(BuildContext context) {
    final pool = controller.unusedPool;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a name',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in names)
                  ActionChip(
                    label: Text(name),
                    onPressed: () {
                      controller.setLiteral(blockId, nameKey, name);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            if (allowCreate && pool.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'CREATE VARIABLE',
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in pool)
                    OutlinedButton(
                      onPressed: () {
                        controller.declareVariable(v.name, v.type);
                        controller.setLiteral(blockId, nameKey, v.name);
                        Navigator.pop(context);
                      },
                      child: Text(v.name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
