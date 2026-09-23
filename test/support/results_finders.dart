import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The texts of one WHAT IT COST row on the results screen:
/// `[label, used, budget]`, e.g. `['Steps', '58', '30']`.
List<String> costRow(WidgetTester tester, String metric) => [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: find.byKey(Key('cost-$metric')), matching: find.byType(Text)),
      ))
        t.data ?? '',
    ];
