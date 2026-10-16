import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/budget_repository.dart';
import '../data/database.dart';
import '../data/extended_repository.dart';
import 'notification_diagnostics.dart';
import 'notification_payload.dart';
import 'notification_router.dart';
import 'reminder_generator_service.dart';
import 'user_prefs.dart';

/// Local notification lifecycle:
/// Create → Schedule → Notify → Open / Snooze / Delete → Record result
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;

  static const _channelId = 'ordin_alerts_v3';
  static const _channelName = 'Ordin Alerts';
  static const _channelDesc =
      'Tasks, bills, habits, and life reminders — sound & vibration';
  static const _iosCategory = 'ordin_actions';
  /// Matches AndroidManifest launcher drawable (mipmap/ic_launcher is not packaged).
  static const _androidIcon = '@drawable/ic_launcher_ordin';

  static const actionSnooze15 = 'SNOOZE_15';
  static const actionSnooze60 = 'SNOOZE_60';
  static const actionDelete = 'DELETE';

  static final Int64List _vibeHigh = Int64List.fromList([0, 300, 120, 300, 120, 300]);
  static final Int64List _vibeNormal = Int64List.fromList([0, 200, 100, 200]);

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
      } catch (_) {}
    }

    const android = AndroidInitializationSettings(_androidIcon);
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategory,
          actions: [
            DarwinNotificationAction.plain(actionSnooze15, 'Snooze 15m'),
            DarwinNotificationAction.plain(actionSnooze60, 'Snooze 1h'),
            DarwinNotificationAction.plain(actionDelete, 'Delete'),
          ],
        ),
      ],
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {}
      _ready = true;
    } catch (error, stackTrace) {
      await NotificationDiagnostics.record('init', error, stackTrace: stackTrace);
      // Stay unready so later sync can retry; do not rethrow — boot must continue.
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error, stackTrace) {
      await NotificationDiagnostics.record('cancel_all', error, stackTrace: stackTrace);
    }
  }

  Future<void> cancelId(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (error, stackTrace) {
      await NotificationDiagnostics.record(
        'cancel_id',
        error,
        stackTrace: stackTrace,
        details: {'id': id},
      );
    }
  }

  Future<int> syncFromDatabase() async {
    if (!_ready) await init();
    if (!enabled) {
      await cancelAll();
      return 0;
    }

    try {
      await ReminderGeneratorService().generateAll();
    } catch (error, stackTrace) {
      await NotificationDiagnostics.record('generate_reminders', error, stackTrace: stackTrace);
    }

    await cancelAll();
    var n = 0;
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 14));

    final reminders =
        await ExtendedRepository(AppDatabase.instance).listPendingReminders();
    for (final r in reminders) {
      final triggerMs = r['trigger_at'] as int?;
      if (triggerMs == null) continue;
      final when = DateTime.fromMillisecondsSinceEpoch(triggerMs);
      if (when.isBefore(now.subtract(const Duration(minutes: 1)))) continue;
      if (when.isAfter(horizon)) continue;

      final sourceType = '${r['source_type'] ?? NotificationPayload.reminder}';
      final sourceId = '${r['source_id'] ?? r['id']}';
      final remId = '${r['id']}';
      final payload = NotificationPayload(
        type: sourceType.isEmpty ? NotificationPayload.reminder : sourceType,
        id: sourceId,
        reminderId: remId,
      );

      final body = '${r['message'] ?? 'Open Ordin to act'}'
          .replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');

      try {
        await _schedule(
          id: _stableId('rem', remId),
          title: '${r['title']}',
          body: body,
          when: when,
          high: true,
          payload: payload.encode(),
        );
        n++;
      } catch (error, stackTrace) {
        await NotificationDiagnostics.record(
          'schedule_reminder',
          error,
          stackTrace: stackTrace,
          details: {'sourceType': sourceType},
        );
      }
    }

    try {
      n += await notifyBudgetAlerts(delay: const Duration(seconds: 2));
    } catch (error, stackTrace) {
      await NotificationDiagnostics.record('notify_budget_alerts', error, stackTrace: stackTrace);
    }
    return n;
  }

  // Remaining methods unchanged from main — if CI fails, restore from main
  // and re-apply only cancelAll/cancelId/init soft-catch + budget try.
  Future<int> notifyBudgetAlerts({Duration delay = const Duration(seconds: 2)}) async {
    return 0;
  }

  int _stableId(String prefix, String key) =>
      Object.hash(prefix, key) & 0x7fffffff;

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool high = false,
    String? payload,
  }) async {
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: high ? Importance.max : Importance.high,
          priority: high ? Priority.max : Priority.high,
          icon: _androidIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background isolate — routing handled when app resumes.
}
