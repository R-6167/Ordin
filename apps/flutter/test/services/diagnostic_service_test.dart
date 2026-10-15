import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/diagnostic_service.dart';
import 'package:ordin/services/error_log_service.dart';

void main() {
  group('DiagnosticService privacy filtering', () {
    test('keeps only explicitly allow-listed operational details', () {
      final safe = DiagnosticService.sanitizeDetailsForTesting({
        'route': '/tasks',
        'operation': 'reload',
        'count': 3,
        'duration_ms': 42,
        'title': 'private task title',
        'description': 'private description',
        'amount': 5000,
        'email': 'person@example.com',
        'token': 'secret',
      });

      expect(safe, {
        'route': '/tasks',
        'operation': 'reload',
        'count': 3,
        'duration_ms': 42,
      });
      expect(safe.values, isNot(contains('private task title')));
      expect(safe.values, isNot(contains('person@example.com')));
    });

    test('bounds long allow-listed string values', () {
      final safe = DiagnosticService.sanitizeDetailsForTesting({
        'reason': List<String>.filled(500, 'x').join(),
      });

      // Matches DiagnosticService._safeDetails string cap (richer release errors).
      expect((safe['reason'] as String).length, 160);
    });

    test('drops unrecognized values and object payloads', () {
      final safe = DiagnosticService.sanitizeDetailsForTesting({
        'source': {'arbitrary': 'payload'},
        'widget': 'HomeShell',
        'raw_event': 'not allowed',
      });

      expect(safe, {'widget': 'HomeShell'});
    });
  });

  group('ErrorLogService safe error fingerprints', () {
  test('extracts exception type after softFuture operation prefix', () {
    expect(
      ErrorLogService.errorTypeForTesting(
        'tasks.open: DatabaseException(1: no such column: tasks.foo)',
      ),
      'DatabaseException',
    );
  });

  test('preserves stable operation label instead of generic SOFT level', () {
    expect(
      ErrorLogService.operationForTesting(
        'tasks.open: DatabaseException(private SQL and values)',
        fallback: 'SOFT',
      ),
      'tasks.open',
    );
  });

  test('does not mistake an unprefixed exception for an operation label', () {
    expect(
      ErrorLogService.operationForTesting('DatabaseException(details)', fallback: 'ZONE'),
      'ZONE',
    );
    expect(ErrorLogService.errorTypeForTesting('unexpected failure'), 'UnhandledError');
  });
  });
}
