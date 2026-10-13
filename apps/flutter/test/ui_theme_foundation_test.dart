import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordin/ui/theme.dart';

void main() {
  group('AppTheme blue design foundation', () {
    final theme = AppTheme.dark();

    test('uses the Ordin blue as its primary interaction color', () {
      expect(AppTheme.seed, AppTheme.brandBlue);
      expect(AppTheme.amber, AppTheme.brandBlue);
      expect(theme.colorScheme.primary, AppTheme.brandBlue);
      expect(theme.floatingActionButtonTheme.backgroundColor, AppTheme.brandBlue);
      expect(theme.progressIndicatorTheme.color, AppTheme.brandBlue);
    });

    test('keeps readable dark surfaces and selected-state contrast', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppTheme.bgDeep);
      expect(theme.colorScheme.onSurface, AppTheme.silver);
      expect(theme.navigationBarTheme.indicatorColor, AppTheme.brandBlueContainer);
      expect(theme.chipTheme.selectedColor, AppTheme.brandBlueContainer);
    });

    test('uses a blue focus border and consistent rounded inputs', () {
      final decoration = theme.inputDecorationTheme;
      final focusedBorder = decoration.focusedBorder;

      expect(focusedBorder, isA<OutlineInputBorder>());
      expect((focusedBorder! as OutlineInputBorder).borderSide.color,
          AppTheme.brandBlue);
      expect((focusedBorder as OutlineInputBorder).borderRadius,
          BorderRadius.circular(14));
    });
  });
}
