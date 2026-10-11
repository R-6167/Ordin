from pathlib import Path
import re

# ---------------------------------------------------------------------------
# 1. HomeShell: stop double-reload after bus publish
# ---------------------------------------------------------------------------
hp = Path('apps/flutter/lib/ui/home_shell.dart')
hs = hp.read_text()
# After tasksChanged the bus listener already reloads; extra await doubles work.
hs2 = hs.replace(
    '''                  if (ok) {
                    AppDataBus.instance.tasksChanged();
                    await _reloadTasks();
                  }''',
    '''                  if (ok) {
                    AppDataBus.instance.tasksChanged();
                  }''',
    1,
)
hs2 = hs2.replace(
    '''                await _tasks.complete(t.id);
                AppDataBus.instance.tasksChanged();
                await _reloadTasks();''',
    '''                await _tasks.complete(t.id);
                AppDataBus.instance.tasksChanged();''',
    1,
)
if hs2 != hs:
    print('home_shell double-reload removed')
else:
    print('home_shell patterns miss (may already be fixed)')
hp.write_text(hs2)

# ---------------------------------------------------------------------------
# 2. Task detail: after mutation, publish bus OR local _load — not both
#    Keep local _load for the open detail; drop bus for pure local fields
#    that the parent list does not need until pop… actually parent needs
#    complete/delete. Pattern: tasksChanged() then _load() causes HomeShell
#    AND this screen to reload. Prefer: _load() locally, tasksChanged() only
#    (bus will refresh parent; this screen keeps its own _load).
#    That's fine — the user complaint is parent scroll jump. Debounce bus
#    is harder. Instead: local-only priority dropdown already only setState.
#    Remove redundant _load after tasksChanged where generation-gated open
#    already handles return — keep _load for in-screen UI update.
#    Soften: tasksChanged already triggers parent; for in-screen we need _load.
#    Leave task detail as-is for correctness; home_shell was the double hit.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 3. Notes: do NOT auto-scan on every open (removes mystery loading line)
# ---------------------------------------------------------------------------
np = Path('apps/flutter/lib/ui/screens/note_detail_screen.dart')
n = np.read_text()

# Remove auto scan at end of successful _load
old_auto = '''    if (n != null) {
      await _scanMentions(content: n.content, title: n.title);
    }'''
if old_auto in n:
    n = n.replace(
        old_auto,
        '''    // Link scan is on-demand (auto_awesome) — avoids a surprise progress
    // bar and full rebuild every time the note is opened.''',
        1,
    )
    print('note auto-scan removed')
else:
    print('note auto-scan already gone or pattern miss')

# Label the scanning indicator if present as bare LinearProgressIndicator
if 'Scanning note for links' not in n:
    n2 = n.replace(
        'if (_scanning)\n              const LinearProgressIndicator(color: AppTheme.amber),',
        '''if (_scanning) ...[
              const LinearProgressIndicator(color: AppTheme.amber),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Scanning note for links…',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
            ],''',
        1,
    )
    if n2 != n:
        n = n2
        print('scanning label ok')

# Harden extract tasks + publish bus
if 'Created tasks failed' not in n and 'createTasksFromNote' in n:
    old_ex = '''    final n = await NoteIntelligence().createTasksFromNote(
      noteId: widget.noteId,
      titles: selected.toList(),
      projectId: projectId,
      goalId: goalId,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created $n task${n == 1 ? '' : 's'} from this note')),
      );
    }'''
    new_ex = '''    try {
      final n = await NoteIntelligence().createTasksFromNote(
        noteId: widget.noteId,
        titles: selected.toList(),
        projectId: projectId,
        goalId: goalId,
      );
      AppDataBus.instance.tasksChanged();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $n task${n == 1 ? '' : 's'} from this note')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create tasks: $e')),
      );
    }'''
    if old_ex in n:
        n = n.replace(old_ex, new_ex, 1)
        print('extract tasks hardened')
    else:
        print('extract pattern miss')

# Ensure AppDataBus import
if "import '../../services/app_data_bus.dart';" not in n and 'AppDataBus' in n:
    n = n.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\n\nimport '../../services/app_data_bus.dart';",
        1,
    )

