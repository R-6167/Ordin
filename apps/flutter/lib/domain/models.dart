import 'db_map.dart';

class Goal {
  final String id;
  final String ownerId;
  final String title;
  final String status;
  final int priority;
  final String? lifeAreaId;
  final int createdAt;
  final int updatedAt;

  const Goal({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.priority = 0,
    this.lifeAreaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: dbStr(m['id']),
        ownerId: dbStr(m['owner_id']),
        title: dbStr(m['title']),
        status: dbStr(m['status'], 'ACTIVE'),
        priority: dbIntOr(m['priority']),
        lifeAreaId: dbStrOrNull(m['life_area_id']),
        createdAt: dbIntOr(m['created_at']),
        updatedAt: dbIntOr(m['updated_at']),
      );

  Map<String, Object?> toInsertMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'status': status,
        'life_area_id': lifeAreaId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

// SEE artifacts/models.dart for full file — do not use this stub
