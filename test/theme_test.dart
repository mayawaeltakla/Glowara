import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/theme/app_theme.dart';

/// نسبة التباين WCAG بين لونين.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('Serene Glow is the first and default palette', () {
    expect(AppThemes.ids().first, 'serene');
    expect(AppThemes.palette('serene').nameEn, 'Serene Glow');
    // معرّف غير معروف يعود إلى الافتراضي.
    expect(AppThemes.palette('does-not-exist').id, 'serene');
  });

  group('every palette builds a theme in both modes', () {
    for (final id in AppThemes.ids()) {
      for (final brightness in Brightness.values) {
        for (final locale in <String>['ar', 'en']) {
          test('$id / ${brightness.name} / $locale', () {
            final theme = AppThemes.material(id, brightness, locale: locale, webFonts: false);
            expect(theme.brightness, brightness);
            expect(theme.useMaterial3, isTrue);
            final colors = theme.extension<GlowThemeExtension>()!.colors;
            expect(theme.colorScheme.primary, colors.primary);
            expect(theme.scaffoldBackgroundColor, colors.scaffold);
            expect(theme.textTheme.bodyMedium?.color, colors.onSurface);
          });
        }
      }
    }
  });

  group('Serene Glow text contrast meets WCAG AA (4.5:1)', () {
    final palette = AppThemes.palette('serene');
    final modes = <String, GlowColors>{'light': palette.light, 'dark': palette.dark};

    modes.forEach((mode, c) {
      final pairs = <String, List<Color>>{
        'onSurface on scaffold': [c.onSurface, c.scaffold],
        'onSurface on surface': [c.onSurface, c.surface],
        'onSurface on surfaceAlt': [c.onSurface, c.surfaceAlt],
        'onSurface on primaryContainer': [c.onSurface, c.primaryContainer],
        'onSurfaceVariant on scaffold': [c.onSurfaceVariant, c.scaffold],
        'onSurfaceVariant on surface': [c.onSurfaceVariant, c.surface],
        'onSurfaceVariant on surfaceAlt': [c.onSurfaceVariant, c.surfaceAlt],
        'onPrimary on primary': [c.onPrimary, c.primary],
        'primary on scaffold': [c.primary, c.scaffold],
        'primary on surface': [c.primary, c.surface],
        'primary on surfaceAlt': [c.primary, c.surfaceAlt],
        'onGold on gold': [c.onGold, c.gold],
        'success on surface': [c.success, c.surface],
        'warning on surface': [c.warning, c.surface],
        'danger on surface': [c.danger, c.surface],
        'white on hero gradient start': [Colors.white, c.heroGradient.colors.first],
        'white on hero gradient end': [Colors.white, c.heroGradient.colors.last],
      };
      pairs.forEach((name, colors) {
        test('$mode: $name', () {
          expect(contrast(colors[0], colors[1]), greaterThanOrEqualTo(4.5));
        });
      });
    });
  });

  test('Arabic text uses taller lines than English for diacritics', () {
    final ar = AppThemes.material('serene', Brightness.light, locale: 'ar', webFonts: false);
    final en = AppThemes.material('serene', Brightness.light, locale: 'en', webFonts: false);
    expect(ar.textTheme.bodyMedium!.height!, greaterThan(en.textTheme.bodyMedium!.height!));
    expect(ar.textTheme.bodyLarge!.height!, greaterThan(en.textTheme.bodyLarge!.height!));
  });
}
