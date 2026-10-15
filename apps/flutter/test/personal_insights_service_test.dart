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
    expect(summary.dailyActivity, hasLength(7));
    expect(summary.dailyActivity.fold<int>(0, (sum, day) => sum + day.completedTasks), 2);
    expect(summary.dailyActivity.fold<int>(0, (sum, day) => sum + day.completedHabits), 1);
    expect(summary.dailyActivity.fold<int>(0, (sum, day) => sum + day.moneyEvents), 1);
  });

  test('daily buckets use local midnight boundaries with an exclusive next-day end', () async {
    final db = await AppDatabase.instance.database;
    final ownerId = await AppDatabase.instance.requireOwnerId();
    final now = DateTime.fromMillisecondsSinceEpoch(AppDatabase.nowMs()).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final currentStart = DateTime(today.year, today.month, today.day - 6);
    final previousBoundary = currentStart.millisecondsSinceEpoch;
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    Future<void> event(int at) async {
      await db.insert('activity_events', {
        'id': AppDatabase.newId(),
        'owner_id': ownerId,
        'event_type': 'TASK_COMPLETED',
        'entity_type': 'TASK',
        'entity_id': AppDatabase.newId(),
        'occurred_at': at,
        'recorded_at': AppDatabase.nowMs(),
        'source': 'boundary-test',
      });
    }

    await event(previousBoundary - 1);
    await event(previousBoundary);
    await event(tomorrow.millisecondsSinceEpoch);

    final summary = await PersonalInsightsService().load();
    expect(summary.previousCompletedTasks, 1);
    expect(summary.completedTasks, 1);
    expect(summary.dailyActivity.first.date, currentStart);
    expect(summary.dailyActivity.first.completedTasks, 1);
  });

  test('linked goal and project progress uses completed versus total non-archived tasks', () async {
    final db = await AppDatabase.instance.database;
    final ownerId = await AppDatabase.instance.requireOwnerId();
    final now = AppDatabase.nowMs();
    final goalId = AppDatabase.newId();
    final projectId = AppDatabase.newId();

    await db.insert('goals', {
      'id': goalId,
      'owner_id': ownerId,
      'title': 'Finish the launch',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('projects', {
      'id': projectId,
      'owner_id': ownerId,
      'goal_id': goalId,
      'title': 'Launch project',
      'status': 'ACTIVE',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('tasks', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'project_id': projectId,
      'goal_id': goalId,
      'title': 'Completed work',
      'status': 'COMPLETED',
      'completed_at': now,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('tasks', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'project_id': projectId,
      'goal_id': goalId,
      'title': 'Remaining work',
      'status': 'OPEN',
      'completed_at': null,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('tasks', {
      'id': AppDatabase.newId(),
      'owner_id': ownerId,
      'project_id': projectId,
      'goal_id': goalId,
      'title': 'Archived work',
      'status': 'COMPLETED',
      'completed_at': now,
      'archived_at': now,
      'created_at': now,
      'updated_at': now,
    });

    final summary = await PersonalInsightsService().load();
    final goal = summary.progressItems.singleWhere((item) => item.kind == 'Goal');
    final project = summary.progressItems.singleWhere((item) => item.kind == 'Project');

    expect(goal.completed, 1);
    expect(goal.total, 2);
    expect(goal.fraction, 0.5);
    expect(project.completed, 1);
    expect(project.total, 2);
    expect(project.fraction, 0.5);
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
    expect(summary.dailyActivity, hasLength(7));
  });
}
