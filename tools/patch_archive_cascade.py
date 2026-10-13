from pathlib import Path
import sys

GOAL_APPEND = r'''

  /// Counts used by the archive confirmation sheet.
  Future<Map<String, int>> archiveImpact(String goalId) async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final projects = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM projects '
      'WHERE owner_id = ? AND goal_id = ? AND archived_at IS NULL',
      [ownerId, goalId],
    );
    final directTasks = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks '
      'WHERE owner_id = ? AND goal_id = ? AND project_id IS NULL '
      'AND archived_at IS NULL',
      [ownerId, goalId],
    );
    final habits = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM habits '
      'WHERE owner_id = ? AND goal_id = ? AND archived_at IS NULL',
      [ownerId, goalId],
    );
    return {
      'projects': (projects.first['c'] as int?) ?? 0,
      'directTasks': (directTasks.first['c'] as int?) ?? 0,
      'habits': (habits.first['c'] as int?) ?? 0,
    };
  }

  /// Soft-archive a goal. See [ArchiveCascade] for child handling.
  Future<void> archive(
    String id, {
    ArchiveCascade cascade = ArchiveCascade.parentOnly,
  }) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final owned = await txn.query(
          'goals',
          columns: ['id'],
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
          limit: 1,
        );
        if (owned.isEmpty) {
          throw StateError('Goal not found or already archived: $id');
        }

        if (cascade == ArchiveCascade.detachChildren) {
          await txn.update(
            'projects',
            {'goal_id': null, 'updated_at': now},
            where: 'goal_id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
          );
          await txn.update(
            'tasks',
            {'goal_id': null, 'updated_at': now},
            where: 'goal_id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
          );
          await txn.update(
            'habits',
            {'goal_id': null, 'updated_at': now},
            where: 'goal_id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
          );
        } else if (cascade == ArchiveCascade.withProjects) {
          await txn.update(
            'projects',
            {'archived_at': now, 'updated_at': now},
            where: 'goal_id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
          );
        }

        final changed = await txn.update(
          'goals',
          {'archived_at': now, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Goal not found or already archived: $id');
        }
      },
      eventType: 'GOAL_ARCHIVED',
      entityType: 'GOAL',
      entityId: id,
      occurredAt: now,
      metadata: '{"cascade":"${cascade.name}"}',
    );
  }

  /// Clear archived_at so the goal returns to active lists.
  Future<void> unarchive(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final changed = await txn.update(
          'goals',
          {'archived_at': null, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NOT NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Goal not found or not archived: $id');
        }
      },
      eventType: 'GOAL_UNARCHIVED',
      entityType: 'GOAL',
      entityId: id,
      occurredAt: now,
    );
  }
}
'''

PROJECT_APPEND = r'''

  Future<Map<String, int>> archiveImpact(String projectId) async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final openTasks = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM tasks WHERE owner_id = ? AND project_id = ? "
      "AND archived_at IS NULL AND status NOT IN (?, ?)",
      [ownerId, projectId, EntityStatus.completed, EntityStatus.cancelled],
    );
    final milestones = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM milestones '
      'WHERE owner_id = ? AND project_id = ?',
      [ownerId, projectId],
    );
    return {
      'openTasks': (openTasks.first['c'] as int?) ?? 0,
      'milestones': (milestones.first['c'] as int?) ?? 0,
    };
  }

  Future<void> archive(
    String id, {
    ArchiveCascade cascade = ArchiveCascade.parentOnly,
  }) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: id,
        );

        if (cascade == ArchiveCascade.detachChildren) {
          await txn.update(
            'tasks',
            {
              'project_id': null,
              'milestone_id': null,
              'updated_at': now,
            },
            where: 'project_id = ? AND owner_id = ? AND archived_at IS NULL',
            whereArgs: [id, ownerId],
          );
        } else if (cascade == ArchiveCascade.withOpenTasks) {
          await txn.update(
            'tasks',
            {'archived_at': now, 'updated_at': now},
            where:
                'project_id = ? AND owner_id = ? AND archived_at IS NULL '
                'AND status NOT IN (?, ?)',
            whereArgs: [
              id,
              ownerId,
              EntityStatus.completed,
              EntityStatus.cancelled,
            ],
          );
        }

        final changed = await txn.update(
          'projects',
          {'archived_at': now, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Project not found or already archived: $id');
        }
      },
      eventType: 'PROJECT_ARCHIVED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
      metadata: '{"cascade":"${cascade.name}"}',
    );
  }

  Future<void> unarchive(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final changed = await txn.update(
          'projects',
          {'archived_at': null, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NOT NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Project not found or not archived: $id');
        }
      },
      eventType: 'PROJECT_UNARCHIVED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }
}
'''


