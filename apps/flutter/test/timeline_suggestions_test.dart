import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/timeline_suggestions.dart';

void main() {
  test('clear suggestion when empty list is default', () {
    const s = TimelineSuggestion(
      title: 'You’re clear for now',
      subtitle: 'No overdue tasks, open bills, or pending habits.',
      iconName: 'check',
    );
    expect(s.entityId, isNull);
    expect(s.priority, 0);
  });

  test('priority orders overdue above due-today style items', () {
    final items = [
      const TimelineSuggestion(
        title: 'due',
        subtitle: 'a',
        iconName: 'today',
        priority: 80,
      ),
      const TimelineSuggestion(
        title: 'overdue',
        subtitle: 'b',
        iconName: 'warning',
        priority: 100,
      ),
    ]..sort((a, b) => b.priority.compareTo(a.priority));
    expect(items.first.title, 'overdue');
  });
}
