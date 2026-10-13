"""Apply milestone UX."""
from pathlib import Path
import subprocess
import sys


def show(path: str) -> str:
    for ref in ('origin/main', 'main'):
        try:
            return subprocess.check_output(['git', 'show', f'{ref}:{path}'], text=True)
        except subprocess.CalledProcessError:
            continue
    subprocess.check_call(['git', 'fetch', 'origin', 'main', '--depth=1'])
    return subprocess.check_output(['git', 'show', f'origin/main:{path}'], text=True)


def main() -> None:
    path = 'apps/flutter/lib/data/milestone_repository.dart'
    t = show(path)
    if 'Future<void> rename' not in t:
        extra = Path('tools/milestone_repo_extra.dart').read_text()
        t = t.rstrip()
        if not t.endswith('}'):
            sys.exit('repo end')
        t = t[:-1] + '\n' + extra + '}\n'
        Path(path).write_text(t)
        print('repo ok')
    else:
        print('repo already')

    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = show(path)
    helpers = Path('tools/ms_helpers.dartfrag').read_text()
    section = Path('tools/ms_section.dartfrag').read_text()
    if '_renameMilestone' not in t:
        marker = '  List<Map<String, Object?>> _blockedOpen(ProjectWorkspace ws) {'
        if marker not in t:
            sys.exit('blockedOpen missing')
        t = t.replace(marker, helpers + marker, 1)
    if 'of $totalTasks tasks done' not in t:
        start = t.find('            // —— Milestones ——')
        end = t.find('            // —— Tasks + subtasks ——')
        if start < 0 or end < 0:
            sys.exit('section bounds')
        t = t[:start] + section + t[end:]
    Path(path).write_text(t)
    print('project ok', len(t))


if __name__ == '__main__':
    main()
