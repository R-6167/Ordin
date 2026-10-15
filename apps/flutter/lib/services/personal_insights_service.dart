import '../data/database.dart';

/// Aggregated personal-life progress. This deliberately reads activity history,
/// never app_usage_events or diagnostic events.
class PersonalInsightsSummary {
  const PersonalInsightsSummary({
    required this.activityCount,
    required this.completedTasks,
    required this.completedHabits,
    required this.moneyEvents,
    required this.previousCompletedTasks,
  });

  final int activityCount;
  final int completedTasks;
  final int completedHabits;
  final int moneyEvents;
  final int previousCompletedTasks;

  int get taskCompletionDelta => completedTasks - previousCompletedTasks;
}

class PersonalInsightsService {
  PersonalInsightsService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<PersonalInsightsSummary> load({int days = 7}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final period = Duration(days: days).inMilliseconds;
    final currentStart = now - period;
    final previousStart = now - (period * 2);

    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS activity_count,
        SUM(CASE WHEN event_type = 'TASK_COMPLETED' THEN 1 ELSE 0 END) AS completed_tasks,
        SUM(CASE WHEN event_type = 'HABIT_COMPLETED' THEN 1 ELSE 0 END) AS completed_habits,
        SUM(CASE WHEN event_type IN ('EXPENSE_RECORDED', 'INCOME_RECORDED', 'BILL_PAID', 'DEBT_PAYMENT_RECORDED', 'SAVINGS_CONTRIBUTION_RECORDED') THEN 1 ELSE 0 END) AS money_events
      FROM activity_events
      WHERE owner_id = ? AND occurred_at >= ?
      ''',
      [ownerId, currentStart],
    );
    final previousRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM activity_events
      WHERE owner_id = ? AND event_type = 'TASK_COMPLETED'
        AND occurred_at >= ? AND occurred_at < ?
      ''',
      [ownerId, previousStart, currentStart],
    );
    int value(dynamic v) => v is num ? v.toInt() : 0;
    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return PersonalInsightsSummary(
      activityCount: value(row['activity_count']),
      completedTasks: value(row['completed_tasks']),
      completedHabits: value(row['completed_habits']),
      moneyEvents: value(row['money_events']),
      previousCompletedTasks: previousRows.isEmpty ? 0 : value(previousRows.first['c']),
    );
  }
}
