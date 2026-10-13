import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/error_log_service.dart';
import 'package:ordin/services/local_analytics.dart';
import 'package:ordin/ui/home_shell.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    ErrorLogService.instance.enabled = false;
    LocalAnalytics.instance.enabled = false;
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
    ErrorLogService.instance.enabled = true;
    LocalAnalytics.instance.enabled = true;
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    // Wait past boot + debounced bus reload (80ms) + possible sqflite lag.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpBounded(WidgetTester tester, {int ticks = 10}) async {
    for (var i = 0; i < ticks; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tab navigation updates titles without losing NavigationBar',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    for (final dest in ['Tasks', 'Life', 'Finance', 'Timeline', 'Today']) {
      await tester.tap(find.text(dest).last);
      await pumpBounded(tester, ticks: 6);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(dest)),
        findsOneWidget,
        reason: 'AppBar should show $dest after selection',
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    }

    // Drain any leftover debounce timers before dispose.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('opening and closing search leaves shell healthy',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Search'));
    await pumpBounded(tester, ticks: 20);

    // Optional: type if a field is already mounted.
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField.first, 'retain-me');
      await pumpBounded(tester, ticks: 3);
      expect(find.text('retain-me'), findsOneWidget);
    }

    await tester.pageBack();
    // SearchScreen may have scheduled DB work (10s lock timer in tests).
    await tester.pump(const Duration(seconds: 11));
    await pumpBounded(tester, ticks: 5);

    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
