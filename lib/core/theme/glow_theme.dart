/// مكتبة ثيم غلوارا — لوحة ألوان أنثوية راقية (وردي غباري، ذهبي، كريمي)
/// مع دعم كامل للوضعين النهاري والليلي وثلاثة ثيمات قابلة للتغيير.
library glowara.theme;

import 'package:flutter/material.dart';

/// لوحة ألوان واحدة (هوية بصرية كاملة) في وضع الإضاءة والظلام.
class GlowPalette {
  const GlowPalette({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.light,
    required this.dark,
  });

  /// معرّف الثيم المستخدم في الإعدادات والتخزين.
  final String id;
  /// اسم الثيم بالعربية.
  final String nameAr;
  /// اسم الثيم بالإنجليزية.
  final String nameEn;
  /// ألوان الوضع النهاري.
  final GlowColors light;
  /// ألوان الوضع الليلي.
  final GlowColors dark;
}

/// جميع الألوان المطلوبة لوحدة إضاءة واحدة من لوحة واحدة.
class GlowColors {
  const GlowColors({
    required this.scaffold,
    required this.surface,
    required this.surfaceAlt,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.gold,
    required this.onGold,
    required this.success,
    required this.warning,
    required this.danger,
    required this.border,
    required this.shadow,
    required this.heroGradient,
  });

  /// خلفية الشاشة الأساسية.
  final Color scaffold;
  /// بطاقات ومحتوى فوق السطح.
  final Color surface;
  /// سطح بديل مرفوع قليلًا.
  final Color surfaceAlt;

  /// النص الأساسي على السطح.
  final Color onSurface;
  /// النص الثانوي/المبهم.
  final Color onSurfaceVariant;

  /// اللون الأساسي للعلامة التجارية.
  final Color primary;
  /// النص على اللون الأساسي.
  final Color onPrimary;
  /// حاوية اللون الأساسي (درجة فاتحة منه).
  final Color primaryContainer;

  /// اللون المميز (الذهبي).
  final Color gold;
  /// النص على اللون الذهبي.
  final Color onGold;

  /// ألوان دلالية للحالة.
  final Color success;
  final Color warning;
  final Color danger;

  /// حدود وفواصل.
  final Color border;
  /// لون الظل المترافق.
  final Color shadow;

  /// تدرج بطلي من لونين (أعلى→أسفل).
  final LinearGradient heroGradient;
}

/// السجل المركزي لجميع الثيمات المدعومة.
class GlowThemes {
  GlowThemes._();

