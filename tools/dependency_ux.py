"""Polish task + project dependency UX."""
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
    path = 'apps/flutter/lib/data/task_repository.dart'
    t = show(path)
    old = (
        "        'SELECT d.id, d.depends_on_task_id, t.title AS depends_on_title '\n"
        "        'FROM task_dependencies d '"
    )
    new = (
        "        'SELECT d.id, d.depends_on_task_id, t.title AS depends_on_title, "
        "t.status AS depends_on_status '\n"
        "        'FROM task_dependencies d '"
    )
    if 'depends_on_status' in t:
        print('repo already')
    elif old not in t:
        sys.exit('repo query marker missing')
    else:
        t = t.replace(old, new, 1)
        Path(path).write_text(t)
        print('repo ok')


def patch_task_detail() -> None:
    path = 'apps/flutter/lib/ui/screens/task_detail_screen.dart'
    t = show(path)
    if 'countDependentsWaiting' in t and 'Still open · blocks this task' in t:
        print('task detail already')
        return
    if "import '../../data/task_dependency_queries.dart';" not in t:
        t = t.replace(
            "import '../../data/task_repository.dart';\n",
            "import '../../data/task_repository.dart';\n"
            "import '../../data/task_dependency_queries.dart';\n",
            1,
        )
    if '_unlocksCount' not in t:
        t = t.replace(
            '  List<Map<String, Object?>> _deps = [];\n',
            '  List<Map<String, Object?>> _deps = [];\n  int _unlocksCount = 0;\n',
            1,
        )
    if 'countDependentsWaiting' not in t:
        t = t.replace(
            '    final deps = await _tasks.dependencies(widget.taskId);\n',
            '    final deps = await _tasks.dependencies(widget.taskId);\n'
            '    final unlocks = await TaskDependencyQueries(AppDatabase.instance)\n'
            '        .countDependentsWaiting(widget.taskId);\n',
            1,
        )
        t = t.replace(
            '      _deps = deps;\n',
            '      _deps = deps;\n      _unlocksCount = unlocks;\n',
            1,
        )

    start = t.find('  Future<void> _addDependency() async {')
    end = t.find('  Future<void> _removeDependency', start)
    if start < 0 or end < 0:
        sys.exit('addDependency bounds missing')
    new_add = Path('/dev/stdin')  # placeholder
    new_add_src = r'''  Future<void> _addDependency() async {
    final candidates = await _tasks.listOpen();
    final existing = {
      for (final d in _deps) d['depends_on_task_id'] as String?,
    };
    final options = [
      for (final task in candidates)
        if (task.id != widget.taskId && !existing.contains(task.id)) task,
    ];
    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other open tasks to depend on.')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Task>(
      context: context,
      backgroundColor: AppTheme.metalDeep,
      isScrollControlled: true,
      builder: (ctx) {
        var filter = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final filtered = [
              for (final task in options)
                if (filter.isEmpty ||
                    task.title.toLowerCase().contains(filter.toLowerCase()))
                  task,
            ];
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'This task is blocked until…',
                          style: TextStyle(
                            color: AppTheme.silver,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(color: AppTheme.silver),
                          decoration: const InputDecoration(
                            hintText: 'Search tasks',
                            prefixIcon:
                                Icon(Icons.search, color: AppTheme.silverMuted),
                          ),
                          onChanged: (v) => setLocal(() => filter = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No matches',
                                  style: TextStyle(
                                    color:
                                        AppTheme.silver.withValues(alpha: 0.45),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final task = filtered[i];
                                  return ListTile(
                                    title: Text(
                                      task.title,
                                      style: const TextStyle(
                                          color: AppTheme.silver),
                                    ),
                                    onTap: () => Navigator.pop(ctx, task),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (chosen == null) return;
    try {
      await _tasks.addDependency(
        taskId: widget.taskId,
        dependsOnTaskId: chosen.id,
      );
      AppDataBus.instance.tasksChanged();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blocked by "${chosen.title}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add dependency: $e')),
        );
      }
    }
  }

'''
    t = t[:start] + new_add_src + t[end:]

    old_ui = (
        "              if (_deps.isEmpty)\n"
        "                Text('No blockers · this task can be scheduled freely',\n"
        "                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12))\n"
        "              else\n"
        "                ..._deps.map((d) => Padding(\n"
        "                      padding: const EdgeInsets.only(top: 4),\n"
        "                      child: Row(\n"
        "                        children: [\n"
        "                          Expanded(\n"
        "                            child: Text(\n"
        "                              '• ${d['depends_on_title'] ?? d['depends_on_task_id']}',\n"
        "                              style: const TextStyle(color: AppTheme.silver),\n"
        "                            ),\n"
        "                          ),\n"
        "                          IconButton(\n"
        "                            tooltip: 'Remove dependency',\n"
        "                            icon: const Icon(Icons.close, size: 16, color: AppTheme.silver),\n"
        "                            onPressed: () => _removeDependency(\n"
        "                              d['depends_on_task_id'] as String,\n"
        "                            ),\n"
        "                          ),\n"
        "                        ],\n"
        "                      ),\n"
        "                    )),"
    )
    new_ui = Path('apps/flutter/lib/ui/screens/task_detail_screen.dart').read_text() if False else None
    # embed new_ui as string
    new_ui = open('/tmp/new_dep_ui.txt').read() if Path('/tmp/new_dep_ui.txt').exists() else None
    if new_ui is None:
        new_ui = r'''              if (_unlocksCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Completing this unlocks $_unlocksCount other task${_unlocksCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppTheme.amber.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (_deps.isEmpty)
                Text(
                  'No blockers · this task can be scheduled freely. Tap Add to require another task first.',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                )
              else
                ..._deps.map((d) {
                  final depId = '${d['depends_on_task_id'] ?? ''}';
                  final title = '${d['depends_on_title'] ?? depId}';
                  final status = '${d['depends_on_status'] ?? ''}'.toUpperCase();
                  final open = status.isNotEmpty &&
                      status != 'COMPLETED' &&
                      status != 'CANCELLED';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GlassCard(
                      onTap: depId.isEmpty
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TaskDetailScreen(taskId: depId),
                                ),
                              );
                              if (mounted) await _load();
                            },
                      child: Row(
                        children: [
                          Icon(
                            open ? Icons.lock_outline : Icons.lock_open,
                            size: 18,
                            color: open
                                ? Colors.orangeAccent
                                : const Color(0xFF6BCB77),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppTheme.silver,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  open
                                      ? 'Still open · blocks this task'
                                      : 'Done · no longer blocking',
                                  style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove dependency',
                            icon: const Icon(Icons.close,
                                size: 16, color: AppTheme.silver),
                            onPressed: () => _removeDependency(depId),
                          ),
                        ],
                      ),
                    ),
                  );
                }),'''
    if old_ui not in t:
        sys.exit('deps UI marker missing')
    t = t.replace(old_ui, new_ui, 1)
    Path(path).write_text(t)
    print('task detail ok', len(t))


