from pathlib import Path

# ---- Planning screen empty states ----
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()

if "import '../forms/create_forms.dart';" not in p:
    p = p.replace(
        "import 'task_detail_screen.dart';",
        "import '../forms/create_forms.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

old_empty = '''                    if (built != null &&
                        built.timeline.isEmpty &&
                        _unscheduled.isEmpty) ...[
                      const SizedBox(height: 8),
                      GlassCard(
                        child: Text(
                          'Nothing planned for this day yet.\n'
                          'Add tasks or tap Build My Day when you have work to place.',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],'''

new_empty = '''                    if (built != null &&
                        built.timeline.isEmpty &&
                        _unscheduled.isEmpty) ...[
                      const SizedBox(height: 12),
                      GlassCard(
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
                              'or you can create a task and run Build My Day '
                              'to place work into time slots.',
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
                      ),
                    ],
                    if (built != null &&
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
                              'Nothing is timed yet for this day. Tap Build My Day '
                              'to fit open work into free hours, or drag tasks '
                              'into the hour grid after building.',
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
                    ],'''

if old_empty in p:
    p = p.replace(old_empty, new_empty, 1)
    print('planning empty ok')
else:
    print('planning empty MISS')

# When load failed and built is still null (not loading)
if 'Could not load this day' not in p:
    marker = '''        body: (_loading && _built == null)
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : RefreshIndicator('''
    repl = '''        body: (_loading && _built == null)
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : (_built == null && !_loading)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load this day',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
            : RefreshIndicator('''
    if marker in p:
        p = p.replace(marker, repl, 1)
        print('planning load-fail empty ok')

pp.write_text(p)

# ---- Schedule screen empty states ----
sp = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
s = sp.read_text()

if "import 'planning_screen.dart';" not in s:
    s = s.replace(
        "import 'task_detail_screen.dart';",
        "import 'planning_screen.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

# After the date GlassCard, inject day-empty banner when timeline empty
# Find unique marker after first GlassCard date row
marker_s = '''                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat.yMMMEd().format(_day),
                            style: const TextStyle(
                                color: AppTheme.silver, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (built != null)
                          Text(
                            '${built.plannedMinutes}m planned · ${built.freeMinutes}m free',
                            style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                          ),
                      ],
                    ),
                  ),'''

if 'No timed blocks yet' not in s and marker_s in s:
    insert = marker_s + '''
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
                                ? 'This day has an empty hour grid. Create open tasks '
                                    'first, then use Day plan → Build My Day to place them, '
                                    'or come back here to drag sessions into hours.'
                                : 'You have $trayHint open task${trayHint == 1 ? '' : 's'}. '
                                    'Open Day plan and tap Build My Day to place them into '
                                    'hours, then Apply here to write them onto the calendar.',
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
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PlanningScreen(initialDay: _day),
                                      ),
                                    ).then((_) => _load());
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
    s = s.replace(marker_s, insert, 1)
    print('schedule empty ok')
elif 'No timed blocks yet' in s:
    print('schedule empty already')
else:
    print('schedule marker MISS')

# Check PlanningScreen supports initialDay
plan = Path('apps/flutter/lib/ui/screens/planning_screen.dart').read_text()
if 'this.initialDay' not in plan and 'initialDay' not in plan.split('class PlanningScreen')[1][:400]:
    # Add optional initialDay to PlanningScreen
    plan = plan.replace(
        '''class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}''',
        '''class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}''',
        1,
    )
    # init _day from widget
    if 'DateTime _day = DateTime.now();' in plan or 'late DateTime _day;' in plan:
        pass
    # find how _day is initialized
    if 'DateTime _day =' in plan:
        # may need initState
        pass
    print('checking _day init...')
    for line in plan.splitlines():
        if '_day' in line and ('=' in line or 'late' in line) and 'class' not in line:
            if 'DateTime' in line or 'late' in line:
                print('  ', line.strip())

sp.write_text(s)
# write plan if we changed it
Path('apps/flutter/lib/ui/screens/planning_screen.dart').write_text(plan if 'this.initialDay' in plan or True else Path('apps/flutter/lib/ui/screens/planning_screen.dart').read_text())

# Fix PlanningScreen initialDay properly by reading current
plan = Path('apps/flutter/lib/ui/screens/planning_screen.dart').read_text()
if 'this.initialDay' not in plan:
    plan = plan.replace(
        'const PlanningScreen({super.key});',
        'const PlanningScreen({super.key, this.initialDay});\n\n  final DateTime? initialDay;',
        1,
    )
    # In state initState, set _day from widget if provided
    if 'void initState() {' in plan and 'widget.initialDay' not in plan:
        plan = plan.replace(
            '''  @override
  void initState() {
    super.initState();
    _load();
  }''',
            '''  @override
  void initState() {
    super.initState();
    final seed = widget.initialDay;
    if (seed != null) {
      _day = DateTime(seed.year, seed.month, seed.day);
    }
    _load();
  }''',
            1,
        )
        print('planning initialDay ok')
    Path('apps/flutter/lib/ui/screens/planning_screen.dart').write_text(plan)
else:
    print('planning already has initialDay')

print('DONE')
