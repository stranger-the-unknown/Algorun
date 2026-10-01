import 'dart:convert';

import '../types/parse_type.dart';
import '../types/value_type.dart';
import 'catalog.dart';
import 'ports.dart';

/// Editor document. Positions are UI-only and ignored by execution.
final class BlockGraph {
  const BlockGraph({
    required this.blocks,
    this.entryIds = const [],
    this.variables = const {},
  });

  /// All block instances keyed by id.
  final Map<String, BlockInstance> blocks;

  /// Top-level statement stack (program body / `main`), in order.
  final List<String> entryIds;

  /// Declared names → types. `var.set` / `var.get` read this.
  final Map<String, ValueType> variables;

  static const empty = BlockGraph(blocks: {});
  static const mainId = BlockGraphMain.id;

  int get blockCount => blocks.length;

  /// Blocks the player placed: everything but the puzzle's FUNCTION blocks
  /// (L2), which the block budget does not count.
  int get playerBlockCount => blocks.values.where((b) => b.catalogId != BlockIds.fnDef).length;

  bool get isEmpty => blocks.isEmpty;

  BlockInstance? operator [](String id) => blocks[id];

  String allocId([String prefix = 'b']) {
    var n = 1;
    while (blocks.containsKey('$prefix$n')) {
      n++;
    }
    return '$prefix$n';
  }

  BlockGraph copyWith({
    Map<String, BlockInstance>? blocks,
    List<String>? entryIds,
    Map<String, ValueType>? variables,
  }) {
    return BlockGraph(
      blocks: blocks ?? Map<String, BlockInstance>.of(this.blocks),
      entryIds: entryIds ?? List<String>.of(this.entryIds),
      variables: variables ?? Map<String, ValueType>.of(this.variables),
    );
  }

  BlockGraph replaceBlock(BlockInstance block) {
    final next = Map<String, BlockInstance>.of(blocks);
    next[block.id] = block;
    return copyWith(blocks: next);
  }

  BlockParent? parentOf(String blockId) {
    for (var i = 0; i < entryIds.length; i++) {
      if (entryIds[i] == blockId) {
        return BlockParent(blockId: mainId, port: 'body', index: i);
      }
    }
    for (final block in blocks.values) {
      for (final entry in block.slots.entries) {
        final slot = entry.value;
        if (slot is RefBinding && slot.blockId == blockId) {
          return BlockParent(blockId: block.id, port: entry.key, index: 0);
        }
        if (slot is ListBinding) {
          final idx = slot.blockIds.indexOf(blockId);
          if (idx >= 0) {
            return BlockParent(blockId: block.id, port: entry.key, index: idx);
          }
        }
      }
    }
    return null;
  }

  /// Drop [blockId] from whatever list/hole holds it. The instance stays.
  BlockGraph detach(String blockId) {
    var changed = false;
    var nextEntries = entryIds;
    if (entryIds.contains(blockId)) {
      nextEntries = [for (final id in entryIds) if (id != blockId) id];
      changed = true;
    }
    final nextBlocks = Map<String, BlockInstance>.of(blocks);
    for (final block in blocks.values) {
      final slots = <String, SlotBinding>{};
      var slotChanged = false;
      for (final entry in block.slots.entries) {
        final slot = entry.value;
        if (slot is RefBinding && slot.blockId == blockId) {
          slotChanged = true;
          continue;
        }
        if (slot is ListBinding && slot.blockIds.contains(blockId)) {
          slots[entry.key] = ListBinding([
            for (final id in slot.blockIds)
              if (id != blockId) id,
          ]);
          slotChanged = true;
        } else {
          slots[entry.key] = slot;
        }
      }
      if (slotChanged) {
        nextBlocks[block.id] = block.copyWith(slots: slots);
        changed = true;
      }
    }
    if (!changed) return this;
    return copyWith(blocks: nextBlocks, entryIds: nextEntries);
  }

  BlockGraph removeBlock(String blockId) {
    var g = detach(blockId);
    if (!g.blocks.containsKey(blockId)) return g;
    final next = Map<String, BlockInstance>.of(g.blocks)..remove(blockId);
    return g.copyWith(blocks: next);
  }

  List<String> slotList(String blockId, String port) {
    if (blockId == mainId && port == 'body') return List<String>.of(entryIds);
    final slot = blocks[blockId]?.slots[port];
    if (slot is ListBinding) return List<String>.of(slot.blockIds);
    if (slot is RefBinding) return [slot.blockId];
    return const [];
  }

  Map<String, Object?> toJson() => {
        'blocks': {
          for (final e in blocks.entries) e.key: e.value.toJson(),
        },
        'entryIds': entryIds,
        'variables': {
          for (final e in variables.entries) e.key: e.value.toString(),
        },
      };

