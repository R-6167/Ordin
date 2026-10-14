import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/load_error_state.dart';
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
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _ctrl.text = q;
      _run(q);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final generation = ++_requestGeneration;
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
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Search could not be completed. Check your local data and try again.';
        _hits = [];
      });
    }
  }

  void _clearSearch() {
    _ctrl.clear();
    _run('');
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
            kind == 'PERSON' ? 'People detail screen is not available yet' : 'No detail for $kind',
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
    final queryLength = _ctrl.text.trim().length;
    return Scaffold(
      backgroundColor: AppTheme.metalDeep,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: const TextStyle(color: AppTheme.silver),
          decoration: const InputDecoration(
            hintText: 'Search tasks, goals, projects, notes…',
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
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.amber),
            )
          : _error != null
              ? LoadErrorState(
                  title: 'Search unavailable',
                  message: _error!,
                  icon: Icons.search_off,
                  onRetry: () => _run(_ctrl.text),
                )
              : _hits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              queryLength < 2 ? Icons.manage_search : Icons.search_off,
                              size: 42,
                              color: AppTheme.silverMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              queryLength < 2 ? 'Search your life' : 'No matches found',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.silver,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              queryLength < 2
                                  ? 'Enter at least 2 characters to search tasks, goals, projects, notes, habits, routines, and life areas.'
                                  : 'Try a shorter phrase or check the spelling.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.silverMuted,
                                    height: 1.4,
                                  ),
                            ),
                            if (queryLength > 1) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear search'),
                              ),
                            ],
                          ],
                        ),
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
                                kind.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.55),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppTheme.silverMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
