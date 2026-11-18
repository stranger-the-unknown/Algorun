import 'package:algorun_engine/algorun_engine.dart';

/// A block as one line of words (E1), the way the editor lays it out:
/// `SET total TO total PLUS (nums GET ELEMENT i)`. Used by the program
/// outline. Block names stay English, like everywhere else.
///
/// The layout comes from `BlockChrome` and the block's own ports, so a block
/// added to the catalog later reads sensibly without a line here.
abstract final class BlockText {
  /// What an empty slot reads as.
  static const String empty = '…';

  /// The instruction [id] on one line. A C-block gives its header only (its
  /// body is other lines).
  static String line(BlockGraph graph, String id) {
    final block = graph.blocks[id];
    if (block == null) return '';
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) return BlockChrome.labelOf(block.catalogId);
    final label = BlockChrome.labelOf(block.catalogId);
    final name = block.literals['name'];
    final signature = FunctionSignature.of(block);
    if (signature != null) {
      return '$label ${signature.name} (${signature.params.map((p) => p.name).join(', ')})';
    }
    final words = <String>[label, if (name is String) name];
    final slots = [
      for (final port in def.inputs)
        if (port.isExpr) port,
    ];
    for (final (i, port) in slots.indexed) {
      final joiner = _joiner(block.catalogId, port.name, first: i == 0, named: name is String);
      if (joiner != null) words.add(joiner);
      // A lone value, or one behind its own word, needs no parentheses:
      // `WHILE i LESS THAN n`, `SET x TO a PLUS b`, but `PUT counts x (c PLUS 1)`.
      words.add(_slot(graph, id, port.name, nested: slots.length > 1 && joiner == null));
    }
    return words.join(' ');
  }

  /// The words the editor draws between the slots of the few blocks that
  /// have them.
  static String? _joiner(String catalogId, String port, {required bool first, required bool named}) {
    if (catalogId == BlockIds.ctrlForRange) {
      return switch (port) { 'start' => 'FROM', 'end' => 'TO', 'step' => 'BY', _ => null };
    }
    if (catalogId == BlockIds.ctrlForEach && first) return 'IN';
    if (catalogId == BlockIds.varSet && first && named) return 'TO';
    return null;
  }

  static String _slot(BlockGraph graph, String parentId, String port, {bool nested = true}) {
    final filled = graph.slotList(parentId, port);
    return filled.isEmpty ? empty : value(graph, filled.first, nested: nested);
  }

  /// The value [id] in words. [nested] puts a block that has slots of its
  /// own in parentheses, as the block reference writes its examples.
  static String value(BlockGraph graph, String id, {bool nested = false}) {
    final block = graph.blocks[id];
    if (block == null) return empty;
    final def = BlockCatalog.of(block.catalogId);
    final chrome = BlockChrome.of(block.catalogId);
    final name = block.literals['name'];
    if (block.catalogId == BlockIds.varGet) return name is String ? name : empty;
    if (block.catalogId == BlockIds.litNum) return '${block.literals['value'] ?? 0}';
    if (block.catalogId == BlockIds.litBool) return block.literals['value'] == true ? 'TRUE' : 'FALSE';
    final label = name is String ? '${chrome.label} $name' : chrome.label;
    final slots = [
      for (final port in def?.inputs ?? const <PortDefinition>[])
        if (port.isExpr) _slot(graph, id, port.name),
    ];
    if (slots.isEmpty) return label;
    final text = switch (chrome.layout) {
      BlockLayout.infixBinary when slots.length >= 2 => '${slots[0]} $label ${slots.skip(1).join(' ')}',
      BlockLayout.verbObject => [slots.first, label, ...slots.skip(1)].join(' '),
      _ => [label, ...slots].join(' '),
    };
    return nested ? '($text)' : text;
  }
}
