part of 'puzzle_screen.dart';

/// A predict puzzle being played (M1): the puzzle's program, read only, and
/// one question per visible case — *what does it return for this input?*
///
/// Phone layout, top to bottom: the brief, hints and the program in one
/// scroll; the question panel (the inputs, the answer); the answered count
/// and CHECK. Nothing here can change the program, and nothing runs until
/// CHECK: the answers are then compared with what the interpreter returns
/// (`checkPredictions`), and a right set completes the puzzle like a correct
/// RUN does.
///
/// Answers live as long as the screen. They are never saved: a predict
/// puzzle keeps only its completion, its last result and its hint count.
final class PredictPuzzle extends ConsumerStatefulWidget {
  const PredictPuzzle({super.key, required this.puzzle, this.save, this.briefOpen = true});

  final Puzzle puzzle;
  final PuzzleSaveHooks? save;
  final bool briefOpen;

  @override
  ConsumerState<PredictPuzzle> createState() => _PredictPuzzleState();
}

class _PredictPuzzleState extends ConsumerState<PredictPuzzle> {
  late final EditorController _program = EditorController(
    puzzle: widget.puzzle,
    initialGraph: widget.puzzle.starter?.graph,
    readOnly: true,
  );
  late final HintSession _hints = HintSession(widget.puzzle.hints);
  late bool _briefOpen = widget.briefOpen;
  bool _hintsOpen = false;
  bool _checking = false;

  /// The player's answer per visible case id.
  final Map<String, RuntimeValue> _answers = {};

  /// The question on screen.
  int _at = 0;

  List<TestCase> get _questions => widget.puzzle.visibleTests;

  @override
  void dispose() {
    widget.save?.leaving();
    _program.dispose();
    super.dispose();
  }

  void _answer(RuntimeValue value) {
    setState(() {
      _answers[_questions[_at].id] = value;
      // On to the next question still open, if any.
      for (var step = 1; step <= _questions.length; step++) {
        final next = (_at + step) % _questions.length;
        if (!_answers.containsKey(_questions[next].id)) {
          _at = next;
          break;
        }
      }
    });
  }

  Future<void> _askNumber() async {
    final current = _answers[_questions[_at].id];
    final value = await _numberFromPad(context, widget.puzzle, current is NumValue ? current.value.toInt() : null);
    if (value != null && mounted) _answer(NumValue(value));
  }

