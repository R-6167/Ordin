import 'package:flutter/material.dart';

/// Ordin's semantic color tokens.
///
/// The supplied logo uses a cool blue accent. Keep color roles centralized
/// here so the final sampled brand value can be tuned without scattering
/// literals across screens. Legacy names remain as compatibility aliases
/// while older screens migrate to semantic names.
class AppTheme {
  /// Brand accent and its darker interaction variant.
  static const brandBlue = Color(0xFF6EA8FF);
  static const brandBlueDeep = Color(0xFF3D82E8);
  static const brandBlueContainer = Color(0x336EA8FF);
  static const brandBlueSoft = Color(0xFFB9D5FF);

  /// Cool metallic grey / silver neutrals.
  static const silver = Color(0xFFC5CBD3);
  static const silverMuted = Color(0xFF9AA3AD);
  static const metal = Color(0xFF252D39);
  static const metalDeep = Color(0xFF111923);
  static const surfaceRaised = Color(0xFF202B39);

  /// Warm wood is retained only for legacy surfaces; avoid using it as a
  /// primary interaction color in new UI.
  static const wood = Color(0xFF8B5A3C);
  static const woodDeep = Color(0xFF5C3A28);
  static const woodLight = Color(0xFFB07A55);

  /// Compatibility aliases for existing screens. New code should use
  /// brandBlue / brandBlueDeep.
  static const amber = brandBlue;
  static const amberDeep = brandBlueDeep;

  static const seed = brandBlue;
  static const bgDeep = metalDeep;
  static const bgMid = metal;
  static const glassFill = Color(0x182F5F9E);
  static const glassBorder = Color(0x334E83C4);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: Brightness.dark,
      primary: brandBlue,
      onPrimary: const Color(0xFF07182E),
      primaryContainer: const Color(0xFF234B78),
      onPrimaryContainer: const Color(0xFFDCEBFF),
      secondary: silver,
      onSecondary: metalDeep,
      tertiary: const Color(0xFF8DB9F5),
      onTertiary: const Color(0xFF0D2038),
      surface: metal,
      onSurface: silver,
      surfaceContainerHighest: surfaceRaised,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgDeep,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: silver,
        iconTheme: IconThemeData(color: silver),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: metal.withValues(alpha: 0.96),
        indicatorColor: brandBlueContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: silver.withValues(alpha: 0.9)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return const IconThemeData(color: brandBlue);
          }
          return IconThemeData(color: silver.withValues(alpha: 0.7));
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandBlue,
        foregroundColor: const Color(0xFF07182E),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: const Color(0xFF07182E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised.withValues(alpha: 0.78),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: silver.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: silver.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandBlue, width: 1.6),
        ),
        hintStyle: TextStyle(color: silver.withValues(alpha: 0.48)),
        labelStyle: TextStyle(color: silver.withValues(alpha: 0.76)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: brandBlueContainer,
        side: BorderSide(color: silver.withValues(alpha: 0.18)),
        labelStyle: const TextStyle(color: silver),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: silver),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: silver,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: silver.withValues(alpha: 0.88), fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: silverMuted,
        textColor: silver,
      ),
      dividerTheme: DividerThemeData(
        color: silver.withValues(alpha: 0.12),
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandBlue,
        linearTrackColor: Color(0x334E83C4),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