def patch_goal() -> None:
    path = Path('apps/flutter/lib/data/goal_repository.dart')
    t = path.read_text()
    if 'Future<void> archive(' in t:
        print('goal already')
        return
    if "import '../domain/archive_cascade.dart';" not in t:
        t = t.replace(
            "import '../domain/enums.dart';",
            "import '../domain/archive_cascade.dart';\nimport '../domain/enums.dart';",
            1,
        )
    if not t.rstrip().endswith('}'):
        sys.exit('goal ending')
    # strip final class closing brace
    t = t.rstrip()
    if t.endswith('}'):
        t = t[:-1] + GOAL_APPEND
    path.write_text(t)
    print('goal ok')


def patch_project() -> None:
    path = Path('apps/flutter/lib/data/project_repository.dart')
    t = path.read_text()
    if 'Future<void> archive(' in t and 'ArchiveCascade' in t:
        print('project already')
        return
    if "import '../domain/archive_cascade.dart';" not in t:
        t = t.replace(
            "import '../domain/enums.dart';",
            "import '../domain/archive_cascade.dart';\nimport '../domain/enums.dart';",
            1,
        )
    t = t.rstrip()
    if t.endswith('}'):
        t = t[:-1] + PROJECT_APPEND
    path.write_text(t)
    print('project ok')


def patch_task_lists() -> None:
    path = Path('apps/flutter/lib/data/task_repository.dart')
    t = path.read_text()
    if 'NOT EXISTS' in t and 'archived_at IS NOT NULL' in t:
        print('task lists maybe already')
    # listOpen
    old_open = '''  Future<List<Task>> listOpen() async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'owner_id = ? AND status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [ownerId, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC, updated_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }'''
    new_open = '''  Future<List<Task>> listOpen() async {
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT t.* FROM tasks t '
      'WHERE t.owner_id = ? AND t.status NOT IN (?, ?) AND t.archived_at IS NULL '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM projects p WHERE p.id = t.project_id '
      '  AND p.owner_id = t.owner_id AND p.archived_at IS NOT NULL'
      ') '
      'ORDER BY t.priority DESC, t.due_at ASC, t.updated_at DESC',
      [ownerId, EntityStatus.completed, EntityStatus.cancelled],
    );
    return rows.map(Task.fromMap).toList();
  }'''
    if old_open not in t:
        if 'SELECT t.* FROM tasks t' in t:
            print('listOpen already')
        else:
            sys.exit('listOpen missing')
    else:
        t = t.replace(old_open, new_open, 1)
        print('listOpen ok')

    old_overdue = '''  Future<List<Task>> listOverdue() async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where:
          'owner_id = ? AND due_at IS NOT NULL AND due_at < ? AND status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [ownerId, now, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'due_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }'''
    new_overdue = '''  Future<List<Task>> listOverdue() async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT t.* FROM tasks t '
      'WHERE t.owner_id = ? AND t.due_at IS NOT NULL AND t.due_at < ? '
      'AND t.status NOT IN (?, ?) AND t.archived_at IS NULL '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM projects p WHERE p.id = t.project_id '
      '  AND p.owner_id = t.owner_id AND p.archived_at IS NOT NULL'
      ') '
      'ORDER BY t.due_at ASC',
      [ownerId, now, EntityStatus.completed, EntityStatus.cancelled],
    );
    return rows.map(Task.fromMap).toList();
  }'''
    if old_overdue in t:
        t = t.replace(old_overdue, new_overdue, 1)
        print('listOverdue ok')

    old_due = '''  Future<List<Task>> listDueToday() async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where:
          'owner_id = ? AND due_at IS NOT NULL AND due_at >= ? AND due_at <= ? AND status NOT IN (?, ?) AND archived_at IS NULL',
      whereArgs: [ownerId, start, end, EntityStatus.completed, EntityStatus.cancelled],
      orderBy: 'priority DESC, due_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }'''
    new_due = '''  Future<List<Task>> listDueToday() async {
    final start = AppDatabase.startOfTodayMs();
    final end = AppDatabase.endOfTodayMs();
    final ownerId = await _db.requireOwnerId();
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT t.* FROM tasks t '
      'WHERE t.owner_id = ? AND t.due_at IS NOT NULL AND t.due_at >= ? AND t.due_at <= ? '
      'AND t.status NOT IN (?, ?) AND t.archived_at IS NULL '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM projects p WHERE p.id = t.project_id '
      '  AND p.owner_id = t.owner_id AND p.archived_at IS NOT NULL'
      ') '
      'ORDER BY t.priority DESC, t.due_at ASC',
      [ownerId, start, end, EntityStatus.completed, EntityStatus.cancelled],
    );
    return rows.map(Task.fromMap).toList();
  }'''
    if old_due in t:
        t = t.replace(old_due, new_due, 1)
        print('listDueToday ok')

    path.write_text(t)


