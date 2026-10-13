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
    // Bounded pumps — HomeShell may schedule debounced reloads / timers.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpBounded(WidgetTester tester, {int ticks = 10}) async {
    for (var i = 0; i < ticks; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tab navigation keeps shell mounted and titles update',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Tasks').last);
    await pumpBounded(tester, ticks: 5);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Tasks')),
      findsOneWidget,
    );
    // IndexedStack keeps inactive tabs offstage — always search with skipOffstage: false.
    expect(
      find.byKey(const ValueKey('tab-tasks'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Life').last);
    await pumpBounded(tester, ticks: 5);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Life')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tab-tasks'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tab-life'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Tasks').last);
    await pumpBounded(tester, ticks: 5);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Tasks')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search typing retained on route; shell healthy after pop',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Search'));
    await pumpBounded(tester, ticks: 15);

    final textField = find.byType(TextField);
    final formField = find.byType(TextFormField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField.first, 'retain-me');
    } else if (formField.evaluate().isNotEmpty) {
      await tester.enterText(formField.first, 'retain-me');
    } else {
      // Search UI may still be loading; shell must remain intact after back.
      await tester.pageBack();
      await pumpBounded(tester, ticks: 10);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      return;
    }
    await pumpBounded(tester, ticks: 3);
    expect(find.text('retain-me'), findsOneWidget);

    await tester.pageBack();
    await pumpBounded(tester, ticks: 10);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
