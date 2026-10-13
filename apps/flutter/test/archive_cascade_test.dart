import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/domain/archive_cascade.dart';
import 'package:ordin/domain/enums.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('goal archive parentOnly keeps project FK and hides goal from active',
      () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);

    final g = await goals.create(title: 'G');
    final p = await projects.create(title: 'P', goalId: g.id);

    await goals.archive(g.id, cascade: ArchiveCascade.parentOnly);

    final active = await goals.listActive();
    expect(active.any((x) => x.id == g.id), isFalse);

    final prow = await (await app.database).query(
      'projects',
      where: 'id = ?',
      whereArgs: [p.id],
      limit: 1,
    );
    expect(prow.first['goal_id'], g.id);
    expect(prow.first['archived_at'], isNull);
  });

  test('goal archive withProjects archives child projects', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);

    final g = await goals.create(title: 'G');
    final p = await projects.create(title: 'P', goalId: g.id);
    await goals.archive(g.id, cascade: ArchiveCascade.withProjects);

    final prow = await (await app.database).query(
      'projects',
      where: 'id = ?',
      whereArgs: [p.id],
      limit: 1,
    );
    expect(prow.first['archived_at'], isNotNull);
  });

  test('goal archive detachChildren clears FKs then archives goal', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final g = await goals.create(title: 'G');
    final p = await projects.create(title: 'P', goalId: g.id);
    final t = await tasks.create(title: 'Direct', goalId: g.id);

    await goals.archive(g.id, cascade: ArchiveCascade.detachChildren);

    final prow = await (await app.database).query(
      'projects',
      where: 'id = ?',
      whereArgs: [p.id],
      limit: 1,
    );
    expect(prow.first['goal_id'], isNull);
    expect(prow.first['archived_at'], isNull);

    final trow = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [t.id],
      limit: 1,
    );
    expect(trow.first['goal_id'], isNull);

    final grow = await (await app.database).query(
      'goals',
      where: 'id = ?',
      whereArgs: [g.id],
      limit: 1,
    );
    expect(grow.first['archived_at'], isNotNull);
  });

  test('project archive parentOnly hides tasks from listOpen', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p = await projects.create(title: 'P');
    final t = await tasks.create(title: 'T', projectId: p.id);

    expect((await tasks.listOpen()).any((x) => x.id == t.id), isTrue);

    await projects.archive(p.id, cascade: ArchiveCascade.parentOnly);

    expect((await tasks.listOpen()).any((x) => x.id == t.id), isFalse);

    final trow = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [t.id],
      limit: 1,
    );
    expect(trow.first['project_id'], p.id);
    expect(trow.first['archived_at'], isNull);
  });

  test('project archive detachChildren clears project/milestone on tasks',
      () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p = await projects.create(title: 'P');
    final t = await tasks.create(title: 'T', projectId: p.id);
    await projects.archive(p.id, cascade: ArchiveCascade.detachChildren);

    final trow = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [t.id],
      limit: 1,
    );
    expect(trow.first['project_id'], isNull);
    expect(trow.first['milestone_id'], isNull);
    expect((await tasks.listOpen()).any((x) => x.id == t.id), isTrue);
  });

  test('project archive withOpenTasks also archives legacy tasks with null status',
      () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p = await projects.create(title: 'P');
    final legacy = await tasks.create(title: 'Legacy status', projectId: p.id);
    await (await app.database).update(
      'tasks',
      {'status': null},
      where: 'id = ?',
      whereArgs: [legacy.id],
    );

    final impact = await projects.archiveImpact(p.id);
    expect(impact['openTasks'], 1);

    await projects.archive(p.id, cascade: ArchiveCascade.withOpenTasks);

    final row = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [legacy.id],
      limit: 1,
    );
    expect(row.first['archived_at'], isNotNull);
  });

  test('project archive withOpenTasks soft-archives open tasks', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p = await projects.create(title: 'P');
    final open = await tasks.create(title: 'Open', projectId: p.id);
    final done = await tasks.create(title: 'Done', projectId: p.id);
    await tasks.complete(done.id);

    await projects.archive(p.id, cascade: ArchiveCascade.withOpenTasks);

    final openRow = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [open.id],
      limit: 1,
    );
    expect(openRow.first['archived_at'], isNotNull);

    final doneRow = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [done.id],
      limit: 1,
    );
    expect(doneRow.first['archived_at'], isNull);
    expect(doneRow.first['status'], EntityStatus.completed);
  });
}