def patch_goal_ui() -> None:
    path = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
    t = path.read_text()
    if 'showArchiveSheet' in t:
        print('goal ui already')
        return
    if "import '../widgets/archive_sheet.dart';" not in t:
        t = t.replace(
            "import '../widgets/glass.dart';",
            "import '../widgets/archive_sheet.dart';\nimport '../widgets/glass.dart';",
            1,
        )
    if "import '../../domain/archive_cascade.dart';" not in t:
        t = t.replace(
            "import '../../domain/db_map.dart';",
            "import '../../domain/archive_cascade.dart';\nimport '../../domain/db_map.dart';",
            1,
        )

    old = '''              onSelected: (v) async {
                if (v == 'target') await _setTarget();
                if (v == 'habit') await _addHabit();
                if (v == 'task') await _addDirectTask();
                if (v == 'complete') {
                  await _goals.complete(widget.goalId);
                  AppDataBus.instance.lifeChanged();
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'target', child: Text('Set target date')),
                PopupMenuItem(value: 'habit', child: Text('Link habit')),
                PopupMenuItem(value: 'task', child: Text('Add direct task')),
                PopupMenuItem(value: 'complete', child: Text('Mark goal complete')),
              ],'''
    new = '''              onSelected: (v) async {
                if (v == 'target') await _setTarget();
                if (v == 'habit') await _addHabit();
                if (v == 'task') await _addDirectTask();
                if (v == 'complete') {
                  await _goals.complete(widget.goalId);
                  AppDataBus.instance.lifeChanged();
                  if (mounted) Navigator.pop(context);
                }
                if (v == 'archive') await _archiveGoal();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'target', child: Text('Set target date')),
                PopupMenuItem(value: 'habit', child: Text('Link habit')),
                PopupMenuItem(value: 'task', child: Text('Add direct task')),
                PopupMenuItem(value: 'complete', child: Text('Mark goal complete')),
                PopupMenuItem(value: 'archive', child: Text('Archive goal…')),
              ],'''
    if old not in t:
        sys.exit('goal menu missing')
    t = t.replace(old, new, 1)

    # Add method before last closing of state class - find a stable anchor
    method = r'''
  Future<void> _archiveGoal() async {
    final impact = await _goals.archiveImpact(widget.goalId);
    if (!mounted) return;
    final result = await showArchiveSheet(
      context: context,
      title: 'Archive this goal?',
      impact: {
        'projects': impact['projects'] ?? 0,
        'direct tasks': impact['directTasks'] ?? 0,
        'habits': impact['habits'] ?? 0,
      },
      options: const [
        (
          mode: ArchiveCascade.parentOnly,
          label: 'Archive goal only',
          subtitle: 'Projects and tasks keep their link; goal leaves active lists.',
        ),
        (
          mode: ArchiveCascade.withProjects,
          label: 'Archive goal and its projects',
          subtitle: 'Projects (and their boards) leave active lists with the goal.',
        ),
        (
          mode: ArchiveCascade.detachChildren,
          label: 'Detach children, then archive',
          subtitle: 'Projects, direct tasks, and habits become independent.',
        ),
      ],
    );
    if (result == null || !mounted) return;
    await _goals.archive(widget.goalId, cascade: result.cascade);
    AppDataBus.instance.lifeChanged();
    if (mounted) Navigator.pop(context);
  }
'''
    # insert before final closing braces of file
    # State class ends near end of file
    idx = t.rfind('}\n}')
    if idx < 0:
        sys.exit('goal state end missing')
    t = t[:idx] + method + t[idx:]
    path.write_text(t)
    print('goal ui ok')


