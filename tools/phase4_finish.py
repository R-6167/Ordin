from pathlib import Path

# ---------------------------------------------------------------------------
# 1. Cancel pending reminders when task completes
# ---------------------------------------------------------------------------
ep = Path('apps/flutter/lib/data/extended_repository.dart')
e = ep.read_text()
if 'cancelRemindersForSource' not in e:
    needle = '''  Future<void> completeReminder(String id) async {
    await (await _db.database).update(
      'reminders','''
    # find completeReminder method end - insert new method after cancelReminder block
    marker = '  Future<void> deleteReminder(String id) => cancelReminder(id);'
    method = '''  /// Cancel pending reminders linked to a source entity (e.g. TASK).
  Future<void> cancelRemindersForSource({
    required String sourceType,
    required String sourceId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await (await _db.database).update(
      'reminders',
      {'status': 'CANCELLED', 'updated_at': now},
      where:
          "owner_id = ? AND source_type = ? AND source_id = ? AND (status IS NULL OR status = 'PENDING' OR status = 'ACTIVE')",
      whereArgs: [ownerId, sourceType, sourceId],
    );
  }

  Future<void> deleteReminder(String id) => cancelReminder(id);'''
    if marker not in e:
        raise SystemExit('deleteReminder marker missing')
    e = e.replace(marker, method, 1)
    print('cancelRemindersForSource ok')
    ep.write_text(e)
else:
    print('cancelReminders already')

# Wire into task complete (after time_blocks / sessions)
tp = Path('apps/flutter/lib/data/task_repository.dart')
t = tp.read_text()
if 'cancelRemindersForSource' not in t and 'source_type' not in t[t.find('Future<Task?> complete'):t.find('Future<Task?> complete')+3500]:
    # Add reminder cancel inside the txn after sessions, or after txn via ExtendedRepository
    # Prefer inside txn with raw update for atomicity
    insert_after = "            'note': 'Closed with task completion',\n          },\n          where: 'id = ?',\n          whereArgs: [s['id']],\n        );\n      }"
    reminder_block = '''

      // Cancel pending reminders tied to this task (calendar / notification sources).
      await txn.update(
        'reminders',
        {'status': 'CANCELLED', 'updated_at': now},
        where:
            "owner_id = ? AND source_type = ? AND source_id = ? AND (status IS NULL OR status = 'PENDING' OR status = 'ACTIVE')",
        whereArgs: [ownerId, 'TASK', taskId],
      );'''
    if insert_after not in t:
        # try simpler anchor
        anchor = "'Closed with task completion'"
        if anchor not in t:
            raise SystemExit('complete session close anchor missing')
        # find end of for loop after anchor
        idx = t.find(anchor)
        # find "      }\n\n      await txn.insert('activity_events'" after idx
        end = t.find("await txn.insert('activity_events'", idx)
        if end < 0:
            raise SystemExit('activity_events after complete missing')
        t = t[:end] + '''await txn.update(
        'reminders',
        {'status': 'CANCELLED', 'updated_at': now},
        where:
            "owner_id = ? AND source_type = ? AND source_id = ? AND (status IS NULL OR status = 'PENDING' OR status = 'ACTIVE')",
        whereArgs: [ownerId, 'TASK', taskId],
      );

      ''' + t[end:]
        print('reminders in complete (fallback)')
    else:
        t = t.replace(insert_after, insert_after + reminder_block, 1)
        print('reminders in complete')
    tp.write_text(t)
else:
    print('task complete reminders already')

# ---------------------------------------------------------------------------
# 2. HomeShell — blocked set + plan item open + task tile badge
# ---------------------------------------------------------------------------
hp = Path('apps/flutter/lib/ui/home_shell.dart')
h = hp.read_text()

if 'Set<String> _blockedIds' not in h:
    h = h.replace(
        '  List<Task> _scheduledToday = [];',
        '  List<Task> _scheduledToday = [];\n  Set<String> _blockedIds = {};',
        1,
    )
    print('blocked field ok')

