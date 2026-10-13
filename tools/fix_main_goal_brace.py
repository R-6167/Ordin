from pathlib import Path

p = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
t = p.read_text()

# 1) Remove premature State close after build()
bad1 = '''    );
  }
}


  Widget _evidenceChip(String label) {
'''
good1 = '''    );
  }

  Widget _evidenceChip(String label) {
'''
if bad1 in t:
    t = t.replace(bad1, good1, 1)
    print('removed premature close')
elif good1 in t:
    print('no premature close')
else:
    raise SystemExit('pattern1 not found')

# 2) Ensure State closes before ProjectTreeCard
bad2 = '''    if (mounted) Navigator.pop(context);
  }

class _ProjectTreeCard extends StatelessWidget {
'''
good2 = '''    if (mounted) Navigator.pop(context);
  }
}

class _ProjectTreeCard extends StatelessWidget {
'''
if bad2 in t:
    t = t.replace(bad2, good2, 1)
    print('added state close before ProjectTreeCard')
elif good2 in t:
    print('state already closed before ProjectTreeCard')
else:
    raise SystemExit('pattern2 not found')

p.write_text(t)

# Verify structure
t = p.read_text()
state = t.find('class _GoalDetailScreenState')
evidence = t.find('Widget _evidenceChip')
archive = t.find('Future<void> _archiveGoal')
tree = t.find('class _ProjectTreeCard')
assert state < evidence < archive < tree, (state, evidence, archive, tree)
# Between archive method end and tree there should be a class-closing brace
chunk = t[archive:tree]
assert chunk.rstrip().endswith('}'), 'missing method/class close'
print('structure ok')