def patch_project_ui() -> None:
    path = Path('apps/flutter/lib/ui/screens/project_detail_screen.dart')
    t = path.read_text()
    if 'showArchiveSheet' in t:
        print('project ui already')
        return
    if "import '../widgets/archive_sheet.dart';" not in t:
        t = t.replace(
            "import '../widgets/glass.dart';",
            "import '../widgets/archive_sheet.dart';\nimport '../widgets/glass.dart';",
            1,
        )
    if "import '../../domain/archive_cascade.dart';" not in t:
        t = t.replace(
            "import '../../domain/db_map.dart';",
            "import '../../domain/archive_cascade.dart';\nimport '../../domain/db_map.dart';",
            1,
        )

    old = '''              onSelected: (v) async {
                if (v == 'deadline') await _setDeadline();
                if (v == 'note') await _addNote();
                if (v == 'resource') await _addResource();
                if (v == 'complete') {
                  await _projects.complete(widget.projectId);
                  if (mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'deadline', child: Text('Set deadline')),
                PopupMenuItem(value: 'note', child: Text('Add note')),
                PopupMenuItem(value: 'resource', child: Text('Add resource')),
                PopupMenuItem(value: 'complete', child: Text('Mark project complete')),
              ],'''
    new = '''              onSelected: (v) async {
                if (v == 'deadline') await _setDeadline();
                if (v == 'note') await _addNote();
                if (v == 'resource') await _addResource();
                if (v == 'complete') {
                  await _projects.complete(widget.projectId);
                  AppDataBus.instance.lifeChanged();
                  if (mounted) Navigator.pop(context);
                }
                if (v == 'archive') await _archiveProject();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'deadline', child: Text('Set deadline')),
                PopupMenuItem(value: 'note', child: Text('Add note')),
                PopupMenuItem(value: 'resource', child: Text('Add resource')),
                PopupMenuItem(value: 'complete', child: Text('Mark project complete')),
                PopupMenuItem(value: 'archive', child: Text('Archive project…')),
              ],'''
    if old not in t:
        sys.exit('project menu missing')
    t = t.replace(old, new, 1)

    method = r'''
  Future<void> _archiveProject() async {
    final impact = await _projects.archiveImpact(widget.projectId);
    if (!mounted) return;
    final result = await showArchiveSheet(
      context: context,
      title: 'Archive this project?',
      impact: {
        'open tasks': impact['openTasks'] ?? 0,
        'milestones': impact['milestones'] ?? 0,
      },
      options: const [
        (
          mode: ArchiveCascade.parentOnly,
          label: 'Archive project only',
          subtitle: 'Tasks stay linked but leave the main Tasks list.',
        ),
        (
          mode: ArchiveCascade.detachChildren,
          label: 'Detach tasks, then archive',
          subtitle: 'Open work becomes independent; project is archived.',
        ),
        (
          mode: ArchiveCascade.withOpenTasks,
          label: 'Archive project and open tasks',
          subtitle: 'Open tasks are soft-archived; completed history stays.',
        ),
      ],
    );
    if (result == null || !mounted) return;
    await _projects.archive(widget.projectId, cascade: result.cascade);
    AppDataBus.instance.lifeChanged();
    AppDataBus.instance.tasksChanged();
    if (mounted) Navigator.pop(context);
  }
'''
    idx = t.rfind('}\n}')
    if idx < 0:
        sys.exit('project state end missing')
    t = t[:idx] + method + t[idx:]
    path.write_text(t)
    print('project ui ok')


def main() -> None:
    patch_goal()
    patch_project()
    patch_task_lists()
    patch_goal_ui()
    patch_project_ui()


if __name__ == '__main__':
    main()
