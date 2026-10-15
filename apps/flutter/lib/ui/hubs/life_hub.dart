import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../services/app_data_bus.dart';
import '../../data/extended_repository.dart';
import '../../data/goal_repository.dart';
import '../../data/habit_repository.dart';
import '../../data/routine_repository.dart';
import '../../domain/models.dart';
import '../forms/create_forms.dart';
import '../screens/calendar_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/needs_attention_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/planning_screen.dart';
import '../screens/practical_life_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/routine_detail_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/life_areas_screen.dart';
import 'more_hub.dart';
import '../screens/wellness_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/empty_state.dart';

class LifeHub extends StatefulWidget {
  const LifeHub({
    super.key,
    required this.goals,
    required this.habits,
    required this.onOpenTasks,
    required this.notes,
    required this.projects,
    required this.onChanged,
    required this.finance,
    this.routines = const [],
  });

  final List<Goal> goals;
  final List<Habit> habits;
  final VoidCallback onOpenTasks;
  final List<Note> notes;
  final List<Project> projects;
  final List<Routine> routines;
  final Future<void> Function() onChanged;
  final Widget finance;

  @override
  State<LifeHub> createState() => _LifeHubState();
}

class _LifeHubState extends State<LifeHub> {
  List<String> _attention = [];
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _refreshAttention();
  }

  @override
  void didUpdateWidget(covariant LifeHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goals != widget.goals ||
        oldWidget.habits != widget.habits ||
        oldWidget.projects != widget.projects ||
        oldWidget.routines != widget.routines) {
      _refreshAttention();
    }
  }

  Future<void> _refreshAttention() async {
    // Soft: never block the hub if attention aggregation fails.
    try {
      final tips = <String>[];
      if (widget.goals.isEmpty && widget.projects.isEmpty) {
        tips.add('Start with a goal or project so Today has direction.');
      }
      if (widget.habits.isEmpty) {
        tips.add('A single daily habit is enough to build momentum.');
      }
      if (!mounted) return;
      setState(() => _attention = tips);
    } catch (_) {}
  }

  Future<void> _open(Widget screen) async {
    final genBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    if (AppDataBus.instance.generation != genBefore) {
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attention = _attention;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 720 ? 3 : 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Navigation grid
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _navTile(
              context,
              icon: Icons.flag_outlined,
              label: 'Goals',
              onTap: () {},
            ),
            _navTile(
              context,
              icon: Icons.folder_outlined,
              label: 'Projects',
              onTap: () {},
            ),
            _navTile(
              context,
              icon: Icons.check_circle_outline,
              label: 'Tasks',
              onTap: widget.onOpenTasks,
            ),
            _navTile(
              context,
              icon: Icons.repeat,
              label: 'Habits',
              onTap: () {},
            ),
            _navTile(
              context,
              icon: Icons.list_alt,
              label: 'Routines',
              onTap: () {},
            ),
            _navTile(
              context,
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              onTap: () {},
            ),
            _navTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              label: 'Finance',
              semanticLabel: 'Open Finance',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Finance')),
                      body: widget.finance,
                    ),
                  ),
                );
              },
            ),
            _navTile(
              context,
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              onTap: () => _open(const CalendarScreen()),
            ),
            _navTile(
              context,
              icon: Icons.schedule,
              label: 'Schedule',
              onTap: () => _open(const ScheduleScreen()),
            ),
            _navTile(
              context,
              icon: Icons.auto_awesome,
              label: 'Plan day',
              onTap: () => _open(const PlanningScreen()),
            ),
            _navTile(
              context,
              icon: Icons.spa_outlined,
              label: 'Wellness',
              onTap: () => _open(const WellnessScreen()),
            ),
            _navTile(
              context,
              icon: Icons.home_work_outlined,
              label: 'Practical',
              onTap: () => _open(const PracticalLifeScreen()),
            ),
            _navTile(
              context,
              icon: Icons.category_outlined,
              label: 'Life areas',
              onTap: () => _open(const LifeAreasScreen()),
            ),
            _navTile(
              context,
              icon: Icons.more_horiz,
              label: 'More',
              onTap: () => _open(const MoreHub()),
            ),
            _navTile(
              context,
              icon: Icons.priority_high,
              label: 'Attention',
              onTap: () => _open(const NeedsAttentionScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (attention.isNotEmpty) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Heads-up', style: TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...attention.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $a', style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _header(context, 'Goals', AddKind.goal),
        if (widget.goals.isEmpty)
          EmptyState(
            title: 'No goals yet',
            detail: 'Capture an outcome you want to move toward.',
            icon: Icons.flag_outlined,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
          )
        else
          ...widget.goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _open(GoalDetailScreen(goalId: g.id)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(g.title, style: const TextStyle(color: AppTheme.silver)),
                    subtitle: g.areaId != null
                        ? Text(g.areaId!, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12))
                        : null,
                  ),
                ),
              )),
        _header(context, 'Projects', AddKind.project),
        if (widget.projects.isEmpty)
          EmptyState(
            title: 'No projects yet',
            detail: 'Group related work under a project.',
            icon: Icons.folder_outlined,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
          )
        else
          ...widget.projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _open(ProjectDetailScreen(projectId: p.id)),
                  padding: const EdgeInsets.all(14),
                  child: Text(p.title, style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600)),
                ),
              )),
        _header(context, 'Habits', AddKind.habit),
        if (widget.habits.isEmpty)
          EmptyState(
            title: 'No habits yet',
            detail: 'Track a daily practice you want to keep.',
            icon: Icons.repeat,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
          )
        else
          ...widget.habits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _open(HabitDetailScreen(habitId: h.id)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(h.title, style: const TextStyle(color: AppTheme.silver)),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.brandBlue),
                      onPressed: () async {
                        await HabitRepository(AppDatabase.instance).completeToday(h.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged ${h.title}')));
                        }
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        _header(context, 'Routines', AddKind.routine),
        if (widget.routines.isEmpty)
          EmptyState(
            title: 'No routines yet',
            detail: 'Bundle steps you run together.',
            icon: Icons.list_alt,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
          )
        else
          ...widget.routines.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _open(RoutineDetailScreen(routineId: r.id)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ListTile(
                    title: Text(r.name, style: const TextStyle(color: AppTheme.silver)),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: AppTheme.brandBlue),
                      onPressed: () async {
                        await RoutineRepository(AppDatabase.instance).completeToday(r.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Completed ${r.name}')));
                        }
                        await widget.onChanged();
                      },
                    ),
                  ),
                ),
              )),
        _header(context, 'Notes', AddKind.note),
        if (widget.notes.isEmpty)
          EmptyState(
            title: 'No notes yet',
            detail: 'Jot ideas, links, or context for later.',
            icon: Icons.sticky_note_2_outlined,
            padding: const EdgeInsets.only(bottom: 12, top: 4),
          )
        else
          ...widget.notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _open(NoteDetailScreen(noteId: n.id)),
                  child: Text(
                    n.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.silver),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _header(BuildContext context, String label, AddKind kind) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.silverMuted, fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final ok = await showCreateForm(context, kind);
                if (ok) await widget.onChanged();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.brandBlue, size: 26),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.silver,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