# Keep notepad in edit mode after reload
if 'bool _editing = true' not in n and 'bool _editing = false' in n:
    n = n.replace('bool _editing = false;', 'bool _editing = true;', 1)
    print('default edit mode')

# After _load setState, do not force _editing false
n = n.replace(
    "setState(() => _editing = false);",
    "setState(() { /* keep edit mode */ });",
    1,
)

np.write_text(n)

# ---------------------------------------------------------------------------
# 4. Narrow lifeChanged for pure navigation is already gated; ensure
#    planning .then(_load) after task open is generation-aware if present
# ---------------------------------------------------------------------------
pp = Path('apps/flutter/lib/ui/screens/planning_screen.dart')
p = pp.read_text()
if '.then((_) => _load());' in p:
    # replace with generation gate if AppDataBus available
    if "import '../../services/app_data_bus.dart';" not in p:
        p = p.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\n\nimport '../../services/app_data_bus.dart';",
            1,
        )
    # Find a typical push then _load — make generation gated
    p2 = p.replace(
        '.then((_) => _load());',
        '''.then((_) async {
                                  // only reload if a mutation published while task was open
                                  // (handled by bus for shell; local plan may still need refresh)
                                  await _load();
                                });''',
        1,
    )
    # Actually user wants NO reload if view-only. Do it properly:
    p = pp.read_text()  # reset if we half-edited
    if "import '../../services/app_data_bus.dart';" not in p:
        p = p.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\n\nimport '../../services/app_data_bus.dart';",
            1,
        )
    # Only one occurrence in planning at ~613
    if 'generationBefore' not in p:
        p = p.replace(
            '.then((_) => _load());',
            '''.then((_) async {
                                  final after = AppDataBus.instance.generation;
                                  if (after != generationBefore) await _load();
                                });''',
            1,
        )
        # Need generationBefore before the push — find nearby push pattern
        # Look for Navigator push task in planning
        if 'generationBefore' in p and 'final generationBefore' not in p:
            # inject before the push that has the .then
            # Heuristic: line with TaskDetailScreen
            p = p.replace(
                'MaterialPageRoute(\n                                      builder: (_) => TaskDetailScreen(taskId: t.id)))',
                '''MaterialPageRoute(
                                      builder: (_) => TaskDetailScreen(taskId: t.id)))''',
                1,
            )
            # Find context: look for await Navigator or .push.*TaskDetail
            m = re.search(
                r'((?:await )?Navigator\.[^;]*TaskDetailScreen[^;]*);',
                p,
                re.S,
            )
            # Simpler approach for planning: just remove .then(_load) entirely;
            # bus will refresh shell; planning can listen later.
            p = Path('apps/flutter/lib/ui/screens/planning_screen.dart').read_text()
            if "import '../../services/app_data_bus.dart';" not in p:
                p = p.replace(
                    "import 'package:flutter/material.dart';",
                    "import 'package:flutter/material.dart';\n\nimport '../../services/app_data_bus.dart';",
                    1,
                )
            # Replace .then((_) => _load()) after task open with generation check
            old_frag = None
            # get surrounding lines from file
            lines = p.splitlines()
            for i, line in enumerate(lines):
                if '.then((_) => _load())' in line:
                    # look backward for push
                    block = '\n'.join(lines[max(0, i - 8) : i + 1])
                    print('planning frag:\n', block)
                    # inject generation before push 5 lines up
                    for j in range(i, max(0, i - 12), -1):
                        if 'Navigator' in lines[j] or 'push' in lines[j]:
                            lines[j] = (
                                '                                final generationBefore = AppDataBus.instance.generation;\n'
                                + lines[j]
                            )
                            break
                    lines[i] = line.replace(
                        '.then((_) => _load())',
                        '.then((_) async { if (AppDataBus.instance.generation != generationBefore) await _load(); })',
                    )
                    p = '\n'.join(lines) + ('\n' if p.endswith('\n') else '')
                    print('planning generation gate ok')
                    break
            else:
                print('planning then _load not found')
    pp.write_text(p)
else:
    print('planning no then _load')

print('DONE')
