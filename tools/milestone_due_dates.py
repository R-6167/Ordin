"""Add milestones.due_at + setDue + project UI date picker."""
from pathlib import Path
import subprocess
import sys


def show(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def patch_database() -> None:
    path = 'apps/flutter/lib/data/database.dart'
    t = show(path)
    if 'schemaVersion = 29' in t or 'milestones ADD COLUMN due_at' in t:
        print('db already')
        return
    if 'static const schemaVersion = 28' not in t:
        sys.exit(f'schemaVersion 28 not found')
    t = t.replace(
        'static const schemaVersion = 28;',
        'static const schemaVersion = 29;',
        1,
    )
    t = t.replace(
        '        if (oldVersion < 28) await _migrateToV28(db);\n',
        '        if (oldVersion < 28) await _migrateToV28(db);\n'
        '        if (oldVersion < 29) await _migrateToV29(db);\n',
        1,
    )
    # insert migrate after v28
    marker = '  Future<void> _migrateToV28(Database db) async {\n    await _executeIgnoringDuplicateColumn(db, \'ALTER TABLE routines ADD COLUMN archived_at INTEGER\');\n  }\n'
    if marker not in t:
        # looser
        idx = t.find('Future<void> _migrateToV28')
        if idx < 0:
            sys.exit('v28 missing')
        end = t.find('\n  Future<void>', idx + 10)
        if end < 0:
            end = t.find('\n  Future<void> _executeIgnoringDuplicateColumn', idx)
        insert = (
            '\n  Future<void> _migrateToV29(Database db) async {\n'
            "    await _executeIgnoringDuplicateColumn(\n"
            "        db, 'ALTER TABLE milestones ADD COLUMN due_at INTEGER');\n"
            '  }\n'
        )
        t = t[:end] + insert + t[end:]
    else:
        t = t.replace(
            marker,
            marker
            + '\n  Future<void> _migrateToV29(Database db) async {\n'
            "    await _executeIgnoringDuplicateColumn(\n"
            "        db, 'ALTER TABLE milestones ADD COLUMN due_at INTEGER');\n"
            '  }\n',
            1,
        )
    Path(path).write_text(t)
    print('db ok')


def patch_schema() -> None:
    path = 'apps/flutter/assets/schema.sql'
    t = show(path)
    old = (
        'CREATE TABLE IF NOT EXISTS milestones (\n'
        '  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, title TEXT NOT NULL,\n'
        '  status TEXT, position INTEGER DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,\n'
        '  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE\n'
        ');'
    )
    new = (
        'CREATE TABLE IF NOT EXISTS milestones (\n'
        '  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT, title TEXT NOT NULL,\n'
        '  status TEXT, position INTEGER DEFAULT 0, due_at INTEGER, completed_at INTEGER,\n'
        '  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,\n'
        '  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE\n'
        ');'
    )
    if 'due_at INTEGER' in t and 'milestones' in t:
        # check milestones block
        if 'milestones' in t and 'due_at' in t[t.find('milestones'):t.find('milestones') + 400]:
            print('schema already')
            return
    if old not in t:
        print('schema marker skip')
        return
    Path(path).write_text(t.replace(old, new, 1))
    print('schema ok')


def patch_model() -> None:
    path = 'apps/flutter/lib/domain/models.dart'
    t = show(path)
    if 'final int? dueAt;' in t and 'class Milestone' in t:
        # check it's on Milestone
        block = t[t.find('class Milestone'):t.find('class Task')]
        if 'dueAt' in block:
            print('model already')
            return
    old = '''class Milestone {
  final String id;
  final String projectId;
  final String title;
  final String status;
  final int position;
  final int createdAt;
  final int updatedAt;

  const Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: dbStr(m['id']),
        projectId: dbStr(m['project_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'PLANNED'),
        position: dbIntOr(m['position']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );
}'''
    new = '''class Milestone {
  final String id;
  final String projectId;
  final String title;
  final String status;
  final int position;
  final int? dueAt;
  final int createdAt;
  final int updatedAt;

  const Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    this.position = 0,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: dbStr(m['id']),
        projectId: dbStr(m['project_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'PLANNED'),
        position: dbIntOr(m['position']),
        dueAt: m['due_at'] == null ? null : dbIntOr(m['due_at']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );
}'''
    if old not in t:
        sys.exit('Milestone model marker missing')
    Path(path).write_text(t.replace(old, new, 1))
    print('model ok')


def patch_repo() -> None:
    path = 'apps/flutter/lib/data/milestone_repository.dart'
    t = show(path)
    if 'Future<void> setDue' in t:
        print('repo already')
        return
    extra = r'''
  /// Set or clear the milestone target date ([dueAtMs] null clears).
  Future<void> setDue({required String id, int? dueAtMs}) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.query(
          'milestones',
          columns: ['id', 'project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Milestone not found or not owned: $id');
        }
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: rows.first['project_id'] as String,
        );
        final changed = await txn.update(
          'milestones',
          {'due_at': dueAtMs, 'updated_at': now},
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Milestone not found or not owned: $id');
        }
      },
      eventType: 'MILESTONE_DUE_SET',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
      metadata: dueAtMs == null ? '{"cleared":true}' : '{"dueAt":$dueAtMs}',
    );
  }
'''
    t = t.rstrip()
    if not t.endswith('}'):
        sys.exit('repo end')
    Path(path).write_text(t[:-1] + extra + '}\n')
    print('repo ok')


def patch_project() -> None:
    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = show(path)

    # Helper to set due date
    if '_setMilestoneDue' not in t:
        helpers = r'''
  Future<void> _setMilestoneDue(Map<String, Object?> m) async {
    final existing = m['due_at'];
    final initial = existing is int
        ? DateTime.fromMillisecondsSinceEpoch(existing)
        : DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final ms = DateTime(picked.year, picked.month, picked.day, 23, 59)
        .millisecondsSinceEpoch;
    try {
      await _milestonesRepo.setDue(id: dbStr(m['id']), dueAtMs: ms);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set due date: $e')),
        );
      }
    }
  }

  Future<void> _clearMilestoneDue(Map<String, Object?> m) async {
    try {
      await _milestonesRepo.setDue(id: dbStr(m['id']), dueAtMs: null);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear due date: $e')),
        );
      }
    }
  }

'''
        marker = '  List<Map<String, Object?>> _blockedOpen(ProjectWorkspace ws) {'
        if marker not in t:
            # try after toggle
            marker2 = '  Future<void> _toggleMilestoneComplete'
            if marker2 in t:
                # insert before blockedOpen still preferred
                sys.exit('blockedOpen marker missing')
            sys.exit('blockedOpen marker missing')
        t = t.replace(marker, helpers + marker, 1)

    # Enhance progress/status line with due date
    old_progress = (
        "                          final status = dbStr(m['status']);\n"
        "                          final progress = msTasks.isEmpty\n"
        "                              ? status\n"
        "                              : '$status · $doneN/${msTasks.length} tasks';\n"
        "                          return Text(\n"
        "                            progress,\n"
        "                            style: TextStyle(\n"
        "                                color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),\n"
        "                          );"
    )
    new_progress = (
        "                          final status = dbStr(m['status']);\n"
        "                          final dueRaw = m['due_at'];\n"
        "                          String? dueLabel;\n"
        "                          var overdue = false;\n"
        "                          if (dueRaw is int) {\n"
        "                            final d = DateTime.fromMillisecondsSinceEpoch(dueRaw);\n"
        "                            dueLabel =\n"
        "                                'Due ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';\n"
        "                            final today = DateTime.now();\n"
        "                            final day = DateTime(d.year, d.month, d.day);\n"
        "                            final start = DateTime(today.year, today.month, today.day);\n"
        "                            overdue = status.toUpperCase() != 'COMPLETED' &&\n"
        "                                day.isBefore(start);\n"
        "                          }\n"
        "                          final parts = <String>[status];\n"
        "                          if (msTasks.isNotEmpty) {\n"
        "                            parts.add('$doneN/${msTasks.length} tasks');\n"
        "                          }\n"
        "                          if (dueLabel != null) parts.add(dueLabel);\n"
        "                          return Text(\n"
        "                            parts.join(' · '),\n"
        "                            style: TextStyle(\n"
        "                              color: overdue\n"
        "                                  ? Colors.orangeAccent\n"
        "                                  : AppTheme.silver.withValues(alpha: 0.4),\n"
        "                              fontSize: 11,\n"
        "                            ),\n"
        "                          );"
    )
    if old_progress in t:
        t = t.replace(old_progress, new_progress, 1)
        print('subtitle due')
    else:
        print('subtitle marker skip')

    # Calendar icon before rename
    old_rename = (
        "                            IconButton(\n"
        "                              tooltip: 'Rename',\n"
        "                              icon: const Icon(Icons.edit_outlined, color: AppTheme.silverMuted, size: 18),\n"
        "                              onPressed: () => _renameMilestone(m),\n"
        "                            ),"
    )
    new_rename = (
        "                            IconButton(\n"
        "                              tooltip: 'Due date',\n"
        "                              icon: const Icon(Icons.event_outlined, color: AppTheme.silverMuted, size: 18),\n"
        "                              onPressed: () => _setMilestoneDue(m),\n"
        "                              onLongPress: () => _clearMilestoneDue(m),\n"
        "                            ),\n"
        "                            IconButton(\n"
        "                              tooltip: 'Rename',\n"
        "                              icon: const Icon(Icons.edit_outlined, color: AppTheme.silverMuted, size: 18),\n"
        "                              onPressed: () => _renameMilestone(m),\n"
        "                            ),"
    )
    if old_rename in t:
        t = t.replace(old_rename, new_rename, 1)
        print('due button')
    else:
        print('rename button skip')

    Path(path).write_text(t)
    print('project ok', len(t))


def main() -> None:
    patch_database()
    patch_schema()
    patch_model()
    patch_repo()
    patch_project()


if __name__ == '__main__':
    main()
