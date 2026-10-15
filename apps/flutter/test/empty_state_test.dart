import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows title, detail, and optional action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Nothing here yet',
            detail: 'Add something to get started.',
            actionLabel: 'Add',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add something to get started.'), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyState without action has no button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: 'Quiet day'),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}
