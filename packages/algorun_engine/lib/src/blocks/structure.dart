import '../validation/validation_report.dart';
import 'block_graph.dart';
import 'catalog.dart';
import 'ports.dart';

/// Structural consistency. Does not grade a puzzle and does not lower to IR.
abstract final class GraphStructure {
  static ValidationReport validate(BlockGraph graph) {
    final messages = <ValidationMessage>[];
    final seenParents = <String, BlockParent>{};

    for (final id in graph.entryIds) {
      if (!graph.blocks.containsKey(id)) {
        messages.add(ValidationMessage(
          code: 'missing_block',
          message: 'A stack points at a missing block.',
          blockId: id,
        ));
      }
    }

    for (final block in graph.blocks.values) {
      final def = BlockCatalog.of(block.catalogId);
      if (def == null) {
        messages.add(ValidationMessage(
          code: 'unknown_block',
          message: 'Unknown block.',
          blockId: block.id,
        ));
        continue;
      }
      for (final entry in block.slots.entries) {
        final port = def.port(entry.key);
        if (port == null) {
          messages.add(ValidationMessage(
            code: 'unknown_port',
            message: 'This piece does not fit here.',
            blockId: block.id,
            port: entry.key,
          ));
          continue;
        }
        final slot = entry.value;
        if (port.kind == PortKind.expression) {
          if (slot is! RefBinding) {
            messages.add(ValidationMessage(
              code: 'wrong_kind',
              message: 'This spot needs a value, not a full instruction.',
              blockId: block.id,
              port: entry.key,
            ));
            continue;
          }
          _checkChild(
            graph,
            messages,
            seenParents,
            parent: block.id,
            port: entry.key,
            childId: slot.blockId,
            index: 0,
            expectKind: PortKind.expression,
          );
        } else {
          final ids = slot is ListBinding
              ? slot.blockIds
              : slot is RefBinding
                  ? [slot.blockId]
                  : const <String>[];
          if (port.arity == PortArity.one && ids.length > 1) {
            messages.add(ValidationMessage(
              code: 'duplicate',
              message: 'Something is already plugged in here.',
              blockId: block.id,
              port: entry.key,
            ));
          }
          for (var i = 0; i < ids.length; i++) {
            _checkChild(
              graph,
              messages,
              seenParents,
              parent: block.id,
              port: entry.key,
              childId: ids[i],
              index: i,
              expectKind: port.kind,
            );
          }
        }
      }
    }

    for (var i = 0; i < graph.entryIds.length; i++) {
      final id = graph.entryIds[i];
      if (!graph.blocks.containsKey(id)) continue;
      final existing = seenParents[id];
      if (existing != null) {
        messages.add(ValidationMessage(
          code: 'two_parents',
          message: 'This block is attached in two places.',
          blockId: id,
        ));
      } else {
        seenParents[id] = BlockParent(blockId: BlockGraph.mainId, port: 'body', index: i);
      }
      final def = BlockCatalog.of(graph.blocks[id]!.catalogId);
      if (def != null && def.outputOfKind(PortKind.statement) == null) {
        messages.add(ValidationMessage(
          code: 'wrong_kind',
          message: 'This spot needs an instruction, not a value.',
          blockId: id,
        ));
      }
    }

    _cycles(graph, messages);
    return ValidationReport(messages: messages);
  }
}

void _checkChild(
  BlockGraph graph,
  List<ValidationMessage> messages,
  Map<String, BlockParent> seenParents, {
  required String parent,
  required String port,
  required String childId,
  required int index,
  required PortKind expectKind,
}) {
  final child = graph.blocks[childId];
  if (child == null) {
    messages.add(ValidationMessage(
      code: 'missing_block',
      message: 'A connection points at a missing block.',
      blockId: parent,
      port: port,
    ));
    return;
  }
  final existing = seenParents[childId];
  if (existing != null) {
    messages.add(ValidationMessage(
      code: 'two_parents',
      message: 'This block is attached in two places.',
      blockId: childId,
    ));
  } else {
    seenParents[childId] = BlockParent(blockId: parent, port: port, index: index);
  }
  final def = BlockCatalog.of(child.catalogId);
  if (def?.outputOfKind(expectKind) == null) {
    messages.add(ValidationMessage(
      code: 'wrong_kind',
      message: expectKind == PortKind.expression
          ? 'This spot needs a value, not a full instruction.'
          : expectKind == PortKind.elseClause
              ? 'Only an else branch fits here.'
              : 'This spot needs an instruction, not a value.',
      blockId: parent,
      port: port,
    ));
  }
}

void _cycles(BlockGraph graph, List<ValidationMessage> messages) {
  for (final id in graph.blocks.keys) {
    final seen = <String>{};
    var cur = id;
    while (true) {
      if (!seen.add(cur)) {
        messages.add(ValidationMessage(
          code: 'cycle',
          message: 'This would loop back on itself.',
          blockId: id,
        ));
        break;
      }
      final parent = graph.parentOf(cur);
      if (parent == null || parent.blockId == BlockGraph.mainId) break;
      cur = parent.blockId;
    }
  }
}
