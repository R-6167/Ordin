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
import 'hubs/more_hub.dart';
import 'screens/planning_screen.dart';
import 'screens/search_screen.dart';
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
  /// Coalesce rapid AppDataBus events (mutations, pop-navigation).
  Set<DataDomain> _pendingDomains = {};
  Future<void>? _reloadInFlight;
  bool _reloadQueued = false;


  final _tasks = TaskRepository(AppDatabase.instance);
  final _habits = HabitRepository(AppDatabase.instance);
  final _goals = GoalRepository(AppDatabase.instance);
  final _notes = NoteRepository(AppDatabase.instance);
  final _projects = ProjectRepository(AppDatabase.instance);
  final _expenses = ExpenseRepository(AppDatabase.instance);
  final _bills = BillRepository(AppDatabase.instance);
  final _routines = RoutineRepository(AppDatabase.instance);
  final _income = IncomeRepository(AppDatabase.instance);
  final _ext = ExtendedRepository(AppDatabase.instance);

  List<Task> _taskList = [];
  List<Task> _overdue = [];
  List<Habit> _habitList = [];
  List<Goal> _goalList = [];
  List<Note> _noteList = [];
  List<Project> _projectList = [];
  List<Expense> _expenseList = [];
  List<BillOccurrence> _billOcc = [];
  List<Routine> _routineList = [];
  List<Income> _incomeList = [];
  List<PlanItem> _plan = [];
  List<Task> _scheduledToday = [];
  Set<String> _blockedIds = {};
  int _freeMinutes = 0;
  int _monthSpendMinor = 0;

  static const _titles = ['Today', 'Tasks', 'Life', 'Finance', 'Timeline'];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[RefreshTrace] HomeShell initState');
    AppDataBus.instance.addListener(_onBus);
    _boot();
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint('[RefreshTrace] HomeShell dispose');
    AppDataBus.instance.removeListener(_onBus);
    super.dispose();
  }

  /// Single place that moves bus dirty → pending (never discard without queueing).
  void _consumeDirtyFromBus() {
    final gen = AppDataBus.instance.generation;
    if (gen != _busGen) {
      _busGen = gen;
    }
    final dirty = AppDataBus.instance.takeDirty();
    if (dirty.isEmpty) return;
    _pendingDomains.addAll(dirty);
    _scheduleReload();
  }

  void _onBus() => _consumeDirtyFromBus();

  /// Debounce + single-flight so bursts of notifyDomains do not thrash UI.
  void _scheduleReload() {
    if (_reloadQueued) return;
    _reloadQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 80), () async {
      _reloadQueued = false;
      if (!mounted) return;
      final domains = Set<DataDomain>.from(_pendingDomains);
      _pendingDomains.clear();
      if (domains.isEmpty) return;
      if (_reloadInFlight != null) {
        _pendingDomains.addAll(domains);
        await _reloadInFlight;
        if (!mounted) return;
        if (_pendingDomains.isEmpty) return;
        final more = Set<DataDomain>.from(_pendingDomains);
        _pendingDomains.clear();
        _reloadInFlight = _reload(domains: more);
        await _reloadInFlight;
        _reloadInFlight = null;
        return;
      }
      _reloadInFlight = _reload(domains: domains);
      await _reloadInFlight;
      _reloadInFlight = null;
      if (_pendingDomains.isNotEmpty && mounted) {
        _scheduleReload();
      }
    });
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
    final startedAt = DateTime.now();
    final reloadId = AppDatabase.newId();
    final want = domains == null || domains.isEmpty
        ? DataDomain.values.toSet()
        : domains;
    await DiagnosticService.instance.record('home_reload_started', category: 'refresh', correlationId: reloadId, details: {'domain': want.map((d) => d.name).join(',')});
    if (kDebugMode) {
      debugPrint('[RefreshTrace] HomeShell reload start '
          'domains=${want.map((d) => d.name).join(',')} maintenance=$runMaintenance');
    }

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
      await softRun(() async {
        await Future.wait([
          softRun(() => _habits.ensureAllTodayOccurrences(), label: 'habit.ensure'),
          softRun(() => _routines.ensureAllTodayOccurrences(), label: 'routine.ensure'),
        ]);
        await Future.wait([
          softRun(() => _habits.markMissedBeforeToday(), label: 'habit.missed'),
          softRun(() => _routines.markMissedBeforeToday(), label: 'routine.missed'),
        ]);
      }, label: 'maintenance');
    }

    final futures = <Future<void>>[];

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
    // Phase7: life lists only when wantLife — Today does not need habits/goals.
    if (wantLife) {
      futures.add(() async {
        habitList =
            await softFuture(_habits.listActive, fallback: <Habit>[], label: 'habits') ??
                <Habit>[];
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
          monthSpend =
              await softFuture(_expenses.totalMinorThisMonth, fallback: 0, label: 'spend') ?? 0;
          incomeList =
              await softFuture(_income.listRecent, fallback: <Income>[], label: 'income') ??
                  <Income>[];
        } else if (wantToday) {
          monthSpend =
              await softFuture(_expenses.totalMinorThisMonth, fallback: 0, label: 'spend') ?? 0;
        }
      }());
    }

    await Future.wait(futures);

    if (!_notifsSynced) {
      await softRun(() async {
        await NotificationService.instance.syncFromDatabase();
        _notifsSynced = true;
      }, label: 'notifs.sync');
    }

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
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    await DiagnosticService.instance.record(
      'home_reload_completed',
      category: 'refresh',
      durationMs: elapsedMs,
      correlationId: reloadId,
      details: {'domain': want.map((d) => d.name).join(','), 'duration_ms': elapsedMs},
    );
    if (kDebugMode) {
      debugPrint('[RefreshTrace] HomeShell reload complete '
          'domains=${want.map((d) => d.name).join(',')}');
    }
  }

  Future<void> _reloadTasks() =>
      _reload(domains: {DataDomain.tasks, DataDomain.today});

  Future<void> _openTask(Task t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
    );
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

  Future<void> _openAssistant() async {
    final generationBefore = AppDataBus.instance.generation;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
    if (!mounted) return;
    if (AppDataBus.instance.generation == generationBefore) return;
    // The bus listener may already have consumed dirty domains into
    // [_pendingDomains] while the assistant route was open. Never invent a
    // full-domain reload when the residual dirty set is empty.
    _consumeDirtyFromBus();
    if (_pendingDomains.isNotEmpty) {
      _scheduleReload();
    }
    if (_reloadInFlight != null) {
      await _reloadInFlight;
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await UserPrefs.instance.load();
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final kind = await showUniversalAdd(context);
    if (kind == null) return;
    HapticFeedback.lightImpact();
    // Domain-scoped notify — avoid allChanged() full-tab blast.
    switch (kind) {
      case AddKind.task:
      case AddKind.event:
      case AddKind.reminder:
        AppDataBus.instance.tasksChanged();
      case AddKind.expense:
      case AddKind.income:
      case AddKind.bill:
        AppDataBus.instance.financeChanged();
      case AddKind.project:
      case AddKind.goal:
      case AddKind.habit:
      case AddKind.routine:
      case AddKind.note:
      case AddKind.person:
        AppDataBus.instance.lifeChanged();
    }
  }

  void _onTab(int i) {
    setState(() => _tab = i);
    LocalAnalytics.instance.screenView(_titles[i].toLowerCase());
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _currency => UserPrefs.instance.currency;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leadingWidth: 52,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Image.asset(
              'assets/ordin_logo.png.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[_tab],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(
                _tab == 0 ? _greeting : 'Local · private',
                style: TextStyle(fontSize: 11, color: AppTheme.silver.withValues(alpha: 0.5)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Search',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Intelligence',
              onPressed: _openAssistant,
              icon: const Icon(Icons.auto_awesome),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: GlassCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _ready = false;
                                  _error = null;
                                });
                                _boot();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _body(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _onTab,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.check_box_outlined),
                selectedIcon: Icon(Icons.check_box),
                label: 'Tasks'),
            NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Life'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Finance'),
            NavigationDestination(
                icon: Icon(Icons.view_timeline_outlined),
                selectedIcon: Icon(Icons.view_timeline),
                label: 'Timeline'),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return IndexedStack(
      index: _tab,
      children: [
        KeyedSubtree(key: const ValueKey('tab-today'), child: _today()),
        KeyedSubtree(key: const ValueKey('tab-tasks'), child: _tasksView()),
        LifeHub(
          key: const ValueKey('tab-life'),
          goals: _goalList,
          habits: _habitList,
          notes: _noteList,
          projects: _projectList,
          routines: _routineList,
          onChanged: () async {
            AppDataBus.instance.lifeChanged();
          },
        ),
        FinanceHub(
          key: const ValueKey('tab-finance'),
          expenses: _expenseList,
          income: _incomeList,
          billOcc: _billOcc,
          monthSpendMinor: _monthSpendMinor,
          onChanged: () async {
            AppDataBus.instance.financeChanged();
          },
          onPayBill: (o) async {
            await promptAndPayBill(context, o);
            AppDataBus.instance.financeChanged();
          },
        ),
        MoreHub(
          key: const ValueKey('tab-more'),
          onChanged: () async {
            AppDataBus.instance.notifyDomains({
              DataDomain.life,
              DataDomain.finance,
              DataDomain.today,
              DataDomain.timeline,
            });
          },
        ),
      ],
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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'What needs attention',
                            style: TextStyle(
                              color: AppTheme.silver,
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlueContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.wb_sunny_outlined,
                        color: AppTheme.brandBlue,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TodayMetric(
                        icon: Icons.schedule_rounded,
                        label: 'TIME AVAILABLE',
                        value: '~${_freeMinutes ~/ 60}h',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TodayMetric(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'SPENT THIS MONTH',
                        value: '$_currency $spend',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PlanningScreen()),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Plan my day'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Refresh today',
                      onPressed: () => _reload(
                        domains: {
                          DataDomain.tasks,
                          DataDomain.life,
                          DataDomain.finance,
                          DataDomain.today,
                        },
                        runMaintenance: true,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pull down to refresh your overview.',
                  style: TextStyle(
                    color: AppTheme.silver.withValues(alpha: 0.42),
                    fontSize: 11,
                  ),
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
                    key: ValueKey('task-${t.id}'),
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
                    key: ValueKey('plan-${p.id}'),
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
            ..._overdue.take(5).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    key: ValueKey('task-${t.id}'),
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
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
          if (_taskList.isNotEmpty) ...[
            const SectionHeader('Open work'),
            ..._taskList.take(8).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    key: ValueKey('task-${t.id}'),
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
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
        ],
      ),
    );
  }

  String _scheduledLabel(Task t) {
    final start = t.scheduledStart;
    if (start == null) return t.status;
    final dt = DateTime.fromMillisecondsSinceEpoch(start);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final blocked = _blockedIds.contains(t.id) ? ' · Blocked' : '';
    return '$hh:$mm$blocked · ${t.status}';
  }

  Widget _tasksView() {
    return RefreshIndicator(
      color: AppTheme.amber,
      onRefresh: _reloadTasks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_overdue.isNotEmpty) ...[
            const SectionHeader('Overdue'),
            ..._overdue.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    key: ValueKey('task-${t.id}'),
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
                      title: Text(t.title, style: const TextStyle(color: AppTheme.silver)),
                      subtitle: Text(
                        _taskStatusLine(t),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
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
                )),
          ],
          const SectionHeader('All open'),
          if (_taskList.isEmpty)
            GlassCard(
              child: Text('No open tasks',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5))),
            )
          else
            ..._taskList.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    key: ValueKey('task-${t.id}'),
                    onTap: () => _openTask(t),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ListTile(
                      dense: true,
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
                )),
        ],
      ),
    );
  }
}
