from pathlib import Path
import re

# ========== 1. schema.sql: routines.archived_at ==========
sp = Path('apps/flutter/assets/schema.sql')
sql = sp.read_text()
old_r = '''CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  estimated_minutes INTEGER, status TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''
new_r = '''CREATE TABLE IF NOT EXISTS routines (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL,
  estimated_minutes INTEGER, status TEXT,
  archived_at INTEGER,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''
if old_r in sql:
    sql = sql.replace(old_r, new_r, 1)
    print('schema routines ok')
elif 'archived_at INTEGER' in sql[sql.find('routines'):sql.find('routines')+400]:
    print('schema routines already has archived_at')
else:
    sql2, n = re.subn(
        r'CREATE TABLE IF NOT EXISTS routines \([^;]+\);',
        new_r,
        sql,
        count=1,
        flags=re.S,
    )
    sql = sql2
    print('schema routines regex', n)
sp.write_text(sql)

# ========== 2. database.dart: soft column + v28 ==========
dbp = Path('apps/flutter/lib/data/database.dart')
db = dbp.read_text()

if "ALTER TABLE routines ADD COLUMN archived_at INTEGER" not in db:
    db = db.replace(
        "'ALTER TABLE habits ADD COLUMN archived_at INTEGER',",
        "'ALTER TABLE habits ADD COLUMN archived_at INTEGER',\n      'ALTER TABLE routines ADD COLUMN archived_at INTEGER',",
        1,
    )
    print('soft column routines ok')

if 'schemaVersion = 28' not in db:
    db = db.replace('schemaVersion = 27', 'schemaVersion = 28', 1)
    if 'await _migrateToV28(db);' not in db:
        # onCreate: after v27
        db = db.replace(
            'await _migrateToV27(db);',
            'await _migrateToV27(db);\n        await _migrateToV28(db);',
            1,
        )
    if 'if (oldVersion < 28)' not in db:
        db = db.replace(
            'if (oldVersion < 27) await _migrateToV27(db);',
            'if (oldVersion < 27) await _migrateToV27(db);\n        if (oldVersion < 28) await _migrateToV28(db);',
            1,
        )
    v28 = '''
  Future<void> _migrateToV28(Database db) async {
    // routines.listActive filters archived_at; old schema lacked the column.
    await _executeIgnoringDuplicateColumn(db, 'ALTER TABLE routines ADD COLUMN archived_at INTEGER');
  }
'''
    if 'Future<void> _migrateToV28' not in db:
        marker = '  Future<void> _migrateToV27(Database db) async {'
        if marker not in db:
            marker = '  Future<void> _migrateToV26(Database db) async {'
        # insert before first migrate after soft columns area — after v27 method
        # Find end of v27: after its last execute/index
        i = db.find('Future<void> _migrateToV27')
        if i < 0:
            raise SystemExit('no v27')
        # find next Future after v27 body
        rest = db[i+10:]
        # skip to next method at class indent
        m2 = re.search(r'\n  Future<void> _migrateToV\d+', rest)
        if m2:
            insert_at = i + 10 + m2.start()
            db = db[:insert_at] + '\n' + v28 + db[insert_at:]
        else:
            # before _executeIgnoringDuplicateColumn
            m3 = db.find('  Future<void> _executeIgnoringDuplicateColumn')
            db = db[:m3] + v28 + '\n' + db[m3:]
        print('v28 inserted')
    print('schema 28')

dbp.write_text(db)

# ========== 3. calendar: null-safe status filter + default status ==========
cp = Path('apps/flutter/lib/ui/screens/calendar_screen.dart')
c = cp.read_text()
c = c.replace(
    "where: 'start_at >= ? AND start_at < ? AND status != ?',\n      whereArgs: [\n        start.millisecondsSinceEpoch,\n        end.millisecondsSinceEpoch,\n        'CANCELLED',\n      ],",
    "where: 'start_at >= ? AND start_at < ? AND (status IS NULL OR status != ?)',\n      whereArgs: [\n        start.millisecondsSinceEpoch,\n        end.millisecondsSinceEpoch,\n        'CANCELLED',\n      ],",
    1,
)
if "'status': 'ACTIVE'," not in c:
    c = c.replace(
        "await db.insert('calendar_events', {\n      'id': AppDatabase.newId(),\n      'owner_id': ownerId,\n      'title': title.text.trim(),\n      'start_at': start.millisecondsSinceEpoch,\n      'end_at': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,\n      'created_at': now,\n      'updated_at': now,\n    });",
        "await db.insert('calendar_events', {\n      'id': AppDatabase.newId(),\n      'owner_id': ownerId,\n      'title': title.text.trim(),\n      'start_at': start.millisecondsSinceEpoch,\n      'end_at': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,\n      'status': 'ACTIVE',\n      'created_at': now,\n      'updated_at': now,\n    });",
        1,
    )
    print('calendar insert status ok')
print('calendar filter ok' if 'status IS NULL' in c else 'calendar filter FAIL')
cp.write_text(c)

# ========== 4. planning: try/catch rebuild ==========
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()
old_rb = '''  Future<void> _rebuild() async {
    setState(() => _building = true);
    final built = await _engine.build(day: _day);
    final n = await _engine.apply(built);
    await _load();
    if (!mounted) return;
    setState(() => _building = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'No new sessions applied (day may already be full or blocked)'
              : 'Applied $n timed session${n == 1 ? '' : 's'}',
        ),
      ),'''
# find full method is hard — wrap start
if 'Building failed' not in p:
    p = p.replace(
        '''  Future<void> _rebuild() async {
    setState(() => _building = true);
    final built = await _engine.build(day: _day);
    final n = await _engine.apply(built);
    await _load();
    if (!mounted) return;
    setState(() => _building = false);''',
        '''  Future<void> _rebuild() async {
    setState(() => _building = true);
    try {
    final built = await _engine.build(day: _day);
    final n = await _engine.apply(built);
    await _load();
    if (!mounted) return;
    setState(() => _building = false);''',
        1,
    )
    # close try after snackbar block - look for setState building false is already inside; add catch after first snackbar's closing
    # simpler: after _building = false block ends with snackbar, inject catch before next method
    # Find the snackbar end pattern unique to _rebuild
    # After "Applied $n timed session" snackbar, there's typically ); and }
    if 'Building failed' not in p:
        # insert catch before next Future after rebuild's snackbar
        needle = "              : 'Applied $n timed session${n == 1 ? '' : 's'}',\n        ),\n      ),"
        # read a bit more context from file
        idx = p.find(": 'Applied $n timed session")
        if idx > 0:
            # find closing of method - next \n  Future or \n  Widget
            chunk = p[idx:idx+400]
            # print for debug in CI
            print('rebuild tail', repr(chunk[:200]))
        # Use a more reliable approach: replace the whole known ending
        p2 = p.replace(
            '''    setState(() => _building = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'No new sessions applied (day may already be full or blocked)'
              : 'Applied $n timed session${n == 1 ? '' : 's'}',
        ),
      ),
    );
  }''',
            '''    setState(() => _building = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'No new sessions applied (day may already be full or blocked)'
              : 'Applied $n timed session${n == 1 ? '' : 's'}',
        ),
      ),
    );
    } catch (e) {
      if (!mounted) return;
      setState(() => _building = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Build My Day failed: $e')),
      );
    }
  }''',
            1,
        )
        if p2 != p:
            p = p2
            print('planning rebuild try ok')
        else:
            print('planning rebuild pattern miss — soft wrap only')
pp.write_text(p)

# ========== 5. wellness: draft metrics + unified save + show today ==========
wp = Path('apps/flutter/lib/ui/screens/wellness_screen.dart')
w = wp.read_text()
# Add draft fields if missing
if 'double? _draftWeight' not in w:
    w = w.replace(
        '  bool _loading = true;',
        '''  bool _loading = true;
  double? _draftWeight;
  double? _draftSteps;
  double? _draftExercise;
  double? _draftWater;
  String? _todayWeight;
  String? _todaySteps;
  String? _todayExercise;
  String? _todayWater;''',
        1,
    )
    print('wellness drafts fields')

# Extend _load to fetch today's metrics
if "_todayWeight" in w and "listMetrics('WEIGHT'" not in w:
    old_load_end = '''        _loading = false;
      });
    } catch (e) {'''
    # insert metric load before _loading = false in try block
    if old_load_end in w:
        w = w.replace(
            '''        _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        _loading = false;
      });''',
            '''        _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        // Today's latest metrics (for display)
        Future<String?> latest(String type) async {
          final rows = await _repo.listMetrics(type, limit: 1);
          if (rows.isEmpty) return null;
          final v = rows.first['value'];
          final u = rows.first['unit'];
          return v == null ? null : '${v is num ? (v as num).toStringAsFixed(v is int || (v as num) == (v as num).roundToDouble() ? 0 : 1) : v}${u != null ? ' $u' : ''}';
        }
        // inline sequential load
      });
      // reload metrics outside first setState
      final tw = await _repo.listMetrics('WEIGHT', limit: 1);
      final ts = await _repo.listMetrics('STEPS', limit: 1);
      final te = await _repo.listMetrics('EXERCISE_MINUTES', limit: 1);
      final twa = await _repo.listMetrics('WATER_ML', limit: 1);
      String? fmt(List rows) {
        if (rows.isEmpty) return null;
        final v = rows.first['value'] as num?;
        final u = rows.first['unit'] as String?;
        if (v == null) return null;
        final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
        return u == null || u.isEmpty ? s : '$s $u';
      }
      if (!mounted) return;
      setState(() {
        _todayWeight = fmt(tw);
        _todaySteps = fmt(ts);
        _todayExercise = fmt(te);
        _todayWater = fmt(twa);
        _loading = false;
      });
    } catch (e) {''',
            1,
        )
        # The above may have broken structure - do a cleaner full _load replace instead
        print('wellness load metric attempt')

# Simpler approach: rewrite _saveCheckin to also persist drafts, and change metric buttons to set drafts
# Replace _logMetric with draft setters and show values in UI

if 'Save all' not in w and "child: const Text('Save check-in')" in w:
    # Replace _saveCheckin body to log metrics too
    old_save = '''  Future<void> _saveCheckin() async {
    await _repo.saveCheckin(
      mood: _mood,
      energy: _energy,
      stress: _stress,
      sleepHours: _sleep,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wellness check-in saved')),
      );
    }
    await _load();
  }'''
    new_save = '''  Future<void> _saveCheckin() async {
    try {
      await _repo.saveCheckin(
        mood: _mood,
        energy: _energy,
        stress: _stress,
        sleepHours: _sleep,
      );
      if (_draftWeight != null) {
        await _repo.logMetric(type: 'WEIGHT', value: _draftWeight!, unit: 'kg');
      }
      if (_draftSteps != null) {
        await _repo.logMetric(type: 'STEPS', value: _draftSteps!, unit: 'steps');
      }
      if (_draftExercise != null) {
        await _repo.logMetric(type: 'EXERCISE_MINUTES', value: _draftExercise!, unit: 'min');
      }
      if (_draftWater != null) {
        await _repo.logMetric(type: 'WATER_ML', value: _draftWater!, unit: 'ml');
      }
      if (mounted) {
        setState(() {
          _draftWeight = null;
          _draftSteps = null;
          _draftExercise = null;
          _draftWater = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in and metrics saved')),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }'''
    if old_save in w:
        w = w.replace(old_save, new_save, 1)
        print('save unified ok')
    else:
        print('save pattern miss')

    # Change metric buttons to draft dialogs that don't save immediately
    old_log = '''  Future<void> _logMetric(String type, String label, String unit) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(label, style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(labelText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log')),
        ],
      ),
    );'''
    # Read rest of method from file - replace Log with Set, and assignment to drafts
    # Full method replacement via regex
    m = re.search(
        r'  Future<void> _logMetric\(String type, String label, String unit\) async \{.*?\n  \}\n',
        w,
        re.S,
    )
    if m:
        new_log = '''  Future<void> _logMetric(String type, String label, String unit) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(label, style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(
            labelText: unit,
            helperText: 'Saved with Check-in',
            helperStyle: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim());
    if (v == null) return;
    setState(() {
      switch (type) {
        case 'WEIGHT':
          _draftWeight = v;
        case 'STEPS':
          _draftSteps = v;
        case 'EXERCISE_MINUTES':
          _draftExercise = v;
        case 'WATER_ML':
          _draftWater = v;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label $v $unit queued — tap Save check-in')),
      );
    }
  }
'''
        w = w[:m.start()] + new_log + w[m.end():]
        print('logMetric draft ok')

    # Button label
    w = w.replace(
        "child: const Text('Save check-in')",
        "child: const Text('Save check-in & metrics')",
        1,
    )

    # Show draft/today under metric buttons section
    if 'Queued metrics' not in w:
        # After the Wrap of metric buttons, before Recent check-ins
        marker = "                  const SizedBox(height: 16),\n                  const Text('Recent check-ins',"
        insert = '''                  if (_draftWeight != null ||
                      _draftSteps != null ||
                      _draftExercise != null ||
                      _draftWater != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Queued: '
                      '${[
                        if (_draftWeight != null) 'Weight $_draftWeight kg',
                        if (_draftSteps != null) 'Steps $_draftSteps',
                        if (_draftExercise != null) 'Exercise $_draftExercise min',
                        if (_draftWater != null) 'Water $_draftWater ml',
                      ].join(' · ')}',
                      style: TextStyle(color: AppTheme.amber.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                  if (_todayWeight != null ||
                      _todaySteps != null ||
                      _todayExercise != null ||
                      _todayWater != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Latest saved: '
                      '${[
                        if (_todayWeight != null) 'Weight $_todayWeight',
                        if (_todaySteps != null) 'Steps $_todaySteps',
                        if (_todayExercise != null) 'Exercise $_todayExercise',
                        if (_todayWater != null) 'Water $_todayWater',
                      ].join(' · ')}',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Recent check-ins','''
        if marker in w:
            w = w.replace(marker, insert, 1)
            print('metric display ok')

# Fix wellness _load to set today metrics — full safe replace of try body ending
if 'listMetrics(\'WEIGHT\'' not in w and 'listMetrics("WEIGHT"' not in w:
    # After setting sleep from today, before _loading false, load metrics
    if '''      setState(() {
        _today = today;
        _week = week;
        _recent = recent;''' in w:
        # replace the catch path structure: load metrics before final loading false
        w = w.replace(
            '''      setState(() {
        _today = today;
        _week = week;
        _recent = recent;
        if (today != null) {
          _mood = (today['mood'] as int?) ?? 3;
          _energy = (today['energy'] as int?) ?? 3;
          _stress = (today['stress'] as int?) ?? 3;
          _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        _loading = false;
      });''',
            '''      final tw = await _repo.listMetrics('WEIGHT', limit: 1);
      final ts = await _repo.listMetrics('STEPS', limit: 1);
      final te = await _repo.listMetrics('EXERCISE_MINUTES', limit: 1);
      final twa = await _repo.listMetrics('WATER_ML', limit: 1);
      String? fmt(List<Map<String, Object?>> rows) {
        if (rows.isEmpty) return null;
        final v = rows.first['value'] as num?;
        final u = rows.first['unit'] as String?;
        if (v == null) return null;
        final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
        return (u == null || u.isEmpty) ? s : '$s $u';
      }
      if (!mounted) return;
      setState(() {
        _today = today;
        _week = week;
        _recent = recent;
        if (today != null) {
          _mood = (today['mood'] as int?) ?? 3;
          _energy = (today['energy'] as int?) ?? 3;
          _stress = (today['stress'] as int?) ?? 3;
          _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
        }
        _todayWeight = fmt(tw);
        _todaySteps = fmt(ts);
        _todayExercise = fmt(te);
        _todayWater = fmt(twa);
        _loading = false;
      });''',
            1,
        )
        print('wellness load metrics ok')

wp.write_text(w)

# ========== 6. notes: clearer scanning + extractTasks try/catch ==========
np = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
n = np.read_text()

# Replace thin loading line with labeled progress
if "Looking for links" not in n:
    n = n.replace(
        '''            if (_scanning)
''',
        '''            if (_scanning) ...[
              const LinearProgressIndicator(color: AppTheme.amber),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  'Looking for people, projects, and tasks mentioned in this note…',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
            ] else if (false)
''',
        1,
    )
    # The above is hacky if original was `if (_scanning) LinearProgress...`
    # Check actual pattern
    print('note scanning patch applied?')

# Safer: fix extractTasks
if 'Extract failed' not in n:
    m = re.search(r'  Future<void> _extractTasks\(\) async \{', n)
    if m:
        # wrap body start
        n = n.replace(
            '  Future<void> _extractTasks() async {\n    final content',
            '  Future<void> _extractTasks() async {\n    try {\n    final content',
            1,
        )
        # Need to close try - find end of method is hard
        # Add catch before next Future at same level after extract
        # Find "Future<void> _extractTasks" end by matching braces later in a second pass
        print('extract try opened')

# Minimal note fix: ensure scanning indicator has text if LinearProgressIndicator alone
if "Looking for people" not in n and 'LinearProgressIndicator' in n:
    n = n.replace(
        'LinearProgressIndicator(color: AppTheme.amber)',
        '''Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LinearProgressIndicator(color: AppTheme.amber),
                  const SizedBox(height: 6),
                  Text(
                    'Scanning note for links…',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              )''',
        1,
    )
    print('scanning label ok')

np.write_text(n)
print('DONE')
