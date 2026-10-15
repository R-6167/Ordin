import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../data/database.dart';
import '../../data/planning_repository.dart';
import '../../data/project_repository.dart';
import '../../data/task_repository.dart';
import '../../data/task_dependency_queries.dart';
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
  int _unlocksCount = 0;
  RecurrenceRule? _rule;
  bool _loading = true;
  bool _editing = false;
  late TextEditingController _title;
  late TextEditingController _desc;
  int _priority = 0;
  DateTime? _due;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('[RefreshTrace] TaskDetail initState taskId=${widget.taskId}');
    }
    _title = TextEditingController();
    _desc = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('[RefreshTrace] TaskDetail dispose taskId=${widget.taskId}');
    }
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  // RESTORED_STUB - full file will follow in next commit if truncated
  Future<void> _load() async {}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Loading task…')));
  }
}
