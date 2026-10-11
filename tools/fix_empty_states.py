from pathlib import Path

pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()

if "import '../forms/create_forms.dart';" not in p:
    p = p.replace(
        "import 'task_detail_screen.dart';",
        "import '../forms/create_forms.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

simple_old = (
    "                      GlassCard(\n"
    "                        child: Text(\n"
    "                          'Nothing planned for this day yet.\\n'\n"
    "                          'Add tasks or tap Build My Day when you have work to place.',\n"
    "                          style: TextStyle(\n"
    "                            color: AppTheme.silver.withValues(alpha: 0.7),\n"
    "                            height: 1.35,\n"
    "                          ),\n"
    "                        ),\n"
    "                      ),"
)

simple_new = '''                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nothing on this day yet',
                              style: TextStyle(
                                color: AppTheme.silver,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Open tasks will appear here once you have some, '
                              'or create a task and run Build My Day to place work into time slots.',
                              style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.65),
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _building ? null : _rebuild,
                                    icon: const Icon(Icons.auto_awesome, size: 18),
                                    label: const Text('Build My Day'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await showCreateForm(
                                        context,
                                        AddKind.task,
                                      );
                                      if (ok) await _load();
                                    },
                                    icon: const Icon(Icons.add_task, size: 18),
                                    label: const Text('New task'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),'''

if 'Nothing on this day yet' not in p:
    if simple_old not in p:
        raise SystemExit('planning empty card not found')
    p = p.replace(simple_old, simple_new, 1)
    print('planning empty card replaced')

if 'waiting to be placed' not in p:
    marker = 'if (built != null && built.unplaced.isNotEmpty)'
    card = '''if (built != null &&
                        built.timeline.isEmpty &&
                        _unscheduled.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_unscheduled.length} task${_unscheduled.length == 1 ? '' : 's'} waiting to be placed',
                              style: const TextStyle(
                                color: AppTheme.silver,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Nothing is timed yet. Tap Build My Day to fit open work into free hours.',
                              style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.65),
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _building ? null : _rebuild,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Build My Day'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    '''
    if marker not in p:
        raise SystemExit('unplaced marker missing')
    p = p.replace(marker, card + marker, 1)
    print('unscheduled empty card added')

if 'Could not load this day' not in p:
    marker = (
        "        body: (_loading && _built == null)\n"
        "            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))\n"
        "            : RefreshIndicator("
    )
    repl = (
        "        body: (_loading && _built == null)\n"
        "            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))\n"
        "            : (_built == null && !_loading)\n"
        "                ? Center(\n"
        "                    child: Padding(\n"
        "                      padding: const EdgeInsets.all(24),\n"
        "                      child: Column(\n"
        "                        mainAxisSize: MainAxisSize.min,\n"
        "                        children: [\n"
        "                          Text(\n"
        "                            'Could not load this day',\n"
        "                            style: TextStyle(\n"
        "                              color: AppTheme.silver.withValues(alpha: 0.85),\n"
        "                              fontWeight: FontWeight.w600,\n"
        "                            ),\n"
        "                          ),\n"
        "                          const SizedBox(height: 12),\n"
        "                          FilledButton(\n"
        "                            onPressed: _load,\n"
        "                            child: const Text('Retry'),\n"
        "                          ),\n"
        "                        ],\n"
        "                      ),\n"
        "                    ),\n"
        "                  )\n"
        "            : RefreshIndicator("
    )
    if marker in p:
        p = p.replace(marker, repl, 1)
        print('load fail ui ok')

if 'this.initialDay' not in p:
    p = p.replace(
        'const PlanningScreen({super.key});',
        'const PlanningScreen({super.key, this.initialDay});\n\n  final DateTime? initialDay;',
        1,
    )
    p = p.replace(
        '  void initState() {\n    super.initState();\n    _load();\n  }',
        '  void initState() {\n    super.initState();\n    final seed = widget.initialDay;\n    if (seed != null) {\n      _day = DateTime(seed.year, seed.month, seed.day);\n    }\n    _load();\n  }',
        1,
    )
    print('initialDay ok')

pp.write_text(p)

# Schedule
sp = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
s = sp.read_text()

if "import 'planning_screen.dart';" not in s:
    s = s.replace(
        "import 'task_detail_screen.dart';",
        "import 'planning_screen.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

if 'No timed blocks yet' not in s:
    anchor = 'DateFormat.yMMMEd().format(_day),'
    idx = s.find(anchor)
    if idx < 0:
        raise SystemExit('schedule date missing')
    insert_at = s.find('\n                  const SizedBox', idx)
    if insert_at < 0:
        insert_at = s.find('\n                  for (var h', idx)
    if insert_at < 0:
        raise SystemExit('schedule insert point missing')
    block = '''
                  if (built != null && built.timeline.isEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No timed blocks yet',
                            style: TextStyle(
                              color: AppTheme.silver,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trayHint == 0
                                ? 'This day has an empty hour grid. Create open tasks, '
                                    'then use Day plan and Build My Day to place them.'
                                : 'You have $trayHint open task${trayHint == 1 ? '' : 's'}. '
                                    'Open Day plan, Build My Day, then Apply here.',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.65),
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PlanningScreen(initialDay: _day),
                                      ),
                                    )
                                        .then((_) => _load());
                                  },
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('Open Day plan'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loading ? null : _load,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Refresh'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],'''
    s = s[:insert_at] + block + s[insert_at:]
    print('schedule empty ok')

sp.write_text(s)
print('DONE')
