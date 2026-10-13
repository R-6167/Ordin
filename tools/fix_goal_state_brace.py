from pathlib import Path

path = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
t = path.read_text()

# Premature class close after build() left _evidenceChip / _archiveGoal outside State.
bad = '''    );
  }
}


  Widget _evidenceChip(String label) {
'''
good = '''    );
  }

  Widget _evidenceChip(String label) {
'''

if bad not in t:
    if 'Widget _evidenceChip' in t and t.find('Widget _evidenceChip') < t.find('class _ProjectTreeCard'):
        # Check if already inside state: class close should be right before ProjectTreeCard
        idx = t.find('class _ProjectTreeCard')
        before = t[max(0, idx - 80):idx]
        if before.strip().endswith('}'):
            print('structure may already be ok', repr(before[-40:]))
        else:
            raise SystemExit('bad pattern missing')
    else:
        raise SystemExit('evidence chip missing')
else:
    t = t.replace(bad, good, 1)
    # Ensure State closes before ProjectTreeCard
    marker = '\nclass _ProjectTreeCard'
    if marker in t and '}\n' + marker not in t and '}\n\n' + marker.lstrip('\n') not in t:
        # after _archiveGoal should close state
        arch_end = t.find('  Future<void> _archiveGoal')
        if arch_end > 0:
            # find end of archive method
            end = t.find('\nclass _ProjectTreeCard')
            chunk = t[arch_end:end]
            if not chunk.rstrip().endswith('}'):
                raise SystemExit('archive method not closed')
            # if no class-closing brace between archive and ProjectTreeCard, add one
            after_arch = t[arch_end:end].rstrip()
            # method ends with }
            # need one more } for class
            lines = after_arch.splitlines()
            # count if we only have method close
            if lines[-1].strip() == '}' and (len(lines) < 2 or lines[-2].strip() != '}'):
                t = t[:end] + '}\n' + t[end:]
    path.write_text(t)
    print('fixed')

# verify
t = path.read_text()
state_start = t.find('class _GoalDetailScreenState')
evidence = t.find('Widget _evidenceChip')
archive = t.find('Future<void> _archiveGoal')
tree = t.find('class _ProjectTreeCard')
# State close is last } before ProjectTreeCard
print('order ok', state_start < evidence < archive < tree)
