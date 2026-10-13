"""Replace DROP wellness/health migrations with non-destructive path."""
from pathlib import Path
import re
import subprocess
import sys

HELPER = r'''
  /// Public for upgrade tests: ensure wellness/health match HealthRepository
  /// without discarding existing rows.
  @visibleForTesting
  static Future<void> migrateWellnessHealthNonDestructive(Database db) async {
    await AppDatabase.instance._ensureWellnessCheckinsTable(db);
    await AppDatabase.instance._ensureHealthMetricsTable(db);
  }

  Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnNames(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info(' + table + ')');
    return info.map((row) => row['name'] as String).toSet();
  }

  Future<void> _ensureWellnessCheckinsTable(Database db) async {
    const createBody = '''
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
''';
    if (!await _tableExists(db, 'wellness_checkins')) {
      await db.execute(
        'CREATE TABLE wellness_checkins (' + createBody + ')',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wellness_owner_day '
        'ON wellness_checkins(owner_id, day DESC)',
      );
      return;
    }

    final cols = await _columnNames(db, 'wellness_checkins');
    if (cols.contains('day') && cols.contains('owner_id') && cols.contains('id')) {
      for (final alter in [
        'ALTER TABLE wellness_checkins ADD COLUMN mood INTEGER',
        'ALTER TABLE wellness_checkins ADD COLUMN energy INTEGER',
        'ALTER TABLE wellness_checkins ADD COLUMN stress INTEGER',
        'ALTER TABLE wellness_checkins ADD COLUMN sleep_hours REAL',
        'ALTER TABLE wellness_checkins ADD COLUMN notes TEXT',
        'ALTER TABLE wellness_checkins ADD COLUMN updated_at INTEGER',
        'ALTER TABLE wellness_checkins ADD COLUMN created_at INTEGER',
      ]) {
        await _executeIgnoringDuplicateColumn(db, alter);
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wellness_owner_day '
        'ON wellness_checkins(owner_id, day DESC)',
      );
      return;
    }

    // Rebuild with copy + validation (missing required `day` or shape mismatch).
    await db.execute('DROP TABLE IF EXISTS wellness_checkins__migrating');
    await db.execute(
      'CREATE TABLE wellness_checkins__migrating (' + createBody + ')',
    );

    final oldRows = await db.query('wellness_checkins');
    var attempted = 0;
    for (final row in oldRows) {
      final ownerId = row['owner_id']?.toString();
      if (ownerId == null || ownerId.isEmpty) continue;
      final id = row['id']?.toString() ?? newId();
      late final int day;
      final dayVal = row['day'];
      final checkinDate = row['checkin_date'];
      if (dayVal is int) {
        day = dayVal;
      } else if (checkinDate is int) {
        day = checkinDate;
      } else {
        final created = (row['created_at'] as int?) ?? nowMs();
        final d = DateTime.fromMillisecondsSinceEpoch(created);
        day = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      }
      final createdAt = (row['created_at'] as int?) ?? day;
      final updatedAt = (row['updated_at'] as int?) ?? createdAt;
      attempted++;
      await db.insert(
        'wellness_checkins__migrating',
        {
          'id': id,
          'owner_id': ownerId,
          'day': day,
          'mood': row['mood'],
          'energy': row['energy'],
          'stress': row['stress'],
          'sleep_hours': row['sleep_hours'],
          'notes': row['notes'],
          'created_at': createdAt,
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final kept = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM wellness_checkins__migrating'),
        ) ??
        0;
    if (kept != attempted) {
      throw StateError(
        'wellness_checkins migration validation failed: '
        'attempted=$attempted kept=$kept',
      );
    }

    await db.execute('DROP TABLE wellness_checkins');
    await db.execute(
      'ALTER TABLE wellness_checkins__migrating RENAME TO wellness_checkins',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wellness_owner_day '
      'ON wellness_checkins(owner_id, day DESC)',
    );
  }

  Future<void> _ensureHealthMetricsTable(Database db) async {
    const createBody = '''
