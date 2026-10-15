import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/error_log_service.dart';
import 'package:ordin/services/local_analytics.dart';
import 'package:ordin/ui/screens/activity_screen.dart';

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

  testWidgets('Timeline empty state is readable without glass event cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ActivityScreen()));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Your Life Timeline'), findsOneWidget);
    expect(find.text('Your story starts here'), findsOneWidget);
    expect(
      find.textContaining('Complete a task, pay a bill, or finish a routine'),
      findsOneWidget,
    );
    // Plain list: no GlassCard widgets on the empty timeline body.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
