from pathlib import Path
import re

# ---- schema.sql: align wellness tables with HealthRepository ----
sp = Path('apps/flutter/assets/schema.sql')
sql = sp.read_text()

old_wc = '''CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, mood INTEGER, notes TEXT,
  occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''

new_wc = '''CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  day INTEGER NOT NULL,
  mood INTEGER,
  energy INTEGER,
  stress INTEGER,
  sleep_hours REAL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(owner_id, day),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''

old_hm = '''CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, kind TEXT NOT NULL,
  value_real REAL, occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''

new_hm = '''CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);'''

if old_wc in sql:
    sql = sql.replace(old_wc, new_wc, 1)
    print('schema.sql wellness_checkins updated')
elif 'day INTEGER NOT NULL' in sql and 'wellness_checkins' in sql:
    print('schema.sql wellness already new')
else:
    # flexible replace via regex
    sql2, n = re.subn(
        r'CREATE TABLE IF NOT EXISTS wellness_checkins \([^;]+\);',
        new_wc,
        sql,
        count=1,
        flags=re.S,
    )
    sql = sql2
    print('schema.sql wellness regex', n)

if old_hm in sql:
    sql = sql.replace(old_hm, new_hm, 1)
    print('schema.sql health_metrics updated')
else:
    sql2, n = re.subn(
        r'CREATE TABLE IF NOT EXISTS health_metrics \([^;]+\);',
        new_hm,
        sql,
        count=1,
        flags=re.S,
    )
    sql = sql2
    print('schema.sql health regex', n)

sp.write_text(sql)

# ---- database.dart: fix v26 + add v27 repair ----
dbp = Path('apps/flutter/lib/data/database.dart')
db = dbp.read_text()

# bump version 26 -> 27
if 'schemaVersion = 27' not in db:
    db = db.replace('schemaVersion = 26', 'schemaVersion = 27', 1)
    # onCreate chain
    if 'await _migrateToV27(db);' not in db:
        db = db.replace(
            'await _migrateToV26(db);',
            'await _migrateToV26(db);\n        await _migrateToV27(db);',
            1,  # only first (onCreate) — careful: onUpgrade may also match
        )
        # Fix if both got double - better explicit
    # Ensure onCreate has both once
    # onUpgrade
    if 'if (oldVersion < 27)' not in db:
        db = db.replace(
            'if (oldVersion < 26) await _migrateToV26(db);',
            'if (oldVersion < 26) await _migrateToV26(db);\n        if (oldVersion < 27) await _migrateToV27(db);',
            1,
        )

# Replace broken v26 body to DROP+CREATE
old_v26 = None
m = re.search(r'  Future<void> _migrateToV26\(Database db\) async \{.*?\n  \}\n', db, re.S)
if m:
    new_v26 = '''  Future<void> _migrateToV26(Database db) async {
    // Old schema.sql created wellness_checkins without `day`; replace with repo contract.
    await db.execute('DROP TABLE IF EXISTS wellness_checkins');
    await db.execute('DROP TABLE IF EXISTS health_metrics');
    await db.execute("""
CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  day INTEGER NOT NULL,
  mood INTEGER,
  energy INTEGER,
  stress INTEGER,
  sleep_hours REAL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(owner_id, day),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute("""
CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wellness_owner_day ON wellness_checkins(owner_id, day DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON health_metrics(owner_id, metric_type, measured_at DESC)');
  }
'''
    db = db[:m.start()] + new_v26 + db[m.end():]
    print('v26 replaced')
else:
    print('v26 method not found')

# Add v27 if missing — same repair for devices that partially applied v26
if 'Future<void> _migrateToV27' not in db:
    v27 = '''
  Future<void> _migrateToV27(Database db) async {
    // Repair: ensure wellness tables match HealthRepository (day / metric_type).
    await db.execute('DROP TABLE IF EXISTS wellness_checkins');
    await db.execute('DROP TABLE IF EXISTS health_metrics');
    await db.execute("""
CREATE TABLE IF NOT EXISTS wellness_checkins (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  day INTEGER NOT NULL,
  mood INTEGER,
  energy INTEGER,
  stress INTEGER,
  sleep_hours REAL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(owner_id, day),
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute("""
CREATE TABLE IF NOT EXISTS health_metrics (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)
    """);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wellness_owner_day ON wellness_checkins(owner_id, day DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON health_metrics(owner_id, metric_type, measured_at DESC)');
  }
'''
    # insert before _migrateToV24 or after v26
    if 'Future<void> _migrateToV26' in db:
        # after v26 closing
        idx = db.find('Future<void> _migrateToV26')
        # find end of that method
        rest = db[idx:]
        end = rest.find('\n  Future<void>')
        if end < 0:
            end = rest.find('\n  Future<')
        # insert after first method
        # simpler: before _migrateToV24
        marker = '  Future<void> _migrateToV24(Database db) async {'
        if marker in db:
            db = db.replace(marker, v27 + '\n' + marker, 1)
            print('v27 inserted before v24')
        else:
            db = db[:idx] + rest[:end] + v27 + rest[end:]
            print('v27 inserted after v26')
    else:
        raise SystemExit('no v26 to anchor v27')

# Ensure onCreate calls v27 (may have only patched first occurrence incorrectly)
# Normalize onCreate block: after v26 call v27 once
if db.count('await _migrateToV27(db);') == 0:
    db = db.replace(
        'await _migrateToV26(db);\n        await _verifySchemaContract(db);',
        'await _migrateToV26(db);\n        await _migrateToV27(db);\n        await _verifySchemaContract(db);',
        1,
    )
    print('onCreate v27 added')

dbp.write_text(db)
print('schemaVersion', [l for l in db.splitlines() if 'schemaVersion' in l][0])
print('v27 defs', db.count('Future<void> _migrateToV27'))
print('DONE')
