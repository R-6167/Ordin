import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/database.dart';

/// Local-first, bounded diagnostic event recorder.
///
/// Event details are deliberately allow-listed so accidental caller-provided
/// task, finance, health, or free-text content is never persisted here.
class DiagnosticService {
  DiagnosticService._();
  static final instance = DiagnosticService._();

  static const int maxPersistedEvents = 2000;
  static const int maxMemoryEvents = 150;
  static const Set<String> _safeDetailKeys = {
    'route',
    'reason',
    'operation',
    'source',
    'result',
    'count',
    'duration_ms',
    'status_code',
    'error_type',
    'widget',
    'domain',
    'phase',
    'code',
    'message',
    'platform',
    'tab',
    'action',
  };

  final List<Map<String, Object?>> _memoryFallback = <Map<String, Object?>>[];
  bool enabled = true;

  /// Records a structured event. Failure is swallowed to avoid diagnostics
  /// ever becoming a cause of an application failure.
  Future<void> record(
    String eventName, {
    String category = 'app',
    String severity = 'info',
    int? durationMs,
    String? correlationId,
    Map<String, Object?> details = const {},
  }) async {
    if (!enabled) return;
    // Release: keep errors always; also keep compact user_action / nav breadcrumbs
    // so device reports show what the user did before a failure.
    final keepInRelease = severity == 'error' ||
        severity == 'fatal' ||
        category == 'user_action' ||
        category == 'nav' ||
        category == 'notif';
    if (kReleaseMode && !keepInRelease) return;

    final now = AppDatabase.nowMs();
    final event = <String, Object?>{
      'id': AppDatabase.newId(),
      'event_name': _bounded(eventName, 80),
      'category': _bounded(category, 40),
      'severity': _bounded(severity, 16),
      'occurred_at': now,
      'duration_ms': durationMs == null ? null : durationMs.clamp(0, 86400000).toInt(),
      'correlation_id': correlationId == null ? null : _bounded(correlationId, 80),
      'details': jsonEncode(_safeDetails(details)),
    };

    // High-frequency traces stay in memory until export/open diagnostics.
    if (severity != 'error' && severity != 'fatal') {
      _remember(event);
      return;
    }
    if (!await _persist(event)) _remember(event);
  }

  /// Breadcrumb for navigation / UI actions (safe, no personal content).
  Future<void> trackAction(String action, {String? route, String? tab}) {
    return record(
      action,
      category: 'user_action',
      severity: 'info',
      details: {
        if (route != null) 'route': route,
        if (tab != null) 'tab': tab,
        'action': action,
      },
    );
  }

  void _remember(Map<String, Object?> event) {
    _memoryFallback.add(event);
    if (_memoryFallback.length > maxMemoryEvents) {
      _memoryFallback.removeAt(0);
    }
  }

  Future<bool> _persist(Map<String, Object?> event) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('diagnostic_events', event);
      await db.rawDelete(
        'DELETE FROM diagnostic_events WHERE id IN '
        '(SELECT id FROM diagnostic_events ORDER BY occurred_at DESC LIMIT -1 OFFSET ?)',
        [maxPersistedEvents],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Map<String, Object?> sanitizeDetailsForTesting(Map<String, Object?> details) {
    return DiagnosticService._()._safeDetails(details);
  }

  Map<String, Object?> _safeDetails(Map<String, Object?> details) {
    final safe = <String, Object?>{};
    for (final entry in details.entries) {
      if (!_safeDetailKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is double && !value.isFinite) continue;
      if (value == null || value is bool || value is num) {
        safe[entry.key] = value;
      } else if (value is String) {
        safe[entry.key] = _bounded(value, 160);
      }
    }
    return safe;
  }

  String _bounded(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  Future<List<Map<String, Object?>>> recent({int limit = 200}) async {
    final safeLimit = limit.clamp(1, maxPersistedEvents).toInt();
    final queued = List<Map<String, Object?>>.from(_memoryFallback);
    for (final event in queued) {
      final persisted = await _persist(event);
      if (persisted) _memoryFallback.remove(event);
    }
    try {
      final db = await AppDatabase.instance.database;
      return db.query(
        'diagnostic_events',
        orderBy: 'occurred_at DESC',
        limit: safeLimit,
      );
    } catch (_) {
      return _memoryFallback.reversed.take(safeLimit).toList();
    }
  }

  Future<String> exportJson({int limit = 500}) async {
    final events = await recent(limit: limit);
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'ordin-diagnostics-v1',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'build_mode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      'event_count': events.length,
      'events': events.map((event) {
        final row = Map<String, Object?>.from(event);
        final rawDetails = row['details'];
        if (rawDetails is String) {
          try {
            row['details'] = jsonDecode(rawDetails);
          } catch (_) {
            row['details'] = <String, Object?>{};
          }
        }
        return row;
      }).toList(),
    });
  }

  Future<void> clear() async {
    _memoryFallback.clear();
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('diagnostic_events');
    } catch (_) {}
  }
}
