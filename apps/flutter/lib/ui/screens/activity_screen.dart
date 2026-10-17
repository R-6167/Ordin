import 'package:flutter/material.dart';

import '../../services/activity_timeline.dart';
import '../../services/app_data_bus.dart';
import '../../services/timeline_suggestions.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/routine_detail_screen.dart';
import '../screens/task_detail_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Your Life Timeline — plain chronological feed with grounded suggestions.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _svc = ActivityTimelineService();
  final _suggestionsSvc = TimelineSuggestionService();
  List<TimelineDayGroup> _groups = [];
  List<TimelineSuggestion> _suggestions = [];
  bool _loading = true;
  bool _hasLoaded = false;
  int _busGen = 0;

  @override
  void initState() {
    super.initState();
    _busGen = AppDataBus.instance.generation;
    AppDataBus.instance.addListener(_onBus);
    _load();
  }

  @override
  void dispose() {
    AppDataBus.instance.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    if (!mounted) return;
    final gen = AppDataBus.instance.generation;
    if (gen == _busGen) return;
    _busGen = gen;
    _load();
  }

  Future<void> _load() async {
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    final entries = await _svc.build(limit: 100);
    final groups = _svc.groupByDay(entries);
    final suggestions = await _suggestionsSvc.build(limit: 4);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _suggestions = suggestions;
      _hasLoaded = true;
      _loading = false;
    });
  }

  IconData _suggestionIcon(String name) {
    return switch (name) {
      'warning' => Icons.warning_amber_rounded,
      'today' => Icons.today_outlined,
      'receipt' => Icons.receipt_long,
      'repeat' => Icons.repeat,
      'check' => Icons.check_circle_outline,
      _ => Icons.lightbulb_outline,
    };
  }

  Color _dotColor(String eventType) {
    if (eventType.contains('COMPLETED') ||
        eventType.contains('PAID') ||
        eventType.contains('REACHED')) {
      return const Color(0xFF6BCB77);
    }
    if (eventType.contains('MISSED') ||
        eventType.contains('DELETED') ||
        eventType.contains('SKIPPED')) {
      return Colors.orangeAccent;
    }
    if (eventType.contains('WORK_') || eventType.contains('SESSION')) {
      return AppTheme.brandBlue;
    }
    if (eventType.contains('EXPENSE') ||
        eventType.contains('BILL') ||
        eventType.contains('DEBT')) {
      return AppTheme.silverMuted;
    }
    return AppTheme.silver.withValues(alpha: 0.5);
  }

  void _openEntity(String entityType, String entityId) {
    if (entityId.isEmpty) return;
    final Widget? screen = switch (entityType) {
      'TASK' => TaskDetailScreen(taskId: entityId),
      'NOTE' => NoteDetailScreen(noteId: entityId),
      'GOAL' => GoalDetailScreen(goalId: entityId),
      'PROJECT' => ProjectDetailScreen(projectId: entityId),
      'HABIT' => HabitDetailScreen(habitId: entityId),
      'ROUTINE' => RoutineDetailScreen(routineId: entityId),
      _ => null,
    };
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open $entityType from its hub for full detail')),
      );
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) _load();
    });
  }

  Widget _suggestionStrip() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'Suggestions',
            style: TextStyle(
              color: AppTheme.silverMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ..._suggestions.map((s) {
          final canOpen =
              s.entityType != null && s.entityId != null && s.entityId!.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              onTap: canOpen ? () => _openEntity(s.entityType!, s.entityId!) : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(_suggestionIcon(s.iconName),
                      color: AppTheme.brandBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            color: AppTheme.silver,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canOpen)
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: AppTheme.silver.withValues(alpha: 0.35)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Divider(height: 1, color: AppTheme.silver.withValues(alpha: 0.08)),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Your Life Timeline'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: (_loading && !_hasLoaded)
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.brandBlue))
            : _groups.isEmpty && _suggestions.every((s) => s.entityId == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 48,
                              color: AppTheme.silver.withValues(alpha: 0.35)),
                          const SizedBox(height: 16),
                          Text(
                            'Your story starts here',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete a task, pay a bill, or finish a routine —\nit will show up on this timeline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.45),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.brandBlue,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: 1 + _groups.length,
                      itemBuilder: (ctx, index) {
                        if (index == 0) return _suggestionStrip();
                        final gi = index - 1;
                        final g = _groups[gi];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                  top: gi == 0 ? 4 : 18, bottom: 6),
                              child: Text(
                                g.label,
                                style: const TextStyle(
                                  color: AppTheme.brandBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            ...g.entries.map((e) {
                              final time =
                                  ActivityTimelineService.formatTime(e.occurredAt);
                              final canOpen = e.entityId.isNotEmpty &&
                                  const {
                                    'TASK',
                                    'NOTE',
                                    'GOAL',
                                    'PROJECT',
                                    'HABIT',
                                    'ROUTINE',
                                  }.contains(e.entityType);
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: canOpen
                                      ? () =>
                                          _openEntity(e.entityType, e.entityId)
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 44,
                                          child: Text(
                                            time,
                                            style: TextStyle(
                                              color: AppTheme.silver
                                                  .withValues(alpha: 0.55),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 5, right: 10),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _dotColor(e.eventType),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.headline,
                                                style: const TextStyle(
                                                  color: AppTheme.silver,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.35,
                                                ),
                                              ),
                                              if (e.detail != null &&
                                                  e.detail!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  e.detail!,
                                                  style: TextStyle(
                                                    color: AppTheme.silver
                                                        .withValues(alpha: 0.45),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (canOpen)
                                          Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: AppTheme.silver
                                                .withValues(alpha: 0.35),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (gi < _groups.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: AppTheme.silver.withValues(alpha: 0.08),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
