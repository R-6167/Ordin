import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_data_bus.dart';
import '../../services/personal_insights_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.service});

  final PersonalInsightsService? service;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late final PersonalInsightsService _service;
  late Future<PersonalInsightsSummary> _summary;
  int _busGen = -1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PersonalInsightsService();
    _summary = _service.load();
    _busGen = AppDataBus.instance.generation;
    AppDataBus.instance.addListener(_onBus);
  }

  @override
  void dispose() {
    AppDataBus.instance.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    if (!mounted) return;
    final gen = AppDataBus.instance.generation;
    if (gen == _busGen) return;
    _busGen = gen;
    _reload();
  }

  Future<void> _reload() async {
    final next = _service.load();
    setState(() => _summary = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        color: AppTheme.brandBlue,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Your last 7 days',
              style: TextStyle(
                color: AppTheme.silver.withValues(alpha: 0.65),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<PersonalInsightsSummary>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Insights are unavailable right now',
                            style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Your tasks and activity are safe. Pull down to try again.',
                            style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.6))),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final s = snapshot.data!;
                final delta = s.taskCompletionDelta;
                final comparison = delta == 0
                    ? 'Same number as the previous 7 days'
                    : delta > 0
                        ? '$delta more than the previous 7 days'
                        : '${delta.abs()} fewer than the previous 7 days';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MetricCard(
                          icon: Icons.check_circle_outline,
                          label: 'TASKS COMPLETED',
                          value: '${s.completedTasks}',
                          detail: comparison,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _MetricCard(
                          icon: Icons.repeat_rounded,
                          label: 'HABITS COMPLETED',
                          value: '${s.completedHabits}',
                          detail: 'Recorded in your activity history',
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _MetricCard(
                          icon: Icons.bolt_outlined,
                          label: 'LIFE ACTIVITY',
                          value: '${s.activityCount}',
                          detail: 'Events recorded this week',
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _MetricCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'MONEY ACTIVITY',
                          value: '${s.moneyEvents}',
                          detail: 'Income, expenses, bills and savings',
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _WeeklyActivityChart(days: s.dailyActivity),
                    const SizedBox(height: 12),
                    _LinkedWorkProgress(items: s.progressItems),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('A simple way to use this',
                              style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            s.activityCount == 0
                                ? 'Your activity history is quiet so far. As you complete tasks, habits and record life events, this page will build a picture of your week.'
                                : 'Use these numbers as a reflection aid, not a score. Look for a small win to repeat and one commitment that needs attention.',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.65),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Private by design · calculated on this device from your life activity. App usage and Diagnostics are separate.',
                      style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.4),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeInsightsCard extends StatefulWidget {
  const HomeInsightsCard({super.key, this.service});

  final PersonalInsightsService? service;

  @override
  State<HomeInsightsCard> createState() => _HomeInsightsCardState();
}

class _HomeInsightsCardState extends State<HomeInsightsCard> {
  late final PersonalInsightsService _service;
  late Future<PersonalInsightsSummary> _summary;
  int _busGen = -1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PersonalInsightsService();
    _summary = _service.load();
    _busGen = AppDataBus.instance.generation;
    AppDataBus.instance.addListener(_onBus);
  }

  @override
  void dispose() {
    AppDataBus.instance.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    if (!mounted) return;
    final gen = AppDataBus.instance.generation;
    if (gen == _busGen) return;
    _busGen = gen;
    setState(() => _summary = _service.load());
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InsightsScreen(service: _service)),
      ),
      padding: const EdgeInsets.all(14),
      child: FutureBuilder<PersonalInsightsSummary>(
        future: _summary,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.brandBlueContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_outlined, color: AppTheme.brandBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your week at a glance',
                        style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.hasError
                          ? 'Personal insights are temporarily unavailable'
                          : summary == null
                              ? 'Building your personal insights…'
                              : '${summary.completedTasks} tasks · ${summary.completedHabits} habits completed in 7 days',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.silver.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.silverMuted),
            ],
          );
        },
      ),
    );
  }
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.days});

  final List<PersonalInsightsDay> days;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<int>(0, (max, day) {
      final dayMax = [
        day.completedTasks,
        day.completedHabits,
        day.moneyEvents,
      ].reduce((a, b) => a > b ? a : b);
      return dayMax > max ? dayMax : max;
    }).clamp(1, 1000000);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity over time',
              style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Recorded completions and money events by day',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12)),
          const SizedBox(height: 16),
          if (days.isEmpty)
            Text(
              'A trend will appear when activity history is available.',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.6)),
            )
          else
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: days.map((day) {
                  double barHeight(int value) =>
                      value == 0 ? 2 : 4 + (value / maxValue) * 62;
                  return Expanded(
                    child: Tooltip(
                      message: '${DateFormat('EEE, d MMM').format(day.date)}\n'
                          'Tasks: ${day.completedTasks}\n'
                          'Habits: ${day.completedHabits}\n'
                          'Money events: ${day.moneyEvents}',
                      child: Semantics(
                        label: '${DateFormat('EEEE, d MMMM').format(day.date)}: '
                            '${day.completedTasks} tasks, ${day.completedHabits} habits, '
                            '${day.moneyEvents} money events',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _ChartBar(height: barHeight(day.completedTasks), color: AppTheme.brandBlue),
                                  const SizedBox(width: 2),
                                  _ChartBar(height: barHeight(day.completedHabits), color: AppTheme.amber),
                                  const SizedBox(width: 2),
                                  _ChartBar(height: barHeight(day.moneyEvents), color: Colors.tealAccent.shade400),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('E').format(day.date).substring(0, 1),
                              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _ChartLegend(color: AppTheme.brandBlue, label: 'Tasks'),
              _ChartLegend(color: AppTheme.amber, label: 'Habits'),
              _ChartLegend(color: Colors.tealAccent.shade400, label: 'Money events'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.62), fontSize: 11)),
        ],
      );
}

class _LinkedWorkProgress extends StatelessWidget {
  const _LinkedWorkProgress({required this.items});

  final List<PersonalProgressItem> items;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Linked-work progress',
                style: TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Based on completed versus total linked tasks',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Text(
                'Link tasks to a goal or project to see progress here.',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.62), height: 1.4),
              )
            else
              ...items.map((item) {
                final percent = (item.fraction * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.silver, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: item.kind == 'Goal' ? AppTheme.brandBlue : AppTheme.amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: item.fraction,
                          minHeight: 6,
                          backgroundColor: AppTheme.silver.withValues(alpha: 0.12),
                          color: item.kind == 'Goal' ? AppTheme.brandBlue : AppTheme.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.kind} · ${item.completed} of ${item.total} linked tasks complete',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 11),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.brandBlue, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(
              color: AppTheme.silver, fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(
              color: AppTheme.silverMuted, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(detail, style: TextStyle(
              color: AppTheme.silver.withValues(alpha: 0.48), fontSize: 11, height: 1.3)),
          ],
        ),
      );
}
