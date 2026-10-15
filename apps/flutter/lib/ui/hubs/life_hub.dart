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

// Content continues - this push may be incomplete if truncated.
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
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('LifeHub restore incomplete'));
  }
}
