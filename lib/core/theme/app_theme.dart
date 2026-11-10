/// بناء ThemeData لتطبيق غلوارا من لوحة الألوان المختارة (نظام Serene Glow).
///
/// الشكل: كبسولات للأزرار والوسوم، وزوايا واسعة للبطاقات والنوافذ، وظلال موف
/// ناعمة بدل الظلال القاسية، وحدود رفيعة دافئة، وإطار ذهبي عند التركيز.
library glowara.app_theme;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'glow_theme.dart';

export 'glow_theme.dart';

/// أنصاف أقطار موحّدة (من نظام التصميم).
class GlowRadius {
  GlowRadius._();

  static const double sm = 8;
  static const double md = 16;
  static const double card = 24;
  static const double sheet = 32;
  static const double input = 20;
  static const double pill = 999;
}

/// لوحات الألوان والثيمات المتاحة في التطبيق.
class AppThemes {
  AppThemes._();

  /// اللوحة حسب المعرّف (أو الأولى إن لم يوجد).
  static GlowPalette palette(String id) => GlowThemes.byId(id);

  /// معرّفات اللوحات المتاحة.
  static List<String> ids() => GlowThemes.ids();

  /// بناء ThemeData من لوحة وسطوع ولغة.
  ///
  /// [locale] يحدد الخط: Tajawal للعربية وPlus Jakarta Sans للإنجليزية.
  /// الخطوط تُجلب عبر `google_fonts` عند أول استخدام وتُخزَّن محليًا، وإلى أن
  /// تصل (أو دون إنترنت) يُعرض خط النظام. مرّري [webFonts] = false لتعطيل ذلك
  /// (الاختبارات).
  static ThemeData material(
    String paletteId,
    Brightness brightness, {
    String locale = 'ar',
    bool webFonts = true,
  }) {
    final p = palette(paletteId);
    final c = brightness == Brightness.light ? p.light : p.dark;
    final text = _applyFont(_textTheme(c, locale), locale, webFonts);
    final isLight = brightness == Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.scaffold,
      cardColor: c.surface,
      dividerColor: c.border,
      shadowColor: c.shadow,
      highlightColor: c.primary.withValues(alpha: 0.08),
      splashColor: c.primary.withValues(alpha: 0.10),
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
        tertiary: c.lilac,
        onTertiary: isLight ? c.onSurface : c.scaffold,
        surface: c.surface,
        onSurface: c.onSurface,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surfaceAlt,
        surfaceContainerHigh: c.surfaceAlt,
        surfaceContainerHighest: c.surfaceAlt,
        onSurfaceVariant: c.onSurfaceVariant,
        error: c.danger,
        onError: isLight ? Colors.white : c.scaffold,
        outline: c.border,
        outlineVariant: c.border.withValues(alpha: 0.6),
        inverseSurface: c.onSurface,
        onInverseSurface: c.scaffold,
        inversePrimary: c.primaryContainer,
        surfaceTint: Colors.transparent,
      ),
      extensions: [GlowThemeExtension(colors: c)],
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffold,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlowRadius.card),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlowRadius.sheet),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.scaffold,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.scaffold,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(GlowRadius.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.scaffold),
        actionTextColor: c.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlowRadius.md)),
      ),
      inputDecorationTheme: _inputDecorationTheme(c, text, isLight),
      elevatedButtonTheme: _elevatedButtonTheme(c, text),
      filledButtonTheme: _filledButtonTheme(c, text),
      outlinedButtonTheme: _outlinedButtonTheme(c, text),
      textButtonTheme: _textButtonTheme(c, text),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.onSurfaceVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: c.border)),
          textStyle: WidgetStatePropertyAll<TextStyle?>(
            text.labelLarge?.copyWith(fontSize: 13),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            return states.contains(WidgetState.selected) ? c.primary : c.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            return states.contains(WidgetState.selected) ? c.onPrimary : c.onSurfaceVariant;
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: c.border),
        backgroundColor: c.surfaceAlt,
        selectedColor: c.primary,
        labelStyle: text.labelMedium?.copyWith(color: c.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlowRadius.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primaryContainer,
        circularTrackColor: c.primaryContainer,
        linearMinHeight: 8,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color?>(c.onPrimary),
        side: BorderSide(color: c.onSurfaceVariant.withValues(alpha: 0.7), width: 1.5),
        shape: const CircleBorder(),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.onPrimary;
          return isLight ? Colors.white : c.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(GlowRadius.sm),
        ),
        textStyle: TextStyle(color: c.scaffold, fontSize: 13),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlowRadius.md)),
      ),
    );

    return base;
  }

  /// يطبّق عائلة الخط على نص كامل مع الحفاظ على الأحجام والألوان.
  static TextTheme _applyFont(TextTheme base, String locale, bool webFonts) {
    if (!webFonts) return base;
    return locale == 'ar'
        ? GoogleFonts.tajawalTextTheme(base)
        : GoogleFonts.plusJakartaSansTextTheme(base);
  }

  /// سلّم الخطوط من نظام التصميم. العربية تأخذ ارتفاع سطر أكبر قليلًا
  /// (حركات التشكيل والصواعد والنوازل).
  static TextTheme _textTheme(GlowColors c, String locale) {
    final ar = locale == 'ar';
    double h(double latin, double arabic) => ar ? arabic : latin;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: c.onSurface,
        letterSpacing: ar ? 0 : -0.7,
        height: h(1.22, 1.35),
      ),
      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        letterSpacing: ar ? 0 : -0.45,
        height: h(1.25, 1.4),
      ),
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: c.onSurface,
        letterSpacing: ar ? 0 : -0.25,
        height: h(1.3, 1.45),
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: h(1.27, 1.4),
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: h(1.27, 1.4),
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: h(1.3, 1.45),
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: c.onSurface,
        height: h(1.35, 1.5),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        height: h(1.4, 1.55),
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.onSurfaceVariant,
        height: h(1.4, 1.55),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: c.onSurface,
        height: h(1.5, 1.65),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: c.onSurface,
        height: h(1.45, 1.65),
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: c.onSurfaceVariant,
        height: h(1.45, 1.6),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.onSurface,
        letterSpacing: ar ? 0 : 0.15,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.onSurfaceVariant,
        letterSpacing: ar ? 0 : 0.25,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: c.onSurfaceVariant,
        letterSpacing: ar ? 0 : 0.25,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(GlowColors c, TextTheme t, bool isLight) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GlowRadius.input),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      // أبيض ناصع في النهاري، وسطح مرفوع في الليلي.
      fillColor: isLight ? c.surface : c.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.75)),
      labelStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant, fontSize: 15),
      errorStyle: t.bodySmall?.copyWith(color: c.danger, fontSize: 12, height: 1.3),
      enabledBorder: border(c.border, 1.2),
      // توهّج شمبانيا ذهبي عند التركيز.
      focusedBorder: border(c.gold, 1.8),
      errorBorder: border(c.danger, 1.2),
      focusedErrorBorder: border(c.danger, 1.8),
      disabledBorder: border(c.border.withValues(alpha: 0.5), 1.2),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(GlowColors c, TextTheme t) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 3,
        // وهج برقوقي ناعم تحت الزر الرئيسي.
        shadowColor: c.primary.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: t.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(GlowColors c, TextTheme t) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: t.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(GlowColors c, TextTheme t) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        // إطار وردي ناعم بدل الإطار الداكن.
        side: BorderSide(color: c.blush, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: t.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(GlowColors c, TextTheme t) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
