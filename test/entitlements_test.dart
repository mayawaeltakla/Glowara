import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/models/entitlements.dart';

void main() {
  group('launch defaults', () {
    test('everything is enabled in this version', () {
      const service = EntitlementService.launch();
      for (final f in GlowFeature.values) {
        expect(service.isEnabled(f), isTrue, reason: f.name);
      }
    });
  });

  group('fixed protections', () {
    const lockedDown = EntitlementService(EntitlementSnapshot.protectedOnly());

    test('worship, Quran, adhkar and duas can never be closed', () {
      for (final f in <GlowFeature>[GlowFeature.worship, GlowFeature.quran, GlowFeature.adhkar, GlowFeature.duas]) {
        expect(f.protected, isTrue, reason: f.name);
        expect(lockedDown.isEnabled(f), isTrue, reason: f.name);
      }
    });

    test('the basics stay free even with nothing unlocked', () {
      for (final f in <GlowFeature>[
        GlowFeature.tasks,
        GlowFeature.habits,
        GlowFeature.calendar,
        GlowFeature.study,
        GlowFeature.care,
        GlowFeature.journalAndMood,
        GlowFeature.water,
        GlowFeature.meals,
        GlowFeature.englishBasics,
      ]) {
        expect(lockedDown.isEnabled(f), isTrue, reason: f.name);
      }
    });

    test('extendable features follow the snapshot', () {
      const some = EntitlementService(EntitlementSnapshot(unlocked: <GlowFeature>{GlowFeature.dreams}));
      expect(some.isEnabled(GlowFeature.dreams), isTrue);
      expect(some.isEnabled(GlowFeature.routines), isFalse);
      expect(lockedDown.isEnabled(GlowFeature.dashboard), isFalse);
    });

    test('a user\'s own data is never locked, whatever is unlocked', () {
      for (final f in GlowFeature.values) {
        expect(lockedDown.canAccessOwnData(f), isTrue, reason: f.name);
      }
    });
  });

  group('no selling before it exists', () {
    test('the app contains no sales, trial or subscription wording', () {
      final banned = RegExp(r'(glowara plus|\bplus\b(?! jakarta)|اشتراك|subscription|premium|بريميوم|free trial|تجربة مجانية|upgrade|ترقية)', caseSensitive: false);
      final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final f in files) {
        if (f.path.endsWith('entitlements.dart')) continue; // التعليقات التوضيحية
        final text = f.readAsStringSync();
        expect(banned.hasMatch(text), isFalse, reason: f.path);
      }
    });

    test('no payment or analytics packages are declared', () {
      final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
      for (final word in <String>['in_app_purchase', 'purchases_flutter', 'stripe', 'firebase_analytics', 'sentry', 'mixpanel', 'amplitude']) {
        expect(pubspec.contains(word), isFalse, reason: word);
      }
    });
  });
}
