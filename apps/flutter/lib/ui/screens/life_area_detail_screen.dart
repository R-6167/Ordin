import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/goal_repository.dart';
import '../../data/life_area_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../domain/life_area.dart';
import '../../domain/models.dart';
import '../../services/app_data_bus.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'goal_detail_screen.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Overview for one life area: snapshot, attention, next actions, goals/projects/tasks.
class LifeAreaDetailScreen extends StatefulWidget {
  const LifeAreaDetailScreen({super.key, required this.lifeAreaId});
  final String lifeAreaId;

  @override
  State<LifeAreaDetailScreen> createState() => _LifeAreaDetailScreenState();
}

class _LifeAreaDetailScreenState extends State<LifeAreaDetailScreen> {
  final _areas = LifeAreaRepository(AppDatabase.instance);
  final _goals = GoalRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _tasks = TaskRepository(AppDatabase.instance);

  LifeArea? _area;
  List<Goal> _goalList = [];
  List<Project> _projectList = [];
  List<Task> _taskList = [];
  Set<String> _blockedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openAfterMaybeReload(Future<void> Function() open) async {
    final generationBefore = AppDataBus.instance.generation;
    await open();
    if (!mounted) return;
    if (AppDataBus.instance.generation != generationBefore) {
      await _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final area = await _areas.getById(widget.lifeAreaId);
      final goals = await _goals.listByLifeArea(widget.lifeAreaId);
      final projects = await _projects.listByLifeArea(widget.lifeAreaId);
      final tasks = await _tasks.listByLifeArea(widget.lifeAreaId);
      Set<String> blocked = {};
      try {
        blocked = await _tasks.listBlockedTaskIds();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _area = area;
        _goalList = goals;
        _projectList = projects;
        _taskList = tasks;
        _blockedIds = blocked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Task> get _openTasks =>
      _taskList.where((t) => t.status != EntityStatus.completed).toList();

  List<Task> get _overdue => _openTasks.where((t) => t.isOverdue).toList();

  List<Task> get _blockedInArea =>
      _openTasks.where((t) => _blockedIds.contains(t.id)).toList();

  List<Task> get _nextActions {
    final open = List<Task>.from(_openTasks);
    open.sort((a, b) {
      final ao = a.isOverdue ? 0 : 1;
      final bo = b.isOverdue ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = a.isDueToday ? 0 : 1;
      final bd = b.isDueToday ? 0 : 1;
      if (ad != bd) return ad.compareTo(bd);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return open.take(5).toList();
  }

  String _taskSubtitle(Task t) {
    final parts = <String>[];
    if (t.isOverdue) {
      parts.add('OVERDUE');
    } else if (t.isDueToday) {
      parts.add('Due today');
    }
    if (_blockedIds.contains(t.id)) parts.add('Blocked');
    parts.add(t.status);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final title = _area?.title ?? 'Life area';
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDeep,
        title: Text(title, style: const TextStyle(color: AppTheme.silver)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.amber))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load this area',
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.amber,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_area?.description != null &&
                          _area!.description!.trim().isNotEmpty) ...[
                        Text(
                          _area!.description!,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.65),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _snapshotCard(),
                      const SizedBox(height: 16),
                      if (_overdue.isNotEmpty || _blockedInArea.isNotEmpty)
                        _attentionSection(),
                      _section(
                        'Next actions',
                        empty:
                            'No open tasks in this area yet. Link tasks to this area or create them under related goals/projects.',
                        children: _nextActions
                            .map(
                              (t) => _tile(
                                title: t.title,
                                subtitle: _taskSubtitle(t),
                                accent: t.isOverdue
                                    ? Colors.redAccent
                                    : (_blockedIds.contains(t.id)
                                        ? Colors.orangeAccent
                                        : null),
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: t.id),
                                    ),
                                  );
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      _section(
                        'Goals',
                        empty: 'No goals linked to this area.',
                        children: _goalList
                            .map(
                              (g) => _tile(
                                title: g.title,
                                subtitle: g.status,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GoalDetailScreen(goalId: g.id),
                                    ),
                                  );
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      _section(
                        'Projects',
                        empty: 'No projects linked to this area.',
                        children: _projectList
                            .map(
                              (p) => _tile(
                                title: p.title,
                                subtitle: p.status,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailScreen(
                                          projectId: p.id),
                                    ),
                                  );
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      _section(
                        'All open tasks',
                        empty: 'No open tasks linked to this area.',
                        children: _openTasks
                            .map(
                              (t) => _tile(
                                title: t.title,
                                subtitle: _taskSubtitle(t),
                                accent: t.isOverdue ? Colors.redAccent : null,
                                onTap: () => _openAfterMaybeReload(() async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TaskDetailScreen(taskId: t.id),
                                    ),
                                  );
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _snapshotCard() {
    final open = _openTasks.length;
    final overdue = _overdue.length;
    final blocked = _blockedInArea.length;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Snapshot',
            style: TextStyle(
              color: AppTheme.woodLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip('${_goalList.length} goals'),
              _chip('${_projectList.length} projects'),
              _chip('$open open tasks'),
              if (overdue > 0)
                _chip('$overdue overdue', color: Colors.redAccent),
              if (blocked > 0)
                _chip('$blocked blocked', color: Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {Color? color}) {
    final c = color ?? AppTheme.silver;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c.withValues(alpha: 0.9), fontSize: 12),
      ),
    );
  }

  Widget _attentionSection() {
    return _section(
      'Needs attention',
      empty: '',
      children: [
        ..._overdue.map(
          (t) => _tile(
            title: t.title,
            subtitle: 'Overdue',
            accent: Colors.redAccent,
            onTap: () => _openAfterMaybeReload(() async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: t.id),
                ),
              );
            }),
          ),
        ),
        ..._blockedInArea.where((t) => !t.isOverdue).map(
              (t) => _tile(
                title: t.title,
                subtitle: 'Blocked by dependencies',
                accent: Colors.orangeAccent,
                onTap: () => _openAfterMaybeReload(() async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(taskId: t.id),
                    ),
                  );
                }),
              ),
            ),
      ],
    );
  }

  Widget _section(
    String heading, {
    required String empty,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: AppTheme.woodLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              empty,
              style: TextStyle(
                color: AppTheme.silver.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        child: ListTile(
          title: Text(title, style: const TextStyle(color: AppTheme.silver)),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: (accent ?? AppTheme.silver).withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          trailing:
              const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
        ),
      ),
    );
  }
}
