from pathlib import Path
import re
import sys

ARCHIVE_GOAL = r'''
  Future<void> _archiveGoal() async {
    final impact = await _goals.archiveImpact(widget.goalId);
    if (!mounted) return;
    final result = await showArchiveSheet(
      context: context,
      title: 'Archive this goal?',
      impact: {
        'projects': impact['projects'] ?? 0,
        'direct tasks': impact['directTasks'] ?? 0,
        'habits': impact['habits'] ?? 0,
      },
      options: const [
        (
          mode: ArchiveCascade.parentOnly,
          label: 'Archive goal only',
          subtitle: 'Projects and tasks keep their link; goal leaves active lists.',
        ),
        (
          mode: ArchiveCascade.withProjects,
          label: 'Archive goal and its projects',
          subtitle: 'Projects (and their boards) leave active lists with the goal.',
        ),
        (
          mode: ArchiveCascade.detachChildren,
          label: 'Detach children, then archive',
          subtitle: 'Projects, direct tasks, and habits become independent.',
        ),
      ],
    );
    if (result == null || !mounted) return;
    await _goals.archive(widget.goalId, cascade: result.cascade);
    AppDataBus.instance.lifeChanged();
    if (mounted) Navigator.pop(context);
  }
'''

ARCHIVE_PROJECT = r'''
  Future<void> _archiveProject() async {
    final impact = await _projects.archiveImpact(widget.projectId);
    if (!mounted) return;
    final result = await showArchiveSheet(
      context: context,
      title: 'Archive this project?',
      impact: {
        'open tasks': impact['openTasks'] ?? 0,
        'milestones': impact['milestones'] ?? 0,
      },
      options: const [
        (
          mode: ArchiveCascade.parentOnly,
          label: 'Archive project only',
          subtitle: 'Tasks stay linked but leave the main Tasks list.',
        ),
        (
          mode: ArchiveCascade.detachChildren,
          label: 'Detach tasks, then archive',
          subtitle: 'Open work becomes independent; project is archived.',
        ),
        (
          mode: ArchiveCascade.withOpenTasks,
          label: 'Archive project and open tasks',
          subtitle: 'Open tasks are soft-archived; completed history stays.',
        ),
      ],
    );
    if (result == null || !mounted) return;
    await _projects.archive(widget.projectId, cascade: result.cascade);
    AppDataBus.instance.lifeChanged();
    AppDataBus.instance.tasksChanged();
    if (mounted) Navigator.pop(context);
  }
'''


def strip_archive_methods(src: str, name: str) -> str:
    # Remove any existing Future<void> _archiveX blocks
    pattern = rf'\n  Future<void> {name}\(\) async \{{.*?\n  \}}\n'
    return re.sub(pattern, '\n', src, flags=re.S)


def fix_goal() -> None:
    path = Path('apps/flutter/lib/ui/screens/goal_detail_screen.dart')
    t = path.read_text()
    t = strip_archive_methods(t, '_archiveGoal')

    # Insert method at end of _GoalDetailScreenState, before its closing brace.
    # State class ends right before "class _ProjectTreeCard".
    marker = '\nclass _ProjectTreeCard'
    if marker not in t:
        sys.exit('ProjectTreeCard marker missing')
    # Find last method end of state class - insert before class _ProjectTreeCard
    t = t.replace(marker, '\n' + ARCHIVE_GOAL + marker, 1)
    path.write_text(t)
    print('goal fixed')


def fix_project() -> None:
    path = Path('apps/flutter/lib/ui/screens/project_detail_screen.dart')
    t = path.read_text()
    t = strip_archive_methods(t, '_archiveProject')

    # Method was wrongly nested inside build(). Ensure build closes cleanly,
    # then append method before final class closing.
    # After strip, append before last "\n}\n" of file (state class end).
    # Find: end of file should be "}\n}" for state + maybe nothing else

    # Prefer insert just before the final closing brace of the state class.
    # The state class is the last class in the file typically.
    # Append before the very last "}\n" that closes the state class.

    # If build lost a closing brace when method was inserted, restore common pattern:
    # Look for broken pattern after ActivityTimeline section without enough braces.
    if '_archiveProject' in t:
        print('still has archive?')

    # Insert before last single closing brace of the outermost state class.
    # File ends with: }\n}\n for nested widgets? Let's find class _ProjectDetailScreenState
    # and count - simpler: append method before the last line that is just "}"
    lines = t.rstrip().splitlines()
    # Remove trailing empty
    while lines and not lines[-1].strip():
        lines.pop()
    # Expect last line is "}" closing state class
    if lines[-1].strip() != '}':
        sys.exit(f'unexpected end: {lines[-1]!r}')
    # Insert method before final }
    body = '\n'.join(lines[:-1]) + '\n' + ARCHIVE_PROJECT + '}\n'
    path.write_text(body)
    print('project fixed')


def fix_sheet() -> None:
    path = Path('apps/flutter/lib/ui/widgets/archive_sheet.dart')
    t = path.read_text()
    t = t.replace('AppTheme.surface', 'AppTheme.metalDeep')
    path.write_text(t)
    print('sheet fixed')


def main() -> None:
    fix_sheet()
    fix_goal()
    fix_project()


if __name__ == '__main__':
    main()
