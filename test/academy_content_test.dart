// سلامة محتوى الأكاديمية (ملف الأصول). المحتوى كتبه Claude نصًّا أصليًا، وهذه
// الاختبارات تمسك الأخطاء البنيوية والتناقضات الظاهرة. المراجعة اللغوية تبقى لـ Maya
// عبر docs/ACADEMY_A1_CONTENT_REVIEW_AR.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/services/academy_content.dart';

final RegExp _arabic = RegExp(r'[؀-ۿ]');
final RegExp _diacritics = RegExp(r'[ً-ْـ]');

String _plain(String s) => s.replaceAll(_diacritics, '').trim();

AcademyCurriculum _load() => AcademyContent.parse(File(AcademyContent.a1Asset).readAsStringSync());

void main() {
  late AcademyCurriculum curriculum;

  setUpAll(() => curriculum = _load());

  test('the asset is declared in pubspec so it ships offline in the app', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains(AcademyContent.a1Asset));
  });

  test('twelve A1 units in order, with safe unique ids', () {
    expect(curriculum.level, 'A1');
    expect(curriculum.units, hasLength(12));
    expect(curriculum.units.map((u) => u.order), List<int>.generate(12, (i) => i + 1));
    final ids = curriculum.units.map((u) => u.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id.contains('_'), isFalse, reason: '$id goes into <userId>_<unitId> keys');
    }
    expect(curriculum.unit('a1-u01')!.titleEn, 'Greetings and Introductions');
    expect(curriculum.unit('nope'), isNull);
  });

  test('every unit has the full shape', () {
    for (final u in curriculum.units) {
      expect(u.vocab, hasLength(10), reason: u.id);
      expect(u.phrases.length, inInclusiveRange(4, 6), reason: u.id);
      expect(u.grammar.examples, hasLength(3), reason: u.id);
      expect(u.questions, hasLength(8), reason: u.id);
      expect(u.grammar.bodyAr, isNotEmpty);
      final words = u.vocab.map((w) => w.en).toList();
      expect(words.toSet().length, words.length, reason: '${u.id} duplicate vocabulary');
    }
  });

  test('English fields are English and Arabic fields are Arabic', () {
    for (final u in curriculum.units) {
      expect(_arabic.hasMatch(u.titleEn), isFalse, reason: u.id);
      expect(_arabic.hasMatch(u.titleAr), isTrue, reason: u.id);
      expect(_arabic.hasMatch(u.summaryAr), isTrue, reason: u.id);
      for (final w in u.vocab) {
        expect(_arabic.hasMatch(w.en), isFalse, reason: '${u.id} ${w.en}');
        expect(_arabic.hasMatch(w.exEn), isFalse, reason: '${u.id} ${w.exEn}');
        expect(_arabic.hasMatch(w.ar), isTrue, reason: '${u.id} ${w.en}');
        expect(_arabic.hasMatch(w.exAr), isTrue, reason: '${u.id} ${w.en}');
      }
      for (final e in <AcademyExample>[...u.phrases, ...u.grammar.examples]) {
        expect(_arabic.hasMatch(e.en), isFalse, reason: '${u.id} ${e.en}');
        expect(_arabic.hasMatch(e.ar), isTrue, reason: '${u.id} ${e.en}');
      }
      expect(_arabic.hasMatch(u.grammar.bodyAr), isTrue, reason: u.id);
    }
  });

  test('every question is well formed', () {
    for (final u in curriculum.units) {
      final ids = u.questions.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length, reason: u.id);
      for (final q in u.questions) {
        expect(q.id.startsWith('${u.id}-q'), isTrue, reason: q.id);
        expect(q.options.length, inInclusiveRange(2, 4), reason: q.id);
        expect(q.options.toSet().length, q.options.length, reason: '${q.id} duplicate options');
        expect(q.answer, inInclusiveRange(0, q.options.length - 1), reason: q.id);
        expect(q.options.every((o) => o.trim().isNotEmpty), isTrue, reason: q.id);
        expect(_arabic.hasMatch(q.prompt), isTrue, reason: q.id);
        expect(_arabic.hasMatch(q.why), isTrue, reason: q.id);
      }
    }
  });

  test('"what does X mean" questions point at a real word and its real translation', () {
    final pattern = RegExp(r'^ما معنى "([^" ]+)"');
    var checked = 0;
    for (final u in curriculum.units) {
      final unitText = <String>[
        ...u.vocab.map((w) => '${w.en} ${w.exEn}'),
        ...u.phrases.map((p) => p.en),
        ...u.grammar.examples.map((e) => e.en),
      ].join(' ').toLowerCase();
      for (final q in u.questions) {
        final m = pattern.firstMatch(q.prompt);
        if (m == null) continue;
        final word = m.group(1)!;
        expect(unitText.contains(word.toLowerCase()), isTrue, reason: '${q.id} asks about "$word", not in the unit');
        final vocab = u.vocab.where((w) => w.en.toLowerCase() == word.toLowerCase()).toList();
        if (vocab.isEmpty) continue;
        final expected = _plain(vocab.first.ar).split(RegExp(r'[\s()]+')).where((t) => t.isNotEmpty).toSet();
        final given = _plain(q.correctOption).split(RegExp(r'[\s()]+')).where((t) => t.isNotEmpty);
        expect(given.every(expected.contains), isTrue,
            reason: '${q.id}: correct option "${q.correctOption}" does not match "${vocab.first.ar}"');
        checked++;
      }
    }
    expect(checked, greaterThan(20), reason: 'the check must really run');
  });

  test('no sensitive topics in the English content', () {
    final text = <String>[
      for (final u in curriculum.units) ...<String>[
        u.titleEn,
        ...u.vocab.expand((w) => <String>[w.en, w.exEn]),
        ...u.phrases.map((p) => p.en),
        ...u.grammar.examples.map((e) => e.en),
        ...u.questions.expand((q) => q.options),
      ],
    ].join(' ').toLowerCase();
    for (final word in <String>[
      'alcohol', 'wine', 'beer', 'vodka', 'whisky', 'pork', 'bacon', 'ham', 'pig',
      'boyfriend', 'girlfriend', 'dating', 'kiss', 'drunk', 'party', 'bar',
    ]) {
      expect(RegExp('\\b$word\\b').hasMatch(text), isFalse, reason: word);
    }
  });

  test('the Arabic review document lists every unit and word', () {
    final doc = File('docs/ACADEMY_A1_CONTENT_REVIEW_AR.md').readAsStringSync();
    for (final u in curriculum.units) {
      expect(doc, contains(u.titleEn), reason: u.id);
      expect(doc, contains(u.titleAr), reason: u.id);
      for (final w in u.vocab) {
        expect(doc, contains(w.en), reason: '${u.id} ${w.en}');
      }
    }
  });
}