  static const _roseLight = GlowColors(
    scaffold: Color(0xFFFBF6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3E9EC),
    onSurface: Color(0xFF4A3A40),
    onSurfaceVariant: Color(0xFF8A6E78),
    primary: Color(0xFFC77E90),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF0DCE2),
    gold: Color(0xFFC9A46A),
    onGold: Color(0xFFFFFFFF),
    success: Color(0xFF7FA67F),
    warning: Color(0xFFD9A441),
    danger: Color(0xFFC98B94),
    border: Color(0xFFEAD9DF),
    shadow: Color(0x0F000000),
    heroGradient: GlowGradient.rose,
  );

  static const _roseDark = GlowColors(
    scaffold: Color(0xFF1A1418),
    surface: Color(0xFF231C20),
    surfaceAlt: Color(0xFF2C2329),
    onSurface: Color(0xFFF3E9EC),
    onSurfaceVariant: Color(0xFFC9AAB5),
    primary: Color(0xFFE0A8BA),
    onPrimary: Color(0xFF2B2326),
    primaryContainer: Color(0xFF3A2B33),
    gold: Color(0xFFD9B980),
    onGold: Color(0xFF2B2326),
    success: Color(0xFF8FBA8F),
    warning: Color(0xFFE2C17D),
    danger: Color(0xFFD99AA2),
    border: Color(0xFF3A3036),
    shadow: Color(0x38000000),
    heroGradient: GlowGradient.roseDark,
  );

  static const _lilacLight = GlowColors(
    scaffold: Color(0xFFFBF6FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0ECF6),
    onSurface: Color(0xFF463A50),
    onSurfaceVariant: Color(0xFF8E7E9B),
    primary: Color(0xFFA98BC4),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE9DFF1),
    gold: Color(0xFFC7A46A),
    onGold: Color(0xFFFFFFFF),
    success: Color(0xFF7FA67F),
    warning: Color(0xFFD9A441),
    danger: Color(0xFFC98B94),
    border: Color(0xFFE9DFEE),
    shadow: Color(0x0F000000),
    heroGradient: GlowGradient.lilac,
  );

  static const _lilacDark = GlowColors(
    scaffold: Color(0xFF18131D),
    surface: Color(0xFF211B28),
    surfaceAlt: Color(0xFF2A2232),
    onSurface: Color(0xFFF0ECF6),
    onSurfaceVariant: Color(0xFFCCC2DA),
    primary: Color(0xFFC5B0E0),
    onPrimary: Color(0xFF2B2330),
    primaryContainer: Color(0xFF3A2E4A),
    gold: Color(0xFFD9B980),
    onGold: Color(0xFF2B2330),
    success: Color(0xFF8FBA8F),
    warning: Color(0xFFE2C17D),
    danger: Color(0xFFD99AA2),
    border: Color(0xFF3A3042),
    shadow: Color(0x38000000),
    heroGradient: GlowGradient.lilacDark,
  );

  static const _sandLight = GlowColors(
    scaffold: Color(0xFFFCF7F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5EBDD),
    onSurface: Color(0xFF5A463C),
    onSurfaceVariant: Color(0xFF9C806F),
    primary: Color(0xFFC08A72),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEFDBD2),
    gold: Color(0xFFC9A05A),
    onGold: Color(0xFFFFFFFF),
    success: Color(0xFF7FA67F),
    warning: Color(0xFFD9A441),
    danger: Color(0xFFC98B94),
    border: Color(0xFFEAD9CE),
    shadow: Color(0x0F000000),
    heroGradient: GlowGradient.sand,
  );

  static const _sandDark = GlowColors(
    scaffold: Color(0xFF1A1410),
    surface: Color(0xFF231D18),
    surfaceAlt: Color(0xFF2C241D),
    onSurface: Color(0xFFF5EBDD),
    onSurfaceVariant: Color(0xFFC9A88E),
    primary: Color(0xFFD7A88B),
    onPrimary: Color(0xFF2B231C),
    primaryContainer: Color(0xFF4A362D),
    gold: Color(0xFFD9C080),
    onGold: Color(0xFF2B231C),
    success: Color(0xFF8FBA8F),
    warning: Color(0xFFE2C17D),
    danger: Color(0xFFD99AA2),
    border: Color(0xFF3A3024),
    shadow: Color(0x38000000),
    heroGradient: GlowGradient.sandDark,
  );

  /// كل الثيمات المتاحة.
  static const List<GlowPalette> all = <GlowPalette>[
    GlowPalette(
      id: 'rose',
      nameAr: 'الوردي الغباري',
      nameEn: 'Dusty Rose',
      light: _roseLight,
      dark: _roseDark,
    ),
    GlowPalette(
      id: 'lilac',
      nameAr: 'البنفسجي الفاتح',
      nameEn: 'Soft Lilac',
      light: _lilacLight,
      dark: _lilacDark,
    ),
    GlowPalette(
      id: 'sand',
      nameAr: 'الرملية الكريمية',
      nameEn: 'Cream Sand',
      light: _sandLight,
      dark: _sandDark,
    ),
  ];

  /// اللوحة حسب المعرّف (أو الأولى إن لم يوجد).
  static GlowPalette byId(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } on StateError {
      return all.first;
    }
  }

  /// معرّفات جميع اللوحات.
  static List<String> ids() => all.map((p) => p.id).toList();
}

/// تدرجات ثابتة تُستخدم داخل `GlowColors.heroGradient`.
class GlowGradient {
  GlowGradient._();

  static const LinearGradient rose = LinearGradient(
    colors: <Color>[
      Color(0xFFC77E90),
      Color(0xFFC9A46A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseDark = LinearGradient(
    colors: <Color>[
      Color(0xFFE0A8BA),
      Color(0xFFD9B980),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient lilac = LinearGradient(
    colors: <Color>[
      Color(0xFFA98BC4),
      Color(0xFFC7A46A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient lilacDark = LinearGradient(
    colors: <Color>[
      Color(0xFFC5B0E0),
      Color(0xFFD9B980),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient sand = LinearGradient(
    colors: <Color>[
      Color(0xFFC08A72),
      Color(0xFFC9A05A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient sandDark = LinearGradient(
    colors: <Color>[
      Color(0xFFD7A88B),
      Color(0xFFD9C080),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// امتداد ThemeExtension يحمل ألوان غلوارا للقراءة من أي سياق.
class GlowThemeExtension extends ThemeExtension<GlowThemeExtension> {
  const GlowThemeExtension({required this.colors});

  final GlowColors colors;

  @override
  GlowThemeExtension copyWith({GlowColors? colors}) {
    return GlowThemeExtension(colors: colors ?? this.colors);
  }

  @override
  GlowThemeExtension lerp(GlowThemeExtension? other, double t) {
    return this;
  }
}

/// قراءة ألوان الثيم الحالي من سياق البناء.
extension GlowThemeX on BuildContext {
  GlowColors get glowColors {
    final ext = Theme.of(this).extension<GlowThemeExtension>();
    return ext?.colors ??
        const GlowColors(
          scaffold: Color(0xFFFBF6F2),
          surface: Color(0xFFFFFFFF),
          surfaceAlt: Color(0xFFF3E9EC),
          onSurface: Color(0xFF4A3A40),
          onSurfaceVariant: Color(0xFF8A6E78),
          primary: Color(0xFFC77E90),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFF0DCE2),
          gold: Color(0xFFC9A46A),
          onGold: Color(0xFFFFFFFF),
          success: Color(0xFF7FA67F),
          warning: Color(0xFFD9A441),
          danger: Color(0xFFC98B94),
          border: Color(0xFFEAD9DF),
          shadow: Color(0x0F000000),
          heroGradient: GlowGradient.rose,
        );
  }
}
