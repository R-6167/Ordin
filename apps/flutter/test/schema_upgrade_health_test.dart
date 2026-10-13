import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Simulates an older install where wellness/health tables lack the current
/// contract columns, then runs the non-destructive migration and asserts
/// that rows survive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('health + wellness rows survive non-destructive schema migration', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, _) async {
        await d.execute('''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  name TEXT,
  currency TEXT,
  week_start_day INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
        // Legacy wellness: no `day` column (pre-v26 contract).
        await d.execute('''
CREATE TABLE wellness_checkins (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  mood INTEGER,
  energy INTEGER,
  stress INTEGER,
  sleep_hours REAL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)''');
        // Legacy health_metrics: `type` instead of `metric_type`.
        await d.execute('''
CREATE TABLE health_metrics (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT,
  measured_at INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
)''');
      },
    );

    const ownerId = 'owner-health-upgrade';
    final now = DateTime(2026, 3, 15, 10, 30).millisecondsSinceEpoch;
    final dayStart = DateTime(2026, 3, 15).millisecondsSinceEpoch;

    await db.insert('users', {
      'id': ownerId,
      'display_name': 'Me',
      'name': 'Me',
      'currency': 'USD',
      'week_start_day': 1,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('wellness_checkins', {
      'id': 'wc-1',
      'owner_id': ownerId,
      'mood': 4,
      'energy': 3,
      'stress': 2,
      'sleep_hours': 7.5,
      'notes': 'legacy checkin',
      'created_at': now,
    });

    await db.insert('health_metrics', {
      'id': 'hm-1',
      'owner_id': ownerId,
      'type': 'WEIGHT',
      'value': 72.4,
      'unit': 'kg',
      'measured_at': now,
      'notes': 'morning',
      'created_at': now,
    });
    await db.insert('health_metrics', {
      'id': 'hm-2',
      'owner_id': ownerId,
      'type': 'STEPS',
      'value': 8500,
      'unit': 'count',
      'measured_at': now,
      'notes': null,
      'created_at': now,
    });

    // Apply non-destructive migration (same path as v26/v27).
    await AppDatabase.migrateWellnessHealthNonDestructive(db);

    // Schema contract
    final wellnessCols = (await db.rawQuery('PRAGMA table_info(wellness_checkins)'))
        .map((r) => r['name'] as String)
        .toSet();
    expect(wellnessCols.contains('day'), isTrue);

    final healthCols = (await db.rawQuery('PRAGMA table_info(health_metrics)'))
        .map((r) => r['name'] as String)
        .toSet();
    expect(healthCols.contains('metric_type'), isTrue);
    expect(healthCols.contains('type'), isFalse);

    // Data survived
    final checkins = await db.query('wellness_checkins');
    expect(checkins, hasLength(1));
    expect(checkins.first['id'], 'wc-1');
    expect(checkins.first['mood'], 4);
    expect(checkins.first['energy'], 3);
    expect(checkins.first['notes'], 'legacy checkin');
    expect(checkins.first['day'], dayStart);

    final metrics = await db.query('health_metrics', orderBy: 'id ASC');
    expect(metrics, hasLength(2));
    final weight = metrics.firstWhere((m) => m['id'] == 'hm-1');
    expect(weight['metric_type'], 'WEIGHT');
    expect(weight['value'], 72.4);
    expect(weight['unit'], 'kg');
    expect(weight['notes'], 'morning');

    final steps = metrics.firstWhere((m) => m['id'] == 'hm-2');
    expect(steps['metric_type'], 'STEPS');
    expect(steps['value'], 8500);

    // Idempotent: second pass must not drop or duplicate
    await AppDatabase.migrateWellnessHealthNonDestructive(db);
    expect(await db.query('wellness_checkins'), hasLength(1));
    expect(await db.query('health_metrics'), hasLength(2));

    await db.close();
  });
}
