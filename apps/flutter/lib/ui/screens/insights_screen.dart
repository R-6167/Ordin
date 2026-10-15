import 'package:flutter/material.dart';

import '../../services/personal_insights_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _service = PersonalInsightsService();
  late Future<PersonalInsightsSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _service.load();
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
