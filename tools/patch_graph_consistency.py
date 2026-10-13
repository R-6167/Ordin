"""Patch task reassignment, dependency project match, project reopen."""
from pathlib import Path
import re
import sys


def patch_task_update(src: str) -> str:
    old = '''      final targetMilestoneId = clearMilestone
          ? null
          : (milestoneId ?? current['milestone_id'] as String?);

      await RelationshipValidator.validateTaskLinks(
        txn,
        ownerId: ownerId,
        projectId: targetProjectId,
        goalId: targetGoalId,
        milestoneId: targetMilestoneId,
        parentTaskId: current['parent_task_id'] as String?,
        taskId: id,
      );
      final changed = await txn.update(
        'tasks',
        patch,'''

    new = '''      var targetMilestoneId = clearMilestone
          ? null
          : (milestoneId ?? current['milestone_id'] as String?);
      var resolvedGoalId = targetGoalId;

      // Project reassignment: drop milestones that no longer belong, and align
      // goal to the project's goal so the graph stays connected.
      if (projectId != null) {
        if (targetProjectId == null) {
          if (targetMilestoneId != null && milestoneId == null && !clearMilestone) {
            targetMilestoneId = null;
            patch['milestone_id'] = null;
          }
        } else {
          if (targetMilestoneId != null && milestoneId == null && !clearMilestone) {
            final ms = await txn.query(
              'milestones',
              columns: ['id'],
              where: 'id = ? AND project_id = ? AND owner_id = ?',
              whereArgs: [targetMilestoneId, targetProjectId, ownerId],
              limit: 1,
            );
            if (ms.isEmpty) {
              targetMilestoneId = null;
              patch['milestone_id'] = null;
            }
          }
          if (goalId == null) {
            final prow = await txn.query(
              'projects',
              columns: ['goal_id'],
              where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
              whereArgs: [targetProjectId, ownerId],
              limit: 1,
            );
            if (prow.isNotEmpty) {
              final pg = prow.first['goal_id'] as String?;
              resolvedGoalId = (pg != null && pg.isNotEmpty) ? pg : null;
              patch['goal_id'] = resolvedGoalId;
            }
          }
        }
      }

      await RelationshipValidator.validateTaskLinks(
        txn,
        ownerId: ownerId,
        projectId: targetProjectId,
        goalId: resolvedGoalId,
        milestoneId: targetMilestoneId,
        parentTaskId: current['parent_task_id'] as String?,
        taskId: id,
      );
      final changed = await txn.update(
        'tasks',
        patch,'''

    if old not in src:
        if 'resolvedGoalId' in src:
            print('task update already patched')
            return src
        sys.exit('task update block not found')
    return src.replace(old, new, 1)


def patch_deps(src: str) -> str:
    needle = '''        if (await loadTask(dependsOnTaskId) == null) {
          throw StateError('Dependency target not found or not owned: $dependsOnTaskId');
        }

        final existing = await txn.query('''
    insert = '''        if (await loadTask(dependsOnTaskId) == null) {
          throw StateError('Dependency target not found or not owned: $dependsOnTaskId');
        }

        final left = await txn.query(
          'tasks',
          columns: ['project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [taskId, ownerId],
          limit: 1,
        );
        final right = await txn.query(
          'tasks',
          columns: ['project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [dependsOnTaskId, ownerId],
          limit: 1,
        );
        final leftProject = left.isEmpty ? null : left.first['project_id'] as String?;
        final rightProject = right.isEmpty ? null : right.first['project_id'] as String?;
        if (leftProject != rightProject) {
          throw StateError(
            'Dependencies must stay within the same project '
            '(task.project_id=$leftProject, depends_on.project_id=$rightProject).',
          );
        }

        final existing = await txn.query('''
    if 'Dependencies must stay within the same project' in src:
        print('deps already')
        return src
    if needle not in src:
        sys.exit('deps needle missing')
    return src.replace(needle, insert, 1)


def patch_project_reopen(src: str) -> str:
    if 'Future<void> reopen(' in src:
        print('reopen already')
        return src
    marker = '''      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }
}
'''
    addition = '''      eventType: 'PROJECT_COMPLETED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }

  /// Re-open a completed project (status back to active). Progress is still
  /// derived from child tasks/milestones — no fabricated completion counts.
  Future<void> reopen(String id) async {
    final now = AppDatabase.nowMs();
    final ownerId = await _db.requireOwnerId();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        await RelationshipValidator.validateProject(txn, ownerId: ownerId, projectId: id);
        final changed = await txn.update(
          'projects',
          {'status': EntityStatus.active, 'updated_at': now},
          where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Project not found or not owned by the current user: $id');
        }
      },
      eventType: 'PROJECT_REOPENED',
      entityType: 'PROJECT',
      entityId: id,
      occurredAt: now,
    );
  }
}
'''
    if marker not in src:
        sys.exit('project complete marker missing')
    return src.replace(marker, addition, 1)


def main() -> None:
    tr = Path('apps/flutter/lib/data/task_repository.dart')
    tr.write_text(patch_task_update(tr.read_text()))
    print('task_repository ok')

    dep = Path('apps/flutter/lib/data/task_dependency_mutations.dart')
    dep.write_text(patch_deps(dep.read_text()))
    print('deps ok')

    pr = Path('apps/flutter/lib/data/project_repository.dart')
    pr.write_text(patch_project_reopen(pr.read_text()))
    print('project ok')


if __name__ == '__main__':
    main()