def patch_project() -> None:
    path = 'apps/flutter/lib/ui/screens/project_detail_screen.dart'
    t = show(path)
    old = (
        "              ...ws.dependencies.map((d) => Padding(\n"
        "                    padding: const EdgeInsets.only(bottom: 6),\n"
        "                    child: GlassCard(\n"
        "                      child: Text(\n"
        "                        'Blocked by: ${dbStr(d['depends_on_title'])} (${dbStr(d['depends_on_status'])})',\n"
        "                        style: const TextStyle(color: AppTheme.silver, fontSize: 13),\n"
        "                      ),\n"
        "                    ),\n"
        "                  )),"
    )
    new = r'''              ...ws.dependencies.map((d) {
                final taskId = dbStr(d['task_id']);
                final depTitle = dbStr(d['depends_on_title']);
                final st = dbStr(d['depends_on_status']).toUpperCase();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassCard(
                    onTap: taskId.isEmpty ? null : () => _openTaskDetails(taskId),
                    child: Row(
                      children: [
                        Icon(
                          st == 'COMPLETED' || st == 'CANCELLED'
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          size: 18,
                          color: st == 'COMPLETED' || st == 'CANCELLED'
                              ? const Color(0xFF6BCB77)
                              : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Waits on $depTitle · $st',
                            style: const TextStyle(
                                color: AppTheme.silver, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.silverMuted, size: 18),
                      ],
                    ),
                  ),
                );
              }),'''
    if 'Waits on' in t:
        print('project already')
        return
    if old not in t:
        sys.exit('project deps marker missing')
    Path(path).write_text(t.replace(old, new, 1))
    print('project ok')


def patch_workspace() -> None:
    path = 'apps/flutter/lib/services/project_workspace.dart'
    t = show(path)
    old = (
        '        SELECT d.*, t.title AS depends_on_title, t.status AS depends_on_status\n'
        '        FROM task_dependencies d\n'
        '        JOIN tasks t ON t.id = d.depends_on_task_id AND t.owner_id = ?'
    )
    new = (
        '        SELECT d.*, t.title AS depends_on_title, t.status AS depends_on_status,\n'
        '               src.title AS task_title\n'
        '        FROM task_dependencies d\n'
        '        JOIN tasks t ON t.id = d.depends_on_task_id AND t.owner_id = ?\n'
        '        JOIN tasks src ON src.id = d.task_id AND src.owner_id = ?'
    )
    if 'task_title' in t:
        print('workspace already')
        return
    if old not in t:
        print('workspace marker skip')
        Path(path).write_text(t)
        return
    # also fix owner args if query gains join - need to check call site
    t = t.replace(old, new, 1)
    Path(path).write_text(t)
    print('workspace query updated — verify bind args')


def main() -> None:
    patch_repo()
    patch_task_detail()
    patch_project()
    # workspace optional - skip bind-arg risk; project UI does not need task_title


if __name__ == '__main__':
    main()
