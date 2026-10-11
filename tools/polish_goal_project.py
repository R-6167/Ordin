from pathlib import Path

# ---- Goal: evidence card ----
gp = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
g = gp.read_text()

if 'Progress evidence' not in g:
    needle = '''            if (t.nextMoves.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Next moves','''
    card = '''            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress evidence',
                    style: TextStyle(
                      color: AppTheme.woodLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Counts from linked work — not an arbitrary percentage.',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _evidenceChip(
                        '${t.projectsDone}/${t.projectsTotal} projects done',
                      ),
                      _evidenceChip(
                        '${t.milestonesDone}/${t.milestonesTotal} milestones',
                      ),
                      _evidenceChip(
                        '${t.tasksDone}/${t.tasksTotal} tasks',
                      ),
                      if (t.habitsActive > 0)
                        _evidenceChip(
                          '${t.habitsDoneToday}/${t.habitsActive} habits today',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (t.nextMoves.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Next moves','''
    if needle not in g:
        raise SystemExit('goal nextMoves needle missing')
    g = g.replace(needle, card, 1)
    # helper method before closing of class
    helper = '''
  Widget _evidenceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.silver.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.silver.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.silver.withValues(alpha: 0.85),
          fontSize: 12,
        ),
      ),
    );
  }
'''
    # insert before _ProjectTreeCard class
    if 'Widget _evidenceChip' not in g:
        marker = 'class _ProjectTreeCard'
        if marker not in g:
            raise SystemExit('ProjectTreeCard missing')
        g = g.replace(marker, helper + '\n' + marker, 1)
    print('goal evidence ok')
else:
    print('goal already')

gp.write_text(g)

# ---- Project: blocked attention ----
pp = Path('apps/flutter/lib/ui/screens/project_detail_screen.dart')
p = pp.read_text()

if 'Needs attention' not in p or 'Blocked open work' in p:
    pass

if 'Blocked open work' not in p:
    # Build helper in state class and UI after next-action GlassCard
    # Find unique spot: comment Progress + deadline
    needle = '''            const SizedBox(height: 12),

            // —— Progress + deadline ——'''
    if needle not in p:
        # try without blank line variation
        needle2 = "// —— Progress + deadline ——"
        if needle2 not in p:
            raise SystemExit('project progress marker missing')
        insert_before = needle2
        block = '''            if (_blockedOpen(ws).isNotEmpty) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blocked open work',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These tasks wait on incomplete dependencies. Clear blockers first.',
                      style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._blockedOpen(ws).take(6).map(
                      (t) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          dbStr(t['title']),
                          style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                        ),
                        subtitle: Text(
                          _blockedReason(ws, dbStr(t['id'])),
                          style: TextStyle(
                            color: Colors.orangeAccent.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.silverMuted, size: 18),
                        onTap: () => _openTaskDetails(dbStr(t['id'])),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // —— Progress + deadline ——'''
        p = p.replace(needle2, block, 1)
    else:
        block = '''            if (_blockedOpen(ws).isNotEmpty) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blocked open work',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These tasks wait on incomplete dependencies. Clear blockers first.',
                      style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._blockedOpen(ws).take(6).map(
                      (t) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          dbStr(t['title']),
                          style: const TextStyle(color: AppTheme.silver, fontSize: 13),
                        ),
                        subtitle: Text(
                          _blockedReason(ws, dbStr(t['id'])),
                          style: TextStyle(
                            color: Colors.orangeAccent.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.silverMuted, size: 18),
                        onTap: () => _openTaskDetails(dbStr(t['id'])),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),

            // —— Progress + deadline ——'''
        p = p.replace(needle, block, 1)
    print('project blocked UI ok')

    methods = '''
  List<Map<String, Object?>> _blockedOpen(ProjectWorkspace ws) {
    final open = <Map<String, Object?>>[
      ...ws.tasks,
      ...ws.subtasks,
    ].where((t) {
      final s = dbStr(t['status']).toUpperCase();
      return s != 'COMPLETED' && s != 'CANCELLED' && s != 'DONE';
    }).toList();
    final out = <Map<String, Object?>>[];
    for (final t in open) {
      final id = dbStr(t['id']);
      final deps = ws.dependencies.where((d) => dbStr(d['task_id']) == id);
      for (final d in deps) {
        final st = dbStr(d['depends_on_status']).toUpperCase();
        if (st != 'COMPLETED' && st != 'CANCELLED' && st != 'DONE') {
          out.add(t);
          break;
        }
      }
    }
    return out;
  }

  String _blockedReason(ProjectWorkspace ws, String taskId) {
    final titles = <String>[];
    for (final d in ws.dependencies) {
      if (dbStr(d['task_id']) != taskId) continue;
      final st = dbStr(d['depends_on_status']).toUpperCase();
      if (st == 'COMPLETED' || st == 'CANCELLED' || st == 'DONE') continue;
      final title = dbStr(d['depends_on_title']);
      if (title.isNotEmpty) titles.add(title);
    }
    if (titles.isEmpty) return 'Blocked by dependency';
    return 'Waiting on: ${titles.take(2).join(', ')}';
  }
'''
    if 'List<Map<String, Object?>> _blockedOpen' not in p:
        # insert before first Future void _add or before @override Widget build
        marker = '  @override\n  Widget build(BuildContext context) {'
        if marker not in p:
            raise SystemExit('project build marker missing')
        p = p.replace(marker, methods + '\n' + marker, 1)
        print('project helpers ok')
else:
    print('project already has blocked open work')

pp.write_text(p)
print('DONE')
