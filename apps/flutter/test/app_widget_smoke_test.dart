import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/error_log_service.dart';
import 'package:ordin/services/local_analytics.dart';
import 'package:ordin/services/personal_insights_service.dart';
import 'package:ordin/ui/home_shell.dart';
import 'package:ordin/ui/screens/insights_screen.dart';

import 'helpers/test_db.dart';

class _ImmediateInsightsService extends PersonalInsightsService {
  @override
  Future<PersonalInsightsSummary> load({int days = 7}) async =>
      const PersonalInsightsSummary(
        activityCount: 3,
        completedTasks: 2,
        completedHabits: 1,
        moneyEvents: 0,
        previousCompletedTasks: 1,
      );
}

void main() {
  setUp(() async {
    // Widget smoke tests should exercise app navigation, not start background
    // diagnostics/analytics writes that require platform lifecycle services.
    ErrorLogService.instance.enabled = false;
    LocalAnalytics.instance.enabled = false;
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
    ErrorLogService.instance.enabled = true;
    LocalAnalytics.instance.enabled = true;
  });

  testWidgets('home shell boots and exposes all primary destinations',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    // W5: bottom tab "More" renamed to "Timeline".
    for (final destination in ['Insights', 'Life', 'Finance', 'Timeline']) {
      await tester.tap(find.text(destination).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(destination),
        ),
        findsOneWidget,
        reason: 'Selecting $destination should update the active screen title',
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    }

    await tester.tap(find.text('Today').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Today'),
      ),
      findsOneWidget,
    );

    // Unmount the stateful shell so no route animation survives the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Today insights card opens personal insights', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Exercise the card's navigation in isolation. HomeShell's startup also
    // initializes platform-backed preferences and notifications; those boot
    // dependencies are covered separately by the shell smoke test.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeInsightsCard(service: _ImmediateInsightsService())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final card = find.text('Your week at a glance');
    await tester.ensureVisible(card);
    await tester.tap(card);
    // Insights deliberately shows an indeterminate loader while local data is
    // being read, so pumpAndSettle would wait forever for that animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Your last 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('primary navigation remains usable at narrow phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final destination in ['Tasks', 'Life', 'Finance', 'Timeline', 'Today']) {
      final tab = find.text(destination).last;
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(destination),
        ),
        findsOneWidget,
        reason: '$destination should remain reachable at 360 logical pixels',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Narrow-screen navigation to $destination should not throw',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
