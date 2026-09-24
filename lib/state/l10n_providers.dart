import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/content_text.dart';
import '../l10n/l10n.dart';
import 'progress_providers.dart';

/// The player's language (`en`, `tr`), from the saved settings; English
/// until the save has loaded.
final languageProvider = Provider<String>(
  (ref) => ref.watch(progressProvider).valueOrNull?.settings.language ?? 'en',
);

/// The UI strings of the current language, for code that has a `ref` but no
/// `BuildContext`.
final stringsProvider = Provider<AppLocalizations>((ref) => stringsFor(ref.watch(languageProvider)));

/// Turkish puzzle content (`assets/l10n/content_tr.json`). Loaded only when
/// Turkish is chosen, so English play never touches the asset.
final turkishContentProvider = FutureProvider<ContentTranslations>((ref) async {
  return ContentTranslations.parse(await rootBundle.loadString('assets/l10n/content_tr.json'));
});

/// Puzzle titles, stories, hints, world titles and concept words in the
/// player's language; English while a translation loads.
final contentTextProvider = Provider<ContentText>((ref) {
  final language = ref.watch(languageProvider);
  if (language == 'en') return ContentText.english;
  final translations = ref.watch(turkishContentProvider).valueOrNull;
  return translations == null ? ContentText.english : ContentText(language, translations);
});
