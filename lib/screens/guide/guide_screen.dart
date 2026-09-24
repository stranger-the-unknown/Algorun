import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';

import '../../guide/guide_data.dart';
import '../../l10n/l10n.dart';
import '../../l10n/terms.dart';
import '../../shared/theme/app_theme.dart';

enum GuideTab { basics, concepts, blocks }

/// What the block reference opens on. From a puzzle, [allow] lists the
/// puzzle's blocks so they come first.
final class GuideArgs {
  const GuideArgs({this.allow, this.tab = GuideTab.basics});

  final List<String>? allow;
  final GuideTab tab;
}

/// The block reference (Blok Rehberi): how to play, the ideas behind the
/// blocks, and every block with its Turkish name, what it does in both
/// languages and a small example. Open from home, settings, the puzzle's
/// app bar and the piece picker.
final class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = ModalRoute.of(context)?.settings.arguments;
    final guide = args is GuideArgs ? args : const GuideArgs();
    final language = Localizations.localeOf(context).languageCode;
    return DefaultTabController(
      length: GuideTab.values.length,
      initialIndex: guide.tab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.guideTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // The open tab is bright, bold and underlined; the others muted.
            labelColor: AppColors.fg,
            unselectedLabelColor: AppColors.muted,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            indicatorColor: AppColors.fg,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.border,
            tabs: [
              Tab(key: const Key('guide-tab-basics'), height: 48, text: l.guideTabBasics),
              Tab(key: const Key('guide-tab-concepts'), height: 48, text: l.guideTabConcepts),
              Tab(key: const Key('guide-tab-blocks'), height: 48, text: l.guideTabBlocks),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _Basics(l: l),
              _EntryList(
                key: const Key('guide-concepts'),
                language: language,
                sections: [
                  (
                    label: null,
                    entries: [
                      for (var i = 0; i < conceptGuide.length; i++) (key: 'concept-$i', entry: conceptGuide[i]),
                    ],
                  ),
                ],
              ),
              _EntryList(
                key: const Key('guide-blocks'),
                language: language,
                note: l.guideKeywordNote,
                sections: _blockSections(guide.allow, l),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Keyed = ({String key, GuideEntry entry});
typedef _Section = ({String? label, List<_Keyed> entries});

List<_Section> _blockSections(List<String>? allow, AppLocalizations l) {
  // In the reference's own order (control first), not the puzzle file's.
  final allowed = {...?allow};
  final here = [
    for (final e in blockGuide.entries)
      if (allowed.contains(e.key)) (key: 'block-here-${e.key}', entry: e.value),
  ];
  return [
    if (here.isNotEmpty) (label: l.guideInThisPuzzle, entries: here),
    for (final category in BlockCategory.values)
      (
        label: category == BlockCategory.values.first
            ? '${l.guideAllBlocks} · ${categoryText(category, l)}'
            : categoryText(category, l),
        entries: [
          for (final e in blockGuide.entries)
            if (BlockChrome.of(e.key).category == category) (key: 'block-${e.key}', entry: e.value),
        ],
      ),
  ].where((s) => s.entries.isNotEmpty).toList();
}

class _Basics extends StatelessWidget {
  const _Basics({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (l.guideBasics1Title, l.guideBasics1),
      (l.guideBasics2Title, l.guideBasics2),
      (l.guideBasics3Title, l.guideBasics3),
      (l.guideBasics4Title, l.guideBasics4),
      (l.guideBasics5Title, l.guideBasics5),
      (l.guideBasics6Title, l.guideBasics6),
    ];
    return ListView(
      key: const Key('guide-basics'),
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s4, AppSpace.s4, AppSpace.s6),
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Text('${i + 1}', style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          steps[i].$1,
                          style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      Text(steps[i].$2, style: const TextStyle(color: AppColors.muted, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    super.key,
    required this.language,
    required this.sections,
    this.note,
  });

  final String language;
  final List<_Section> sections;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s4, AppSpace.s4, AppSpace.s6),
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s4),
            child: Text(note!, style: const TextStyle(color: AppColors.muted, height: 1.45)),
          ),
        for (final section in sections) ...[
          if (section.label != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2, bottom: AppSpace.s2),
              child: Semantics(header: true, child: Text(section.label!, style: AppText.label)),
            ),
          for (final item in section.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: GuideCard(key: Key('guide-${item.key}'), entry: item.entry, language: language),
            ),
        ],
      ],
    );
  }
}

/// One block or idea: its English name and Turkish name, what it means in
/// the player's language and then in the other one, and an example.
final class GuideCard extends StatelessWidget {
  const GuideCard({super.key, required this.entry, required this.language});

  final GuideEntry entry;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final other = language == 'tr' ? 'en' : 'tr';
    final example = entry.exampleFor(language);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: entry.term,
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: '  —  ${entry.tr}',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          _Meaning(tag: language.toUpperCase(), text: entry.text(language), primary: true),
          const SizedBox(height: AppSpace.s2),
          _Meaning(tag: other.toUpperCase(), text: entry.text(other), primary: false),
          if (example != null) ...[
            const SizedBox(height: AppSpace.s3),
            Text(l.upper(l.guideExample), style: AppText.label),
            const SizedBox(height: AppSpace.s1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s2),
              decoration: BoxDecoration(
                color: AppColors.subtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                example,
                style: const TextStyle(
                  color: AppColors.fg,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meaning extends StatelessWidget {
  const _Meaning({required this.tag, required this.text, required this.primary});

  final String tag;
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2, right: AppSpace.s2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: primary ? AppColors.borderStrong : AppColors.border),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: primary ? AppColors.fg : AppColors.faint,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: primary ? AppColors.fg : AppColors.muted,
              fontSize: primary ? 14 : 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
