import 'package:algorun_engine/algorun_engine.dart';

/// One step a player could not have taken. [path] points into the graph JSON
/// (`blocks.loop_i`, `variables.seen`).
final class ReplayIssue {
  const ReplayIssue(this.path, this.message);

  final String path;
  final String message;
}

/// The largest number the editor's number pad can enter.
const editorNumberLimit = 999999;

/// Blocks whose `name` literal the editor lets a player choose.
const _namedBlocks = {
  BlockIds.varGet,
  BlockIds.varSet,
  BlockIds.varInc,
  BlockIds.varDec,
  BlockIds.ctrlForRange,
  BlockIds.ctrlForEach,
  ...BlockIds.calls,
};

/// Rebuild [target] the way a player would: start from the puzzle's givens,
/// create names only from its variable pool, and place every block top-down
/// through the same commands the editor issues (`AddBlockCommand`,
/// `AttachStatementCommand`, `ConnectCommand`). Every connection therefore
/// passes `GraphTyping.canConnect`, exactly as it would on a phone.
///
/// Returns every step that could not be taken; empty means a player can build
/// this graph with the puzzle as shipped. The allowlist and block budget are
/// the engine's own `validate`, checked separately.
List<ReplayIssue> replayInEditor(BlockGraph target, Puzzle puzzle) {
  return _Replay(target, puzzle).run();
}

final class _Replay {
  _Replay(this.target, this.puzzle)
      : history = GraphHistory(FunctionSetup.ensure(
          BlockGraph(
            blocks: const {},
            variables: {for (final b in puzzle.io.inputs) b.name: b.type},
          ),
          puzzle.functions,
        ));

  final BlockGraph target;
  final Puzzle puzzle;
  final GraphHistory history;
  final issues = <ReplayIssue>[];
  final placed = <String>{};

  List<ReplayIssue> run() {
    _declareVariables();
    for (final block in target.blocks.values) {
      _checkLiterals(block);
    }
    if (issues.isNotEmpty) return issues;

    for (final (i, id) in target.entryIds.indexed) {
      if (!_statement(id, PortRef.mainBody, i)) return issues;
    }
    for (final id in target.blocks.keys) {
      if (!placed.contains(id)) {
        issues.add(ReplayIssue('blocks.$id', 'This block is not attached to the program.'));
      }
    }
    return issues;
  }

  void _declareVariables() {
    final givens = {for (final b in puzzle.io.inputs) b.name: b.type};
    final pool = {for (final b in puzzle.variablePool) b.name: b.type};
    // Parameters come with the puzzle's functions (L2), already declared.
    final params = {
      for (final f in puzzle.functions)
        for (final p in f.params) p.name: p.type,
    };
    for (final entry in target.variables.entries) {
      final path = 'variables.${entry.key}';
      final param = params[entry.key];
      if (param != null && !pool.containsKey(entry.key)) {
        if (param != entry.value) {
          issues.add(ReplayIssue(path, 'The puzzle\'s function makes "${entry.key}" a $param, not ${entry.value}.'));
        }
        continue;
      }
      final given = givens[entry.key];
      if (given != null) {
        if (given != entry.value) {
          issues.add(ReplayIssue(path, 'The puzzle gives "${entry.key}" as $given, not ${entry.value}.'));
        }
        continue;
      }
      final pooled = pool[entry.key];
      if (pooled == null) {
        issues.add(ReplayIssue(
          path,
          '"${entry.key}" is not in the puzzle\'s variable pool, so a player cannot create it.',
        ));
        continue;
      }
      if (pooled != entry.value) {
        issues.add(ReplayIssue(path, 'The pool makes "${entry.key}" a $pooled, not ${entry.value}.'));
        continue;
      }
      _apply(DeclareVariableCommand(name: entry.key, type: entry.value), path);
    }
  }

