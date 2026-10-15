import '../data/database.dart';

/// A daily bucket of real, owner-scoped life activity.
class PersonalInsightsDay {
  const PersonalInsightsDay({
    required this.date,
    required this.completedTasks,
    required this.completedHabits,
    required this.moneyEvents,
    required this.activityCount,
  });

  final DateTime date;
  final int completedTasks;
  final int completedHabits;
  final int moneyEvents;
  final int activityCount;
}

/// Progress only appears when local records provide a meaningful denominator.
class PersonalProgressItem {
  const PersonalProgressItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.completed,
    required this.total,
  });

  final String id;
  final String title;
  final String kind;
  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);
}

class PersonalInsightsSummary {
  const PersonalInsightsSummary({
    required this.activityCount,
    required this.completedTasks,
    required this.completedHabits,
    required this.moneyEvents,
    required this.previousCompletedTasks,
    this.dailyActivity = const [],
    this.progressItems = const [],
  });

  final int activityCount;
  final int completedTasks;
  final int completedHabits;
  final int moneyEvents;
  final int previousCompletedTasks;
  final List<PersonalInsightsDay> dailyActivity;
  final List<PersonalProgressItem> progressItems;

  int get taskCompletionDelta => completedTasks - previousCompletedTasks;
}

class PersonalInsightsService {
  PersonalInsightsService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;
  final AppDatabase _db;

  Future<PersonalInsightsSummary> load({int days = 7}) async {
    final db = await _db.database;
    final ownerId = await _db.requireOwnerId();
    final safeDays = days.clamp(1, 30);
    final now = DateTime.fromMillisecondsSinceEpoch(AppDatabase.nowMs()).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final currentStartDate = DateTime(today.year, today.month, today.day - safeDays + 1);
    final previousStartDate = DateTime(
      currentStartDate.year,
      currentStartDate.month,
      currentStartDate.day - safeDays,
    );
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final currentStart = currentStartDate.millisecondsSinceEpoch;
    final previousStart = previousStartDate.millisecondsSinceEpoch;
    final currentEnd = tomorrow.millisecondsSinceEpoch;

    final previousRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM activity_events
      WHERE owner_id = ? AND event_type = 'TASK_COMPLETED'
        AND occurred_at >= ? AND occurred_at < ?
      ''',
      [ownerId, previousStart, currentStart],
    );

    final activityRows = await db.rawQuery(
      '''
      SELECT event_type, occurred_at FROM activity_events
      WHERE owner_id = ? AND occurred_at >= ? AND occurred_at < ?
      ORDER BY occurred_at ASC
      ''',
      [ownerId, currentStart, currentEnd],
    );

    int tasks = 0;
    int habits = 0;
    int money = 0;
    final bucketByDate = <String, Map<String, int>>{};
    for (var i = 0; i < safeDays; i++) {
      final date = DateTime(today.year, today.month, today.day - safeDays + 1 + i);
      bucketByDate[_dateKey(date)] = {
        'tasks': 0,
        'habits': 0,
        'money': 0,
        'activity': 0,
      };
    }

    for (final row in activityRows) {
      final type = row['event_type'] as String? ?? '';
      final occurredAt = row['occurred_at'];
      if (occurredAt is! num) continue;
      final eventDate = DateTime.fromMillisecondsSinceEpoch(occurredAt.toInt()).toLocal();
      final bucket = bucketByDate[_dateKey(eventDate)];
      if (bucket == null) continue;
      bucket['activity'] = bucket['activity']! + 1;
      if (type == 'TASK_COMPLETED') {
        tasks++;
        bucket['tasks'] = bucket['tasks']! + 1;
      } else if (type == 'HABIT_COMPLETED') {
        habits++;
        bucket['habits'] = bucket['habits']! + 1;
      } else if (_moneyEventTypes.contains(type)) {
        money++;
        bucket['money'] = bucket['money']! + 1;
      }
    }

    final dailyActivity = bucketByDate.entries.map((entry) {
      final parts = entry.key.split('-').map(int.parse).toList();
      final counts = entry.value;
      return PersonalInsightsDay(
        date: DateTime(parts[0], parts[1], parts[2]),
        completedTasks: counts['tasks']!,
        completedHabits: counts['habits']!,
        moneyEvents: counts['money']!,
        activityCount: counts['activity']!,
      );
    }).toList(growable: false);

    final progressItems = await _loadLinkedWorkProgress(db, ownerId);
    int value(dynamic v) => v is num ? v.toInt() : 0;
    final previousCompletedTasks =
        previousRows.isEmpty ? 0 : value(previousRows.first['c']);

    return PersonalInsightsSummary(
      activityCount: activityRows.length,
      completedTasks: tasks,
      completedHabits: habits,
      moneyEvents: money,
      previousCompletedTasks: previousCompletedTasks,
      dailyActivity: dailyActivity,
      progressItems: progressItems,
    );
  }

  Future<List<PersonalProgressItem>> _loadLinkedWorkProgress(
    dynamic db,
    String ownerId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT id, title, kind, completed, total FROM (
        SELECT
          g.id AS id,
          g.title AS title,
          'Goal' AS kind,
          COUNT(DISTINCT CASE WHEN t.completed_at IS NOT NULL THEN t.id END) AS completed,
          COUNT(DISTINCT t.id) AS total,
          0 AS sort_order
        FROM goals g
        LEFT JOIN tasks t ON t.owner_id = g.owner_id
          AND t.archived_at IS NULL
          AND (
            t.goal_id = g.id OR
            t.project_id IN (
              SELECT p.id FROM projects p
              WHERE p.owner_id = g.owner_id AND p.goal_id = g.id
            )
          )
        WHERE g.owner_id = ?
          AND (g.status IS NULL OR UPPER(g.status) NOT IN ('ARCHIVED', 'DELETED'))
        GROUP BY g.id, g.title
        HAVING COUNT(DISTINCT t.id) > 0

        UNION ALL

        SELECT
          p.id AS id,
          p.title AS title,
          'Project' AS kind,
          COUNT(DISTINCT CASE WHEN t.completed_at IS NOT NULL THEN t.id END) AS completed,
          COUNT(DISTINCT t.id) AS total,
          1 AS sort_order
        FROM projects p
        LEFT JOIN tasks t ON t.owner_id = p.owner_id
          AND t.project_id = p.id AND t.archived_at IS NULL
        WHERE p.owner_id = ?
          AND (p.status IS NULL OR UPPER(p.status) NOT IN ('ARCHIVED', 'DELETED'))
        GROUP BY p.id, p.title
        HAVING COUNT(DISTINCT t.id) > 0
      )
      ORDER BY sort_order, title COLLATE NOCASE
      LIMIT 8
      ''',
      [ownerId, ownerId],
    );

    int value(dynamic v) => v is num ? v.toInt() : 0;
    return rows.map((row) => PersonalProgressItem(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Untitled',
      kind: row['kind'] as String? ?? 'Work',
      completed: value(row['completed']),
      total: value(row['total']),
    )).toList(growable: false);
  }

  static const _moneyEventTypes = {
    'EXPENSE_RECORDED',
    'INCOME_RECORDED',
    'BILL_PAID',
    'DEBT_PAYMENT_RECORDED',
    'SAVINGS_CONTRIBUTION_RECORDED',
  };

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
