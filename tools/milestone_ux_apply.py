"""Milestone UX: rename/reopen API + project stage polish."""
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


def patch_repo() -> None:
    path = 'apps/flutter/lib/data/milestone_repository.dart'
    t = show(path)
    if 'Future<void> rename' in t:
        print('repo already')
        return
    extra = Path('tools/milestone_repo_extra.dart').read_text()
    t = t.rstrip()
    if not t.endswith('}'):
        sys.exit('repo end')
    Path(path).write_text(t[:-1] + '\n' + extra + '}\n')
    print('repo ok')


def patch_project() -> None:
    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = show(path)

    helpers = Path('tools/ms_helpers.dartfrag').read_text()
    if '_renameMilestone' not in t:
        marker = '  List<Map<String, Object?>> _blockedOpen(ProjectWorkspace ws) {'
        if marker not in t:
            sys.exit('blockedOpen missing')
        t = t.replace(marker, helpers + marker, 1)

    t = t.replace(
        "Text('Stages toward finishing this project.',\n"
        "                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))",
        "Text(\n"
        "                  'Break the project into stages. Add a milestone, then attach tasks to it.',\n"
        "                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),\n"
        "                )",
    )

    # Enhance subtitle to show task progress when possible
    old_sub = (
        "                        subtitle: Text(dbStr(m['status']),\n"
        "                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),"
    )
    new_sub = (
        "                        subtitle: Builder(builder: (_) {\n"
        "                          final mid = dbStr(m['id']);\n"
        "                          final msTasks = [\n"
        "                            ...ws.tasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),\n"
        "                            ...ws.subtasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),\n"
        "                          ];\n"
        "                          final doneN = msTasks\n"
        "                              .where((x) => dbStr(x['status']).toUpperCase() == 'COMPLETED')\n"
        "                              .length;\n"
        "                          final status = dbStr(m['status']);\n"
        "                          final progress = msTasks.isEmpty\n"
        "                              ? status\n"
        "                              : '$status · $doneN/${msTasks.length} tasks';\n"
        "                          return Text(\n"
        "                            progress,\n"
        "                            style: TextStyle(\n"
        "                                color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),\n"
        "                          );\n"
        "                        }),"
    )
    if old_sub in t:
        t = t.replace(old_sub, new_sub, 1)
        print('subtitle progress')

    # Add rename + reopen to trailing actions before complete flag
    old_complete = (
        "                            if (dbStr(m['status']) != 'COMPLETED')\n"
        "                              IconButton(\n"
        "                                tooltip: 'Complete milestone',\n"
        "                                icon: const Icon(Icons.flag, color: AppTheme.amber),\n"
        "                                onPressed: () async {\n"
        "                                  await _milestonesRepo.complete(dbStr(m['id']));\n"
        "                                  await _load();\n"
        "                                },\n"
        "                              )\n"
        "                            else\n"
        "                              const Icon(Icons.flag, color: AppTheme.amber),"
    )
    new_complete = (
        "                            IconButton(\n"
        "                              tooltip: 'Rename',\n"
        "                              icon: const Icon(Icons.edit_outlined, color: AppTheme.silverMuted, size: 18),\n"
        "                              onPressed: () => _renameMilestone(m),\n"
        "                            ),\n"
        "                            IconButton(\n"
        "                              tooltip: dbStr(m['status']) == 'COMPLETED' ? 'Reopen' : 'Complete milestone',\n"
        "                              icon: Icon(\n"
        "                                dbStr(m['status']) == 'COMPLETED' ? Icons.flag : Icons.flag_outlined,\n"
        "                                color: AppTheme.amber,\n"
        "                              ),\n"
        "                              onPressed: () => _toggleMilestoneComplete(m),\n"
        "                            ),"
    )
    if old_complete in t:
        t = t.replace(old_complete, new_complete, 1)
        print('complete/reopen actions')
    else:
        print('complete block not matched')

    Path(path).write_text(t)
    print('project ok', len(t))


def main() -> None:
    patch_repo()
    patch_project()


if __name__ == '__main__':
    main()
