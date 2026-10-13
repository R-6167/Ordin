import 'package:sqflite/sqflite.dart';

/// Validates cross-entity references before a write is committed.
///
/// Keep these checks at repository transaction boundaries so invalid links
/// cannot be persisted by UI or assistant callers.
///
/// Relationships are treated as a **connected graph**, not independent FKs:
/// project ⊆ goal, milestone ⊆ project, parent task ⊆ same project (and goal
/// when both sides declare one).
class RelationshipValidator {
  RelationshipValidator._();

  static Future<void> validateGoal(
    Transaction txn, {
    required String ownerId,
    required String goalId,
  }) async {
    final rows = await txn.query(
      'goals',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [goalId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Goal not found, archived, or not owned by the current user.');
    }
  }

  static Future<void> validateProject(
    Transaction txn, {
    required String ownerId,
    required String projectId,
  }) async {
    final rows = await txn.query(
      'projects',
      columns: ['id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [projectId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Project not found, archived, or not owned by the current user.');
    }
  }

  /// Returns the project's `goal_id` (nullable) after ownership checks.
  static Future<String?> _projectGoalId(
    Transaction txn, {
    required String ownerId,
    required String projectId,
  }) async {
    final rows = await txn.query(
      'projects',
      columns: ['id', 'goal_id'],
      where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
      whereArgs: [projectId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Project not found, archived, or not owned by the current user.');
    }
    final g = rows.first['goal_id'];
    return g is String && g.isNotEmpty ? g : null;
  }

  /// Ensures [projectId] is owned and, when [goalId] is set, belongs to that goal.
  static Future<void> validateProjectUnderGoal(
    Transaction txn, {
    required String ownerId,
    required String projectId,
    required String goalId,
  }) async {
    final projectGoalId = await _projectGoalId(
      txn,
      ownerId: ownerId,
      projectId: projectId,
    );
    if (projectGoalId != goalId) {
      throw StateError(
        'Project does not belong to the given goal '
        '(project.goal_id=$projectGoalId, task.goal_id=$goalId).',
      );
    }
  }

  static Future<void> validateTaskLinks(
    Transaction txn, {
    required String ownerId,
    String? projectId,
    String? goalId,
    String? milestoneId,
    String? parentTaskId,
    String? taskId,
  }) async {
    // Normalize empty strings to null.
    final pId = (projectId == null || projectId.isEmpty) ? null : projectId;
    final gId = (goalId == null || goalId.isEmpty) ? null : goalId;
    final mId = (milestoneId == null || milestoneId.isEmpty) ? null : milestoneId;
    final parentId =
        (parentTaskId == null || parentTaskId.isEmpty) ? null : parentTaskId;

    if (gId != null) {
      await validateGoal(txn, ownerId: ownerId, goalId: gId);
    }

    String? projectGoalId;
    if (pId != null) {
      projectGoalId = await _projectGoalId(
        txn,
        ownerId: ownerId,
        projectId: pId,
      );

      // Connected graph: task goal and project goal must agree when both present.
      if (gId != null && projectGoalId != gId) {
        throw StateError(
          'Task goal must match the project goal '
          '(project.goal_id=$projectGoalId, task.goal_id=$gId).',
        );
      }
    }

    if (mId != null) {
      if (pId == null) {
        throw StateError('A task milestone requires a project.');
      }
      final rows = await txn.query(
        'milestones',
        columns: ['id', 'project_id'],
        where: 'id = ? AND project_id = ? AND owner_id = ?',
        whereArgs: [mId, pId, ownerId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError(
          'The milestone must belong to the task project and current owner.',
        );
      }
      // Milestone ⊆ project already; project ⊆ goal enforced above when gId set.
    }

    if (parentId != null) {
      if (taskId != null && parentId == taskId) {
        throw StateError('A task cannot be its own parent.');
      }
      final rows = await txn.query(
        'tasks',
        columns: ['id', 'project_id', 'goal_id'],
        where: 'id = ? AND owner_id = ? AND archived_at IS NULL',
        whereArgs: [parentId, ownerId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError(
          'Parent task not found, archived, or not owned by the current user.',
        );
      }
      final parentProjectId = rows.first['project_id'] as String?;
      if (parentProjectId != pId) {
        throw StateError('Parent and child tasks must belong to the same project.');
      }
      final parentGoal = rows.first['goal_id'] as String?;
      final parentGoalId =
          (parentGoal != null && parentGoal.isNotEmpty) ? parentGoal : null;
      // When both declare a goal, they must match (avoids split goal views).
      if (gId != null && parentGoalId != null && parentGoalId != gId) {
        throw StateError(
          'Parent and child tasks must belong to the same goal '
          '(parent.goal_id=$parentGoalId, child.goal_id=$gId).',
        );
      }
    }
  }
}
