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
      return false; // let Flutter also handle
    };
  }

  Future<void> log({
    required String message,
    String? stack,
    String? context,
    String level = 'ERROR',
  }) async {
    if (!enabled) return;
    // Detailed exception text and stack traces are development-only. Release
    // builds keep the structured, redacted error type in DiagnosticService.
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
    await DiagnosticService.instance.record(
      'uncaught_exception',
      category: 'error',
      severity: 'error',
      details: {
        'operation': level,
        'error_type': _errorType(message),
      },
    );
  }

  String _errorType(String message) {
    final match = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*Exception|^[A-Za-z_][A-Za-z0-9_.]*Error')
        .firstMatch(message.trim());
    return match?.group(0) ?? 'UnhandledError';
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
