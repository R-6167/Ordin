import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/services/personal_insights_service.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async => openTestDb());
  tearDown(() async => closeTestDb());

  test('summarizes personal activity and compares task completions with prior week', () async {
    final db = await AppDatabase.instance.database;
    final ownerId = await AppDatabase.instance.requireOwnerId();
    final now = AppDatabase.nowMs();
    final week = const Duration(days: 7).inMilliseconds;

    Future<void> event(String type, int occurredAt) async {
      await db.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': type,
        'entity_type': 'TASK',
        'entity_id': AppDatabase.newId(),
        'occurred_at': occurredAt,
        'recorded_at': now,
        'source': 'test',
      });
    }

    await event('TASK_COMPLETED', now - 1000);
    await event('TASK_COMPLETED', now - 2000);
    await event('HABIT_COMPLETED', now - 3000);
    await event('EXPENSE_RECORDED', now - 4000);
    await event('TASK_COMPLETED', now - week - 1000);

    final summary = await PersonalInsightsService().load();

    expect(summary.activityCount, 4);
    expect(summary.completedTasks, 2);
    expect(summary.completedHabits, 1);
    expect(summary.moneyEvents, 1);
    expect(summary.previousCompletedTasks, 1);
    expect(summary.taskCompletionDelta, 1);
  });

  test('does not include another owner’s activity', () async {
    final db = await AppDatabase.instance.database;
    final now = AppDatabase.nowMs();
    await db.insert('users', {
      'id': 'another-owner',
      'display_name': 'Other',
      'name': 'Other',
      'currency': 'KES',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('activity_events', {
      'id': AppDatabase.newId(),
      'owner_id': 'another-owner',
      'event_type': 'TASK_COMPLETED',
      'entity_type': 'TASK',
      'entity_id': AppDatabase.newId(),
      'occurred_at': now,
      'recorded_at': now,
      'source': 'test',
    });

    final summary = await PersonalInsightsService().load();
    expect(summary.activityCount, 0);
    expect(summary.completedTasks, 0);
  });
}
