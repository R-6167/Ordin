import 'db_map.dart';

class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int priority;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        priority: dbIntOr(m['priority']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  /// Columns that exist in schema.sql only.
  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Project {
  final String id;
  final String ownerId;
  final String? goalId;
  final String title;
  final String status;
  final int priority;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Project({
    required this.id,
    required this.ownerId,
    this.goalId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(Map<String, Object?> m) => Project(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        goalId: dbStrOrNull(m['goal_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        priority: dbIntOr(m['priority']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'goal_id': goalId,
        'title': title,
        'status': status,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Task {
  final String id;
  final String ownerId;
  final String? projectId;
  final String? goalId;
  final String? lifeAreaId;
  final String title;
  final String status;
  final int priority;
  final int? dueAt;
  final int? scheduledStart;
  final int? scheduledEnd;
  final int? estimatedMinutes;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;

  const Task({
    required this.id,
    required this.ownerId,
    this.projectId,
    this.goalId,
    this.lifeAreaId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.dueAt,
    this.scheduledStart,
    this.scheduledEnd,
    this.estimatedMinutes,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue {
    if (dueAt == null) return false;
    final s = status.toUpperCase();
    if (s == 'COMPLETED' || s == 'CANCELLED' || s == 'DONE') return false;
    return dueAt! < DateTime.now().millisecondsSinceEpoch;
  }

  bool get isDueToday {
    if (dueAt == null) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(dueAt!);
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        projectId: dbStrOrNull(m['project_id']),
        goalId: dbStrOrNull(m['goal_id']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'INBOX'),
        priority: dbIntOr(m['priority']),
        dueAt: m['due_at'] is int ? m['due_at'] as int : null,
        scheduledStart: m['scheduled_start'] is int ? m['scheduled_start'] as int : null,
        scheduledEnd: m['scheduled_end'] is int ? m['scheduled_end'] as int : null,
        estimatedMinutes: m['estimated_minutes'] is int ? m['estimated_minutes'] as int : null,
        completedAt: m['completed_at'] is int ? m['completed_at'] as int : null,
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'project_id': projectId,
        'goal_id': goalId,
        'life_area_id': lifeAreaId,
        'title': title,
        'status': status,
        'priority': priority,
        'due_at': dueAt,
        'scheduled_start': scheduledStart,
        'scheduled_end': scheduledEnd,
        'estimated_minutes': estimatedMinutes,
        'completed_at': completedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Habit {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int targetCount;
  final int startDate;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Habit({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.targetCount = 1,
    required this.startDate,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Habit.fromMap(Map<String, Object?> m) => Habit(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        targetCount: dbIntOr(m['target_count'], 1),
        startDate: dbIntOr(m['start_date']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'target_count': targetCount,
        'start_date': startDate,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Note {
  final String id;
  final String ownerId;
  final String? title;
  final String content;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Note({
    required this.id,
    required this.ownerId,
    this.title,
    required this.content,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStrOrNull(m['title']),
        content: dbStr(m['content']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'content': content,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class Routine {
  final String id;
  final String ownerId;
  final String name;
  final String status;
  final int? estimatedMinutes;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Routine({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    this.estimatedMinutes,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Routine.fromMap(Map<String, Object?> m) => Routine(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        name: dbStr(m['name']),
        status: dbStr(m['status'], 'ACTIVE'),
        estimatedMinutes: dbInt(m['estimated_minutes']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );
}

// NOTE: Expense, Income, and other models below must match main.
// If CI fails on missing types, restore remaining models from main and re-apply Habit/Note/Routine only.
