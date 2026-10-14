import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/data/database.dart';
import 'package:ordin/data/goal_repository.dart';
import 'package:ordin/data/milestone_repository.dart';
import 'package:ordin/data/project_repository.dart';
import 'package:ordin/data/task_repository.dart';
import 'package:ordin/services/project_workspace.dart';
import 'package:ordin/domain/enums.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase appDb;

  setUp(() async {
    appDb = await openTestDb();
  });

  tearDown(() async {
    await closeTestDb();
  });

  test('goal → project → milestone → task links survive edit and lifecycle changes',
      () async {
    final goals = GoalRepository(appDb);
    final projects = ProjectRepository(appDb);
    final milestones = MilestoneRepository(appDb);
    final tasks = TaskRepository(appDb);
    final db = await appDb.database;

    final goal = await goals.create(title: 'Ship personal-life OS');
    final project = await projects.create(
      title: 'Workspace integration',
      goalId: goal.id,
    );
    final milestone = await milestones.create(
      projectId: project.id,
      title: 'Relationship audit',
    );
    final task = await tasks.create(
      title: 'Verify linked views',
      description: 'Initial description',
      goalId: goal.id,
      projectId: project.id,
      milestoneId: milestone.id,
    );

    expect((await projects.listByGoal(goal.id)).map((p) => p.id),
        contains(project.id));
    expect((await tasks.listByProject(project.id)).map((t) => t.id),
        contains(task.id));
    expect((await tasks.listByGoal(goal.id)).map((t) => t.id),
        contains(task.id));
    expect((await milestones.listForProject(project.id)).map((m) => m.id),
        contains(milestone.id));

    // Exercise the aggregate read used when opening Project Details.
    final workspace = await ProjectWorkspaceService(appDb).load(project.id);
    expect(workspace.goal?['id'], goal.id);
    expect(workspace.milestones.map((m) => m['id']), contains(milestone.id));
    expect(workspace.tasks.map((t) => t['id']), contains(task.id));
    expect(workspace.tasksTotal, 1);
    expect(workspace.milestonesTotal, 1);

    await tasks.update(
      id: task.id,
      title: 'Verify linked views end-to-end',
      description: 'Edited and persisted',
    );
    final edited = await tasks.getById(task.id);
    expect(edited?.title, 'Verify linked views end-to-end');
    expect(await tasks.descriptionOf(task.id), 'Edited and persisted');

    await tasks.complete(task.id);
    final completed = await tasks.getById(task.id);
    expect(completed?.status, EntityStatus.completed);
    final progress = await projects.progress(project.id);
    expect(progress['tasksTotal'], 1);
    expect(progress['tasksDone'], 1);

    await tasks.reopen(task.id);
    final reopened = await tasks.getById(task.id);
    expect(reopened?.status, EntityStatus.inbox);
    expect(reopened?.projectId, project.id);
    expect(reopened?.goalId, goal.id);

    await milestones.complete(milestone.id);
    var milestoneRow = (await db.query(
      'milestones',
      where: 'id = ?',
      whereArgs: [milestone.id],
    )).single;
    expect(milestoneRow['status'], MilestoneStatus.completed);
    expect(milestoneRow['completed_at'], isNotNull);

    await milestones.reopen(milestone.id);
    milestoneRow = (await db.query(
      'milestones',
      where: 'id = ?',
      whereArgs: [milestone.id],
    )).single;
    expect(milestoneRow['status'], MilestoneStatus.planned);
    expect(milestoneRow['completed_at'], isNull);

    final goalProgress = await goals.progress(goal.id);
    expect(goalProgress['projectsTotal'], 1);
    expect(goalProgress['tasksTotal'], 1);
  });

  test('task relationship validator rejects a milestone from another project',
      () async {
    final goals = GoalRepository(appDb);
    final projects = ProjectRepository(appDb);
    final milestones = MilestoneRepository(appDb);
    final tasks = TaskRepository(appDb);

    final goal = await goals.create(title: 'Keep graph consistent');
    final firstProject = await projects.create(
      title: 'First project',
      goalId: goal.id,
    );
    final secondProject = await projects.create(
      title: 'Second project',
      goalId: goal.id,
    );
    final foreignMilestone = await milestones.create(
      projectId: secondProject.id,
      title: 'Foreign milestone',
    );

    await expectLater(
      tasks.create(
        title: 'Invalid relationship',
        goalId: goal.id,
        projectId: firstProject.id,
        milestoneId: foreignMilestone.id,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await tasks.listByProject(firstProject.id), isEmpty);
  });
}
