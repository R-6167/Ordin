import 'package:flutter/material.dart';

import '../../services/upcoming_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  List<UpcomingItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await UpcomingService().build();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Upcoming items could not be loaded.';
        _loading = false;
      });
    }
  }

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today · $time';
    if (diff == 1) return 'Tomorrow · $time';
    if (diff < 0) return 'Past due';
    return '${d.month}/${d.day} · $time';
  }

  IconData _icon(String kind) {
    switch (kind) {
      case 'bill':
        return Icons.receipt_long;
      case 'appointment':
        return Icons.event;
      case 'habit':
        return Icons.repeat;
      case 'routine':
        return Icons.playlist_play;
      default:
        return Icons.check_box_outlined;
    }
  }

  String _label(String kind) {
    switch (kind) {
      case 'bill':
        return 'Bills';
      case 'appointment':
        return 'Appointments';
      case 'habit':
        return 'Habits';
      case 'routine':
        return 'Routines';
      default:
        return 'Tasks';
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.kind] = (counts[item.kind] ?? 0) + 1;
    }
    final nextItem = _items.isEmpty ? null : _items.first;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Upcoming'),
          actions: [
            IconButton(
              tooltip: 'Refresh upcoming items',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.brandBlueContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.upcoming_rounded,
                                color: AppTheme.brandBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'The next two weeks',
                                    style: TextStyle(
                                      color: AppTheme.silver,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _error != null
                                        ? 'Your plan is temporarily unavailable'
                                        : '${_items.length} scheduled ${_items.length == 1 ? 'item' : 'items'} to keep in view',
                                    style: TextStyle(
                                      color: AppTheme.silver.withValues(alpha: 0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (nextItem != null && _error == null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: AppTheme.glassBorder),
                          const SizedBox(height: 10),
                          Text(
                            'COMING UP NEXT',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            nextItem.title,
                            style: const TextStyle(
                              color: AppTheme.silver,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_label(nextItem.kind)} · ${_when(nextItem.whenMs)}',
                            style: const TextStyle(
                              color: AppTheme.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_outlined,
                              color: AppTheme.amber, size: 30),
                          const SizedBox(height: 10),
                          const Text(
                            'We couldn’t build your upcoming list.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.silver,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your saved items have not been changed. Try loading them again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_items.isEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 34,
                            color: AppTheme.silver.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'You have some breathing room.',
                            style: TextStyle(
                              color: AppTheme.silver,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Nothing is scheduled in the next two weeks. New tasks, reminders, bills, and appointments will appear here when they are due.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        children: [
                          const Text(
                            'YOUR LINEUP',
                            style: TextStyle(
                              color: AppTheme.silver,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${counts.length} categories',
                            style: TextStyle(
                              color: AppTheme.silver.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: counts.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.glass,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_icon(entry.key),
                                  color: AppTheme.amber, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                '${_label(entry.key)} · ${entry.value}',
                                style: const TextStyle(
                                  color: AppTheme.silver,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    ..._items.map((it) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.brandBlueContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_icon(it.kind),
                                    color: AppTheme.brandBlue),
                              ),
                              title: Text(
                                it.title,
                                style: const TextStyle(
                                  color: AppTheme.silver,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${_label(it.kind)} · ${it.subtitle}',
                                style: TextStyle(
                                  color: AppTheme.silver.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                _when(it.whenMs),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: AppTheme.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ],
              ),
      ),
    );
  }
}
