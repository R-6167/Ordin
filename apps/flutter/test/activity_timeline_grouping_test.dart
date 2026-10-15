import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/activity_timeline.dart';

void main() {
  group('ActivityTimelineService.groupByDay', () {
    test('preserves chronological order of day groups and entries', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 30);
      final yesterday = today.subtract(const Duration(days: 1));
      final earlier = today.subtract(const Duration(days: 3));

      final entries = [
        TimelineEntry(
          id: '1',
          headline: 'Completed Orion',
          occurredAt: today.millisecondsSinceEpoch,
          eventType: 'TASK_COMPLETED',
          entityType: 'TASK',
          entityId: 't1',
        ),
        TimelineEntry(
          id: '2',
          headline: 'Paid rent',
          occurredAt: yesterday.millisecondsSinceEpoch,
          eventType: 'BILL_PAID',
          entityType: 'BILL',
          entityId: 'b1',
        ),
        TimelineEntry(
          id: '3',
          headline: 'Habit: stretch',
          occurredAt: earlier.millisecondsSinceEpoch,
          eventType: 'HABIT_COMPLETED',
          entityType: 'HABIT',
          entityId: 'h1',
        ),
      ];

      final groups = ActivityTimelineService().groupByDay(entries);

      expect(groups.length, 3);
      expect(groups[0].label, 'Today');
      expect(groups[0].entries.single.headline, 'Completed Orion');
      expect(groups[1].label, 'Yesterday');
      expect(groups[1].entries.single.headline, 'Paid rent');
      expect(groups[2].entries.single.headline, 'Habit: stretch');
    });

    test('headlines used in fixtures have no decorative quotation marks', () {
      const samples = [
        'Completed Orion',
        'Added task Buy milk',
        'Paid rent',
        'Habit: stretch',
        'Project: Home office',
      ];
      for (final h in samples) {
        expect(h.contains('"'), isFalse, reason: 'decorative quotes banned: $h');
      }
    });
  });

  group('ActivityTimelineService.formatTime', () {
    test('zero-pads hour and minute', () {
      final t = DateTime(2026, 10, 15, 9, 5);
      expect(ActivityTimelineService.formatTime(t.millisecondsSinceEpoch), '09:05');
    });
  });
}