  Future<void> _check() async {
    if (_checking || _answers.length < _questions.length) return;
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    final outcome = checkPredictions(ref.read(engineProvider), widget.puzzle, _answers, hintsUsed: _hints.used);
    final progress = widget.save?.runFinished(null, outcome.suite);
    final solved = outcome.suite.kind == ResultKind.correct;
    final next = solved ? widget.save?.next(ref.read(contentTextProvider)) : null;
    setState(() => _checking = false);
    final action = await Navigator.pushNamed(
      context,
      '/results',
      arguments: ResultsArgs(
        puzzle: widget.puzzle,
        validation: outcome.validation,
        suite: outcome.suite,
        progress: progress,
        next: next,
        text: ref.read(contentTextProvider),
      ),
    );
    if (!mounted) return;
    if (action == ResultsAction.next && next != null) {
      await Navigator.pushReplacementNamed(
        context,
        '/puzzle',
        arguments: {'worldId': next.worldId, 'puzzleId': next.puzzleId},
      );
      return;
    }
    // Back on the first question that was not right.
    final wrong = outcome.suite.visible.indexWhere((c) => !c.ok);
    setState(() {
      if (wrong >= 0) _at = wrong;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = ref.watch(contentTextProvider);
    final puzzle = widget.puzzle;
    final solved = widget.save?.solved ?? false;
    return ListenableBuilder(
      listenable: _program,
      builder: (context, _) {
        final header = <Widget>[
          if (solved) const _SolvedLine(onLoadBest: null),
          _Brief(
            puzzle: puzzle,
            story: text.story(puzzle),
            open: _briefOpen,
            onToggle: () => setState(() => _briefOpen = !_briefOpen),
          ),
          _HintBar(
            hints: _hints,
            texts: text.hints(puzzle),
            open: _hintsOpen,
            onToggle: () => setState(() => _hintsOpen = !_hintsOpen),
            onReveal: () => setState(() {
              _hints.revealNext();
              _hintsOpen = true;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(l.program, style: AppText.label(context)),
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 13, color: context.palette.muted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    l.predictReadOnly,
                    key: const Key('predict-read-only'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(text.puzzleTitle(puzzle), overflow: TextOverflow.ellipsis)),
                if (solved) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: context.palette.ok, semanticLabel: l.solved),
                ],
              ],
            ),
            actions: [
              IconButton(
                key: const Key('open-guide'),
                tooltip: l.openGuide,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/guide',
                  arguments: GuideArgs(allow: _program.paletteIds, tab: GuideTab.blocks),
                ),
                icon: const Icon(Icons.menu_book_outlined),
              ),
            ],
          ),
          body: ContentWidth(
            maxWidth: ContentWidth.editor,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  Expanded(child: ScriptView(controller: _program, header: header)),
                  _QuestionPanel(
                    puzzle: puzzle,
                    at: _at,
                    answers: _answers,
                    onPick: (i) => setState(() => _at = i),
                    onAskNumber: _askNumber,
                    onBool: (value) => _answer(BoolValue(value)),
                  ),
                  _CheckBar(
                    answered: _answers.length,
                    total: _questions.length,
                    checking: _checking,
                    saved: widget.save != null,
                    onCheck: _check,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The game's own number pad, asked for a plain number.
///
/// The pad edits a NUMBER block through an [EditorController], so it is handed
/// a scratch program holding one: nothing of it is kept but the number. Null
/// when the pad was closed without choosing.
Future<int?> _numberFromPad(BuildContext context, Puzzle puzzle, int? current) async {
  const id = 'answer';
  final pad = EditorController(
    puzzle: puzzle,
    initialGraph: BlockGraph(
      blocks: {
        id: BlockInstance(id: id, catalogId: BlockIds.litNum, literals: {'value': current ?? 0}),
      },
      entryIds: const [id],
    ),
  );
  var chosen = false;
  pad.addListener(() => chosen = true);
  await LiteralSheet.showNumber(context, pad, id);
  final value = pad.graph.blocks[id]?.literals['value'];
  pad.dispose();
  return chosen && value is int ? value : null;
}

/// One question: which one, what the program is given, and the answer.
class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.puzzle,
    required this.at,
    required this.answers,
    required this.onPick,
    required this.onAskNumber,
    required this.onBool,
  });

  final Puzzle puzzle;
  final int at;
  final Map<String, RuntimeValue> answers;
  final ValueChanged<int> onPick;
  final VoidCallback onAskNumber;
  final ValueChanged<bool> onBool;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final questions = puzzle.visibleTests;
    final question = questions[at];
    final answer = answers[question.id];
    final name = TextStyle(color: context.palette.fg, fontWeight: FontWeight.w600);
    final value = TextStyle(color: context.palette.fg, fontFeatures: const [FontFeature.tabularFigures()]);
    return Material(
      color: context.palette.elevated,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.borderStrong))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.predictQuestion(at + 1, questions.length),
                      key: const Key('predict-question'),
                      style: AppText.label(context),
                    ),
                  ),
                  for (var i = 0; i < questions.length; i++)
                    _QuestionDot(
                      key: Key('predict-q-$i'),
                      number: i + 1,
                      current: i == at,
                      answered: answers.containsKey(questions[i].id),
                      onTap: () => onPick(i),
                    ),
                ],
              ),
              for (final input in puzzle.io.inputs)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: input.name, style: name),
                      TextSpan(text: ' = ${fixtureText(valueToJson(question.input[input.name]!))}', style: value),
                    ]),
                    key: Key('predict-input-${input.name}'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l.predictItReturns, style: AppText.label(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: puzzle.io.output == ValueType.boolean
                        ? Row(
                            children: [
                              Expanded(child: _boolChoice(context, true, answer)),
                              const SizedBox(width: 8),
                              Expanded(child: _boolChoice(context, false, answer)),
                            ],
                          )
                        : OutlinedButton(
                            key: const Key('predict-answer'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(
                                color: answer == null ? context.palette.holeOutline : context.palette.borderStrong,
                              ),
                            ),
                            onPressed: onAskNumber,
                            child: Text(
                              answer == null ? l.predictTapToAnswer : fixtureText(valueToJson(answer)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: answer == null
                                  ? TextStyle(color: context.palette.muted)
                                  : TextStyle(
                                      color: context.palette.fg,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boolChoice(BuildContext context, bool value, RuntimeValue? answer) {
    final selected = answer is BoolValue && answer.value == value;
    return Semantics(
      selected: selected,
      child: OutlinedButton.icon(
        key: Key(value ? 'predict-true' : 'predict-false'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: selected ? context.palette.subtle : null,
          side: BorderSide(
            color: selected ? context.palette.accent : context.palette.borderStrong,
            width: selected ? 2 : 1,
          ),
        ),
        onPressed: () => onBool(value),
        icon: Icon(selected ? Icons.check : Icons.circle_outlined, size: 18),
        label: Text(value ? 'TRUE' : 'FALSE'),
      ),
    );
  }
}

/// A question's number: filled once answered, outlined when it is the one on
/// screen. The state is in the semantics too, never in colour alone.
class _QuestionDot extends StatelessWidget {
  const _QuestionDot({
    super.key,
    required this.number,
    required this.current,
    required this.answered,
    required this.onTap,
  });

  final int number;
  final bool current;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      label: context.l10n.predictQuestionSemantics(number),
      checked: answered,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: answered ? context.palette.subtle : null,
                border: Border.all(
                  color: current ? context.palette.accent : context.palette.borderStrong,
                  width: current ? 2 : 1,
                ),
              ),
              child: answered
                  ? Icon(Icons.check, size: 16, color: context.palette.fg)
                  : Text(
                      '$number',
                      style: TextStyle(color: context.palette.fg, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many questions are answered, and CHECK. Always at the bottom, above
/// the system bar, where RUN is in the editor.
class _CheckBar extends StatelessWidget {
  const _CheckBar({
    required this.answered,
    required this.total,
    required this.checking,
    required this.saved,
    required this.onCheck,
  });

  final int answered;
  final int total;
  final bool checking;
  final bool saved;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: context.palette.bg,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.predictAnswered(answered, total),
                        key: const Key('predict-answered'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        saved ? l.savedOnDevice : l.practiceNotSaved,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('predict-check'),
                  style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                  onPressed: checking || answered < total ? null : onCheck,
                  icon: checking
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.muted),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(checking ? l.predictChecking : l.predictCheck),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
