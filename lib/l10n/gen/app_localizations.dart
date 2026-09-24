import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Algorun'**
  String get appTitle;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Construct the algorithm.\nNever type it.'**
  String get homeTagline;

  /// No description provided for @homeProgress.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get homeProgress;

  /// No description provided for @homeSolvedCount.
  ///
  /// In en, this message translates to:
  /// **'{solved} of {total} puzzles solved'**
  String homeSolvedCount(int solved, int total);

  /// No description provided for @homeLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played: {puzzle} · {world}'**
  String homeLastPlayed(String puzzle, String world);

  /// No description provided for @homeContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get homeContinue;

  /// No description provided for @homeWorlds.
  ///
  /// In en, this message translates to:
  /// **'WORLDS'**
  String get homeWorlds;

  /// No description provided for @homeEnter.
  ///
  /// In en, this message translates to:
  /// **'ENTER'**
  String get homeEnter;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeGuide.
  ///
  /// In en, this message translates to:
  /// **'Block reference'**
  String get homeGuide;

  /// No description provided for @homeHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'New here? See how to play'**
  String get homeHowToPlay;

  /// No description provided for @worldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Worlds'**
  String get worldsTitle;

  /// No description provided for @worldTeaches.
  ///
  /// In en, this message translates to:
  /// **'Teaches {concepts}'**
  String worldTeaches(String concepts);

  /// No description provided for @tagCurrent.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get tagCurrent;

  /// No description provided for @worldNoPuzzles.
  ///
  /// In en, this message translates to:
  /// **'No puzzles yet'**
  String get worldNoPuzzles;

  /// No description provided for @worldSolvedOne.
  ///
  /// In en, this message translates to:
  /// **'Solved'**
  String get worldSolvedOne;

  /// No description provided for @worldAllSolved.
  ///
  /// In en, this message translates to:
  /// **'All {total} solved'**
  String worldAllSolved(int total);

  /// No description provided for @worldProgress.
  ///
  /// In en, this message translates to:
  /// **'{solved} of {total} solved'**
  String worldProgress(int solved, int total);

  /// No description provided for @lockedLearnFirst.
  ///
  /// In en, this message translates to:
  /// **'Locked — learn {concepts} first'**
  String lockedLearnFirst(String concepts);

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @stateCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get stateCompleted;

  /// No description provided for @stateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get stateOpen;

  /// No description provided for @puzzlesTitle.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get puzzlesTitle;

  /// No description provided for @worldHeading.
  ///
  /// In en, this message translates to:
  /// **'{index} · {title}'**
  String worldHeading(String index, String title);

  /// No description provided for @puzzleListHeader.
  ///
  /// In en, this message translates to:
  /// **'{solved} of {total} solved · teaches {concepts}'**
  String puzzleListHeader(int solved, int total, String concepts);

  /// No description provided for @tierLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String tierLabel(int tier);

  /// No description provided for @tierWithMode.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier} · {mode}'**
  String tierWithMode(int tier, String mode);

  /// No description provided for @unknownWorld.
  ///
  /// In en, this message translates to:
  /// **'Unknown world.'**
  String get unknownWorld;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statusNotStarted;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusInProgressLastRun.
  ///
  /// In en, this message translates to:
  /// **'In progress · last run: {result}'**
  String statusInProgressLastRun(String result);

  /// No description provided for @statusInProgressLastRunEdited.
  ///
  /// In en, this message translates to:
  /// **'In progress · last run: {result}, edited since'**
  String statusInProgressLastRunEdited(String result);

  /// No description provided for @statusSolved.
  ///
  /// In en, this message translates to:
  /// **'Solved'**
  String get statusSolved;

  /// No description provided for @statusSolvedBest.
  ///
  /// In en, this message translates to:
  /// **'Solved · best {steps} steps · {blocks} blocks'**
  String statusSolvedBest(String steps, int blocks);

  /// No description provided for @modeBuild.
  ///
  /// In en, this message translates to:
  /// **'build'**
  String get modeBuild;

  /// No description provided for @modeBudget.
  ///
  /// In en, this message translates to:
  /// **'budget'**
  String get modeBudget;

  /// No description provided for @modeOptimize.
  ///
  /// In en, this message translates to:
  /// **'optimize'**
  String get modeOptimize;

  /// No description provided for @modeEdge.
  ///
  /// In en, this message translates to:
  /// **'edge'**
  String get modeEdge;

  /// No description provided for @modeRestricted.
  ///
  /// In en, this message translates to:
  /// **'restricted'**
  String get modeRestricted;

  /// No description provided for @modeOther.
  ///
  /// In en, this message translates to:
  /// **'challenge'**
  String get modeOther;

  /// No description provided for @puzzleFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Puzzle'**
  String get puzzleFallbackTitle;

  /// No description provided for @puzzleCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This puzzle could not be opened.'**
  String get puzzleCouldNotOpen;

  /// No description provided for @puzzleOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the puzzle…'**
  String get puzzleOpening;

  /// No description provided for @puzzleLocked.
  ///
  /// In en, this message translates to:
  /// **'This puzzle is locked.'**
  String get puzzleLocked;

  /// No description provided for @puzzleLockedLearn.
  ///
  /// In en, this message translates to:
  /// **'This puzzle is locked. It opens once you have learned {concepts}.'**
  String puzzleLockedLearn(String concepts);

  /// No description provided for @puzzleLockedHow.
  ///
  /// In en, this message translates to:
  /// **'A concept is learned by solving every puzzle of the world that teaches it.'**
  String get puzzleLockedHow;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get back;

  /// No description provided for @puzzleChangedNotice.
  ///
  /// In en, this message translates to:
  /// **'This puzzle changed since you last played it. Your program was kept; RUN shows what to update.'**
  String get puzzleChangedNotice;

  /// No description provided for @solved.
  ///
  /// In en, this message translates to:
  /// **'Solved'**
  String get solved;

  /// No description provided for @programOptions.
  ///
  /// In en, this message translates to:
  /// **'Program options'**
  String get programOptions;

  /// No description provided for @foldAll.
  ///
  /// In en, this message translates to:
  /// **'Fold every block'**
  String get foldAll;

  /// No description provided for @unfoldAll.
  ///
  /// In en, this message translates to:
  /// **'Unfold every block'**
  String get unfoldAll;

  /// No description provided for @clearProgram.
  ///
  /// In en, this message translates to:
  /// **'Clear the program'**
  String get clearProgram;

  /// No description provided for @solvedLine.
  ///
  /// In en, this message translates to:
  /// **'Solved. Keep improving, or try the next one.'**
  String get solvedLine;

  /// No description provided for @loadBest.
  ///
  /// In en, this message translates to:
  /// **'Load best solution'**
  String get loadBest;

  /// No description provided for @bestButton.
  ///
  /// In en, this message translates to:
  /// **'BEST'**
  String get bestButton;

  /// No description provided for @bestLoaded.
  ///
  /// In en, this message translates to:
  /// **'Your best solution is loaded. UNDO brings back the program you had.'**
  String get bestLoaded;

  /// No description provided for @programCleared.
  ///
  /// In en, this message translates to:
  /// **'The program is cleared. UNDO brings it back.'**
  String get programCleared;

  /// No description provided for @blockNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'This block needs attention.'**
  String get blockNeedsAttention;

  /// No description provided for @brief.
  ///
  /// In en, this message translates to:
  /// **'BRIEF'**
  String get brief;

  /// No description provided for @briefTier.
  ///
  /// In en, this message translates to:
  /// **'TIER {tier}'**
  String briefTier(int tier);

  /// No description provided for @briefTierMode.
  ///
  /// In en, this message translates to:
  /// **'TIER {tier} · {mode}'**
  String briefTierMode(int tier, String mode);

  /// No description provided for @ioInputs.
  ///
  /// In en, this message translates to:
  /// **'INPUTS'**
  String get ioInputs;

  /// No description provided for @ioReturns.
  ///
  /// In en, this message translates to:
  /// **'RETURNS'**
  String get ioReturns;

  /// No description provided for @hints.
  ///
  /// In en, this message translates to:
  /// **'HINTS'**
  String get hints;

  /// No description provided for @showHint.
  ///
  /// In en, this message translates to:
  /// **'SHOW HINT {n}'**
  String showHint(int n);

  /// No description provided for @noMoreHints.
  ///
  /// In en, this message translates to:
  /// **'NO MORE HINTS'**
  String get noMoreHints;

  /// No description provided for @hintsIntro.
  ///
  /// In en, this message translates to:
  /// **'Hints go from the idea to the approach, one at a time. They are counted, never charged.'**
  String get hintsIntro;

  /// No description provided for @givens.
  ///
  /// In en, this message translates to:
  /// **'GIVENS'**
  String get givens;

  /// No description provided for @variables.
  ///
  /// In en, this message translates to:
  /// **'VARIABLES'**
  String get variables;

  /// No description provided for @variablesNote.
  ///
  /// In en, this message translates to:
  /// **'The puzzle provides these names; tap a slot, then a name.'**
  String get variablesNote;

  /// No description provided for @program.
  ///
  /// In en, this message translates to:
  /// **'PROGRAM'**
  String get program;

  /// No description provided for @tapSlotThenName.
  ///
  /// In en, this message translates to:
  /// **'Tap a value slot, then a name.'**
  String get tapSlotThenName;

  /// No description provided for @nameDoesNotFit.
  ///
  /// In en, this message translates to:
  /// **'That name does not fit this slot.'**
  String get nameDoesNotFit;

  /// No description provided for @openGuide.
  ///
  /// In en, this message translates to:
  /// **'Block reference'**
  String get openGuide;

  /// No description provided for @typeNumber.
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get typeNumber;

  /// No description provided for @typeBool.
  ///
  /// In en, this message translates to:
  /// **'yes / no'**
  String get typeBool;

  /// No description provided for @typeText.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get typeText;

  /// No description provided for @typeNothing.
  ///
  /// In en, this message translates to:
  /// **'nothing'**
  String get typeNothing;

  /// No description provided for @typeValue.
  ///
  /// In en, this message translates to:
  /// **'value'**
  String get typeValue;

  /// No description provided for @typeListNode.
  ///
  /// In en, this message translates to:
  /// **'chain link'**
  String get typeListNode;

  /// No description provided for @typeTreeNode.
  ///
  /// In en, this message translates to:
  /// **'tree node'**
  String get typeTreeNode;

  /// No description provided for @typeGraph.
  ///
  /// In en, this message translates to:
  /// **'graph'**
  String get typeGraph;

  /// No description provided for @itemNumber.
  ///
  /// In en, this message translates to:
  /// **'numbers'**
  String get itemNumber;

  /// No description provided for @itemBool.
  ///
  /// In en, this message translates to:
  /// **'yes / no values'**
  String get itemBool;

  /// No description provided for @itemText.
  ///
  /// In en, this message translates to:
  /// **'texts'**
  String get itemText;

  /// No description provided for @itemValue.
  ///
  /// In en, this message translates to:
  /// **'values'**
  String get itemValue;

  /// No description provided for @itemList.
  ///
  /// In en, this message translates to:
  /// **'lists'**
  String get itemList;

  /// No description provided for @itemListNode.
  ///
  /// In en, this message translates to:
  /// **'chain links'**
  String get itemListNode;

  /// No description provided for @itemTreeNode.
  ///
  /// In en, this message translates to:
  /// **'tree nodes'**
  String get itemTreeNode;

  /// No description provided for @itemGraph.
  ///
  /// In en, this message translates to:
  /// **'graphs'**
  String get itemGraph;

  /// No description provided for @itemOther.
  ///
  /// In en, this message translates to:
  /// **'collections'**
  String get itemOther;

  /// No description provided for @typeListOf.
  ///
  /// In en, this message translates to:
  /// **'list of {item}'**
  String typeListOf(String item);

  /// No description provided for @typeSetOf.
  ///
  /// In en, this message translates to:
  /// **'set of {item}'**
  String typeSetOf(String item);

  /// No description provided for @typeStackOf.
  ///
  /// In en, this message translates to:
  /// **'stack of {item}'**
  String typeStackOf(String item);

  /// No description provided for @typeQueueOf.
  ///
  /// In en, this message translates to:
  /// **'queue of {item}'**
  String typeQueueOf(String item);

  /// No description provided for @typeDequeOf.
  ///
  /// In en, this message translates to:
  /// **'deque of {item}'**
  String typeDequeOf(String item);

  /// No description provided for @typeMapOf.
  ///
  /// In en, this message translates to:
  /// **'map from {key} to {value}'**
  String typeMapOf(String key, String value);

  /// No description provided for @typeMaybe.
  ///
  /// In en, this message translates to:
  /// **'{type}, or NOTHING'**
  String typeMaybe(String type);

  /// No description provided for @typeCollection.
  ///
  /// In en, this message translates to:
  /// **'collection'**
  String get typeCollection;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get selected;

  /// No description provided for @blocksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 block} other{{count} blocks}}'**
  String blocksCount(int count);

  /// No description provided for @selectionTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} · {blocks}'**
  String selectionTitle(String label, String blocks);

  /// No description provided for @actionUp.
  ///
  /// In en, this message translates to:
  /// **'UP'**
  String get actionUp;

  /// No description provided for @actionDown.
  ///
  /// In en, this message translates to:
  /// **'DOWN'**
  String get actionDown;

  /// No description provided for @actionOut.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get actionOut;

  /// No description provided for @actionIn.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get actionIn;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get actionCopy;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get actionDelete;

  /// No description provided for @actionReplace.
  ///
  /// In en, this message translates to:
  /// **'REPLACE'**
  String get actionReplace;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveOut.
  ///
  /// In en, this message translates to:
  /// **'Move out of the block around it'**
  String get moveOut;

  /// No description provided for @moveIn.
  ///
  /// In en, this message translates to:
  /// **'Move into the block above'**
  String get moveIn;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteWithInside.
  ///
  /// In en, this message translates to:
  /// **'Delete it and the {blocks} inside'**
  String deleteWithInside(String blocks);

  /// No description provided for @replaceValue.
  ///
  /// In en, this message translates to:
  /// **'Replace this value'**
  String get replaceValue;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @blockCountWithMax.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} blocks'**
  String blockCountWithMax(int count, int max);

  /// No description provided for @blockCountSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} blocks'**
  String blockCountSemantics(int count, int max);

  /// No description provided for @overBudgetSuffix.
  ///
  /// In en, this message translates to:
  /// **', over the budget'**
  String get overBudgetSuffix;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get savedOnDevice;

  /// No description provided for @practiceNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Practice · not saved'**
  String get practiceNotSaved;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'RUN'**
  String get run;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'RUNNING'**
  String get running;

  /// No description provided for @noticeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {label}. UNDO brings it back.'**
  String noticeRemoved(String label);

  /// No description provided for @noticeRemovedWithInside.
  ///
  /// In en, this message translates to:
  /// **'Removed {label} and {blocks} inside. UNDO brings them back.'**
  String noticeRemovedWithInside(String label, String blocks);

  /// No description provided for @noticeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {label}.'**
  String noticeCopied(String label);

  /// No description provided for @noticeCopiedWithInside.
  ///
  /// In en, this message translates to:
  /// **'Copied {label} with {blocks} inside.'**
  String noticeCopiedWithInside(String label, String blocks);

  /// No description provided for @noticeTapSlotFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap a value slot first.'**
  String get noticeTapSlotFirst;

  /// No description provided for @noticePieceDoesNotFit.
  ///
  /// In en, this message translates to:
  /// **'This piece does not fit here.'**
  String get noticePieceDoesNotFit;

  /// No description provided for @chooseAPiece.
  ///
  /// In en, this message translates to:
  /// **'Choose a piece'**
  String get chooseAPiece;

  /// No description provided for @pickerFor.
  ///
  /// In en, this message translates to:
  /// **'For {target}. Only pieces that fit this slot are listed.'**
  String pickerFor(String target);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @nothingFits.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this puzzle fits here.'**
  String get nothingFits;

  /// No description provided for @targetProgram.
  ///
  /// In en, this message translates to:
  /// **'the program'**
  String get targetProgram;

  /// No description provided for @targetSlot.
  ///
  /// In en, this message translates to:
  /// **'this slot'**
  String get targetSlot;

  /// No description provided for @targetElse.
  ///
  /// In en, this message translates to:
  /// **'ELSE'**
  String get targetElse;

  /// No description provided for @targetThenOf.
  ///
  /// In en, this message translates to:
  /// **'THEN of {block}'**
  String targetThenOf(String block);

  /// No description provided for @targetDoOf.
  ///
  /// In en, this message translates to:
  /// **'DO of {block}'**
  String targetDoOf(String block);

  /// No description provided for @targetElseOf.
  ///
  /// In en, this message translates to:
  /// **'ELSE of {block}'**
  String targetElseOf(String block);

  /// No description provided for @targetCaptionOf.
  ///
  /// In en, this message translates to:
  /// **'the {caption} of {block}'**
  String targetCaptionOf(String caption, String block);

  /// No description provided for @captionCondition.
  ///
  /// In en, this message translates to:
  /// **'condition'**
  String get captionCondition;

  /// No description provided for @captionNumber.
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get captionNumber;

  /// No description provided for @captionList.
  ///
  /// In en, this message translates to:
  /// **'list'**
  String get captionList;

  /// No description provided for @captionValue.
  ///
  /// In en, this message translates to:
  /// **'value'**
  String get captionValue;

  /// No description provided for @captionMap.
  ///
  /// In en, this message translates to:
  /// **'map'**
  String get captionMap;

  /// No description provided for @captionSet.
  ///
  /// In en, this message translates to:
  /// **'set'**
  String get captionSet;

  /// No description provided for @captionStack.
  ///
  /// In en, this message translates to:
  /// **'stack'**
  String get captionStack;

  /// No description provided for @captionQueue.
  ///
  /// In en, this message translates to:
  /// **'queue'**
  String get captionQueue;

  /// No description provided for @captionKey.
  ///
  /// In en, this message translates to:
  /// **'key'**
  String get captionKey;

  /// No description provided for @captionNode.
  ///
  /// In en, this message translates to:
  /// **'node'**
  String get captionNode;

  /// No description provided for @captionGraph.
  ///
  /// In en, this message translates to:
  /// **'graph'**
  String get captionGraph;

  /// No description provided for @captionInstruction.
  ///
  /// In en, this message translates to:
  /// **'instruction'**
  String get captionInstruction;

  /// No description provided for @captionElse.
  ///
  /// In en, this message translates to:
  /// **'else'**
  String get captionElse;

  /// No description provided for @emptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty {caption} slot'**
  String emptySlot(String caption);

  /// No description provided for @catAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get catAll;

  /// No description provided for @catControl.
  ///
  /// In en, this message translates to:
  /// **'CONTROL'**
  String get catControl;

  /// No description provided for @catValues.
  ///
  /// In en, this message translates to:
  /// **'VALUES'**
  String get catValues;

  /// No description provided for @catLogic.
  ///
  /// In en, this message translates to:
  /// **'LOGIC'**
  String get catLogic;

  /// No description provided for @catMath.
  ///
  /// In en, this message translates to:
  /// **'MATH'**
  String get catMath;

  /// No description provided for @catLists.
  ///
  /// In en, this message translates to:
  /// **'LISTS'**
  String get catLists;

  /// No description provided for @catStructure.
  ///
  /// In en, this message translates to:
  /// **'STRUCTURE'**
  String get catStructure;

  /// No description provided for @paletteBlocks.
  ///
  /// In en, this message translates to:
  /// **'BLOCKS'**
  String get paletteBlocks;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'add step'**
  String get addStep;

  /// No description provided for @emptyProgram.
  ///
  /// In en, this message translates to:
  /// **'Your program is empty. Tap to place the first instruction.'**
  String get emptyProgram;

  /// No description provided for @addElse.
  ///
  /// In en, this message translates to:
  /// **'ADD ELSE'**
  String get addElse;

  /// No description provided for @removeElse.
  ///
  /// In en, this message translates to:
  /// **'Remove ELSE'**
  String get removeElse;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @foldedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Folded · empty'**
  String get foldedEmpty;

  /// No description provided for @foldedInside.
  ///
  /// In en, this message translates to:
  /// **'Folded · {blocks} inside'**
  String foldedInside(String blocks);

  /// No description provided for @variableChange.
  ///
  /// In en, this message translates to:
  /// **'Variable {name}, change'**
  String variableChange(String name);

  /// No description provided for @namePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'name'**
  String get namePlaceholder;

  /// No description provided for @itemPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get itemPlaceholder;

  /// No description provided for @chooseName.
  ///
  /// In en, this message translates to:
  /// **'Choose a name'**
  String get chooseName;

  /// No description provided for @namesFromPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Names come from the puzzle; there is no typing.'**
  String get namesFromPuzzle;

  /// No description provided for @padDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get padDone;

  /// No description provided for @padClear.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get padClear;

  /// No description provided for @padSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Typing replaces this number'**
  String get padSelectedHint;

  /// No description provided for @padEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the number to select it all'**
  String get padEditHint;

  /// No description provided for @padEmpty.
  ///
  /// In en, this message translates to:
  /// **'Type a number'**
  String get padEmpty;

  /// No description provided for @padNegative.
  ///
  /// In en, this message translates to:
  /// **'negative'**
  String get padNegative;

  /// No description provided for @changeSign.
  ///
  /// In en, this message translates to:
  /// **'Change sign'**
  String get changeSign;

  /// No description provided for @deleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get deleteDigit;

  /// No description provided for @clearNumber.
  ///
  /// In en, this message translates to:
  /// **'Clear the number'**
  String get clearNumber;

  /// No description provided for @padValueSemantics.
  ///
  /// In en, this message translates to:
  /// **'Number {value}'**
  String padValueSemantics(String value);

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultTitle;

  /// No description provided for @noResult.
  ///
  /// In en, this message translates to:
  /// **'No result.'**
  String get noResult;

  /// No description provided for @verdictCorrect.
  ///
  /// In en, this message translates to:
  /// **'CORRECT'**
  String get verdictCorrect;

  /// No description provided for @verdictWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'WRONG ANSWER'**
  String get verdictWrongAnswer;

  /// No description provided for @verdictRuntimeError.
  ///
  /// In en, this message translates to:
  /// **'RUNTIME ERROR'**
  String get verdictRuntimeError;

  /// No description provided for @verdictOperationLimit.
  ///
  /// In en, this message translates to:
  /// **'OPERATION LIMIT'**
  String get verdictOperationLimit;

  /// No description provided for @verdictTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'TIME LIMIT'**
  String get verdictTimeLimit;

  /// No description provided for @verdictMemoryLimit.
  ///
  /// In en, this message translates to:
  /// **'MEMORY LIMIT'**
  String get verdictMemoryLimit;

  /// No description provided for @verdictDepthLimit.
  ///
  /// In en, this message translates to:
  /// **'DEPTH LIMIT'**
  String get verdictDepthLimit;

  /// No description provided for @verdictInvalidProgram.
  ///
  /// In en, this message translates to:
  /// **'INVALID PROGRAM'**
  String get verdictInvalidProgram;

  /// No description provided for @kindCorrect.
  ///
  /// In en, this message translates to:
  /// **'correct'**
  String get kindCorrect;

  /// No description provided for @kindWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'wrong answer'**
  String get kindWrongAnswer;

  /// No description provided for @kindRuntimeError.
  ///
  /// In en, this message translates to:
  /// **'runtime error'**
  String get kindRuntimeError;

  /// No description provided for @kindOperationLimit.
  ///
  /// In en, this message translates to:
  /// **'operation limit'**
  String get kindOperationLimit;

  /// No description provided for @kindTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'time limit'**
  String get kindTimeLimit;

  /// No description provided for @kindMemoryLimit.
  ///
  /// In en, this message translates to:
  /// **'memory limit'**
  String get kindMemoryLimit;

  /// No description provided for @kindDepthLimit.
  ///
  /// In en, this message translates to:
  /// **'depth limit'**
  String get kindDepthLimit;

  /// No description provided for @kindInvalidProgram.
  ///
  /// In en, this message translates to:
  /// **'invalid program'**
  String get kindInvalidProgram;

  /// No description provided for @meaningCorrect.
  ///
  /// In en, this message translates to:
  /// **'Every case came out right, within every budget.'**
  String get meaningCorrect;

  /// No description provided for @meaningWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'The program finished, but at least one answer is not the expected one.'**
  String get meaningWrongAnswer;

  /// No description provided for @meaningRuntimeError.
  ///
  /// In en, this message translates to:
  /// **'The program stopped on an instruction it could not carry out.'**
  String get meaningRuntimeError;

  /// No description provided for @meaningOperationLimit.
  ///
  /// In en, this message translates to:
  /// **'The program needed more steps than the budget allows.'**
  String get meaningOperationLimit;

  /// No description provided for @meaningTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'The program ran out of time.'**
  String get meaningTimeLimit;

  /// No description provided for @meaningMemoryLimit.
  ///
  /// In en, this message translates to:
  /// **'The program kept more values in its lists and maps than the budget allows.'**
  String get meaningMemoryLimit;

  /// No description provided for @meaningDepthLimit.
  ///
  /// In en, this message translates to:
  /// **'The program went deeper than the budget allows.'**
  String get meaningDepthLimit;

  /// No description provided for @meaningInvalidProgram.
  ///
  /// In en, this message translates to:
  /// **'The program cannot run yet. Fix what is listed below.'**
  String get meaningInvalidProgram;

  /// No description provided for @progressSection.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get progressSection;

  /// No description provided for @progressSolved.
  ///
  /// In en, this message translates to:
  /// **'Puzzle solved.'**
  String get progressSolved;

  /// No description provided for @progressNewBest.
  ///
  /// In en, this message translates to:
  /// **'New best: {metrics}.'**
  String progressNewBest(String metrics);

  /// No description provided for @progressNowOpen.
  ///
  /// In en, this message translates to:
  /// **'Now open: {worlds}.'**
  String progressNowOpen(String worlds);

  /// No description provided for @bestSteps.
  ///
  /// In en, this message translates to:
  /// **'fewest steps'**
  String get bestSteps;

  /// No description provided for @bestMemory.
  ///
  /// In en, this message translates to:
  /// **'least memory'**
  String get bestMemory;

  /// No description provided for @bestDepth.
  ///
  /// In en, this message translates to:
  /// **'least depth'**
  String get bestDepth;

  /// No description provided for @bestBlocks.
  ///
  /// In en, this message translates to:
  /// **'fewest blocks'**
  String get bestBlocks;

  /// No description provided for @bestHints.
  ///
  /// In en, this message translates to:
  /// **'fewest hints'**
  String get bestHints;

  /// No description provided for @whatToFix.
  ///
  /// In en, this message translates to:
  /// **'WHAT TO FIX'**
  String get whatToFix;

  /// No description provided for @cases.
  ///
  /// In en, this message translates to:
  /// **'CASES'**
  String get cases;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'HIDDEN'**
  String get hidden;

  /// No description provided for @hiddenPassed.
  ///
  /// In en, this message translates to:
  /// **'{passed} of {total} hidden cases passed.'**
  String hiddenPassed(int passed, int total);

  /// No description provided for @whatItCost.
  ///
  /// In en, this message translates to:
  /// **'WHAT IT COST'**
  String get whatItCost;

  /// No description provided for @costUsed.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get costUsed;

  /// No description provided for @costBudget.
  ///
  /// In en, this message translates to:
  /// **'BUDGET'**
  String get costBudget;

  /// No description provided for @costSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get costSteps;

  /// No description provided for @costMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory cells'**
  String get costMemory;

  /// No description provided for @costDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get costDepth;

  /// No description provided for @costBlocks.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get costBlocks;

  /// No description provided for @costHints.
  ///
  /// In en, this message translates to:
  /// **'Hints'**
  String get costHints;

  /// No description provided for @hintsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hint} other{{count} hints}}'**
  String hintsCount(int count);

  /// No description provided for @costRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}: {used} used, budget {budget}'**
  String costRowSemantics(String label, String used, String budget);

  /// No description provided for @stoppedAfterStep.
  ///
  /// In en, this message translates to:
  /// **'Stopped after step {step}.'**
  String stoppedAfterStep(int step);

  /// No description provided for @hiddenNotShown.
  ///
  /// In en, this message translates to:
  /// **'Hidden test inputs and answers are not shown.'**
  String get hiddenNotShown;

  /// No description provided for @nextPuzzle.
  ///
  /// In en, this message translates to:
  /// **'NEXT: {title}'**
  String nextPuzzle(String title);

  /// No description provided for @backToPuzzle.
  ///
  /// In en, this message translates to:
  /// **'BACK TO PUZZLE'**
  String get backToPuzzle;

  /// No description provided for @casePassed.
  ///
  /// In en, this message translates to:
  /// **'passed'**
  String get casePassed;

  /// No description provided for @caseGiven.
  ///
  /// In en, this message translates to:
  /// **'given'**
  String get caseGiven;

  /// No description provided for @caseExpected.
  ///
  /// In en, this message translates to:
  /// **'expected'**
  String get caseExpected;

  /// No description provided for @caseYouGave.
  ///
  /// In en, this message translates to:
  /// **'you gave'**
  String get caseYouGave;

  /// No description provided for @perfCorrectButOver.
  ///
  /// In en, this message translates to:
  /// **'The result is correct, but this solution uses too many operations: {measured} against a budget of {budget}.'**
  String perfCorrectButOver(String measured, String budget);

  /// No description provided for @perfStillRunning.
  ///
  /// In en, this message translates to:
  /// **'Every case that finished came out right, but this solution uses too many operations: it was still running after {measured}, and the budget is {budget}.'**
  String perfStillRunning(String measured, String budget);

  /// No description provided for @perfWrongAndOver.
  ///
  /// In en, this message translates to:
  /// **'This solution uses too many operations ({ops} against a budget of {budget}), and not every answer is right either.'**
  String perfWrongAndOver(String ops, String budget);

  /// No description provided for @perfMoreThan.
  ///
  /// In en, this message translates to:
  /// **'more than {count}'**
  String perfMoreThan(String count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @showBriefSetting.
  ///
  /// In en, this message translates to:
  /// **'Show the brief when a puzzle opens'**
  String get showBriefSetting;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Progress, your programs and your best results are saved on this device only. There is no account and nothing is uploaded.'**
  String get privacyNote;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get resetProgress;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset progress?'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every solved puzzle, saved program and best result on this device is deleted. This cannot be undone.'**
  String get resetConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @platformNote.
  ///
  /// In en, this message translates to:
  /// **'Android is the primary target. Engine code is pure Dart and does not import Flutter.'**
  String get platformNote;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageSection;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Block names such as IF, WHILE and RETURN stay in English in every language. The block reference explains each of them.'**
  String get languageNote;

  /// No description provided for @languageSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get languageSelected;

  /// No description provided for @developerSection.
  ///
  /// In en, this message translates to:
  /// **'DEVELOPER'**
  String get developerSection;

  /// No description provided for @developerNote.
  ///
  /// In en, this message translates to:
  /// **'Debug builds only. The stress probe opens a long, deep program for testing the editor on a phone; it is not saved and not part of the campaign.'**
  String get developerNote;

  /// No description provided for @openStressProbe.
  ///
  /// In en, this message translates to:
  /// **'Open the editor stress probe'**
  String get openStressProbe;

  /// No description provided for @versionLine.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLine(String version);

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Block reference'**
  String get guideTitle;

  /// No description provided for @guideTabBasics.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get guideTabBasics;

  /// No description provided for @guideTabConcepts.
  ///
  /// In en, this message translates to:
  /// **'Concepts'**
  String get guideTabConcepts;

  /// No description provided for @guideTabBlocks.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get guideTabBlocks;

  /// No description provided for @guideInThisPuzzle.
  ///
  /// In en, this message translates to:
  /// **'IN THIS PUZZLE'**
  String get guideInThisPuzzle;

  /// No description provided for @guideAllBlocks.
  ///
  /// In en, this message translates to:
  /// **'ALL BLOCKS'**
  String get guideAllBlocks;

  /// No description provided for @guideExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get guideExample;

  /// No description provided for @guideKeywordNote.
  ///
  /// In en, this message translates to:
  /// **'Block names stay in English. Each card gives the name, what it means in Turkish and in English, and a small example.'**
  String get guideKeywordNote;

  /// No description provided for @guideBasics1Title.
  ///
  /// In en, this message translates to:
  /// **'Read the brief'**
  String get guideBasics1Title;

  /// No description provided for @guideBasics1.
  ///
  /// In en, this message translates to:
  /// **'The brief tells the story and what to return. INPUTS lists what the puzzle gives you; RETURNS says what your program must give back.'**
  String get guideBasics1;

  /// No description provided for @guideBasics2Title.
  ///
  /// In en, this message translates to:
  /// **'Place instructions'**
  String get guideBasics2Title;

  /// No description provided for @guideBasics2.
  ///
  /// In en, this message translates to:
  /// **'Tap add step and choose a piece. The picker only lists pieces that fit the place you tapped, so you never type code.'**
  String get guideBasics2;

  /// No description provided for @guideBasics3Title.
  ///
  /// In en, this message translates to:
  /// **'Fill the slots'**
  String get guideBasics3Title;

  /// No description provided for @guideBasics3.
  ///
  /// In en, this message translates to:
  /// **'A dashed slot is still empty. Tap it to plug in a value: a name from GIVENS or VARIABLES, a number, or a calculation.'**
  String get guideBasics3;

  /// No description provided for @guideBasics4Title.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get guideBasics4Title;

  /// No description provided for @guideBasics4.
  ///
  /// In en, this message translates to:
  /// **'Tap a block to select it, then move it, copy it or delete it. Every change can be undone. Fold long blocks to see the outline.'**
  String get guideBasics4;

  /// No description provided for @guideBasics5Title.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get guideBasics5Title;

  /// No description provided for @guideBasics5.
  ///
  /// In en, this message translates to:
  /// **'RUN checks your program on the visible cases and on hidden ones. Hidden cases only show how many passed. Some puzzles also have a step budget: a correct but slow program is not enough.'**
  String get guideBasics5;

  /// No description provided for @guideBasics6Title.
  ///
  /// In en, this message translates to:
  /// **'Hints and progress'**
  String get guideBasics6Title;

  /// No description provided for @guideBasics6.
  ///
  /// In en, this message translates to:
  /// **'Hints come one at a time. They never stop a solve; the result only counts how many you used. Solving every puzzle of a world teaches its concepts and opens the next worlds.'**
  String get guideBasics6;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program is not ready to run.'**
  String get engineNotReadyToRun;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'The canvas is empty.'**
  String get engineTheCanvasIsEmpty;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Unknown block.'**
  String get engineUnknownBlock;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'A stack points at a missing block.'**
  String get engineAStackPointsAtAMissingBlock;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program is not put together correctly.'**
  String get engineThisProgramIsNotPutTogetherCorrectly;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Only an else branch fits here.'**
  String get engineOnlyAnElseBranchFitsHere;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This piece cannot be used yet.'**
  String get engineThisPieceCannotBeUsedYet;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This spot needs an instruction, not a value.'**
  String get engineThisSpotNeedsAnInstructionNotA;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'A connection points at a missing block.'**
  String get engineAConnectionPointsAtAMissingBlock;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Choose a name.'**
  String get engineChooseAName;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a list.'**
  String get engineThisBlockNeedsAList;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This variable is not defined.'**
  String get engineThisVariableIsNotDefined;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This variable is not a number.'**
  String get engineThisVariableIsNotANumber;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This piece does not fit here.'**
  String get engineThisPieceDoesNotFitHere;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a number.'**
  String get engineThisBlockNeedsANumber;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This spot needs a value, not a full instruction.'**
  String get engineThisSpotNeedsAValueNotA;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a condition.'**
  String get engineThisBlockNeedsACondition;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a map.'**
  String get engineThisBlockNeedsAMap;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a set.'**
  String get engineThisBlockNeedsASet;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a stack.'**
  String get engineThisBlockNeedsAStack;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a queue.'**
  String get engineThisBlockNeedsAQueue;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a value.'**
  String get engineThisBlockNeedsAValue;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a key.'**
  String get engineThisBlockNeedsAKey;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a node.'**
  String get engineThisBlockNeedsANode;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a graph.'**
  String get engineThisBlockNeedsAGraph;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'That block already exists.'**
  String get engineThatBlockAlreadyExists;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'That block is gone.'**
  String get engineThatBlockIsGone;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is not attached.'**
  String get engineThisBlockIsNotAttached;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'That name is already in use.'**
  String get engineThatNameIsAlreadyInUse;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This value may be empty here. Check that it is not empty first.'**
  String get engineThisValueMayBeEmptyHereCheck;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Check a value that may be empty, not NOTHING itself.'**
  String get engineCheckAValueThatMayBeEmpty;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This value is never empty here, so there is nothing to check.'**
  String get engineThisValueIsNeverEmptyHereSo;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Something is already plugged in here.'**
  String get engineSomethingIsAlreadyPluggedInHere;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is attached in two places.'**
  String get engineThisBlockIsAttachedInTwoPlaces;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This would loop back on itself.'**
  String get engineThisWouldLoopBackOnItself;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'These pieces do not attach that way.'**
  String get engineThesePiecesDoNotAttachThatWay;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is already attached somewhere else.'**
  String get engineThisBlockIsAlreadyAttachedSomewhereElse;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is already in that stack.'**
  String get engineThisBlockIsAlreadyInThatStack;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'That stack position does not exist.'**
  String get engineThatStackPositionDoesNotExist;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Break and continue only work inside a loop.'**
  String get engineBreakAndContinueOnlyWorkInsideA;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This puzzle does not expose any blocks.'**
  String get engineThisPuzzleDoesNotExposeAnyBlocks;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This puzzle does not include that block.'**
  String get engineThisPuzzleDoesNotIncludeThatBlock;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program has no starting point.'**
  String get engineThisProgramHasNoStartingPoint;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program went too many levels deep.'**
  String get engineThisProgramWentTooManyLevelsDeep;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block only works inside a loop.'**
  String get engineThisBlockOnlyWorksInsideALoop;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This loop would never finish.'**
  String get engineThisLoopWouldNeverFinish;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This value cannot be used here.'**
  String get engineThisValueCannotBeUsedHere;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This name has no value yet.'**
  String get engineThisNameHasNoValueYet;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'You cannot divide by zero.'**
  String get engineYouCannotDivideByZero;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This number is too big.'**
  String get engineThisNumberIsTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This call is missing a value.'**
  String get engineThisCallIsMissingAValue;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is missing a value.'**
  String get engineThisBlockIsMissingAValue;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This list got too big.'**
  String get engineThisListGotTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This map got too big.'**
  String get engineThisMapGotTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This set got too big.'**
  String get engineThisSetGotTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This stack got too big.'**
  String get engineThisStackGotTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This stack is empty.'**
  String get engineThisStackIsEmpty;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This queue got too big.'**
  String get engineThisQueueGotTooBig;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This queue is empty.'**
  String get engineThisQueueIsEmpty;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block cannot run yet.'**
  String get engineThisBlockCannotRunYet;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block is missing a name.'**
  String get engineThisBlockIsMissingAName;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block can only swap two names.'**
  String get engineThisBlockCanOnlySwapTwoNames;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'There is nothing here.'**
  String get engineThereIsNothingHere;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a yes or no value.'**
  String get engineThisBlockNeedsAYesOrNo;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This block needs a number, some text, or a yes or no value as the key.'**
  String get engineThisBlockNeedsANumberSomeText;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'A position has to be a whole number.'**
  String get engineAPositionHasToBeAWhole;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'That position is outside the list.'**
  String get engineThatPositionIsOutsideTheList;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program is nested too deeply.'**
  String get engineThisProgramIsNestedTooDeeply;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program took too many steps.'**
  String get engineThisProgramTookTooManySteps;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This program used too much memory.'**
  String get engineThisProgramUsedTooMuchMemory;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This puzzle has no test cases.'**
  String get engineThisPuzzleHasNoTestCases;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'Every case passed.'**
  String get engineEveryCasePassed;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'This case did not come out the way the puzzle expects.'**
  String get engineThisCaseDidNotComeOutThe;

  /// Engine message, looked up by its English text (lib/l10n/engine_text.dart).
  ///
  /// In en, this message translates to:
  /// **'A hidden case did not come out the way the puzzle expects.'**
  String get engineAHiddenCaseDidNotComeOut;

  /// No description provided for @engineMaxBlocks.
  ///
  /// In en, this message translates to:
  /// **'This puzzle allows at most {max} blocks.'**
  String engineMaxBlocks(String max);

  /// No description provided for @engineNoValueFor.
  ///
  /// In en, this message translates to:
  /// **'This program did not get a value for {name}.'**
  String engineNoValueFor(String name);

  /// No description provided for @engineCaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Case {id} did not come out the way the puzzle expects.'**
  String engineCaseFailed(String id);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
