import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/link_repository.dart';
import '../theme.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/task_detail_screen.dart';
import 'glass.dart';

/// Bidirectional related records for any entity (entity_links).
class RelatedLinksSection extends StatefulWidget {
  const RelatedLinksSection({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final String entityId;

  @override
  State<RelatedLinksSection> createState() => _RelatedLinksSectionState();
}

class _RelatedLinksSectionState extends State<RelatedLinksSection> {
  List<Map<String, String>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RelatedLinksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityId != widget.entityId ||
        oldWidget.entityType != widget.entityType) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await LinkRepository(AppDatabase.instance)
          .relatedWithTitles(widget.entityType, widget.entityId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Future<void> _open(Map<String, String> item) async {
    final type = item['type'] ?? '';
    final id = item['id'] ?? '';
    if (id.isEmpty) return;
    final Widget? screen = switch (type) {
      'TASK' => TaskDetailScreen(taskId: id),
      'PROJECT' => ProjectDetailScreen(projectId: id),
      'GOAL' => GoalDetailScreen(goalId: id),
      'NOTE' => NoteDetailScreen(noteId: id),
      'HABIT' => HabitDetailScreen(habitId: id),
      _ => null,
    };
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No detail screen for $type yet')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  IconData _icon(String type) {
    return switch (type) {
      'TASK' => Icons.check_box_outlined,
      'PROJECT' => Icons.folder_outlined,
      'GOAL' => Icons.flag_outlined,
      'NOTE' => Icons.sticky_note_2_outlined,
      'HABIT' => Icons.repeat,
      'PERSON' => Icons.person_outline,
      'EVENT' => Icons.event,
      'CALENDAR_EVENT' => Icons.event,
      _ => Icons.link,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.amber),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Related',
          style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Text(
            'Nothing linked yet — notes and other records can connect here.',
            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35), fontSize: 12),
          )
        else
          ..._items.map((item) {
            final type = item['type'] ?? '';
            final title = item['title'] ?? type;
            final rel = item['relation'] ?? 'RELATED';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassCard(
                onTap: () => _open(item),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: Icon(_icon(type), color: AppTheme.amber, size: 20),
                  title: Text(title, style: const TextStyle(color: AppTheme.silver)),
                  subtitle: Text(
                    '$type · $rel',
                    style: TextStyle(
                      color: AppTheme.silver.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.silverMuted, size: 18),
                ),
              ),
            );
          }),
      ],
    );
  }
}
