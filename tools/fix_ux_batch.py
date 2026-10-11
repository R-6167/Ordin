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
    await _executeIgnoringDuplicateColumn(db, 'ALTER TABLE routines ADD COLUMN archived_at INTEGER');
  }
'''
    if 'Future<void> _migrateToV28' not in db:
        i = db.find('Future<void> _migrateToV27')
        if i < 0:
            raise SystemExit('no v27')
        rest = db[i + 10 :]
        m2 = re.search(r'\n  Future<void> _migrateToV\d+', rest)
        if m2:
            insert_at = i + 10 + m2.start()
            db = db[:insert_at] + '\n' + v28 + db[insert_at:]
        else:
            m3 = db.find('  Future<void> _executeIgnoringDuplicateColumn')
            db = db[:m3] + v28 + '\n' + db[m3:]
        print('v28 inserted')

dbp.write_text(db)
print('db version', [l for l in db.splitlines() if 'schemaVersion' in l][0])

# ========== 3. calendar ==========
cp = Path('apps/flutter/lib/ui/screens/calendar_screen.dart')
c = cp.read_text()
if 'status IS NULL OR status !=' not in c:
    c = c.replace(
        "where: 'start_at >= ? AND start_at < ? AND status != ?',",
        "where: 'start_at >= ? AND start_at < ? AND (status IS NULL OR status != ?)',",
        1,
    )
    print('calendar filter ok')
if "'status': 'ACTIVE'," not in c:
    c = c.replace(
        "'end_at': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,\n      'created_at': now,",
        "'end_at': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,\n      'status': 'ACTIVE',\n      'created_at': now,",
        1,
    )
    print('calendar status insert ok')
cp.write_text(c)

# ========== 4. planning rebuild try/catch ==========
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()
if 'Build My Day failed' not in p:
    old = '''  Future<void> _rebuild() async {
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
      ),
    );
  }'''
    new = '''  Future<void> _rebuild() async {
    setState(() => _building = true);
    try {
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
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _building = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Build My Day failed: $e')),
      );
    }
  }'''
    if old in p:
        p = p.replace(old, new, 1)
        print('planning rebuild ok')
    else:
        print('planning rebuild MISS')
pp.write_text(p)

# ========== 5. wellness unified save (rewrite screen helpers carefully) ==========
wp = Path('apps/flutter/lib/ui/screens/wellness_screen.dart')
w = wp.read_text()

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

# Replace _saveCheckin
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
    print('save ok')
else:
    print('save MISS')

# Replace _logMetric via regex
m = re.search(
    r'  Future<void> _logMetric\(String type, String label, String unit\) async \{.*?\n  \}\n',
    w,
    re.S,
)
if m and '_draftWeight = v' not in w:
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
            helperText: 'Included when you tap Save check-in',
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
    w = w[: m.start()] + new_log + w[m.end() :]
    print('logMetric ok')

w = w.replace(
    "child: const Text('Save check-in')",
    "child: const Text('Save check-in & metrics')",
    1,
)

# Load today's metrics into display fields
if "listMetrics('WEIGHT'" not in w:
    target = '''      setState(() {
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
      });'''
    repl = '''      final tw = await _repo.listMetrics('WEIGHT', limit: 1);
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
      });'''
    if target in w:
        w = w.replace(target, repl, 1)
        print('load metrics ok')
    else:
        print('load metrics MISS')

if 'Queued:' not in w:
    marker = "                  const SizedBox(height: 16),\n                  const Text('Recent check-ins',"
    insert = '''                  if (_draftWeight != null ||
                      _draftSteps != null ||
                      _draftExercise != null ||
                      _draftWater != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Queued: ${[
                          if (_draftWeight != null) 'Weight $_draftWeight kg',
                          if (_draftSteps != null) 'Steps $_draftSteps',
                          if (_draftExercise != null) 'Exercise $_draftExercise min',
                          if (_draftWater != null) 'Water $_draftWater ml',
                        ].join(' · ')}',
                        style: TextStyle(color: AppTheme.amber.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ),
                  if (_todayWeight != null ||
                      _todaySteps != null ||
                      _todayExercise != null ||
                      _todayWater != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Latest saved: ${[
                          if (_todayWeight != null) 'Weight $_todayWeight',
                          if (_todaySteps != null) 'Steps $_todaySteps',
                          if (_todayExercise != null) 'Exercise $_todayExercise',
                          if (_todayWater != null) 'Water $_todayWater',
                        ].join(' · ')}',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Recent check-ins','''
    if marker in w:
        w = w.replace(marker, insert, 1)
        print('display ok')

wp.write_text(w)

# ========== 6. notes: only label the progress line (no structure break) ==========
np = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
n = np.read_text()
# Prefer a simple string replace of isolated LinearProgress when scanning
if 'Scanning note for links' not in n:
    # common pattern: if (_scanning) const LinearProgressIndicator(...)
    n2 = n.replace(
        'if (_scanning)\n              const LinearProgressIndicator(color: AppTheme.amber),',
        '''if (_scanning) ...[
              const LinearProgressIndicator(color: AppTheme.amber),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Scanning note for links…',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
            ],''',
        1,
    )
    if n2 != n:
        n = n2
        print('note scanning label ok')
    else:
        print('note scanning pattern skip')
np.write_text(n)

print('DONE')
