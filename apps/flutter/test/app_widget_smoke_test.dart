import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/app_data_bus.dart';
import 'package:ordin/services/diagnostic_service.dart';
import 'package:ordin/services/local_analytics.dart';
import 'package:ordin/ui/home_shell.dart';
import 'package:ordin/ui/hubs/life_hub.dart';
import 'package:ordin/ui/screens/insights_screen.dart';
import 'package:ordin/ui/theme.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDatabase();
    AppDataBus.instance.takeDirty();
  });

  tearDown(() async {
    await closeTestDatabase();
  });

  testWidgets('HomeShell boots without throwing on a basic pump', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
    // Allow async boot / soft futures to settle without requiring full data.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bottom destinations include Insights, Life, Timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    for (final destination in ['Insights', 'Life', 'Timeline']) {
      expect(find.text(destination), findsWidgets);
    }
  });

  testWidgets('Life hub opens Finance as a nested destination', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LifeHub(
            goals: const [],
            habits: const [],
            onOpenTasks: () {},
            notes: const [],
            projects: const [],
            routines: const [],
            onChanged: () async {},
            finance: const Center(child: Text('Finance contents')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Finance').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Finance'),
      ),
      findsOneWidget,
    );
    expect(find.text('Finance contents'), findsOneWidget);
  });

  testWidgets('Life hub is areas-first with tools strip on a narrow phone', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LifeHub(
            goals: const [],
            habits: const [],
            onOpenTasks: () {},
            notes: const [],
            projects: const [],
            routines: const [],
            onChanged: () async {},
            finance: const Center(child: Text('Finance contents')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Areas are the primary surface; tools are a horizontal strip.
    expect(find.text('Life areas'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    // Global hanging lists are gone from the Life home.
    expect(find.text('No goals yet'), findsNothing);
    expect(find.text('No habits yet'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Insights screen shows week heading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const InsightsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('7 days'), findsWidgets);
  });
}
