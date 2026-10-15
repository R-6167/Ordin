import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'diagnostic_service.dart';

/// Stores Flutter errors and zone errors locally for offline diagnostics.
class ErrorLogService {
  ErrorLogService._();
  static final instance = ErrorLogService._();

  bool enabled = true;

  /// Install global handlers (call once from main).
  void install() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      log(
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
        context: details.context?.toString(),
        level: 'FLUTTER',
      );
      prev?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        message: error.toString(),
        stack: stack.toString(),
        level: 'ZONE',
      );
      return false;
    };
  }

  Future<void> log({
    required String message,
    String? stack,
    String? context,
    String level = 'ERROR',
  }) async {
    if (!enabled) return;
    if (!kReleaseMode) {
      try {
        final db = await AppDatabase.instance.database;
        String? ownerId;
        try {
          ownerId = await AppDatabase.instance.requireOwnerId();
        } catch (_) {}
        await db.insert('error_logs', {
          'id': AppDatabase.newId(),
          'owner_id': ownerId,
          'level': level,
          'message': message.length > 2000 ? message.substring(0, 2000) : message,
          'stack': stack == null
              ? null
              : (stack.length > 8000 ? stack.substring(0, 8000) : stack),
          'context': context,
          'occurred_at': AppDatabase.nowMs(),
        });
        await db.rawDelete(
          'DELETE FROM error_logs WHERE id IN '
          '(SELECT id FROM error_logs ORDER BY occurred_at DESC LIMIT -1 OFFSET ?)',
          [500],
        );
      } catch (_) {}
    }

    final op = _operationForTesting(message, fallback: level);
    final errType = _errorTypeForTesting(message);
    // Redacted snippet so release exports show *why* (e.g. invalid resource).
    final snippet = _safeSnippet(message);

    await DiagnosticService.instance.record(
      'uncaught_exception',
      category: 'error',
      severity: 'error',
      details: {
        'operation': op,
        'error_type': errType,
        if (snippet != null) 'message': snippet,
        if (context != null && context.isNotEmpty) 'source': context,
      },
    );
  }

  static String? _safeSnippet(String message) {
    // Strip SQL / long payloads; keep short platform codes.
    var m = message.trim();
    if (m.length > 160) m = m.substring(0, 160);
    // Avoid free-text task titles if present after colon-heavy payloads.
    if (m.toLowerCase().contains('select ') || m.toLowerCase().contains('insert ')) {
      return errTypeOnly(m);
    }
    return m;
  }

  static String errTypeOnly(String message) => _errorTypeForTesting(message);

  @visibleForTesting
  static String errorTypeForTesting(String message) => _errorTypeForTesting(message);

  static String _errorTypeForTesting(String message) {
    final match = RegExp(
      r'(?:^|:\s*)([A-Za-z_][A-Za-z0-9_.]*(?:Exception|Error))\b',
    ).firstMatch(message.trim());
    return match?.group(1) ?? 'UnhandledError';
  }

  @visibleForTesting
  static String operationForTesting(String message, {String fallback = 'ERROR'}) =>
      _operationForTesting(message, fallback: fallback);

  static String _operationForTesting(String message, {required String fallback}) {
    final match = RegExp(r'^([A-Za-z][A-Za-z0-9_.-]{0,79}):\s+').firstMatch(message.trim());
    if (match == null) return fallback;
    return match.group(1)!;
  }

  Future<List<Map<String, Object?>>> recent({int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    return db.query('error_logs', orderBy: 'occurred_at DESC', limit: limit);
  }

  Future<int> count({int days = 30}) async {
    final db = await AppDatabase.instance.database;
    final since = AppDatabase.nowMs() - Duration(days: days).inMilliseconds;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM error_logs WHERE occurred_at >= ?',
      [since],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('error_logs');
  }
}
