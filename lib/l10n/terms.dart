import 'package:algorun_engine/algorun_engine.dart';

import 'l10n.dart';

/// Player words for the engine's closed vocabularies: slot captions, block
/// categories, puzzle modes, verdicts and value types. Block names themselves
/// (IF, WHILE, GET ELEMENT…) are never translated.

/// A slot's caption (`BlockChrome.holeCaption`), in the player's language.
String holeCaptionText(String port, AppLocalizations l) => switch (BlockChrome.holeCaption(port)) {
      'condition' => l.captionCondition,
      'number' => l.captionNumber,
      'list' => l.captionList,
      'map' => l.captionMap,
      'set' => l.captionSet,
      'stack' => l.captionStack,
      'queue' => l.captionQueue,
      'heap' => l.captionHeap,
      'key' => l.captionKey,
      'node' => l.captionNode,
      'graph' => l.captionGraph,
      'instruction' => l.captionInstruction,
      'else' => l.captionElse,
      _ => l.captionValue,
    };

String categoryText(BlockCategory category, AppLocalizations l) => switch (category) {
      BlockCategory.control => l.catControl,
      BlockCategory.value => l.catValues,
      BlockCategory.logic => l.catLogic,
      BlockCategory.math => l.catMath,
      BlockCategory.collection => l.catLists,
      BlockCategory.structure => l.catStructure,
    };

String modeText(PuzzleMode mode, AppLocalizations l) => switch (mode) {
      PuzzleMode.build => l.modeBuild,
      PuzzleMode.budget => l.modeBudget,
      PuzzleMode.optimize => l.modeOptimize,
      PuzzleMode.edge => l.modeEdge,
      PuzzleMode.restricted => l.modeRestricted,
      _ => l.modeOther,
    };

/// The headline of a verdict: `WRONG ANSWER`.
String verdictText(ResultKind kind, AppLocalizations l) => switch (kind) {
      ResultKind.correct => l.verdictCorrect,
      ResultKind.wrongAnswer => l.verdictWrongAnswer,
      ResultKind.runtimeError => l.verdictRuntimeError,
      ResultKind.operationLimit => l.verdictOperationLimit,
      ResultKind.timeLimit => l.verdictTimeLimit,
      ResultKind.memoryLimit => l.verdictMemoryLimit,
      ResultKind.depthLimit => l.verdictDepthLimit,
      ResultKind.invalidProgram => l.verdictInvalidProgram,
    };

/// A verdict inside a sentence: `wrong answer`.
String kindText(ResultKind kind, AppLocalizations l) => switch (kind) {
      ResultKind.correct => l.kindCorrect,
      ResultKind.wrongAnswer => l.kindWrongAnswer,
      ResultKind.runtimeError => l.kindRuntimeError,
      ResultKind.operationLimit => l.kindOperationLimit,
      ResultKind.timeLimit => l.kindTimeLimit,
      ResultKind.memoryLimit => l.kindMemoryLimit,
      ResultKind.depthLimit => l.kindDepthLimit,
      ResultKind.invalidProgram => l.kindInvalidProgram,
    };

/// What a verdict means, in one sentence.
String verdictMeaning(ResultKind kind, AppLocalizations l) => switch (kind) {
      ResultKind.correct => l.meaningCorrect,
      ResultKind.wrongAnswer => l.meaningWrongAnswer,
      ResultKind.runtimeError => l.meaningRuntimeError,
      ResultKind.operationLimit => l.meaningOperationLimit,
      ResultKind.timeLimit => l.meaningTimeLimit,
      ResultKind.memoryLimit => l.meaningMemoryLimit,
      ResultKind.depthLimit => l.meaningDepthLimit,
      ResultKind.invalidProgram => l.meaningInvalidProgram,
    };

/// A value type in words: `list of numbers`, `chain link, or NOTHING`.
String typeText(ValueType type, AppLocalizations l) {
  final base = switch (type.atom) {
    TypeAtom.number => l.typeNumber,
    TypeAtom.boolean => l.typeBool,
    TypeAtom.string => l.typeText,
    TypeAtom.nil || TypeAtom.voidType => l.typeNothing,
    TypeAtom.listNode => l.typeListNode,
    TypeAtom.treeNode => l.typeTreeNode,
    TypeAtom.graph => l.typeGraph,
    TypeAtom.array => l.typeListOf(_itemText(type.param, l)),
    TypeAtom.set => l.typeSetOf(_itemText(type.param, l)),
    TypeAtom.stack => l.typeStackOf(_itemText(type.param, l)),
    TypeAtom.queue => l.typeQueueOf(_itemText(type.param, l)),
    TypeAtom.deque => l.typeDequeOf(_itemText(type.param, l)),
    TypeAtom.map => l.typeMapOf(_itemText(type.param, l), _itemText(type.param2, l)),
    TypeAtom.heap => l.typeHeapOf(_itemText(type.param, l)),
    TypeAtom.pair => l.typeCollection,
    TypeAtom.generic => l.typeValue,
  };
  return type.nullable && type.atom != TypeAtom.nil ? l.typeMaybe(base) : base;
}

/// A type as the items of a collection (English plural, Turkish singular).
String _itemText(ValueType? type, AppLocalizations l) => switch (type?.atom) {
      TypeAtom.number => l.itemNumber,
      TypeAtom.boolean => l.itemBool,
      TypeAtom.string => l.itemText,
      TypeAtom.array => l.itemList,
      TypeAtom.listNode => l.itemListNode,
      TypeAtom.treeNode => l.itemTreeNode,
      TypeAtom.graph => l.itemGraph,
      null || TypeAtom.generic => l.itemValue,
      _ => l.itemOther,
    };

/// `1 block`, `3 blocks`, `3 blok`.
String blocksText(int n, AppLocalizations l) => l.blocksCount(n);
