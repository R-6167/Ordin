  Future<void> rename({required String id, required String title}) async {
    final clean = title.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Milestone title must not be empty.');
    }
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.query(
          'milestones',
          columns: ['id', 'project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Milestone not found or not owned: $id');
        }
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: rows.first['project_id'] as String,
        );
        final changed = await txn.update(
          'milestones',
          {'title': clean, 'updated_at': now},
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Milestone not found or not owned: $id');
        }
      },
      eventType: 'MILESTONE_UPDATED',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
    );
  }

  /// Re-open a completed milestone (status back to planned).
  Future<void> reopen(String id) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    await AtomicWrite.run(
      db: _db,
      state: (txn) async {
        final rows = await txn.query(
          'milestones',
          columns: ['id', 'project_id'],
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Milestone not found or not owned: $id');
        }
        await RelationshipValidator.validateProject(
          txn,
          ownerId: ownerId,
          projectId: rows.first['project_id'] as String,
        );
        final changed = await txn.update(
          'milestones',
          {
            'status': MilestoneStatus.planned,
            'completed_at': null,
            'updated_at': now,
          },
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, ownerId],
        );
        if (changed != 1) {
          throw StateError('Milestone not found or not owned: $id');
        }
      },
      eventType: 'MILESTONE_REOPENED',
      entityType: 'MILESTONE',
      entityId: id,
      occurredAt: now,
    );
  }
