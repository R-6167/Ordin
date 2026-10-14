import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'goal_detail_screen.dart';
import 'habit_detail_screen.dart';
import 'life_area_detail_screen.dart';
import 'note_detail_screen.dart';
import 'project_detail_screen.dart';
import 'routine_detail_screen.dart';
import 'task_detail_screen.dart';

/// Global search across tasks, goals, projects, notes, habits, routines, life areas, people.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, Object?>> _hits = [];
  bool _loading = false;
  String? _error;
  int _refreshTraceBuildCount = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[RefreshTrace] Search initState');
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _ctrl.text = q;
      _run(q);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint('[RefreshTrace] Search dispose');
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final needle = q.trim();
    if (needle.length < 2) {
      setState(() {
        _hits = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hits = await ExtendedRepository(AppDatabase.instance).search(needle);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _hits = [];
      });
    }
  }

  void _openHit(Map<String, Object?> h) {
    final kind = '${h['kind'] ?? ''}';
    final id = '${h['id'] ?? ''}';
    if (id.isEmpty) return;
    final Widget? screen = switch (kind) {
      'TASK' => TaskDetailScreen(taskId: id),
      'NOTE' => NoteDetailScreen(noteId: id),
      'GOAL' => GoalDetailScreen(goalId: id),
      'PROJECT' => ProjectDetailScreen(projectId: id),
      'HABIT' => HabitDetailScreen(habitId: id),
      'ROUTINE' => RoutineDetailScreen(routineId: id),
      'LIFE_AREA' => LifeAreaDetailScreen(lifeAreaId: id),
      _ => null,
    };
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == 'PERSON' ? 'People detail screen not available yet' : 'No detail for $kind',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'TASK' => Icons.check_box_outlined,
      'NOTE' => Icons.sticky_note_2_outlined,
      'GOAL' => Icons.flag_outlined,
      'PROJECT' => Icons.folder_outlined,
      'HABIT' => Icons.repeat,
      'ROUTINE' => Icons.list_alt,
      'LIFE_AREA' => Icons.favorite_outline,
      'PERSON' => Icons.person_outline,
      _ => Icons.search,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      _refreshTraceBuildCount++;
      debugPrint('[RefreshTrace] Search build #$_refreshTraceBuildCount '
          'queryLength=${_ctrl.text.length} loading=$_loading '
          'focus=${_focus.hasFocus} hits=${_hits.length}');
    }
    return Scaffold(
      backgroundColor: AppTheme.metalDeep,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(
            hintText: 'Search everything…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppTheme.silverMuted),
          ),
          textInputAction: TextInputAction.search,
          onChanged: _run,
          onSubmitted: _run,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                _run('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : _hits.isEmpty
                  ? Center(
                      child: Text(
                        _ctrl.text.trim().length < 2
                            ? 'Type at least 2 characters'
                            : 'No matches',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _hits.length,
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        final kind = '${h['kind'] ?? ''}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            onTap: () => _openHit(h),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: ListTile(
                              leading: Icon(_iconFor(kind), color: AppTheme.amber),
                              title: Text(
                                '${h['label'] ?? ''}',
                                style: const TextStyle(color: AppTheme.silver),
                              ),
                              subtitle: Text(
                                kind,
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
