import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/task_repository.dart';
import '../../data/bill_repository.dart';
import '../../services/activity_timeline.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/routine_detail_screen.dart';
import '../screens/task_detail_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Tab 5: Timeline — chronological life activity + offline suggestions.
/// Settings / backup / search live on the AppBar (Search + Settings).
class MoreHub extends StatefulWidget {
  const MoreHub({super.key, this.onChanged});

  final Future<void> Function()? onChanged;

  @override
  State<MoreHub> createState() => _MoreHubState();
}

class _Suggestion {
  const _Suggestion({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

class _MoreHubState extends State<MoreHub> {
  final _timeline = ActivityTimelineService();
  List<TimelineDayGroup> _groups = [];
  List<_Suggestion> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final entries = await _timeline.build(limit: 80);
    final groups = _timeline.groupByDay(entries);
    final suggestions = await _buildSuggestions();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _suggestions = suggestions;
      _loading = false;
    });
  }

  Future<List<_Suggestion>> _buildSuggestions() async {
    final out = <_Suggestion>[];
    try {
      final overdue = await TaskRepository(AppDatabase.instance).listOverdue();
      if (overdue.isNotEmpty) {
        final first = overdue.first;
        out.add(_Suggestion(
          title: '${overdue.length} overdue task${overdue.length == 1 ? '' : 's'}',
          subtitle: first.title,
          icon: Icons.warning_amber_rounded,
          onTap: () => _openEntity('TASK', first.id),
        ));
      }
    } catch (_) {}
    try {
      final bills = await BillRepository(AppDatabase.instance).listOpenOccurrences();
      if (bills.isNotEmpty) {
        out.add(_Suggestion(
          title: '${bills.length} bill${bills.length == 1 ? '' : 's'} open',
          subtitle: 'Review payments in Finance',
          icon: Icons.receipt_long,
        ));
      }
    } catch (_) {}
    // Suggestions here should be grounded in the user's actual records.
    // Intelligence remains available from the global app-bar action.
    if (out.isEmpty) {
      out.add(const _Suggestion(
        title: 'You’re clear for now',
        subtitle: 'No overdue tasks or open bills were found.',
        icon: Icons.check_circle_outline,
      ));
    }
    return out;
  }

  void _openEntity(String entityType, String entityId) {
    if (entityId.isEmpty) return;
    final Widget? screen = () {
      switch (entityType) {
        case 'TASK':
          return TaskDetailScreen(taskId: entityId);
        case 'NOTE':
          return NoteDetailScreen(noteId: entityId);
        case 'GOAL':
          return GoalDetailScreen(goalId: entityId);
        case 'PROJECT':
          return ProjectDetailScreen(projectId: entityId);
        case 'HABIT':
          return HabitDetailScreen(habitId: entityId);
        case 'ROUTINE':
          return RoutineDetailScreen(routineId: entityId);
        default:
          return null;
      }
    }();
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
    if (eventType.contains('EXPENSE') ||
        eventType.contains('BILL') ||
        eventType.contains('DEBT')) {
      return AppTheme.woodLight;
    }
    if (eventType.contains('WORK_') || eventType.contains('SESSION')) {
      return AppTheme.amber;
    }
    return AppTheme.silver.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.amber));
    }

    return RefreshIndicator(
      color: AppTheme.amber,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Suggestions',
                  style: TextStyle(
                    color: AppTheme.woodLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  );
                },
                icon: const Icon(Icons.alarm, size: 18),
                label: const Text('Reminders'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: s.onTap,
                child: Row(
                  children: [
                    Icon(s.icon, color: AppTheme.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: const TextStyle(
                              color: AppTheme.silver,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.onTap != null)
                      const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Activity',
            style: TextStyle(
              color: AppTheme.woodLight,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everything worth remembering — tap a chip to open it.',
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          if (_groups.isEmpty)
            GlassCard(
              child: Text(
                'No activity yet. Complete a task, log an expense, or write a note — it will show up here.',
                style: TextStyle(
                  color: AppTheme.silver.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            )
          else
            ..._groups.expand((g) {
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    g.label,
                    style: const TextStyle(
                      color: AppTheme.woodLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...g.entries.map((e) {
                  final time = ActivityTimelineService.formatTime(e.occurredAt);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () => _openEntity(e.entityType, e.entityId),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _dotColor(e.eventType),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.headline,
                                  style: const TextStyle(
                                    color: AppTheme.silver,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                if (e.detail != null && e.detail!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    e.detail!,
                                    style: TextStyle(
                                      color: AppTheme.silver.withValues(alpha: 0.45),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ];
            }),
          const SizedBox(height: 16),
          Text(
            'Search is on the top bar · Settings holds backup & integrity',
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
