// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Algorun';

  @override
  String get homeTagline => 'Construct the algorithm.\nNever type it.';

  @override
  String get homeProgress => 'PROGRESS';

  @override
  String homeSolvedCount(int solved, int total) {
    return '$solved of $total puzzles solved';
  }

  @override
  String homeLastPlayed(String puzzle, String world) {
    return 'Last played: $puzzle · $world';
  }

  @override
  String get homeContinue => 'CONTINUE';

  @override
  String get homeWorlds => 'WORLDS';

  @override
  String get homeEnter => 'ENTER';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeGuide => 'Block reference';

  @override
  String get homeHowToPlay => 'New here? See how to play';

  @override
  String get worldsTitle => 'Worlds';

  @override
  String worldTeaches(String concepts) {
    return 'Teaches $concepts';
  }

  @override
  String get tagCurrent => 'CURRENT';

  @override
  String get worldNoPuzzles => 'No puzzles yet';

  @override
  String get worldSolvedOne => 'Solved';

  @override
  String worldAllSolved(int total) {
    return 'All $total solved';
  }

  @override
  String worldProgress(int solved, int total) {
    return '$solved of $total solved';
  }

  @override
  String lockedLearnFirst(String concepts) {
    return 'Locked — learn $concepts first';
  }

  @override
  String get locked => 'Locked';

  @override
  String get stateCompleted => 'Completed';

  @override
  String get stateOpen => 'Open';

  @override
  String get puzzlesTitle => 'Puzzles';

  @override
  String worldHeading(String index, String title) {
    return '$index · $title';
  }

  @override
  String puzzleListHeader(int solved, int total, String concepts) {
    return '$solved of $total solved · teaches $concepts';
  }

  @override
  String tierLabel(int tier) {
    return 'Tier $tier';
  }

  @override
  String tierWithMode(int tier, String mode) {
    return 'Tier $tier · $mode';
  }

  @override
  String get unknownWorld => 'Unknown world.';

  @override
  String get statusNotStarted => 'Not started';

  @override
  String get statusInProgress => 'In progress';

  @override
  String statusInProgressLastRun(String result) {
    return 'In progress · last run: $result';
  }

  @override
  String statusInProgressLastRunEdited(String result) {
    return 'In progress · last run: $result, edited since';
  }

  @override
  String get statusSolved => 'Solved';

  @override
  String statusSolvedBest(String steps, int blocks) {
    return 'Solved · best $steps steps · $blocks blocks';
  }

  @override
  String get modeBuild => 'build';

  @override
  String get modeBudget => 'budget';

  @override
  String get modeOptimize => 'optimize';

  @override
  String get modeEdge => 'edge';

  @override
  String get modeRestricted => 'restricted';

  @override
  String get modeOther => 'challenge';

  @override
  String get puzzleFallbackTitle => 'Puzzle';

  @override
  String get puzzleCouldNotOpen => 'This puzzle could not be opened.';

  @override
  String get puzzleOpening => 'Opening the puzzle…';

  @override
  String get puzzleLocked => 'This puzzle is locked.';

  @override
  String puzzleLockedLearn(String concepts) {
    return 'This puzzle is locked. It opens once you have learned $concepts.';
  }

  @override
  String get puzzleLockedHow =>
      'A concept is learned by solving every puzzle of the world that teaches it.';

  @override
  String get back => 'BACK';

  @override
  String get puzzleChangedNotice =>
      'This puzzle changed since you last played it. Your program was kept; RUN shows what to update.';

  @override
  String get solved => 'Solved';

  @override
  String get programOptions => 'Program options';

  @override
  String get foldAll => 'Fold every block';

  @override
  String get unfoldAll => 'Unfold every block';

  @override
  String get clearProgram => 'Clear the program';

  @override
  String get solvedLine => 'Solved. Keep improving, or try the next one.';

  @override
  String get loadBest => 'Load best solution';

  @override
  String get bestButton => 'BEST';

  @override
  String get bestLoaded =>
      'Your best solution is loaded. UNDO brings back the program you had.';

  @override
  String get programCleared => 'The program is cleared. UNDO brings it back.';

  @override
  String get blockNeedsAttention => 'This block needs attention.';

  @override
  String get brief => 'BRIEF';

  @override
  String briefTier(int tier) {
    return 'TIER $tier';
  }

  @override
  String briefTierMode(int tier, String mode) {
    return 'TIER $tier · $mode';
  }

  @override
  String get ioInputs => 'INPUTS';

  @override
  String get ioReturns => 'RETURNS';

  @override
  String get ioFunctions => 'FUNCTIONS YOU WRITE';

  @override
  String get hints => 'HINTS';

  @override
  String showHint(int n) {
    return 'SHOW HINT $n';
  }

  @override
  String get noMoreHints => 'NO MORE HINTS';

  @override
  String get hintsIntro =>
      'Hints go from the idea to the approach, one at a time. They are counted, never charged.';

  @override
  String get givens => 'GIVENS';

  @override
  String get variables => 'VARIABLES';

  @override
  String insideFunction(String name) {
    return 'INSIDE $name';
  }

  @override
  String get variablesNote =>
      'The puzzle provides these names; tap a slot, then a name.';

  @override
  String get program => 'PROGRAM';

  @override
  String get tapSlotThenName => 'Tap a value slot, then a name.';

  @override
  String get nameDoesNotFit => 'That name does not fit this slot.';

  @override
  String get openGuide => 'Block reference';

  @override
  String get typeNumber => 'number';

  @override
  String get typeBool => 'yes / no';

  @override
  String get typeText => 'text';

  @override
  String get typeNothing => 'nothing';

  @override
  String get typeValue => 'value';

  @override
  String get typeListNode => 'chain link';

  @override
  String get typeTreeNode => 'tree node';

  @override
  String get typeGraph => 'graph';

  @override
  String get itemNumber => 'numbers';

  @override
  String get itemBool => 'yes / no values';

  @override
  String get itemText => 'texts';

  @override
  String get itemValue => 'values';

  @override
  String get itemList => 'lists';

  @override
  String get itemListNode => 'chain links';

  @override
  String get itemTreeNode => 'tree nodes';

  @override
  String get itemGraph => 'graphs';

  @override
  String get itemOther => 'collections';

  @override
  String typeListOf(String item) {
    return 'list of $item';
  }

  @override
  String typeSetOf(String item) {
    return 'set of $item';
  }

  @override
  String typeStackOf(String item) {
    return 'stack of $item';
  }

  @override
  String typeQueueOf(String item) {
    return 'queue of $item';
  }

  @override
  String typeDequeOf(String item) {
    return 'deque of $item';
  }

  @override
  String typeMapOf(String key, String value) {
    return 'map from $key to $value';
  }

  @override
  String typeMaybe(String type) {
    return '$type, or NOTHING';
  }

  @override
  String get typeCollection => 'collection';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get selected => 'SELECTED';

  @override
  String blocksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '1 block',
    );
    return '$_temp0';
  }

  @override
  String selectionTitle(String label, String blocks) {
    return '$label · $blocks';
  }

  @override
  String get actionUp => 'UP';

  @override
  String get actionDown => 'DOWN';

  @override
  String get actionOut => 'OUT';

  @override
  String get actionIn => 'IN';

  @override
  String get actionCopy => 'COPY';

  @override
  String get actionDelete => 'DELETE';

  @override
  String get actionReplace => 'REPLACE';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get moveOut => 'Move out of the block around it';

  @override
  String get moveIn => 'Move into the block above';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get delete => 'Delete';

  @override
  String deleteWithInside(String blocks) {
    return 'Delete it and the $blocks inside';
  }

  @override
  String get replaceValue => 'Replace this value';

  @override
  String get done => 'Done';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String blockCountWithMax(int count, int max) {
    return '$count / $max blocks';
  }

  @override
  String blockCountSemantics(int count, int max) {
    return '$count of $max blocks';
  }

  @override
  String get overBudgetSuffix => ', over the budget';

  @override
  String get savedOnDevice => 'Saved on this device';

  @override
  String get practiceNotSaved => 'Practice · not saved';

  @override
  String get run => 'RUN';

  @override
  String get running => 'RUNNING';

  @override
  String noticeRemoved(String label) {
    return 'Removed $label. UNDO brings it back.';
  }

  @override
  String noticeRemovedWithInside(String label, String blocks) {
    return 'Removed $label and $blocks inside. UNDO brings them back.';
  }

  @override
  String noticeCopied(String label) {
    return 'Copied $label.';
  }

  @override
  String noticeCopiedWithInside(String label, String blocks) {
    return 'Copied $label with $blocks inside.';
  }

  @override
  String get noticeTapSlotFirst => 'Tap a value slot first.';

  @override
  String get noticePieceDoesNotFit => 'This piece does not fit here.';

  @override
  String get chooseAPiece => 'Choose a piece';

  @override
  String pickerFor(String target) {
    return 'For $target. Only pieces that fit this slot are listed.';
  }

  @override
  String get close => 'Close';

  @override
  String get nothingFits => 'Nothing in this puzzle fits here.';

  @override
  String get targetProgram => 'the program';

  @override
  String get targetSlot => 'this slot';

  @override
  String get targetElse => 'ELSE';

  @override
  String targetThenOf(String block) {
    return 'THEN of $block';
  }

  @override
  String targetDoOf(String block) {
    return 'DO of $block';
  }

  @override
  String targetElseOf(String block) {
    return 'ELSE of $block';
  }

  @override
  String targetCaptionOf(String caption, String block) {
    return 'the $caption of $block';
  }

  @override
  String get captionCondition => 'condition';

  @override
  String get captionNumber => 'number';

  @override
  String get captionList => 'list';

  @override
  String get captionValue => 'value';

  @override
  String get captionMap => 'map';

  @override
  String get captionSet => 'set';

  @override
  String get captionStack => 'stack';

  @override
  String get captionQueue => 'queue';

  @override
  String get captionKey => 'key';

  @override
  String get captionNode => 'node';

  @override
  String get captionGraph => 'graph';

  @override
  String get captionInstruction => 'instruction';

  @override
  String get captionElse => 'else';

  @override
  String emptySlot(String caption) {
    return 'Empty $caption slot';
  }

  @override
  String get catAll => 'ALL';

  @override
  String get catControl => 'CONTROL';

  @override
  String get catValues => 'VALUES';

  @override
  String get catLogic => 'LOGIC';

  @override
  String get catMath => 'MATH';

  @override
  String get catLists => 'LISTS';

  @override
  String get catStructure => 'STRUCTURE';

  @override
  String get paletteBlocks => 'BLOCKS';

  @override
  String get addStep => 'add step';

  @override
  String get emptyProgram =>
      'Your program is empty. Tap to place the first instruction.';

  @override
  String get addElse => 'ADD ELSE';

  @override
  String get removeElse => 'Remove ELSE';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get foldedEmpty => 'Folded · empty';

  @override
  String foldedInside(String blocks) {
    return 'Folded · $blocks inside';
  }

  @override
  String variableChange(String name) {
    return 'Variable $name, change';
  }

  @override
  String get namePlaceholder => 'name';

  @override
  String get itemPlaceholder => 'item';

  @override
  String get chooseName => 'Choose a name';

  @override
  String get namesFromPuzzle =>
      'Names come from the puzzle; there is no typing.';

  @override
  String get padDone => 'DONE';

  @override
  String get padClear => 'CLEAR';

  @override
  String get padSelectedHint => 'Typing replaces this number';

  @override
  String get padEditHint => 'Tap the number to select it all';

  @override
  String get padEmpty => 'Type a number';

  @override
  String get padNegative => 'negative';

  @override
  String get changeSign => 'Change sign';

  @override
  String get deleteDigit => 'Delete last digit';

  @override
  String get clearNumber => 'Clear the number';

  @override
  String padValueSemantics(String value) {
    return 'Number $value';
  }

  @override
  String get resultTitle => 'Result';

  @override
  String get noResult => 'No result.';

  @override
  String get verdictCorrect => 'CORRECT';

  @override
  String get verdictWrongAnswer => 'WRONG ANSWER';

  @override
  String get verdictRuntimeError => 'RUNTIME ERROR';

  @override
  String get verdictOperationLimit => 'OPERATION LIMIT';

  @override
  String get verdictTimeLimit => 'TIME LIMIT';

  @override
  String get verdictMemoryLimit => 'MEMORY LIMIT';

  @override
  String get verdictDepthLimit => 'DEPTH LIMIT';

  @override
  String get verdictInvalidProgram => 'INVALID PROGRAM';

  @override
  String get kindCorrect => 'correct';

  @override
  String get kindWrongAnswer => 'wrong answer';

  @override
  String get kindRuntimeError => 'runtime error';

  @override
  String get kindOperationLimit => 'operation limit';

  @override
  String get kindTimeLimit => 'time limit';

  @override
  String get kindMemoryLimit => 'memory limit';

  @override
  String get kindDepthLimit => 'depth limit';

  @override
  String get kindInvalidProgram => 'invalid program';

  @override
  String get meaningCorrect =>
      'Every case came out right, within every budget.';

  @override
  String get meaningWrongAnswer =>
      'The program finished, but at least one answer is not the expected one.';

  @override
  String get meaningRuntimeError =>
      'The program stopped on an instruction it could not carry out.';

  @override
  String get meaningOperationLimit =>
      'The program needed more steps than the budget allows.';

  @override
  String get meaningTimeLimit => 'The program ran out of time.';

  @override
  String get meaningMemoryLimit =>
      'The program kept more values in its lists and maps than the budget allows.';

  @override
  String get meaningDepthLimit =>
      'The program went deeper than the budget allows.';

  @override
  String get meaningInvalidProgram =>
      'The program cannot run yet. Fix what is listed below.';

  @override
  String get progressSection => 'PROGRESS';

  @override
  String get progressSolved => 'Puzzle solved.';

  @override
  String progressNewBest(String metrics) {
    return 'New best: $metrics.';
  }

  @override
  String progressNowOpen(String worlds) {
    return 'Now open: $worlds.';
  }

  @override
  String get bestSteps => 'fewest steps';

  @override
  String get bestMemory => 'least memory';

  @override
  String get bestDepth => 'least depth';

  @override
  String get bestBlocks => 'fewest blocks';

  @override
  String get bestHints => 'fewest hints';

  @override
  String get whatToFix => 'WHAT TO FIX';

  @override
  String get cases => 'CASES';

  @override
  String get hidden => 'HIDDEN';

  @override
  String hiddenPassed(int passed, int total) {
    return '$passed of $total hidden cases passed.';
  }

  @override
  String get whatItCost => 'WHAT IT COST';

  @override
  String get costUsed => 'USED';

  @override
  String get costBudget => 'BUDGET';

  @override
  String get costSteps => 'Steps';

  @override
  String get costMemory => 'Memory cells';

  @override
  String get costDepth => 'Depth';

  @override
  String get costBlocks => 'Blocks';

  @override
  String get costHints => 'Hints';

  @override
  String hintsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hints',
      one: '1 hint',
    );
    return '$_temp0';
  }

  @override
  String costRowSemantics(String label, String used, String budget) {
    return '$label: $used used, budget $budget';
  }

  @override
  String stoppedAfterStep(int step) {
    return 'Stopped after step $step.';
  }

  @override
  String get hiddenNotShown => 'Hidden test inputs and answers are not shown.';

  @override
  String nextPuzzle(String title) {
    return 'NEXT: $title';
  }

  @override
  String get backToPuzzle => 'BACK TO PUZZLE';

  @override
  String get casePassed => 'passed';

  @override
  String get caseGiven => 'given';

  @override
  String get caseExpected => 'expected';

  @override
  String get caseYouGave => 'you gave';

  @override
  String perfCorrectButOver(String measured, String budget) {
    return 'The result is correct, but this solution uses too many operations: $measured against a budget of $budget.';
  }

  @override
  String perfStillRunning(String measured, String budget) {
    return 'Every case that finished came out right, but this solution uses too many operations: it was still running after $measured, and the budget is $budget.';
  }

  @override
  String perfWrongAndOver(String ops, String budget) {
    return 'This solution uses too many operations ($ops against a budget of $budget), and not every answer is right either.';
  }

  @override
  String perfMoreThan(String count) {
    return 'more than $count';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get showBriefSetting => 'Show the brief when a puzzle opens';

  @override
  String get privacyNote =>
      'Progress, your programs and your best results are saved on this device only. There is no account and nothing is uploaded.';

  @override
  String get webStorageNote =>
      'In a web browser, progress is kept by that browser for this address. Clearing the site\'s data, or another browser, starts fresh.';

  @override
  String get resetProgress => 'Reset progress';

  @override
  String get resetConfirmTitle => 'Reset progress?';

  @override
  String get resetConfirmBody =>
      'Every solved puzzle, saved program and best result on this device is deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get platformNote =>
      'Android is the primary target. Engine code is pure Dart and does not import Flutter.';

  @override
  String get languageSection => 'LANGUAGE';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageNote =>
      'Block names such as IF, WHILE and RETURN stay in English in every language. The block reference explains each of them.';

  @override
  String get languageSelected => 'selected';

  @override
  String get themeSection => 'APPEARANCE';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get themeNote =>
      'System follows your device\'s light or dark setting.';

  @override
  String get developerSection => 'DEVELOPER';

  @override
  String get developerNote =>
      'Debug builds only. The stress probe opens a long, deep program for testing the editor on a phone; it is not saved and not part of the campaign.';

  @override
  String get openStressProbe => 'Open the editor stress probe';

  @override
  String versionLine(String version) {
    return 'Version $version';
  }

  @override
  String get guideTitle => 'Block reference';

  @override
  String get guideTabBasics => 'How to play';

  @override
  String get guideTabConcepts => 'Concepts';

  @override
  String get guideTabBlocks => 'Blocks';

  @override
  String get guideInThisPuzzle => 'IN THIS PUZZLE';

  @override
  String get guideAllBlocks => 'ALL BLOCKS';

  @override
  String get guideExample => 'Example';

  @override
  String get guideKeywordNote =>
      'Block names stay in English. Each card gives the name, what it means in Turkish and in English, and a small example.';

  @override
  String get guideBasics1Title => 'Read the brief';

  @override
  String get guideBasics1 =>
      'The brief tells the story and what to return. INPUTS lists what the puzzle gives you; RETURNS says what your program must give back.';

  @override
  String get guideBasics2Title => 'Place instructions';

  @override
  String get guideBasics2 =>
      'Tap add step and choose a piece. The picker only lists pieces that fit the place you tapped, so you never type code.';

  @override
  String get guideBasics3Title => 'Fill the slots';

  @override
  String get guideBasics3 =>
      'A dashed slot is still empty. Tap it to plug in a value: a name from GIVENS or VARIABLES, a number, or a calculation.';

  @override
  String get guideBasics4Title => 'Edit';

  @override
  String get guideBasics4 =>
      'Tap a block to select it, then move it, copy it or delete it. Every change can be undone. Fold long blocks to see the outline.';

  @override
  String get guideBasics5Title => 'Run';

  @override
  String get guideBasics5 =>
      'RUN checks your program on the visible cases and on hidden ones. Hidden cases only show how many passed. Some puzzles also have a step budget: a correct but slow program is not enough.';

  @override
  String get guideBasics6Title => 'Hints and progress';

  @override
  String get guideBasics6 =>
      'Hints come one at a time. They never stop a solve; the result only counts how many you used. Solving every puzzle of a world teaches its concepts and opens the next worlds.';

  @override
  String get engineNotReadyToRun => 'This program is not ready to run.';

  @override
  String get engineTheCanvasIsEmpty => 'The canvas is empty.';

  @override
  String get engineUnknownBlock => 'Unknown block.';

  @override
  String get engineAStackPointsAtAMissingBlock =>
      'A stack points at a missing block.';

  @override
  String get engineThisProgramIsNotPutTogetherCorrectly =>
      'This program is not put together correctly.';

  @override
  String get engineOnlyAnElseBranchFitsHere => 'Only an else branch fits here.';

  @override
  String get engineThisPieceCannotBeUsedYet => 'This piece cannot be used yet.';

  @override
  String get engineThisSpotNeedsAnInstructionNotA =>
      'This spot needs an instruction, not a value.';

  @override
  String get engineAConnectionPointsAtAMissingBlock =>
      'A connection points at a missing block.';

  @override
  String get engineChooseAName => 'Choose a name.';

  @override
  String get engineThisBlockNeedsAList => 'This block needs a list.';

  @override
  String get engineThisVariableIsNotDefined => 'This variable is not defined.';

  @override
  String get engineThisVariableIsNotANumber => 'This variable is not a number.';

  @override
  String get engineThisPieceDoesNotFitHere => 'This piece does not fit here.';

  @override
  String get engineThisBlockNeedsANumber => 'This block needs a number.';

  @override
  String get engineThisSpotNeedsAValueNotA =>
      'This spot needs a value, not a full instruction.';

  @override
  String get engineThisBlockNeedsACondition => 'This block needs a condition.';

  @override
  String get engineThisBlockNeedsAMap => 'This block needs a map.';

  @override
  String get engineThisBlockNeedsASet => 'This block needs a set.';

  @override
  String get engineThisBlockNeedsAStack => 'This block needs a stack.';

  @override
  String get engineThisBlockNeedsAQueue => 'This block needs a queue.';

  @override
  String get engineThisBlockNeedsAValue => 'This block needs a value.';

  @override
  String get engineThisBlockNeedsAKey => 'This block needs a key.';

  @override
  String get engineThisBlockNeedsANode => 'This block needs a node.';

  @override
  String get engineThisBlockNeedsAGraph => 'This block needs a graph.';

  @override
  String get engineThatBlockAlreadyExists => 'That block already exists.';

  @override
  String get engineThatBlockIsGone => 'That block is gone.';

  @override
  String get engineThisBlockIsNotAttached => 'This block is not attached.';

  @override
  String get engineThatNameIsAlreadyInUse => 'That name is already in use.';

  @override
  String get engineThisValueMayBeEmptyHereCheck =>
      'This value may be empty here. Check that it is not empty first.';

  @override
  String get engineCheckAValueThatMayBeEmpty =>
      'Check a value that may be empty, not NOTHING itself.';

  @override
  String get engineThisValueIsNeverEmptyHereSo =>
      'This value is never empty here, so there is nothing to check.';

  @override
  String get engineSomethingIsAlreadyPluggedInHere =>
      'Something is already plugged in here.';

  @override
  String get engineThisBlockIsAttachedInTwoPlaces =>
      'This block is attached in two places.';

  @override
  String get engineThisWouldLoopBackOnItself =>
      'This would loop back on itself.';

  @override
  String get engineThesePiecesDoNotAttachThatWay =>
      'These pieces do not attach that way.';

  @override
  String get engineThisBlockIsAlreadyAttachedSomewhereElse =>
      'This block is already attached somewhere else.';

  @override
  String get engineThisBlockIsAlreadyInThatStack =>
      'This block is already in that stack.';

  @override
  String get engineThatStackPositionDoesNotExist =>
      'That stack position does not exist.';

  @override
  String get engineBreakAndContinueOnlyWorkInsideA =>
      'Break and continue only work inside a loop.';

  @override
  String get engineThisPuzzleDoesNotExposeAnyBlocks =>
      'This puzzle does not expose any blocks.';

  @override
  String get engineThisPuzzleDoesNotIncludeThatBlock =>
      'This puzzle does not include that block.';

  @override
  String get engineThisProgramHasNoStartingPoint =>
      'This program has no starting point.';

  @override
  String get engineThisProgramWentTooManyLevelsDeep =>
      'This program went too many levels deep.';

  @override
  String get engineThisBlockOnlyWorksInsideALoop =>
      'This block only works inside a loop.';

  @override
  String get engineThisLoopWouldNeverFinish => 'This loop would never finish.';

  @override
  String get engineThisValueCannotBeUsedHere =>
      'This value cannot be used here.';

  @override
  String get engineThisNameHasNoValueYet => 'This name has no value yet.';

  @override
  String get engineYouCannotDivideByZero => 'You cannot divide by zero.';

  @override
  String get engineThisNumberIsTooBig => 'This number is too big.';

  @override
  String get engineThisCallIsMissingAValue => 'This call is missing a value.';

  @override
  String get engineThisBlockIsMissingAValue => 'This block is missing a value.';

  @override
  String get engineThisListGotTooBig => 'This list got too big.';

  @override
  String get engineThisMapGotTooBig => 'This map got too big.';

  @override
  String get engineThisSetGotTooBig => 'This set got too big.';

  @override
  String get engineThisStackGotTooBig => 'This stack got too big.';

  @override
  String get engineThisStackIsEmpty => 'This stack is empty.';

  @override
  String get engineThisQueueGotTooBig => 'This queue got too big.';

  @override
  String get engineThisQueueIsEmpty => 'This queue is empty.';

  @override
  String get engineThisBlockCannotRunYet => 'This block cannot run yet.';

  @override
  String get engineThisBlockIsMissingAName => 'This block is missing a name.';

  @override
  String get engineThisBlockCanOnlySwapTwoNames =>
      'This block can only swap two names.';

  @override
  String get engineThereIsNothingHere => 'There is nothing here.';

  @override
  String get engineThisBlockNeedsAYesOrNo =>
      'This block needs a yes or no value.';

  @override
  String get engineThisBlockNeedsANumberSomeText =>
      'This block needs a number, some text, or a yes or no value as the key.';

  @override
  String get engineAPositionHasToBeAWhole =>
      'A position has to be a whole number.';

  @override
  String get engineThatPositionIsOutsideTheList =>
      'That position is outside the list.';

  @override
  String get engineThisProgramIsNestedTooDeeply =>
      'This program is nested too deeply.';

  @override
  String get engineThisProgramTookTooManySteps =>
      'This program took too many steps.';

  @override
  String get engineThisProgramUsedTooMuchMemory =>
      'This program used too much memory.';

  @override
  String get engineThisPuzzleHasNoTestCases => 'This puzzle has no test cases.';

  @override
  String get engineEveryCasePassed => 'Every case passed.';

  @override
  String get engineThisCaseDidNotComeOutThe =>
      'This case did not come out the way the puzzle expects.';

  @override
  String get engineAHiddenCaseDidNotComeOut =>
      'A hidden case did not come out the way the puzzle expects.';

  @override
  String engineMaxBlocks(String max) {
    return 'This puzzle allows at most $max blocks.';
  }

  @override
  String get engineChooseAFunction => 'Choose a function.';

  @override
  String get engineFunctionAtTop =>
      'A FUNCTION must stay at the top of the program, outside other blocks.';

  @override
  String get engineFunctionMalformed =>
      'This FUNCTION is not put together correctly.';

  @override
  String engineTwoFunctions(String name) {
    return 'There are two FUNCTION blocks named $name.';
  }

  @override
  String engineNoFunction(String name) {
    return 'There is no FUNCTION named $name.';
  }

  @override
  String engineWrongArity(String name) {
    return 'This CALL passes the wrong number of values to $name.';
  }

  @override
  String engineNotInFunction(String name) {
    return '$name is not known inside a FUNCTION: pass it in as a value.';
  }

  @override
  String engineNoReturn(String name) {
    return 'FUNCTION $name ended without RETURN.';
  }

  @override
  String engineNoValueFor(String name) {
    return 'This program did not get a value for $name.';
  }

  @override
  String engineCaseFailed(String id) {
    return 'Case $id did not come out the way the puzzle expects.';
  }
}
