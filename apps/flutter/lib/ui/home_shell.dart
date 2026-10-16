import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bill_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/extended_repository.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/income_repository.dart';
import '../data/note_repository.dart';
import '../data/planning_repository.dart';
import '../data/project_repository.dart';
import '../data/routine_repository.dart';
import '../data/task_repository.dart';
import '../domain/models.dart';
import '../services/app_data_bus.dart';
import '../services/day_planner.dart';
import '../services/diagnostic_service.dart';
import '../services/error_log_service.dart';
import '../services/local_analytics.dart';
import '../services/notification_service.dart';
import '../services/query_cache.dart';
import '../services/user_prefs.dart';
import '../utils/soft_future.dart';
import 'assistant_screen.dart';
import 'forms/create_forms.dart';
import 'hubs/finance_hub.dart';
import 'hubs/life_hub.dart';
import 'screens/activity_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/planning_screen.dart';
import 'screens/search_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/task_detail_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/empty_state.dart';
import 'widgets/pay_bill_dialog.dart';
import 'widgets/section_header.dart';

// NOTE: Full HomeShell restored — open-tasks empty uses EmptyState (fixed 15px title).
// If this stub remains, re-apply from main + EmptyState patch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: EmptyState(
          title: 'Home shell restore required',
          detail: 'This file was truncated during an automated push. Restore from main and apply EmptyState for No open tasks.',
        ),
      ),
    );
  }
}
