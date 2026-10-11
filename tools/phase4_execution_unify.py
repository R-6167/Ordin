from pathlib import Path

# ---------------------------------------------------------------------------
# 1. TaskRepository.complete — same status everywhere + close sessions/blocks
# ---------------------------------------------------------------------------
tp = Path('apps/flutter/lib/data/task_repository.dart')
t = tp.read_text()

old = '''      final changed = await txn.update(
        'tasks',
        {
          'status': EntityStatus.completed,
          'completed_at': now,
          'updated_at': now,
        },
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
      );
      if (changed != 1) {
        throw StateError('Task not found, archived, or not owned by the current user: $taskId');
      }
      await txn.insert('activity_events', {'''

new = '''      final changed = await txn.update(
        'tasks',
        {
          'status': EntityStatus.completed,
          'completed_at': now,
          // Clear schedule so Today / calendar / plan no longer show this task as on the clock.
          'scheduled_start': null,
          'scheduled_end': null,
          'updated_at': now,
        },
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [taskId, ownerId],
      );
      if (changed != 1) {
        throw StateError('Task not found, archived, or not owned by the current user: $taskId');
      }

      // Cancel remaining planned time blocks (Day plan / Schedule / calendar feed).
      await txn.update(
        'time_blocks',
        {'status': 'CANCELLED', 'updated_at': now},
        where: "task_id = ? AND owner_id = ? AND status = 'PLANNED'",
        whereArgs: [taskId, ownerId],
      );

      // Close any open work sessions so session history matches task completion.
      final openSessions = await txn.query(
        'work_sessions',
        columns: ['id', 'status', 'started_at', 'accumulated_ms'],
        where: "task_id = ? AND owner_id = ? AND status IN ('RUNNING', 'PAUSED')",
        whereArgs: [taskId, ownerId],
      );
      for (final s in openSessions) {
        var acc = (s['accumulated_ms'] as int?) ?? 0;
        if (s['status'] == 'RUNNING') {
          final started = (s['started_at'] as int?) ?? now;
          acc += now - started;
        }
        await txn.update(
          'work_sessions',
          {
            'status': 'COMPLETED',
            'ended_at': now,
            'paused_at': null,
            'accumulated_ms': acc,
            'updated_at': now,
            'note': 'Closed with task completion',
          },
          where: 'id = ?',
          whereArgs: [s['id']],
        );
      }

      await txn.insert('activity_events', {'''

if 'Closed with task completion' not in t:
    if old not in t:
        raise SystemExit('complete block not found')
    t = t.replace(old, new, 1)
    print('task complete unified')
else:
    print('task complete already unified')

tp.write_text(t)

# ---------------------------------------------------------------------------
# 2. HomeShell Today — richer scheduled tiles + complete from Today
# ---------------------------------------------------------------------------
hp = Path('apps/flutter/lib/ui/home_shell.dart')
h = hp.read_text()

old_sched = '''            ..._scheduledToday.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openTask(t),
                    child: ListTile(
                      dense: true,
                      title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                    ),
                  ),
                )),'''

new_sched = '''            ..._scheduledToday.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
                      title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        _scheduledLabel(t),
                        style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                        tooltip: 'Complete',
                        onPressed: () async {
                          await _tasks.complete(t.id);
                          AppDataBus.instance.tasksChanged();
                        },
                      ),
                    ),
                  ),
                )),'''

if '_scheduledLabel' not in h:
    if old_sched not in h:
        raise SystemExit('scheduled today tile not found')
    h = h.replace(old_sched, new_sched, 1)
    helper = '''
  String _scheduledLabel(Task t) {
    final start = t.scheduledStart;
    if (start == null) return t.status;
    final d = DateTime.fromMillisecondsSinceEpoch(start);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm · ${t.status}';
  }
'''
    # insert before _tasksView
    marker = '  Widget _tasksView() {'
    if marker not in h:
        raise SystemExit('tasksView marker missing')
    h = h.replace(marker, helper + '\n' + marker, 1)
    print('today scheduled tiles ok')
else:
    print('today scheduled already enhanced')

# Ensure task complete on Today overdue/task list also uses same path (already does)
# Focus plan items: if PlanItem has task id, make completable - check PlanItem
hp.write_text(h)
print('DONE')
