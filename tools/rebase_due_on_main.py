"""Merge origin/main; on conflict take main project_detail then re-apply due UX."""
from pathlib import Path
import subprocess
import sys


def sh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    print('+', ' '.join(args))
    return subprocess.run(list(args), check=check, text=True, capture_output=True)


def ensure_due_in_project(t: str) -> str:
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
            sys.exit('blockedOpen missing')
        t = t.replace(marker, helpers + marker, 1)

    if 'Set due date' not in t:
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
            "                            ),\n" + rename
        )
        if rename not in t:
            sys.exit('rename button missing on main UI')
        t = t.replace(rename, menu, 1)

    t = t.replace("                              onLongPress: () => _clearMilestoneDue(m),\n", '')

    if 'dueExtra' not in t and 'final label = msDone' in t:
        needle = (
            "                          final label = msDone\n"
            "                              ? (total == 0\n"
            "                                  ? 'Completed'\n"
            "                                  : 'Completed · $doneN/$total tasks')\n"
            "                              : (total == 0\n"
            "                                  ? 'No tasks yet'\n"
            "                                  : '$doneN of $total tasks');\n"
        )
        if needle in t:
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
            old_txt = (
                "                              Text(\n"
                "                                label,\n"
                "                                style: TextStyle(\n"
                "                                  color: AppTheme.silver.withValues(alpha: 0.45),\n"
                "                                  fontSize: 11,\n"
                "                                ),\n"
                "                              ),"
            )
            new_txt = (
                "                              Text(\n"
                "                                displayLabel,\n"
                "                                style: TextStyle(\n"
                "                                  color: overdue\n"
                "                                      ? Colors.orangeAccent\n"
                "                                      : AppTheme.silver.withValues(alpha: 0.45),\n"
                "                                  fontSize: 11,\n"
                "                                ),\n"
                "                              ),"
            )
            if old_txt in t:
                t = t.replace(old_txt, new_txt, 1)
    return t


def ensure_db_model_repo() -> None:
    dbp = Path('apps/flutter/lib/data/database.dart')
    db = dbp.read_text()
    if 'schemaVersion = 29' not in db and 'schemaVersion = 28' in db:
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
        dbp.write_text(db)

    modelp = Path('apps/flutter/lib/domain/models.dart')
    model = modelp.read_text()
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
        modelp.write_text(model)

    repop = Path('apps/flutter/lib/data/milestone_repository.dart')
    repo = repop.read_text()
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
        repop.write_text(repo[:-1] + extra + '}\n')

    sp = Path('apps/flutter/assets/schema.sql')
    schema = sp.read_text()
    chunk = schema[schema.find('milestones'):schema.find('milestones') + 400]
    if 'due_at' not in chunk:
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
            sp.write_text(schema.replace(old, new, 1))


def main() -> None:
    sh('git', 'fetch', 'origin', 'main')
    r = sh('git', 'merge', 'origin/main', '-m', 'merge main into milestone-due-dates', check=False)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr)
        sh('git', 'checkout', '--theirs', 'apps/flutter/lib/ui/screens/project_detail_screen.dart')
        status = sh('git', 'status', '--porcelain').stdout
        print(status)
        for line in status.splitlines():
            if line.startswith('UU ') or line.startswith('AA '):
                path = line[3:].strip()
                if path.endswith('project_detail_screen.dart'):
                    continue
                sh('git', 'checkout', '--ours', path, check=False)
                sh('git', 'add', path, check=False)
        sh('git', 'add', 'apps/flutter/lib/ui/screens/project_detail_screen.dart')
    ensure_db_model_repo()
    pd = Path('apps/flutter/lib/ui/screens/project_detail_screen.dart')
    pd.write_text(ensure_due_in_project(pd.read_text()))
    sh('git', 'add', '-A')
    if Path('.git/MERGE_HEAD').exists():
        sh('git', 'commit', '-m', 'merge main; due dates + progress bars (no onLongPress)')
    print('ready')


if __name__ == '__main__':
    main()
