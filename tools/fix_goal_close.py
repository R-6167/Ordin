from pathlib import Path
p = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
t = p.read_text()
bad = '''    if (mounted) Navigator.pop(context);
  }

class _ProjectTreeCard extends StatelessWidget {
'''
good = '''    if (mounted) Navigator.pop(context);
  }
}

class _ProjectTreeCard extends StatelessWidget {
'''
if bad in t:
    p.write_text(t.replace(bad, good, 1))
    print('closed state')
elif good in t:
    print('already closed')
else:
    raise SystemExit('pattern not found')
