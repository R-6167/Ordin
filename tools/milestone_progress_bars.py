"""Add LinearProgressIndicator to project milestone cards."""
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
    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = show(path)
    if 'LinearProgressIndicator' in t and 'msTasks' in t:
        # may already have from another feature — still replace subtitle builder if needed
        pass

    old = '''                        subtitle: Builder(builder: (_) {
                          final mid = dbStr(m['id']);
                          final msTasks = [
                            ...ws.tasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),
                            ...ws.subtasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),
                          ];
                          final doneN = msTasks
                              .where((x) => dbStr(x['status']).toUpperCase() == 'COMPLETED')
                              .length;
                          final status = dbStr(m['status']);
                          final progress = msTasks.isEmpty
                              ? status
                              : '$status · $doneN/${msTasks.length} tasks';
                          return Text(
                            progress,
                            style: TextStyle(
                                color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                          );
                        }),'''

    new = '''                        subtitle: Builder(builder: (_) {
                          final mid = dbStr(m['id']);
                          final msDone =
                              dbStr(m['status']).toUpperCase() == 'COMPLETED';
                          final msTasks = [
                            ...ws.tasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),
                            ...ws.subtasks.where((x) => dbStrOrNull(x['milestone_id']) == mid),
                          ];
                          final doneN = msTasks
                              .where((x) => dbStr(x['status']).toUpperCase() == 'COMPLETED')
                              .length;
                          final total = msTasks.length;
                          // Milestone marked complete counts as full bar even with no tasks.
                          final ratio = msDone
                              ? 1.0
                              : (total == 0 ? 0.0 : doneN / total);
                          final label = msDone
                              ? (total == 0
                                  ? 'Completed'
                                  : 'Completed · $doneN/$total tasks')
                              : (total == 0
                                  ? 'No tasks yet'
                                  : '$doneN of $total tasks');
                          final barColor = msDone
                              ? const Color(0xFF6BCB77)
                              : AppTheme.amber;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor:
                                      AppTheme.silver.withValues(alpha: 0.12),
                                  color: barColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }),'''

    if old not in t:
        sys.exit('subtitle builder marker missing')
    t = t.replace(old, new, 1)
    Path(path).write_text(t)
    print('ok', 'LinearProgressIndicator' in t, len(t))


if __name__ == '__main__':
    main()
