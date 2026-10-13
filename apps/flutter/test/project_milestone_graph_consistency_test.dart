import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/services/progress_calculator.dart';
import 'package:ordin/services/project_workspace.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('reassigning task project clears foreign milestone and aligns goal',
      () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final milestones = MilestoneRepository(app);
    final tasks = TaskRepository(app);

    final goalA = await goals.create(title: 'Goal A');
    final goalB = await goals.create(title: 'Goal B');
    final projectA =
        await projects.create(title: 'Project A', goalId: goalA.id);
    final projectB =
        await projects.create(title: 'Project B', goalId: goalB.id);
    final msA =
        await milestones.create(projectId: projectA.id, title: 'MS A');

    final task = await tasks.create(
      title: 'Move me',
      projectId: projectA.id,
      goalId: goalA.id,
      milestoneId: msA.id,
    );

    // Reassign project only — must not keep MS A or goal A.
    await tasks.update(id: task.id, projectId: projectB.id);

    final rows = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [task.id],
      limit: 1,
    );
    expect(rows.first['project_id'], projectB.id);
    expect(rows.first['goal_id'], goalB.id);
    expect(rows.first['milestone_id'], isNull);
  });

  test('dependency cannot link tasks from different projects', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p1 = await projects.create(title: 'P1');
    final p2 = await projects.create(title: 'P2');
    final t1 = await tasks.create(title: 'T1', projectId: p1.id);
    final t2 = await tasks.create(title: 'T2', projectId: p2.id);

    await expectLater(
      tasks.addDependency(taskId: t1.id, dependsOnTaskId: t2.id),
      throwsA(isA<StateError>()),
    );
  });

  test('progress ignores cancelled tasks consistently', () async {
    final app = AppDatabase.instance;
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final p = await projects.create(title: 'Progress');
    final open = await tasks.create(title: 'Open', projectId: p.id);
    final done = await tasks.create(title: 'Done', projectId: p.id);
    final cancel = await tasks.create(title: 'Cancel', projectId: p.id);
    await tasks.complete(done.id);
    await tasks.update(id: cancel.id, status: 'CANCELLED');

    final prog = await projects.progress(p.id);
    expect(prog['tasksTotal'], 2); // cancelled excluded
    expect(prog['tasksDone'], 1);

    final ws = await ProjectWorkspaceService(app).load(p.id);
    expect(ws.tasksTotal, 2);
    expect(ws.tasksDone, 1);
    expect(
      ProgressCalculator.completionRatio(
        done: ws.tasksDone,
        total: ws.tasksTotal,
      ),
      ProgressCalculator.completionRatio(
        done: prog['tasksDone']!,
        total: prog['tasksTotal']!,
      ),
    );

    // reopen project after complete — progress still derived from tasks
    await projects.complete(p.id);
    await projects.reopen(p.id);
    final again = await projects.progress(p.id);
    expect(again['tasksDone'], 1);
    expect(again['tasksTotal'], 2);
    expect(open.id, isNotEmpty);
  });
}
