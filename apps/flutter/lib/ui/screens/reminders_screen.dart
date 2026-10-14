import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/extended_repository.dart';
import '../../services/notification_payload.dart';
import '../../services/notification_router.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_generator_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Reminders inbox: Open · Snooze · Complete · Record result.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _ext = ExtendedRepository(AppDatabase.instance);
  List<Map<String, Object?>> _pending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _ext.listPendingReminders();
      if (!mounted) return;
      setState(() {
        _pending = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load reminders.'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminders failed to load: $e')),
      );
    }
  }

  Future<void> _resyncNotifs() async {
    try {
      await NotificationService.instance.syncFromDatabase();
    } catch (_) {}
  }

  Future<void> _add() async {
    final title = TextEditingController();
    var hours = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.metal,
          title: const Text('New reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                style: const TextStyle(color: AppTheme.silver),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: hours,
                dropdownColor: AppTheme.metal,
                decoration: const InputDecoration(labelText: 'Remind in'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('In 15 minutes')),
                  DropdownMenuItem(value: 1, child: Text('In 1 hour')),
                  DropdownMenuItem(value: 3, child: Text('In 3 hours')),
                  DropdownMenuItem(value: 24, child: Text('Tomorrow')),
                  DropdownMenuItem(value: 72, child: Text('In 3 days')),
                ],
                onChanged: (v) => setLocal(() => hours = v ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final when = hours == 0
        ? DateTime.now().add(const Duration(minutes: 15))
        : DateTime.now().add(Duration(hours: hours));
    await _ext.addReminderAt(title: title.text.trim(), triggerAt: when);
    await _resyncNotifs();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder scheduled locally')),
      );
    }
  }

  Future<void> _snooze(String id, {int minutes = 15}) async {
    await _ext.snoozeReminder(id, minutes: minutes);
    try {
      await ReminderGeneratorService().recordResult(
        reminderId: id,
        result: 'SNOOZED',
        snoozeMinutes: minutes,
      );
    } catch (_) {}
    await _resyncNotifs();
    await _load();
  }

  Future<void> _complete(String id) async {
    await _ext.completeReminder(id);
    try {
      await ReminderGeneratorService().recordResult(
        reminderId: id,
        result: 'COMPLETED',
      );
    } catch (_) {}
    await _resyncNotifs();
    await _load();
  }

  Future<void> _openSource(Map<String, Object?> r) async {
    final type = '${r['source_type'] ?? NotificationPayload.reminder}';
    final sid = '${r['source_id'] ?? r['id']}';
    final payload = NotificationPayload(
      type: type.isEmpty ? NotificationPayload.reminder : type,
      id: sid,
      reminderId: '${r['id']}',
    );
    await NotificationRouter.handle(payload.encode());
  }

  String _whenLabel(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = d.difference(now);
    if (diff.isNegative) return 'Due / past';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    return 'In ${diff.inDays}d · ${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Reminders'),
          actions: [
            IconButton(
              tooltip: 'Refresh reminders',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            IconButton(
              tooltip: 'Resync notifications',
              icon: const Icon(Icons.sync),
              onPressed: () async {
                await _resyncNotifs();
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications resynced')),
                  );
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _add,
          child: const Icon(Icons.add),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_off_outlined, color: AppTheme.amber, size: 36),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.silver)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _pending.isEmpty
                ? Center(
                    child: Text(
                      'No pending reminders.\nAuto-generated from tasks, bills, habits…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45)),
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.amber,
                    onRefresh: () async {
                      await _resyncNotifs();
                      await _load();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _pending.length,
                      itemBuilder: (ctx, i) {
                        final r = _pending[i];
                        final id = r['id'] as String;
                        final title = '${r['title']}';
                        final trigger = r['trigger_at'] as int?;
                        final src = r['source_type'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        color: AppTheme.silver, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  _whenLabel(trigger) +
                                      (src != null ? ' · $src' : ''),
                                  style: TextStyle(
                                    color: AppTheme.silver.withValues(alpha: 0.45),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (src != null)
                                      OutlinedButton(
                                        onPressed: () => _openSource(r),
                                        child: const Text('Open'),
                                      ),
                                    OutlinedButton(
                                      onPressed: () => _snooze(id, minutes: 15),
                                      child: const Text('Snooze 15m'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _snooze(id, minutes: 60),
                                      child: const Text('Snooze 1h'),
                                    ),
                                    FilledButton(
                                      onPressed: () => _complete(id),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
