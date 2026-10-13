import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/domain/archive_cascade.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('listByLifeArea hides archived goals and restores after unarchive',
      () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final areaId = 'life-area-test-1';

    // Ensure life area row exists if schema requires it — create via raw if needed.
    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final existing = await db.query(
      'life_areas',
      where: 'id = ?',
      whereArgs: [areaId],
      limit: 1,
    );
    if (existing.isEmpty) {
      try {
        await db.insert('life_areas', {
          'id': areaId,
          'owner_id': ownerId,
          'title': 'Test Area',
          'created_at': AppDatabase.nowMs(),
          'updated_at': AppDatabase.nowMs(),
        });
      } catch (_) {
        // Schema may use different columns; fall through with create(lifeAreaId).
      }
    }

    final g = await goals.create(title: 'Area Goal', lifeAreaId: areaId);
    expect(
      (await goals.listByLifeArea(areaId)).any((x) => x.id == g.id),
      isTrue,
    );

    await goals.archive(g.id, cascade: ArchiveCascade.parentOnly);
    expect(
      (await goals.listByLifeArea(areaId)).any((x) => x.id == g.id),
      isFalse,
    );

    await goals.unarchive(g.id);
    expect(
      (await goals.listByLifeArea(areaId)).any((x) => x.id == g.id),
      isTrue,
    );
  });

  test('listByLifeArea hides archived projects and restores after unarchive',
      () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final areaId = 'life-area-test-2';

    final db = await app.database;
    final ownerId = await app.requireOwnerId();
    final existing = await db.query(
      'life_areas',
      where: 'id = ?',
      whereArgs: [areaId],
      limit: 1,
    );
    if (existing.isEmpty) {
      try {
        await db.insert('life_areas', {
          'id': areaId,
          'owner_id': ownerId,
          'title': 'Test Area 2',
          'created_at': AppDatabase.nowMs(),
          'updated_at': AppDatabase.nowMs(),
        });
      } catch (_) {}
    }

    final p = await projects.create(title: 'Area Project', lifeAreaId: areaId);
    expect(
      (await projects.listByLifeArea(areaId)).any((x) => x.id == p.id),
      isTrue,
    );

    await projects.archive(p.id, cascade: ArchiveCascade.parentOnly);
    expect(
      (await projects.listByLifeArea(areaId)).any((x) => x.id == p.id),
      isFalse,
    );

    await projects.unarchive(p.id);
    expect(
      (await projects.listByLifeArea(areaId)).any((x) => x.id == p.id),
      isTrue,
    );
  });
}