  String toJsonString({bool pretty = false}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(toJson())
        : jsonEncode(toJson());
  }

  static BlockGraph fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Graph JSON must be an object.');
    }
    return fromJson(Map<String, dynamic>.from(decoded));
  }

  static BlockGraph fromJson(Map<String, dynamic> json) {
    final blocksRaw = json['blocks'];
    if (blocksRaw is! Map) {
      throw const FormatException('Graph JSON needs a blocks object.');
    }
    final blocks = <String, BlockInstance>{};
    for (final e in blocksRaw.entries) {
      final raw = e.value;
      if (raw is! Map) {
        throw FormatException('Block ${e.key} must be an object.');
      }
      final inst = BlockInstance.fromJson(Map<String, dynamic>.from(raw));
      if (blocks.containsKey(inst.id) || blocks.containsKey(e.key as String)) {
        throw FormatException('Duplicate block id ${inst.id}.');
      }
      blocks[inst.id] = inst;
    }
    final entriesRaw = json['entryIds'] ?? json['entry'];
    final entryIds = <String>[];
    if (entriesRaw is List) {
      for (final id in entriesRaw) {
        entryIds.add(id as String);
      }
    }
    final varsRaw = json['variables'];
    final variables = <String, ValueType>{};
    if (varsRaw is Map) {
      for (final e in varsRaw.entries) {
        variables[e.key as String] = parseValueType(e.value as String);
      }
    }
    return BlockGraph(blocks: blocks, entryIds: entryIds, variables: variables);
  }
}

final class BlockInstance {
  const BlockInstance({
    required this.id,
    required this.catalogId,
    this.slots = const {},
    this.literals = const {},
    this.x = 0,
    this.y = 0,
    this.collapsed = false,
  });

  final String id;
  final String catalogId;

  /// Named slot bindings (condition, body, left, right, ...).
  final Map<String, SlotBinding> slots;

  /// Literal payload (number value, variable name, ...).
  final Map<String, Object?> literals;

  /// Canvas position. Ignored by the engine.
  final double x;
  final double y;
  final bool collapsed;

  BlockInstance copyWith({
    Map<String, SlotBinding>? slots,
    Map<String, Object?>? literals,
    double? x,
    double? y,
    bool? collapsed,
  }) {
    return BlockInstance(
      id: id,
      catalogId: catalogId,
      slots: slots ?? this.slots,
      literals: literals ?? this.literals,
      x: x ?? this.x,
      y: y ?? this.y,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'catalogId': catalogId,
        'slots': {
          for (final e in slots.entries) e.key: e.value.toJson(),
        },
        'literals': literals,
        'x': x,
        'y': y,
        'collapsed': collapsed,
      };

  static BlockInstance fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final catalogId = json['catalogId'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Block needs an id.');
    }
    if (catalogId is! String || !BlockIds.exists(catalogId)) {
      throw FormatException('Unknown block.');
    }
    final slots = <String, SlotBinding>{};
    final slotsRaw = json['slots'];
    if (slotsRaw is Map) {
      for (final e in slotsRaw.entries) {
        slots[e.key as String] = SlotBinding.fromJson(e.value);
      }
    }
    final lits = <String, Object?>{};
    final litsRaw = json['literals'];
    if (litsRaw is Map) {
      for (final e in litsRaw.entries) {
        lits[e.key as String] = e.value;
      }
    }
    return BlockInstance(
      id: id,
      catalogId: catalogId,
      slots: slots,
      literals: lits,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      collapsed: json['collapsed'] == true,
    );
  }
}

sealed class SlotBinding {
  const SlotBinding();

  Object toJson();

  static SlotBinding fromJson(Object? raw) {
    if (raw is Map) {
      if (raw.containsKey('ref')) {
        final id = raw['ref'];
        if (id is! String) {
          throw const FormatException('A plug is missing its block.');
        }
        return RefBinding(id);
      }
      if (raw.containsKey('list')) {
        final list = raw['list'];
        if (list is! List) {
          throw const FormatException('A stack must be a list of blocks.');
        }
        return ListBinding([for (final id in list) id as String]);
      }
    }
    throw const FormatException('A connection is not shaped correctly.');
  }
}

/// A single nested expression or statement.
final class RefBinding extends SlotBinding {
  const RefBinding(this.blockId);
  final String blockId;

  @override
  Object toJson() => {'ref': blockId};
}

/// Ordered list, used for statement bodies.
final class ListBinding extends SlotBinding {
  const ListBinding(this.blockIds);
  final List<String> blockIds;

  @override
  Object toJson() => {'list': blockIds};
}
