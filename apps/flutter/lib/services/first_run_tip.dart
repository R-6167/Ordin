import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists whether the short first-run tip was dismissed.
///
/// Uses a documents-directory flag file so no schema migration is required.
class FirstRunTip {
  FirstRunTip._();
  static final instance = FirstRunTip._();

  static const fileName = 'ordin_first_run_tip_seen';

  bool? _seen;

  bool get isLoaded => _seen != null;
  bool get shouldShow => _seen == false;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$fileName');
      _seen = await f.exists();
    } catch (_) {
      _seen = true; // fail closed: never block the UI on storage errors
    }
  }

  Future<void> dismiss() async {
    _seen = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$fileName');
      await f.writeAsString('1', flush: true);
    } catch (_) {}
  }

  /// Test-only: reset in-memory state without touching disk.
  void resetForTest({bool? seen}) {
    _seen = seen;
  }
}
