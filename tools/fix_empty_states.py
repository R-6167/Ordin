from pathlib import Path
import re

# ---- Planning ----
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()

if "import '../forms/create_forms.dart';" not in p:
    p = p.replace(
        "import 'task_detail_screen.dart';",
        "import '../forms/create_forms.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

# Replace the old one-line empty GlassCard text block via regex
pat = re.compile(
    r"if \(built != null &&\s*built\.timeline\.isEmpty &&\s*_unscheduled\.isEmpty\) \.\.\.\[.*?GlassCard\(\s*child: Text\(\s*'Nothing planned for this day yet\.\\n'\s*'Add tasks or tap Build My Day when you have work to place\.',\s*style: TextStyle\([^)]*\),\s*\),\s*\),\s*\],",
    re.S,
)

new_empty = '''if (built != null &&
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
                    ]'''

if 'Nothing on this day yet' not in p:
    p2, n = pat.subn(new_empty, p, count=1)
    if n == 0:
        # fallback: simple string replace of the message card only
        simple_old = """                      GlassCard(
                        child: Text(
                          'Nothing planned for this day yet.\n'
                          'Add tasks or tap Build My Day when you have work to place.',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ),"""
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
        if simple_old in p:
            p = p.replace(simple_old, simple_new, 1)
            # also insert unscheduled-only card after this block's closing ],
            needle = simple_new + '\n                    ],'
            # find first ], after Nothing on this day
            idx = p.find('Nothing on this day yet')
            # insert unscheduled branch before next major if
            unscheduled_card = '''
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
                    ],'''
            if 'waiting to be placed' not in p:
                # after the empty block closes
                close_marker = "_unscheduled.isEmpty) ...["
                # find end of that spread - next "if (built != null && built.unplaced"
                m = p.find("if (built != null && built.unplaced.isNotEmpty)")
                if m > 0 and 'waiting to be placed' not in p:
                    p = p[:m] + unscheduled_card + '\n                    ' + p[m:]
            print('planning simple replace ok')
        else:
            raise SystemExit('planning empty still missing')
    else:
        p = p2
        print('planning regex ok')
else:
    print('planning already done')

# load fail UI
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
        print('planning fail ui ok')
    elif 'Could not load this day' in p:
        pass
    else:
        # maybe already patched with fail ui from prior run
        print('planning body marker miss')

# initialDay
if 'this.initialDay' not in p:
    p = p.replace(
        'const PlanningScreen({super.key});',
        'const PlanningScreen({super.key, this.initialDay});\n\n  final DateTime? initialDay;',
        1,
    )
    p = p.replace(
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
    print('initialDay ok')

pp.write_text(p)

# ---- Schedule ----
sp = Path('apps/flutter/lib/ui/screens/schedule_screen.dart')
s = sp.read_text()

if "import 'planning_screen.dart';" not in s:
    s = s.replace(
        "import 'task_detail_screen.dart';",
        "import 'planning_screen.dart';\nimport 'task_detail_screen.dart';",
        1,
    )

if 'No timed blocks yet' not in s:
    # Insert after the date summary card's closing),
    anchor = "DateFormat.yMMMEd().format(_day),"
    idx = s.find(anchor)
    if idx < 0:
        raise SystemExit('schedule date anchor missing')
    # find end of that GlassCard — next occurrence of '),
                  ),' after plannedMinutes line
    tail = s.find("'m planned · ${built.freeMinutes}m free'", idx)
    if tail < 0:
        raise SystemExit('schedule free minutes missing')
    # from tail, find the GlassCard close
    close = s.find('),
                  ),', tail)
    # better walk to two closing parens after the Row
    insert_at = s.find('\n                  const SizedBox', tail)
    if insert_at < 0:
        insert_at = s.find('\n                  for (var h', tail)
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
                                    'then use Day plan → Build My Day to place them, '
                                    'or drag sessions into hours here after building.'
                                : 'You have $trayHint open task${trayHint == 1 ? '' : 's'}. '
                                    'Open Day plan and tap Build My Day, then Apply here '
                                    'to write sessions onto the calendar.',
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
else:
    print('schedule already')

sp.write_text(s)

print('DONE')
print('planning has empty', 'Nothing on this day yet' in Path('apps/flutter/lib/ui/screens/planning_screen.dart').read_text())
print('schedule has empty', 'No timed blocks yet' in Path('apps/flutter/lib/ui/screens/schedule_screen.dart').read_text())
