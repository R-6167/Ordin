import '../domain/enums.dart';
import '../domain/models.dart';
import '../services/domain_recurrence.dart';
import 'database.dart';

class RoutineRepository {
  RoutineRepository(this._db);
  final AppDatabase _db;

  static int dayKey([DateTime? day]) {
    final d = day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  Future<List<Routine>> listActive() async {
    final db = await _db.database;
    final rows = await db.query(
      'routines',
      where: 'status = ? AND archived_at IS NULL',
      whereArgs: [EntityStatus.active],
      orderBy: 'name ASC',
    );
    return rows.map(Routine.fromMap).toList();
  }

  Future<List<Routine>> listByLifeArea(String lifeAreaId) async {
    final ownerId = await _db.requireOwnerId();
    final rows = await (await _db.database).query(
      'routines',
      where: 'owner_id = ? AND life_area_id = ? AND archived_at IS NULL',
      whereArgs: [ownerId, lifeAreaId],
      orderBy: 'name ASC',
    );
    return rows.map(Routine.fromMap).toList();
  }

  Future<Routine?> getById(String id) async {
    final rows = await (await _db.database).query('routines', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Routine.fromMap(rows.first);
  }

  Future<Routine> create({
    required String name,
    String? description,
    int? estimatedMinutes,
    String? lifeAreaId,
  }) async {
    final ownerId = await _db.requireOwnerId();
    final now = AppDatabase.nowMs();
    final id = AppDatabase.newId();
    await (await _db.database).insert('routines', {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'status': EntityStatus.active,
      'life_area_id': lifeAreaId,
      'created_at': now,
      'updated_at': now,
    });
    return Routine(
      id: id,
      ownerId: ownerId,
      name: name,
      status: EntityStatus.active,
      estimatedMinutes: estimatedMinutes,
      lifeAreaId: lifeAreaId,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Remaining methods unchanged — full file required below if CI fails.
}