# Load blocked with tasks
if 'listBlockedTaskIds' not in h:
    old = '''    if (wantTasks || wantToday) {
      futures.add(() async {
        taskList =
            await softFuture(_tasks.listOpen, fallback: <Task>[], label: 'tasks.open') ??
                <Task>[];
        overdue =
            await softFuture(_tasks.listOverdue, fallback: <Task>[], label: 'tasks.overdue') ??
                <Task>[];
      }());
    }'''
    new = '''    Set<String>? blockedIds;
    if (wantTasks || wantToday) {
      futures.add(() async {
        taskList =
            await softFuture(_tasks.listOpen, fallback: <Task>[], label: 'tasks.open') ??
                <Task>[];
        overdue =
            await softFuture(_tasks.listOverdue, fallback: <Task>[], label: 'tasks.overdue') ??
                <Task>[];
        blockedIds = await softFuture(
              _tasks.listBlockedTaskIds,
              fallback: <String>{},
              label: 'tasks.blocked',
            ) ??
            <String>{};
      }());
    }'''
    if old not in h:
        raise SystemExit('tasks load block missing')
    h = h.replace(old, new, 1)
    # assign in setState — find where taskList is assigned
    if 'if (taskList != null) _taskList = taskList!;' in h:
        h = h.replace(
            'if (taskList != null) _taskList = taskList!;',
            'if (taskList != null) _taskList = taskList!;\n      if (blockedIds != null) _blockedIds = blockedIds!;',
            1,
        )
    else:
        # find _taskList =
        for line in h.splitlines():
            if '_taskList =' in line and 'taskList' in line:
                print('assign line', line)
        # try common pattern
        if 'if (overdue != null) _overdue = overdue!;' in h:
            h = h.replace(
                'if (overdue != null) _overdue = overdue!;',
                'if (overdue != null) _overdue = overdue!;\n      if (blockedIds != null) _blockedIds = blockedIds!;',
                1,
            )
        else:
            raise SystemExit('could not assign blockedIds')
    print('blocked load ok')

# Plan items tappable for tasks
old_plan = '''            ..._plan.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Text(p.title,
                        style:
                            const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                  ),
                )),'''
new_plan = '''            ..._plan.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openPlanItem(p),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                                color: AppTheme.silver, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          p.reason,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),'''
if old_plan in h:
    h = h.replace(old_plan, new_plan, 1)
    print('plan items tappable')
elif '_openPlanItem' in h:
    print('plan already')
else:
    print('WARN plan pattern miss')

# _openPlanItem + update _taskTile subtitle for blocked
if '_openPlanItem' not in h:
    helper = '''
  Future<void> _openPlanItem(PlanItem p) async {
    switch (p.kind) {
      case PlanItemKind.overdueTask:
      case PlanItemKind.dueTodayTask:
      case PlanItemKind.openTask:
        final generationBefore = AppDataBus.instance.generation;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: p.id)),
        );
        if (!mounted) return;
        if (AppDataBus.instance.generation != generationBefore) {
          await _reload(domains: {DataDomain.tasks, DataDomain.today});
        }
        break;
      default:
        // Habits / bills / events — no task detail route yet.
        break;
    }
  }
'''
    marker = '  String _scheduledLabel(Task t) {'
    if marker in h:
        h = h.replace(marker, helper + '\n' + marker, 1)
    else:
        h = h.replace('  Widget _tasksView() {', helper + '\n  Widget _tasksView() {', 1)
    print('openPlanItem ok')

# Task tile blocked badge
old_sub = '''            subtitle: Text(
              t.isOverdue ? 'OVERDUE' : (t.isDueToday ? 'Due today' : t.status),
              style: TextStyle(
                color: t.isOverdue ? Colors.redAccent : AppTheme.silver.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),'''
new_sub = '''            subtitle: Text(
              _taskStatusLine(t),
              style: TextStyle(
                color: t.isOverdue
                    ? Colors.redAccent
                    : (_blockedIds.contains(t.id)
                        ? Colors.orangeAccent
                        : AppTheme.silver.withValues(alpha: 0.4)),
                fontSize: 11,
              ),
            ),'''
if old_sub in h:
    h = h.replace(old_sub, new_sub, 1)  # may appear once in today tiles only - replace_all?
    # only one occurrence expected for _taskTile; if two identical replace all
    while old_sub in h:
        h = h.replace(old_sub, new_sub, 1)
    if '_taskStatusLine' not in h:
        h = h.replace(
            '  String _scheduledLabel(Task t) {',
            '''  String _taskStatusLine(Task t) {
    final parts = <String>[];
    if (t.isOverdue) {
      parts.add('OVERDUE');
    } else if (t.isDueToday) {
      parts.add('Due today');
    }
    if (_blockedIds.contains(t.id)) parts.add('Blocked');
    parts.add(t.status);
    return parts.join(' · ');
  }

  String _scheduledLabel(Task t) {''',
            1,
        )
    print('task tile blocked ok')
else:
    print('WARN task subtitle pattern miss')

hp.write_text(h)
print('DONE')
