/// بناء ThemeData لتطبيق غلوارا من لوحة الألوان المختارة.
library glowara.app_theme;

import 'package:flutter/material.dart';
import 'glow_theme.dart';

export 'glow_theme.dart';

/// عائلة الخطوط المستخدمة في التطبيق.
/// لا تعتمد على خطوط خارجية مضمّنة؛ تستخدم خط النظام العربي المريح
/// مع بدائل لاتينية متناسقة، وتستعيد الخط الافتراضي إن لم يتوفر.
class _AppFonts {
  _AppFonts._();
  static const String display = 'Georgia';
  static const List<String> bodyFallback = <String>[
    'Roboto',
    'Noto Naskh Arabic',
    'Noto Sans Arabic',
    'system-ui',
    'sans-serif',
  ];
}

/// لوحات الألوان والثيمات المتاحة في التطبيق.
class AppThemes {
  AppThemes._();

  /// اللوحة حسب المعرّف (أو الأولى إن لم يوجد).
  static GlowPalette palette(String id) => GlowThemes.byId(id);

  /// معرّفات اللوحات المتاحة.
  static List<String> ids() => GlowThemes.ids();

  /// بناء ThemeData من لوحة وسطوع معين.
  static ThemeData material(String paletteId, Brightness brightness) {
    final c = palette(paletteId).colors(brightness);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.scaffold,
      cardColor: c.surface,
      dividerColor: c.border,
      shadowColor: c.shadow,
      highlightColor: c.primary.withOpacity(0.10),
      splashColor: c.primary.withOpacity(0.12),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onSurface,
        secondary: c.gold,
        onSecondary: c.onGold,
        secondaryContainer: c.primaryContainer,
        onSecondaryContainer: c.onSurface,
        tertiary: c.success,
        onTertiary: c.onSurface,
        surface: c.surface,
        onSurface: c.onSurface,
        surfaceContainerHighest: c.surfaceAlt,
        onSurfaceVariant: c.onSurfaceVariant,
        error: c.danger,
        onError: c.onSurface,
        outline: c.border,
        outlineVariant: c.border.withOpacity(0.45),
        inverseSurface: c.surface,
        onInverseSurface: c.onSurface,
        inversePrimary: c.primaryContainer,
        surfaceTint: c.primary.withOpacity(0.18),
      ),
      extensions: [GlowThemeExtension(colors: c)],
      textTheme: _textTheme(c),
      inputDecorationTheme: _inputDecorationTheme(c),
      elevatedButtonTheme: _elevatedButtonTheme(c),
      outlinedButtonTheme: _outlinedButtonTheme(c),
      textButtonTheme: _textButtonTheme(c),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.primary,
        unselectedItemColor: c.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) return c.primary;
          return c.surface;
        }),
        checkColor: c.onPrimary,
        side: BorderSide(color: c.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) return c.primary;
          return c.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) return c.primary;
          return c.onSurfaceVariant;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) return c.primary.withOpacity(0.5);
          return c.border;
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.onSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: c.scaffold, fontSize: 13),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return base;
  }

  static TextTheme _textTheme(GlowColors c) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _AppFonts.display,
        fontFamilyFallback: _AppFonts.bodyFallback,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: c.onSurface,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontFamily: _AppFonts.display,
        fontFamilyFallback: _AppFonts.bodyFallback,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: _AppFonts.display,
        fontFamilyFallback: _AppFonts.bodyFallback,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: c.onSurface,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: _AppFonts.display,
        fontFamilyFallback: _AppFonts.bodyFallback,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: c.onSurface,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.onSurfaceVariant,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: c.onSurface,
        height: 1.6,
        fontFamilyFallback: _AppFonts.bodyFallback,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: c.onSurface,
        height: 1.6,
        fontFamilyFallback: _AppFonts.bodyFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: c.onSurfaceVariant,
        height: 1.5,
        fontFamilyFallback: _AppFonts.bodyFallback,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: c.onSurfaceVariant,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(GlowColors c) {
    return InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: TextStyle(color: c.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
      labelStyle: TextStyle(color: c.onSurfaceVariant, fontSize: 15),
      errorStyle: TextStyle(color: c.danger, fontSize: 12, height: 1.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.danger, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.border.withOpacity(0.5), width: 1.2),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(GlowColors c) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        shadowColor: c.shadow,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(GlowColors c) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.primary, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(GlowColors c) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