  void _checkLiterals(BlockInstance block) {
    // A FUNCTION's literals are its signature, from the puzzle (L2); the
    // replay compares them with what the editor puts there.
    if (block.catalogId == BlockIds.fnDef) return;
    final path = 'blocks.${block.id}';
    for (final entry in block.literals.entries) {
      final key = entry.key;
      final value = entry.value;
      final ok = switch (block.catalogId) {
        BlockIds.litNum => key == 'value' && _padNumber(value),
        BlockIds.litBool => key == 'value' && value is bool,
        final id when _namedBlocks.contains(id) => key == 'name' && value is String,
        _ => false,
      };
      if (!ok) {
        final padNumber = block.catalogId == BlockIds.litNum && key == 'value';
        issues.add(ReplayIssue(
          '$path.literals.$key',
          padNumber
              ? 'The number pad enters whole numbers from -$editorNumberLimit to $editorNumberLimit.'
              : 'The editor cannot set "$key" on ${BlockChrome.labelOf(block.catalogId)}.',
        ));
      }
    }
  }

  bool _padNumber(Object? value) =>
      value is int && value.abs() <= editorNumberLimit;

  bool _statement(String id, PortRef well, int index) {
    // A FUNCTION is not placed: the editor put it there when the puzzle
    // opened (L2). Its body is built like any other list.
    final given = target.blocks[id];
    if (given != null && given.catalogId == BlockIds.fnDef) {
      final opened = history.current.blocks[id];
      final at = history.current.entryIds.indexOf(id);
      if (opened == null || FunctionSignature.of(opened) != FunctionSignature.of(given) || well != PortRef.mainBody || at != index) {
        issues.add(ReplayIssue('blocks.$id', 'This FUNCTION is not one the puzzle gives, where the editor puts it.'));
        return false;
      }
      if (!placed.add(id)) {
        issues.add(ReplayIssue('blocks.$id', 'This block is plugged in twice.'));
        return false;
      }
      return _fill(given);
    }
    final block = _add(id);
    if (block == null) return false;
    if (!_apply(AttachStatementCommand(blockId: id, to: well, index: index), 'blocks.$id')) {
      return false;
    }
    return _fill(block);
  }

  bool _expression(String id, PortRef hole) {
    final block = _add(id);
    if (block == null) return false;
    if (!_apply(ConnectCommand(from: PortRef(id, 'out'), to: hole), 'blocks.$id')) {
      return false;
    }
    return _fill(block);
  }

  bool _fill(BlockInstance block) {
    final def = BlockCatalog.of(block.catalogId)!;
    for (final port in def.inputs) {
      final slot = block.slots[port.name];
      if (slot == null) continue;
      switch (port.kind) {
        case PortKind.expression:
          if (slot is! RefBinding) return _shape(block, port.name);
          if (!_expression(slot.blockId, PortRef(block.id, port.name))) return false;
        case PortKind.statement:
          if (slot is! ListBinding) return _shape(block, port.name);
          for (final (k, child) in slot.blockIds.indexed) {
            if (!_statement(child, PortRef(block.id, port.name), k)) return false;
          }
        case PortKind.elseClause:
          // The editor's own connect stores an ELSE as a one-item list;
          // hand-written graphs use a ref. Both are the same program.
          final clauseId = switch (slot) {
            RefBinding(:final blockId) => blockId,
            ListBinding(:final blockIds) when blockIds.length == 1 => blockIds.single,
            _ => null,
          };
          if (clauseId == null) return _shape(block, port.name);
          final clause = _add(clauseId);
          if (clause == null) return false;
          final connect = ConnectCommand(
            from: PortRef(clauseId, 'clause'),
            to: PortRef(block.id, port.name),
          );
          if (!_apply(connect, 'blocks.$clauseId')) return false;
          if (!_fill(clause)) return false;
      }
    }
    return true;
  }

  BlockInstance? _add(String id) {
    final block = target.blocks[id];
    if (block == null) {
      issues.add(ReplayIssue('blocks.$id', 'A connection points at a missing block.'));
      return null;
    }
    if (!placed.add(id)) {
      issues.add(ReplayIssue('blocks.$id', 'This block is plugged in twice.'));
      return null;
    }
    final add = AddBlockCommand(catalogId: block.catalogId, id: id, literals: block.literals);
    return _apply(add, 'blocks.$id') ? block : null;
  }

  bool _shape(BlockInstance block, String port) {
    issues.add(ReplayIssue('blocks.${block.id}.slots.$port', 'This connection is not shaped correctly.'));
    return false;
  }

  bool _apply(GraphCommand command, String path) {
    final result = history.apply(command);
    if (result.ok) return true;
    issues.add(ReplayIssue(path, result.decision.message ?? 'The editor refuses this step.'));
    return false;
  }
}
