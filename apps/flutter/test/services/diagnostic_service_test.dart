import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/diagnostic_service.dart';

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

      expect((safe['reason'] as String).length, 120);
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
}
