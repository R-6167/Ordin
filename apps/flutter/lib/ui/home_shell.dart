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
import 'hubs/more_hub.dart';
import 'screens/planning_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/task_detail_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/pay_bill_dialog.dart';
import 'widgets/section_header.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _ready = false;
  String? _error;
  bool _notifsSynced = false;
  int _busGen = 0;

  final _tasks = TaskRepository(AppDatabase.instance);
  final _habits = HabitRepository(AppDatabase.instance);
  final _goals = GoalRepository(AppDatabase.instance);
  final _notes = NoteRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _expenses = ExpenseRepository(AppDatabase.instance);
  final _bills = BillRepository(AppDatabase.instance);
  final _routines = RoutineRepository(AppDatabase.instance);
  final _income = IncomeRepository(AppDatabase.instance);

  List<Task> _taskList = [];
  List<Task> _overdue = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];
  List<Project> _projectList = [];
  List<Expense> _expenseList = [];
  int _monthSpendMinor = 0;
  List<BillOccurrence> _billOcc = [];
  List<Routine> _routineList = [];
  List<Income> _incomeList = [];
  List<PlanItem> _plan = [];
  int _freeMinutes = 0;
  List<Task> _scheduledToday = [];
  Set<String> _blockedIds = {};

  static const _titles = ['Today', 'Tasks', 'Life', 'Finance', 'More'];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _currency => UserPrefs.instance.currencyCode;

  @override
  void initState() {
    super.initState();
    AppDataBus.instance.addListener(_onBus);
    _boot();
  }

  @override
  void dispose() {
    AppDataBus.instance.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    final gen = AppDataBus.instance.generation;
    if (gen == _busGen) return;
    _busGen = gen;
    final dirty = AppDataBus.instance.takeDirty();
    if (dirty.isEmpty) return;
    final domains = <DataDomain>{};
    domains.addAll(dirty);
    _reload(domains: domains);
  }

  Future<void> _boot() async {
    try {
      await AppDatabase.instance.database;
      await AppDatabase.instance.requireOwnerId();
      await UserPrefs.instance.load();
      try {
        await NotificationService.instance.init();
      } catch (_) {}
      await _reload(
        domains: {
          DataDomain.tasks,
          DataDomain.life,
          DataDomain.finance,
          DataDomain.today,
        },
        runMaintenance: true,
      );
      setState(() {
        _error = null;
        _ready = true;
      });
      LocalAnalytics.instance.screenView('today');
    } catch (e, st) {
      await ErrorLogService.instance
          .log(message: 'boot: $e', stack: st.toString(), level: 'BOOT');
      setState(() {
        _error = e.toString();
        _ready = true;
      });
    }
  }

  Future<void> _reload({
    Set<DataDomain>? domains,
    bool runMaintenance = false,
  }) async {
    final want = domains == null || domains.isEmpty
        ? DataDomain.values.toSet()
        : domains;

    final wantTasks = want.contains(DataDomain.tasks);
    final wantLife = want.contains(DataDomain.life);
    final wantFinance = want.contains(DataDomain.finance);
    final wantToday = want.contains(DataDomain.today);

    if (want.length == DataDomain.values.length) {
      QueryCache.instance.invalidate();
    } else {
      if (wantTasks) QueryCache.instance.invalidate('tasks');
      if (wantLife) QueryCache.instance.invalidate('life');
      if (wantFinance) QueryCache.instance.invalidate('finance');
      if (wantToday) QueryCache.instance.invalidate('today');
    }

    if (runMaintenance) {
      await Future.wait([
        softRun(() => _habits.ensureAllTodayOccurrences(), label: 'habit.ensure'),
        softRun(() => _routines.ensureAllTodayOccurrences(), label: 'routine.ensure'),
        softRun(() => _habits.markMissedBeforeToday(), label: 'habit.missed'),
        softRun(() => _routines.markMissedBeforeToday(), label: 'routine.missed'),
      ]);
    }

    final futures = <Future>[];
    List<Task>? taskList;
    List<Task>? overdue;
    List<Task>? scheduled;
    List<Habit>? habitList;
    List<Goal>? goalList;
    List<Note>? noteList;
    List<Project>? projectList;
    List<Expense>? expenseList;
    int? monthSpend;
    List<BillOccurrence>? billOcc;
    List<Routine>? routineList;
    List<Income>? incomeList;
    List<PlanItem>? plan;
    int? freeMin;
    Set<String>? blockedIds;

    if (wantTasks || wantToday) {
      futures.add(() async {
        taskList =
            await softFuture(_tasks.listOpen, fallback: <Task>[], label: 'tasks.open') ??
                <Task>[];
        overdue =
            await softFuture(_tasks.listOverdue, fallback: <Task>[], label: 'tasks.overdue') ??
                <Task>[];
        blockedIds = await softFuture(
              _tasks.listBlockedTaskIds,
              fallback: <String>{},
              label: 'tasks.blocked',
            ) ??
            <String>{};
      }());
    }
    if (wantToday) {
      futures.add(() async {
        scheduled = await softFuture(() => _tasks.listScheduledOnDay(DateTime.now()),
                fallback: <Task>[], label: 'scheduled') ??
            <Task>[];
        plan = await softFuture(() => DayPlanner().buildPlan(limit: 6),
                fallback: <PlanItem>[], label: 'plan') ??
            <PlanItem>[];
        freeMin = await softFuture(
              () => PlanningRepository(AppDatabase.instance)
                  .availableMinutes(day: DateTime.now()),
              fallback: 0,
              label: 'freeMin',
            ) ??
            0;
      }());
    }
    if (wantLife || wantToday) {
      futures.add(() async {
        habitList =
            await softFuture(_habits.listActive, fallback: <Habit>[], label: 'habits') ??
                <Habit>[];
        if (wantLife) {
          goalList =
              await softFuture(_goals.listActive, fallback: <Goal>[], label: 'goals') ??
                  <Goal>[];
          noteList =
              await softFuture(_notes.list, fallback: <Note>[], label: 'notes') ?? <Note>[];
          projectList =
              await softFuture(_projects.listActive, fallback: <Project>[], label: 'projects') ??
                  <Project>[];
          routineList =
              await softFuture(_routines.listActive, fallback: <Routine>[], label: 'routines') ??
                  <Routine>[];
        }
      }());
    }
    if (wantFinance || wantToday) {
      futures.add(() async {
        billOcc = await softFuture(_bills.listOpenOccurrences,
                fallback: <BillOccurrence>[], label: 'bills') ??
            <BillOccurrence>[];
        if (wantFinance) {
          expenseList =
              await softFuture(_expenses.listRecent, fallback: <Expense>[], label: 'expenses') ??
                  <Expense>[];
          monthSpend = await softFuture(_expenses.monthSpendMinor,
                  fallback: 0, label: 'spend') ??
              0;
          incomeList =
              await softFuture(_income.listRecent, fallback: <Income>[], label: 'income') ??
                  <Income>[];
        }
      }());
    }

    await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      if (taskList != null) _taskList = taskList!;
      if (overdue != null) _overdue = overdue!;
      if (blockedIds != null) _blockedIds = blockedIds!;
      if (scheduled != null) _scheduledToday = scheduled!;
      if (habitList != null) _habitList = habitList!;
      if (goalList != null) _goalList = goalList!;
      if (noteList != null) _noteList = noteList!;
      if (projectList != null) _projectList = projectList!;
      if (expenseList != null) _expenseList = expenseList!;
      if (monthSpend != null) _monthSpendMinor = monthSpend!;
      if (billOcc != null) _billOcc = billOcc!;
      if (routineList != null) _routineList = routineList!;
      if (incomeList != null) _incomeList = incomeList!;
      if (plan != null) _plan = plan!;
      if (freeMin != null) _freeMinutes = freeMin!;
    });
  }

  Future<void> _openTask(Task t) async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation == generationBefore) return;
    final dirty = AppDataBus.instance.takeDirty();
    final domains = <DataDomain>{DataDomain.tasks, DataDomain.today};
    domains.addAll(dirty);
    await _reload(domains: domains);
  }

  Future<void> _openPlanItem(PlanItem p) async {
    switch (p.kind) {
      case PlanItemKind.overdueTask:
      case PlanItemKind.dueTodayTask:
      case PlanItemKind.openTask:
        final generationBefore = AppDataBus.instance.generation;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: p.id)),
        );
        if (!mounted) return;
        if (AppDataBus.instance.generation != generationBefore) {
          await _reload(domains: {DataDomain.tasks, DataDomain.today});
        }
        break;
      default:
        break;
    }
  }

  String _taskStatusLine(Task t) {
    final parts = <String>[];
    if (t.isOverdue) {
      parts.add('OVERDUE');
    } else if (t.isDueToday) {
      parts.add('Due today');
    }
    if (_blockedIds.contains(t.id)) parts.add('Blocked');
    parts.add(t.status);
    return parts.join(' · ');
  }

  String _scheduledLabel(Task t) {
    final start = t.scheduledStart;
    if (start == null) return t.status;
    final d = DateTime.fromMillisecondsSinceEpoch(start);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm · ${t.status}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.amber)),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Startup error', style: TextStyle(color: AppTheme.silver)),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5))),
                const SizedBox(height: 12),
                FilledButton(onPressed: _boot, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_titles[_tab]),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: () async {
                final generationBefore = AppDataBus.instance.generation;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistantScreen()),
                );
                if (!mounted) return;
                if (AppDataBus.instance.generation != generationBefore) {
                  final dirty = AppDataBus.instance.takeDirty();
                  await _reload(domains: dirty.isEmpty ? DataDomain.values.toSet() : dirty);
                }
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            _today(),
            _tasksView(),
            LifeHub(
              goals: _goalList,
              projects: _projectList,
              notes: _noteList,
              habits: _habitList,
              routines: _routineList,
            ),
            FinanceHub(
              expenses: _expenseList,
              bills: _billOcc,
              income: _incomeList,
              monthSpendMinor: _monthSpendMinor,
              currency: _currency,
            ),
            const MoreHub(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            setState(() => _tab = i);
            LocalAnalytics.instance.screenView(_titles[i].toLowerCase());
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Life'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
            NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }

  Widget _today() {
    final spend = (_monthSpendMinor / 100).toStringAsFixed(2);
    return RefreshIndicator(
      color: AppTheme.amber,
      onRefresh: () => _reload(
        domains: {
          DataDomain.tasks,
          DataDomain.life,
          DataDomain.finance,
          DataDomain.today,
        },
        runMaintenance: true,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 13)),
                const SizedBox(height: 4),
                const Text('What needs attention',
                    style:
                        TextStyle(color: AppTheme.silver, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Pull to refresh · ~${_freeMinutes ~/ 60}h free · $_currency $spend spent',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          if (_scheduledToday.isNotEmpty) ...[
            SectionHeader(
              'On the clock',
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanningScreen()),
                  );
                },
                child: const Text('Plan'),
              ),
            ),
            ..._scheduledToday.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
                      title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        _scheduledLabel(t),
                        style: TextStyle(
                          color: AppTheme.silver.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
                        tooltip: 'Complete',
                        onPressed: () async {
                          await _tasks.complete(t.id);
                          AppDataBus.instance.tasksChanged();
                        },
                      ),
                    ),
                  ),
                )),
          ],
          if (_plan.isNotEmpty) ...[
            const SectionHeader('Focus now'),
            ..._plan.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => _openPlanItem(p),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                                color: AppTheme.silver, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          p.reason,
                          style: TextStyle(
                            color: AppTheme.silver.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          if (_overdue.isNotEmpty) ...[
            const SectionHeader('Overdue'),
            ..._overdue.map((t) => _taskTile(t)),
          ],
          const SectionHeader('Tasks'),
          if (_taskList.isEmpty)
            Text('Nothing open — use Add when something appears.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
          else
            ..._taskList.take(8).map(_taskTile),
          const SectionHeader('Habits'),
          if (_habitList.isEmpty)
            Text('No habits yet.', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
          else
            ..._habitList.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      title: Text(h.title, style: const TextStyle(color: AppTheme.silver)),
                      trailing: IconButton(
                        icon: const Icon(Icons.done_all, color: AppTheme.amber),
                        onPressed: () async {
                          await _habits.markDoneToday(h.id);
                          HapticFeedback.selectionClick();
                          AppDataBus.instance.lifeChanged();
                        },
                      ),
                    ),
                  ),
                )),
          const SectionHeader('Bills'),
          if (_billOcc.isEmpty)
            Text('No open bills.', style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)))
          else
            ..._billOcc.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: ListTile(
                      title: Text(o.billName ?? 'Bill',
                          style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(o.status,
                          style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _tasksView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '${_taskList.length} open · tap to manage',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final ok = await showCreateForm(context, AddKind.task);
                  if (ok) {
                    AppDataBus.instance.tasksChanged();
                  }
                },
                child: const Text('New task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _taskList.isEmpty
              ? Center(
                  child: Text('No open tasks',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35))))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: _taskList.map(_taskTile).toList(),
                ),
        ),
      ],
    );
  }

  Widget _taskTile(Task t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          onTap: () => _openTask(t),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
            subtitle: Text(
              _taskStatusLine(t),
              style: TextStyle(
                color: t.isOverdue
                    ? Colors.redAccent
                    : (_blockedIds.contains(t.id)
                        ? Colors.orangeAccent
                        : AppTheme.silver.withValues(alpha: 0.4)),
                fontSize: 11,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppTheme.amber),
              onPressed: () async {
                await _tasks.complete(t.id);
                AppDataBus.instance.tasksChanged();
              },
            ),
          ),
        ),
      );
}
