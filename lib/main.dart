import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/progress_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(ProviderScope(
    overrides: [progressStoreProvider.overrideWithValue(platformProgressStore())],
    child: const AlgorunApp(),
  ));
}
