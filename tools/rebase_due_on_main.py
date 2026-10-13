"""Merge origin/main into this branch and ensure due-date UX works with progress bars."""
from pathlib import Path
import subprocess
import sys


def sh(*args: str) -> None:
    print('+', ' '.join(args))
    subprocess.check_call(list(args))


def show_main(path: str) -> str:
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def ensure_due_in_project(t: str) -> str:
    # Helpers
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
            sys.exit('blockedOpen missing after merge')
        t = t.replace(marker, helpers + marker, 1)

    # Due menu (never use IconButton.onLongPress)
    if "value: 'set'" not in t or 'Set due date' not in t:
        # Insert before Rename button if present
        rename = (
            "                            IconButton(\n"
            "                              tooltip: 'Rename',\n"
            "                              icon: const Icon(Icons.edit_outlined, color: AppTheme.silverMuted, size: 18),\n"
            "                              onPressed: () => _renameMilestone(m),\n"
            "                            ),"
        )
        menu = (
            "                            PopupMenuButton<String>(\n"
            "                              tooltip: 'Due date',\n"
            "                              icon: const Icon(Icons.event_outlined,\n"
            "                                  color: AppTheme.silverMuted, size: 18),\n"
            "                              color: AppTheme.metalDeep,\n"
            "                              onSelected: (v) async {\n"
            "                                if (v == 'set') await _setMilestoneDue(m);\n"
            "                                if (v == 'clear') await _clearMilestoneDue(m);\n"
            "                              },\n"
            "                              itemBuilder: (_) => [\n"
            "                                const PopupMenuItem(\n"
            "                                  value: 'set',\n"
            "                                  child: Text('Set due date'),\n"
            "                                ),\n"
            "                                if (m['due_at'] != null)\n"
            "                                  const PopupMenuItem(\n"
            "                                    value: 'clear',\n"
            "                                    child: Text('Clear due date'),\n"
            "                                  ),\n"
            "                              ],\n"
            "                            ),\n"
            + rename
        )
        if rename not in t:
            sys.exit('rename button missing')
        t = t.replace(rename, menu, 1)

    # Strip forbidden onLongPress if any
    t = t.replace(
        "                              onLongPress: () => _clearMilestoneDue(m),\n",
        '',
    )

    # Append due label into progress-bar subtitle if not present
    if "dueLabel" not in t and 'LinearProgressIndicator' in t:
        # After label is built, append due info to the Text under the bar
        needle = (
            "                          final label = msDone\n"
            "                              ? (total == 0\n"
            "                                  ? 'Completed'\n"
            "                                  : 'Completed · $doneN/$total tasks')\n"
            "                              : (total == 0\n"
            "                                  ? 'No tasks yet'\n"
            "                                  : '$doneN of $total tasks');\n"
        )
        if needle not in t:
            print('progress label needle missing — skip label merge')
        else:
            inject = (
                needle
                + "                          final dueRaw = m['due_at'];\n"
                + "                          var overdue = false;\n"
                + "                          var dueExtra = '';\n"
                + "                          if (dueRaw is int) {\n"
                + "                            final d = DateTime.fromMillisecondsSinceEpoch(dueRaw);\n"
                + "                            dueExtra =\n"
                + "                                ' · Due ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';\n"
                + "                            final today = DateTime.now();\n"
                + "                            final day = DateTime(d.year, d.month, d.day);\n"
                + "                            final start = DateTime(today.year, today.month, today.day);\n"
                + "                            overdue = !msDone && day.isBefore(start);\n"
                + "                          }\n"
                + "                          final displayLabel = '$label$dueExtra';\n"
            )
            t = t.replace(needle, inject, 1)
            t = t.replace(
                "                              Text(\n"
                "                                label,\n"
                "                                style: TextStyle(\n"
                "                                  color: AppTheme.silver.withValues(alpha: 0.45),\n"
                "                                  fontSize: 11,\n"
                "                                ),\n"
                "                              ),",
                "                              Text(\n"
                "                                displayLabel,\n"
                "                                style: TextStyle(\n"
                "                                  color: overdue\n"
                "                                      ? Colors.orangeAccent\n"
                "                                      : AppTheme.silver.withValues(alpha: 0.45),\n"
                "                                  fontSize: 11,\n"
                "                                ),\n"
                "                              ),",
                1,
            )
            print('due on progress label')
    return t


