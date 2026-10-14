import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/app_data_bus.dart';
import 'package:ordin/services/error_log_service.dart';
import 'package:ordin/services/local_analytics.dart';
import 'package:ordin/ui/home_shell.dart';
import 'package:ordin/ui/hubs/life_hub.dart';

import 'helpers/test_db.dart';

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
    for (final destination in ['Tasks', 'Life', 'Finance', 'Timeline']) {
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

  testWidgets('domain refresh keeps existing tab State alive', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppDataBus.instance.takeDirty();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Tabs are created lazily; visit Life before asserting its State survives
    // a later parent/domain refresh.
    await tester.tap(find.text('Life').last);
    // Boot/repository work is asynchronous in CI; give the tab time to mount.
    for (var i = 0; i < 50 && find.byType(LifeHub).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LifeHub), findsOneWidget);

    final lifeHubStateBefore = tester.state(find.byType(LifeHub));
    AppDataBus.instance.lifeChanged();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      identical(lifeHubStateBefore, tester.state(find.byType(LifeHub))),
      isTrue,
      reason: 'A parent/domain refresh must rebuild the tab without recreating its State',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}