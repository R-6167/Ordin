from pathlib import Path

g = Path('apps/flutter/lib/data/goal_repository.dart')
t = g.read_text()
old_g = """      where: 'owner_id = ? AND life_area_id = ? AND status != ?',
      whereArgs: [ownerId, lifeAreaId, 'COMPLETED'],"""
new_g = """      where: 'owner_id = ? AND life_area_id = ? AND status != ? AND archived_at IS NULL',
      whereArgs: [ownerId, lifeAreaId, 'COMPLETED'],"""
if old_g not in t:
    raise SystemExit('goal listByLifeArea pattern missing')
g.write_text(t.replace(old_g, new_g, 1))
print('goal ok')

p = Path('apps/flutter/lib/data/project_repository.dart')
t = p.read_text()
old_p = """      where: 'owner_id = ? AND life_area_id = ? AND status != ?',
      whereArgs: [ownerId, lifeAreaId, 'COMPLETED'],"""
new_p = """      where: 'owner_id = ? AND life_area_id = ? AND status != ? AND archived_at IS NULL',
      whereArgs: [ownerId, lifeAreaId, 'COMPLETED'],"""
if old_p not in t:
    raise SystemExit('project listByLifeArea pattern missing')
p.write_text(t.replace(old_p, new_p, 1))
print('project ok')
