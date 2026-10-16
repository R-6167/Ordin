import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../data/life_area_repository.dart';
import '../../domain/life_area.dart';
import '../../domain/models.dart';
import '../../services/app_data_bus.dart';
import '../screens/calendar_screen.dart';
import '../screens/life_area_detail_screen.dart';
import '../screens/life_areas_screen.dart';
import '../screens/needs_attention_screen.dart';
import '../screens/planning_screen.dart';
import '../screens/practical_life_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/wellness_screen.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import 'more_hub.dart';

/// Life tab: **areas first**.
///
/// Goals, projects and tasks live under a life area (see [LifeAreaDetailScreen]).
/// Global hanging lists are intentionally removed from this surface.
/// Tools (finance, schedule, …) stay as a compact strip below the areas map.
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

  /// Still accepted for counts / unassigned; not listed as global sections.
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
  final _areasRepo = LifeAreaRepository(AppDatabase.instance);
  List<LifeArea> _areas = [];
  bool _loadingAreas = true;
  List<Map<String, Object?>> _practical = [];
  List<Map<String, Object?>> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _loadPractical();
  }

  @override
  void didUpdateWidget(covariant LifeHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent reload may change goal/project membership; rebuild counts.
    if (oldWidget.goals != widget.goals || oldWidget.projects != widget.projects) {
      setState(() {});
    }
  }

  Future<void> _loadAreas() async {
    try {
      await _areasRepo.seedDefaultsIfEmpty();
      final list = await _areasRepo.listActive();
      if (!mounted) return;
      setState(() {
        _areas = list;
        _loadingAreas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAreas = false);
    }
  }

  Future<void> _loadPractical() async {
    final ext = ExtendedRepository(AppDatabase.instance);
    final p = await ext.listPractical();
    final d = await ext.listDocuments();
    if (mounted) {
      setState(() {
        _practical = p;
        _docs = d;
      });
    }
  }

  Future<void> _open(Widget page, {bool reloadPractical = false}) async {
    final gen = AppDataBus.instance.generation;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    if (reloadPractical) await _loadPractical();
    await _loadAreas();
    if (AppDataBus.instance.generation != gen) {
      await widget.onChanged();
    }
  }

  Future<void> _openArea(LifeArea area) async {
    await _open(LifeAreaDetailScreen(lifeAreaId: area.id));
  }

  List<String> get _attention {
    final now = DateTime.now().millisecondsSinceEpoch;
    final week = now + const Duration(days: 28).inMilliseconds;
    final items = <String>[];
    for (final d in _docs) {
      final exp = d['expires_at'] as int?;
      if (exp != null && exp <= week) {
        final days = ((exp - now) / Duration.millisecondsPerDay).ceil();
        items.add("${d['title']} expires in ${days < 0 ? 'past due' : '$days days'}");
      }
    }
    for (final p in _practical) {
      final due = p['due_at'] as int?;
      if (due != null && due <= week) {
        items.add("${p['title']} needs attention");
      }
    }
    return items.take(5).toList();
  }

  int _goalCount(String areaId) =>
      widget.goals.where((g) => g.lifeAreaId == areaId).length;

  int _projectCount(String areaId) =>
      widget.projects.where((p) => p.lifeAreaId == areaId).length;

  List<Goal> get _unassignedGoals =>
      widget.goals.where((g) => g.lifeAreaId == null || g.lifeAreaId!.isEmpty).toList();

  List<Project> get _unassignedProjects =>
      widget.projects.where((p) => p.lifeAreaId == null || p.lifeAreaId!.isEmpty).toList();

  Widget _toolChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.silver.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppTheme.brandBlue),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.silver,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolsStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolChip(icon: Icons.checklist_rounded, label: 'Tasks', onTap: widget.onOpenTasks),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Finance',
            onTap: () => _open(
              Scaffold(
                appBar: AppBar(title: const Text('Finance')),
                body: widget.finance,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.priority_high,
            label: 'Attention',
            onTap: () => _open(const NeedsAttentionScreen()),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.favorite_outline,
            label: 'Wellness',
            onTap: () => _open(const WellnessScreen()),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.schedule,
            label: 'Schedule',
            onTap: () => _open(const ScheduleScreen()),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.view_timeline_outlined,
            label: 'Day plan',
            onTap: () => _open(const PlanningScreen()),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.calendar_month,
            label: 'Calendar',
            onTap: () => _open(const CalendarScreen()),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.home_repair_service_outlined,
            label: 'Practical',
            onTap: () => _open(const PracticalLifeScreen(), reloadPractical: true),
          ),
          const SizedBox(width: 8),
          _toolChip(
            icon: Icons.explore_outlined,
            label: 'More',
            onTap: () => _open(MoreHub(onChanged: widget.onChanged)),
          ),
        ],
      ),
    );
  }

  Widget _areaCard(LifeArea area) {
    final goals = _goalCount(area.id);
    final projects = _projectCount(area.id);
    final subtitle = [
      if (goals > 0) '$goals goal${goals == 1 ? '' : 's'}',
      if (projects > 0) '$projects project${projects == 1 ? '' : 's'}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _openArea(area),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.brandBlueContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category_outlined, color: AppTheme.brandBlue, size: 22),
          ),
          title: Text(
            area.title,
            style: const TextStyle(
              color: AppTheme.silver,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle.isEmpty
                ? (area.description?.trim().isNotEmpty == true
                    ? area.description!.trim()
                    : 'Open to add goals and projects')
                : subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
        ),
      ),
    );
  }

  Widget _unassignedCard() {
    final g = _unassignedGoals.length;
    final p = _unassignedProjects.length;
    if (g == 0 && p == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _open(const LifeAreasScreen()),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.silver.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inbox_outlined, color: AppTheme.silver.withValues(alpha: 0.7), size: 22),
          ),
          title: const Text(
            'Unassigned',
            style: TextStyle(
              color: AppTheme.silver,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            [
              if (g > 0) '$g goal${g == 1 ? '' : 's'}',
              if (p > 0) '$p project${p == 1 ? '' : 's'}',
            ].join(' · ') +
                ' without a life area',
            style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attention = _attention;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // —— Areas map (primary) ——
        Row(
          children: [
            const Expanded(
              child: Text(
                'Life areas',
                style: TextStyle(
                  color: AppTheme.silver,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _open(const LifeAreasScreen()),
              child: const Text('Manage'),
            ),
          ],
        ),
        Text(
          'Work, learning, health — open an area for its goals, projects and tasks.',
          style: TextStyle(
            color: AppTheme.silver.withValues(alpha: 0.52),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingAreas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.brandBlue)),
          )
        else if (_areas.isEmpty)
          EmptyState(
            title: 'No life areas yet',
            detail: 'Tap Manage to add domains like Work or Learning.',
            icon: Icons.category_outlined,
            actionLabel: 'Manage areas',
            onAction: () => _open(const LifeAreasScreen()),
          )
        else
          ..._areas.map(_areaCard),
        _unassignedCard(),
        const SizedBox(height: 8),

        // —— Heads-up ——
        if (attention.isNotEmpty) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Heads-up',
                  style: TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...attention.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $a', style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // —— Tools (secondary) ——
        Text(
          'Tools',
          style: TextStyle(
            color: AppTheme.silver.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _toolsStrip(),
      ],
    );
  }
}
