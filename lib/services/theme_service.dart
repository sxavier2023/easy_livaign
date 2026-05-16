import 'package:flutter/material.dart';

enum AppThemeChoice { light, dark, berlin, goth, halloween }

class ThemeService {
  ThemeService._();

  static final ValueNotifier<AppThemeChoice> selectedTheme =
      ValueNotifier<AppThemeChoice>(AppThemeChoice.light);

  static String label(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.light => 'Light',
      AppThemeChoice.dark => 'Dark',
      AppThemeChoice.berlin => 'Berlin',
      AppThemeChoice.goth => 'Goth',
      AppThemeChoice.halloween => 'Halloween',
    };
  }

  static IconData icon(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.light => Icons.light_mode,
      AppThemeChoice.dark => Icons.dark_mode,
      AppThemeChoice.berlin => Icons.location_city,
      AppThemeChoice.goth => Icons.nightlight,
      AppThemeChoice.halloween => Icons.local_fire_department,
    };
  }

  static ThemeData themeData(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.light => _theme(
        brightness: Brightness.light,
        seed: const Color(0xFF4F63E7),
        surface: const Color(0xFFF8FAFC),
      ),
      AppThemeChoice.dark => _theme(
        brightness: Brightness.dark,
        seed: const Color(0xFF7C8CFF),
        surface: const Color(0xFF101623),
      ),
      AppThemeChoice.berlin => _theme(
        brightness: Brightness.light,
        seed: const Color(0xFFD00000),
        surface: const Color(0xFFF7F2E8),
      ),
      AppThemeChoice.goth => _theme(
        brightness: Brightness.dark,
        seed: const Color(0xFF8B5CF6),
        surface: const Color(0xFF0D0A12),
      ),
      AppThemeChoice.halloween => _theme(
        brightness: Brightness.dark,
        seed: const Color(0xFFFF7A1A),
        surface: const Color(0xFF181008),
      ),
    };
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color seed,
    required Color surface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: surface.withValues(alpha: 0.94),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.72),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
