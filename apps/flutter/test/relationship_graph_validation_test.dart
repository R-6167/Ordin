import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';

import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('task cannot link project under goal A with goal B', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final goalA = await goals.create(title: 'Goal A');
    final goalB = await goals.create(title: 'Goal B');
    final projectA = await projects.create(title: 'Project A', goalId: goalA.id);

    await expectLater(
      tasks.create(
        title: 'Cross-linked task',
        projectId: projectA.id,
        goalId: goalB.id,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('task can link project and matching goal', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final goalA = await goals.create(title: 'Goal A');
    final projectA = await projects.create(title: 'Project A', goalId: goalA.id);

    final task = await tasks.create(
      title: 'Aligned task',
      projectId: projectA.id,
      goalId: goalA.id,
    );
    expect(task.projectId, projectA.id);
    expect(task.goalId, goalA.id);
  });

  test('reassigning task project rejects stale goal', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final tasks = TaskRepository(app);

    final goalA = await goals.create(title: 'Goal A');
    final goalB = await goals.create(title: 'Goal B');
    final projectA = await projects.create(title: 'Project A', goalId: goalA.id);
    final projectB = await projects.create(title: 'Project B', goalId: goalB.id);

    final task = await tasks.create(
      title: 'Move me',
      projectId: projectA.id,
      goalId: goalA.id,
    );

    // Reassign project to B while leaving goal A → inconsistent graph.
    await expectLater(
      tasks.update(id: task.id, projectId: projectB.id),
      throwsA(isA<StateError>()),
    );

    // Explicit aligned reassignment succeeds.
    await tasks.update(
      id: task.id,
      projectId: projectB.id,
      goalId: goalB.id,
    );
    final rows = await (await app.database).query(
      'tasks',
      where: 'id = ?',
      whereArgs: [task.id],
      limit: 1,
    );
    expect(rows.first['project_id'], projectB.id);
    expect(rows.first['goal_id'], goalB.id);
  });

  test('milestone must stay under task project (and goal when set)', () async {
    final app = AppDatabase.instance;
    final goals = GoalRepository(app);
    final projects = ProjectRepository(app);
    final milestones = MilestoneRepository(app);
    final tasks = TaskRepository(app);

    final goalA = await goals.create(title: 'Goal A');
    final goalB = await goals.create(title: 'Goal B');
    final projectA = await projects.create(title: 'Project A', goalId: goalA.id);
    final projectB = await projects.create(title: 'Project B', goalId: goalB.id);
    final msB = await milestones.create(projectId: projectB.id, title: 'MS B');

    await expectLater(
      tasks.create(
        title: 'Bad milestone',
        projectId: projectA.id,
        goalId: goalA.id,
        milestoneId: msB.id,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