def ensure_db_model_repo() -> None:
    # Prefer our branch versions if present; otherwise take from current tree after merge
    db = Path('apps/flutter/lib/data/database.dart').read_text()
    if 'schemaVersion = 29' not in db:
        if 'schemaVersion = 28' in db:
            db = db.replace('schemaVersion = 28;', 'schemaVersion = 29;', 1)
            db = db.replace(
                '        if (oldVersion < 28) await _migrateToV28(db);\n',
                '        if (oldVersion < 28) await _migrateToV28(db);\n'
                '        if (oldVersion < 29) await _migrateToV29(db);\n',
                1,
            )
            if '_migrateToV29' not in db:
                insert_at = db.find('  Future<void> _migrateToV28')
                end = db.find('\n  Future<void>', insert_at + 10)
                if end < 0:
                    end = db.find('\n  Future<void> _executeIgnoringDuplicateColumn', insert_at)
                db = (
                    db[:end]
                    + '\n  Future<void> _migrateToV29(Database db) async {\n'
                    + "    await _executeIgnoringDuplicateColumn(\n"
                    + "        db, 'ALTER TABLE milestones ADD COLUMN due_at INTEGER');\n"
                    + '  }\n'
                    + db[end:]
                )
            Path('apps/flutter/lib/data/database.dart').write_text(db)
            print('db patched')
        else:
            print('unexpected schemaVersion')

    model = Path('apps/flutter/lib/domain/models.dart').read_text()
    block = model[model.find('class Milestone'):model.find('class Task')]
    if 'dueAt' not in block:
        model = model.replace(
            '  final int position;\n  final int createdAt;',
            '  final int position;\n  final int? dueAt;\n  final int createdAt;',
            1,
        )
        model = model.replace(
            '    this.position = 0,\n    required this.createdAt,',
            '    this.position = 0,\n    this.dueAt,\n    required this.createdAt,',
            1,
        )
        model = model.replace(
            "        position: dbIntOr(m['position']),\n        createdAt:",
            "        position: dbIntOr(m['position']),\n"
            "        dueAt: m['due_at'] == null ? null : dbIntOr(m['due_at']),\n"
            '        createdAt:',
            1,
        )
        Path('apps/flutter/lib/domain/models.dart').write_text(model)
        print('model patched')

    repo = Path('apps/flutter/lib/data/milestone_repository.dart').read_text()
    if 'Future<void> setDue' not in repo:
        extra = r'''
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
        repo = repo.rstrip()
        Path('apps/flutter/lib/data/milestone_repository.dart').write_text(
            repo[:-1] + extra + '}\n'
        )
        print('repo patched')

    schema = Path('apps/flutter/assets/schema.sql').read_text()
    if 'due_at INTEGER' not in schema[schema.find('milestones'):schema.find('milestones') + 350]:
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
        if old in schema:
            Path('apps/flutter/assets/schema.sql').write_text(schema.replace(old, new, 1))
            print('schema patched')


def main() -> None:
    sh('git', 'fetch', 'origin', 'main', '--depth=50')
    # merge main
    try:
        sh('git', 'merge', 'origin/main', '-m', 'merge main into milestone-due-dates')
    except subprocess.CalledProcessError:
        # accept ours/theirs for conflicts programmatically if any
        print('merge conflict — aborting to inspect')
        sys.exit(1)

    ensure_db_model_repo()
    pd = Path('apps/flutter/lib/ui/screens/project_detail_screen.dart')
    pd.write_text(ensure_due_in_project(pd.read_text()))
    print('project ok')


if __name__ == '__main__':
    main()
