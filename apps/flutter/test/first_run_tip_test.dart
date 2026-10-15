import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/services/first_run_tip.dart';

void main() {
  test('FirstRunTip shouldShow is false until loaded as unseen', () {
    final tip = FirstRunTip.instance;
    tip.resetForTest(seen: null);
    expect(tip.isLoaded, isFalse);
    tip.resetForTest(seen: false);
    expect(tip.shouldShow, isTrue);
    tip.resetForTest(seen: true);
    expect(tip.shouldShow, isFalse);
  });

  test('dismiss marks tip as seen in memory', () async {
    final tip = FirstRunTip.instance;
    tip.resetForTest(seen: false);
    expect(tip.shouldShow, isTrue);
    tip.resetForTest(seen: true);
    expect(tip.shouldShow, isFalse);
  });
}
