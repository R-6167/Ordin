import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../services/app_data_bus.dart';
import '../../services/feedback_service.dart';
import '../../services/recurrence_engine.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/related_links_section.dart';
import '../widgets/work_session_panel.dart';

/// Full task workspace with recurrence control.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _tasks = TaskRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  Task? _task;
  String? _description;
  List<Project> _projectOptions = [];
  List<Map<String, Object?>> _deps = [];
  RecurrenceRule? _rule;
  bool _loading = true;
  bool _editing = false;

  late TextEditingController _title;
  late TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _desc = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await _tasks.getById(widget.taskId);
    final desc = await _tasks.descriptionOf(widget.taskId);
    final deps = await _tasks.dependencies(widget.taskId);
    final rule = await _tasks.getRecurrenceRule(widget.taskId);
    final projects = await _projects.listActive();
    if (!mounted) return;
    setState(() {
      _task = t;
      _description = desc;
      _deps = deps;
      _rule = rule;
      _projectOptions = projects;
      _loading = false;
      if (t != null) {
        _title.text = t.title;
        _desc.text = desc ?? '';
      }
    });
  }

  Future<void> _save() async {
    final t = _task;
    if (t == null) return;
    await _tasks.update(
      id: t.id,
      title: _title.text.trim().isEmpty ? t.title : _title.text.trim(),
      description: _desc.text,
    );
    AppDataBus.instance.tasksChanged();
    setState(() => _editing = false);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
  }

  Future<void> _complete() async {
    await _tasks.complete(widget.taskId);
    AppDataBus.instance.tasksChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reopen() async {
    await _tasks.reopen(widget.taskId);
    AppDataBus.instance.tasksChanged();
    await _load();
  }

  Future<void> _archive() async {
    await _tasks.archive(widget.taskId);
    AppDataBus.instance.tasksChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: const Text('Delete task?'),
        content: const Text('This cancels and archives the task.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _tasks.delete(widget.taskId);
    AppDataBus.instance.tasksChanged();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.amber)));
    }
    final t = _task;
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Task not found')));
    }

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_editing ? 'Edit task' : t.title),
          actions: [
            if (!_editing)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() => _editing = true),
              )
            else
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (_editing) ...[
              TextField(
                controller: _title,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 6,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ] else ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: const TextStyle(
                            color: AppTheme.silver, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(t.status,
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12)),
                    if ((_description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_description!, style: const TextStyle(color: AppTheme.silver)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (t.status != EntityStatus.completed)
                    FilledButton.icon(
                      onPressed: _complete,
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                    )
                  else
                    OutlinedButton(onPressed: _reopen, child: const Text('Reopen')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _archive, child: const Text('Archive')),
                  TextButton(onPressed: _delete, child: const Text('Delete')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Blocked by',
                  style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_deps.isEmpty)
                Text('No blockers · this task can be scheduled freely',
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12))
              else
                ..._deps.map((d) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${d['depends_on_title'] ?? d['depends_on_task_id']}',
                        style: const TextStyle(color: AppTheme.silver),
                      ),
                    )),
              RelatedLinksSection(entityType: 'TASK', entityId: t.id),
              const SizedBox(height: 16),
              WorkSessionPanel(taskId: t.id),
            ],
          ],
        ),
      ),
    );
  }
}