id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
''';
    if (!await _tableExists(db, 'health_metrics')) {
      await db.execute('CREATE TABLE health_metrics (' + createBody + ')');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_health_metrics_type '
        'ON health_metrics(owner_id, metric_type, measured_at DESC)',
      );
      return;
    }

    final cols = await _columnNames(db, 'health_metrics');
    if (cols.contains('metric_type') &&
        cols.contains('value') &&
        cols.contains('measured_at')) {
      for (final alter in [
        'ALTER TABLE health_metrics ADD COLUMN unit TEXT',
        'ALTER TABLE health_metrics ADD COLUMN notes TEXT',
        'ALTER TABLE health_metrics ADD COLUMN created_at INTEGER',
      ]) {
        await _executeIgnoringDuplicateColumn(db, alter);
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_health_metrics_type '
        'ON health_metrics(owner_id, metric_type, measured_at DESC)',
      );
      return;
    }

    await db.execute('DROP TABLE IF EXISTS health_metrics__migrating');
    await db.execute(
      'CREATE TABLE health_metrics__migrating (' + createBody + ')',
    );

    final oldRows = await db.query('health_metrics');
    var attempted = 0;
    for (final row in oldRows) {
      final ownerId = row['owner_id']?.toString();
      if (ownerId == null || ownerId.isEmpty) continue;
      final id = row['id']?.toString() ?? newId();
      final metricType = (row['metric_type'] ?? row['type'])?.toString();
      if (metricType == null || metricType.isEmpty) continue;
      final value = row['value'];
      if (value is! num) continue;
      final measuredAt = (row['measured_at'] as int?) ?? nowMs();
      final createdAt = (row['created_at'] as int?) ?? measuredAt;
      attempted++;
      await db.insert(
        'health_metrics__migrating',
        {
          'id': id,
          'owner_id': ownerId,
          'metric_type': metricType,
          'value': value.toDouble(),
          'unit': row['unit'],
          'measured_at': measuredAt,
          'notes': row['notes'],
          'created_at': createdAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final kept = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM health_metrics__migrating'),
        ) ??
        0;
    if (kept != attempted) {
      throw StateError(
        'health_metrics migration validation failed: '
        'attempted=$attempted kept=$kept',
      );
    }

    await db.execute('DROP TABLE health_metrics');
    await db.execute(
      'ALTER TABLE health_metrics__migrating RENAME TO health_metrics',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_health_metrics_type '
      'ON health_metrics(owner_id, metric_type, measured_at DESC)',
    );
  }

'''

V26 = r'''  Future<void> _migrateToV26(Database db) async {
    // Non-destructive: add columns or copy+validate before table replace.
    await _ensureWellnessCheckinsTable(db);
    await _ensureHealthMetricsTable(db);
  }
'''

V27 = r'''  Future<void> _migrateToV27(Database db) async {
    // Idempotent repair of wellness/health contract (same non-destructive path).
    await _ensureWellnessCheckinsTable(db);
    await _ensureHealthMetricsTable(db);
  }
'''


def show(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def replace_method(src: str, name: str, new_body: str) -> str:
    pattern = rf'  Future<void> {name}\(Database db\) async \{{.*?\n  \}}\n'
    m = re.search(pattern, src, flags=re.S)
    if not m:
        sys.exit(f'method {name} not found')
    return src[: m.start()] + new_body + src[m.end() :]


def main() -> None:
    path = 'apps/flutter/lib/data/database.dart'
    t = show(path)
    if 'migrateWellnessHealthNonDestructive' in t and 'DROP TABLE IF EXISTS wellness_checkins' not in t:
        print('already patched')
        return

    t = replace_method(t, '_migrateToV26', V26)
    t = replace_method(t, '_migrateToV27', V27)

    # Insert helpers before _executeIgnoringDuplicateColumn
    marker = '  Future<void> _executeIgnoringDuplicateColumn(Database db, String sql) async {'
    if marker not in t:
        sys.exit('executeIgnoring marker missing')
    if '_ensureWellnessCheckinsTable' not in t:
        t = t.replace(marker, HELPER + marker, 1)

    # Ensure ConflictAlgorithm / Sqflite imports via sqflite (already imported)
    Path(path).write_text(t)
    print('database.dart ok', 'DROP TABLE IF EXISTS wellness_checkins' in t)


if __name__ == '__main__':
    main()
