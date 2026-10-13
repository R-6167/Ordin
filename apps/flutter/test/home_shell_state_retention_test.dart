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
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tab navigation keeps shell mounted and tab keys stable',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Tasks').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Tasks')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tab-tasks')), findsOneWidget);

    await tester.tap(find.text('Life').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Life')),
      findsOneWidget,
    );

    await tester.tap(find.text('Tasks').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('tab-tasks')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search typing survives until route pop; home shell stays healthy',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    final formField = find.byType(TextFormField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField.first, 'retain-me');
    } else {
      expect(formField, findsWidgets);
      await tester.enterText(formField.first, 'retain-me');
    }
    await tester.pump();
    expect(find.text('retain-me'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
