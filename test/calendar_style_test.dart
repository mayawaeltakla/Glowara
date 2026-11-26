import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/extra_strings.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/theme/glow_theme.dart';
import 'package:glowara/features/calendar/calendar_style.dart';
import 'package:flutter/painting.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('every layer mark reaches 3:1 against the card in all themes and modes', () {
    for (final palette in GlowThemes.all) {
      for (final entry in <String, GlowColors>{'light': palette.light, 'dark': palette.dark}.entries) {
        for (final layer in CalendarLayer.values) {
          final ratio = _contrast(layerColor(entry.value, layer), entry.value.surface);
          expect(ratio, greaterThanOrEqualTo(3.0), reason: '${palette.id}/${entry.key}/${layer.name}: $ratio');
        }
      }
    }
  });

  test('each layer has its own shape, so color is never the only cue', () {
    final shapes = CalendarLayer.values.map(layerShape).toSet();
    expect(shapes.length, CalendarLayer.values.length);
  });

  test('the calendar has no layer for journals or mood', () {
    final names = CalendarLayer.values.map((l) => l.name).toSet();
    expect(names, <String>{'tasks', 'study', 'habits', 'worship', 'care', 'nutrition'});
  });

  test('every label and screen string exists in Arabic and English', () {
    final ar = extraStrings['ar']!;
    final en = extraStrings['en']!;
    for (final layer in CalendarLayer.values) {
      expect(ar.containsKey(layerLabelKey(layer)), isTrue, reason: layerLabelKey(layer));
      expect(en.containsKey(layerLabelKey(layer)), isTrue, reason: layerLabelKey(layer));
    }
    final arCal = ar.keys.where((k) => k.startsWith('cal')).toSet();
    final enCal = en.keys.where((k) => k.startsWith('cal')).toSet();
    expect(arCal, enCal);
    expect(arCal, contains('calendarTitle'));
  });

  test('calendar strings stay neutral: no score words', () {
    for (final lang in <String>['ar', 'en']) {
      final texts = extraStrings[lang]!
          .entries
          .where((e) => e.key.startsWith('cal'))
          .map((e) => e.value.toLowerCase())
          .join(' ');
      for (final banned in <String>['score', 'rating', 'points', 'درجة', 'نقاط', 'فاتك', 'missed']) {
        // «ليست تقييماً ولا درجة» في دليل العلامات تنفي التقييم عمدًا.
        final allowed = texts.replaceAll('not a score or a rating', '').replaceAll('ليست تقييماً ولا درجة', '');
        expect(allowed.contains(banned), isFalse, reason: '$lang contains "$banned"');
      }
    }
  });
}
