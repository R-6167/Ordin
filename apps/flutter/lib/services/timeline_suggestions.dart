import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/habit_repository.dart';
import '../data/task_repository.dart';
import '../domain/models.dart';

/// One grounded suggestion for Timeline (or More tools).
///
/// Values must come from the user's local SQLite data — never fabricated.
class TimelineSuggestion {
  const TimelineSuggestion({
    required this.title,
    required this.subtitle,
    required this.iconName,
    this.entityType,
    this.entityId,
    this.priority = 0,
  });

  final String title;
  final String subtitle;
  /// Material icon name key resolved by the UI layer.
  final String iconName;
  final String? entityType;
  final String? entityId;
  final int priority;
}

/// Builds short, actionable suggestions from owner-scoped local records.
class TimelineSuggestionService {
  TimelineSuggestionService({
    AppDatabase? db,
    TaskRepository? tasks,
    BillRepository? bills,
    HabitRepository? habits,
  })  : _db = db ?? AppDatabase.instance,
        _tasks = tasks,
        _bills = bills,
        _habits = habits;

  final AppDatabase _db;
  final TaskRepository? _tasks;
  final BillRepository? _bills;
  final HabitRepository? _habits;

  TaskRepository get tasks => _tasks ?? TaskRepository(_db);
  BillRepository get bills => _bills ?? BillRepository(_db);
  HabitRepository get habits => _habits ?? HabitRepository(_db);

  /// Returns up to [limit] suggestions, highest priority first.
  Future<List<TimelineSuggestion>> build({int limit = 5}) async {
    final raw = <TimelineSuggestion>[];

    try {
      final overdue = await tasks.listOverdue();
      if (overdue.isNotEmpty) {
        final first = overdue.first;
        raw.add(TimelineSuggestion(
          title: '${overdue.length} overdue task${overdue.length == 1 ? '' : 's'}',
          subtitle: first.title,
          iconName: 'warning',
          entityType: 'TASK',
          entityId: first.id,
          priority: 100,
        ));
      }
    } catch (_) {}

    try {
      final dueToday = await tasks.listDueToday();
      if (dueToday.isNotEmpty) {
        final first = dueToday.first;
        raw.add(TimelineSuggestion(
          title: '${dueToday.length} due today',
          subtitle: first.title,
          iconName: 'today',
          entityType: 'TASK',
          entityId: first.id,
          priority: 80,
        ));
      }
    } catch (_) {}

    try {
      final openBills = await bills.listOpenOccurrences();
      if (openBills.isNotEmpty) {
        raw.add(TimelineSuggestion(
          title: '${openBills.length} open bill${openBills.length == 1 ? '' : 's'}',
          subtitle: 'Review payments in Finance',
          iconName: 'receipt',
          priority: 70,
        ));
      }
    } catch (_) {}

    try {
      final active = await habits.listActive();
      Habit? pending;
      for (final h in active) {
        final st = await habits.todayStatus(h.id);
        if (st == null || st == 'EXPECTED') {
          pending = h;
          break;
        }
      }
      if (pending != null) {
        raw.add(TimelineSuggestion(
          title: 'Habit still open',
          subtitle: pending.title,
          iconName: 'repeat',
          entityType: 'HABIT',
          entityId: pending.id,
          priority: 60,
        ));
      }
    } catch (_) {}

    raw.sort((a, b) => b.priority.compareTo(a.priority));
    if (raw.isEmpty) {
      return const [
        TimelineSuggestion(
          title: 'You’re clear for now',
          subtitle: 'No overdue tasks, open bills, or pending habits.',
          iconName: 'check',
          priority: 0,
        ),
      ];
    }
    return raw.take(limit).toList();
  }
}
