/// يحمي الأذكار والأدعية التي أضافتها صاحبة المشروع من أي تغيير غير مقصود.
///
/// يحسب بصمة SHA-256 لنص القوائم في ملفات المصدر حرفيًا (بالتشكيل والترتيب
/// والتكرارات)، ويقارنها ببصمة ثابتة ونسخة احتياطية في `docs/content-backup/`.
/// إذا فشل هذا الاختبار فقد تغيّر نص ديني. لا تحدّثي البصمة إلا بموافقة صريحة
/// من صاحبة المشروع.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/features/worship/adhkar_screen.dart';
import 'package:glowara/features/worship/dua_screen.dart';

class _Region {
  const _Region(this.file, this.start, this.name, this.sha256);

  final String file;
  final String start;
  final String name;
  final String sha256;
}

const List<_Region> _regions = <_Region>[
  _Region(
    'lib/features/worship/adhkar_screen.dart',
    'const List<Dhikr> kMorningAdhkar = <Dhikr>[',
    'kMorningAdhkar',
    '1f55919e622e0ab90f669248c42b1ad5be6943644e90828cfa5a7eb9f0dba984',
  ),
  _Region(
    'lib/features/worship/adhkar_screen.dart',
    'const List<Dhikr> kEveningAdhkar = <Dhikr>[',
    'kEveningAdhkar',
    '26383e03171b7607f571995ae1a05faf0d419dfd96853caf79a8c29576cf7507',
  ),
  _Region(
    'lib/features/worship/dua_screen.dart',
    'const List<Dua> kDuas = <Dua>[',
    'kDuas',
    '9eed967bda1e1b6c67b396897aca6c20f598e5c4e22cd396a6e8afab9110a128',
  ),
];

String _extract(String source, String start) {
  final i = source.indexOf(start);
  expect(i, greaterThanOrEqualTo(0), reason: 'list declaration not found: $start');
  final j = source.indexOf('\n];', i);
  expect(j, greaterThan(i));
  return source.substring(i, j + 3);
}

void main() {
  group('religious content is preserved verbatim', () {
    test('item counts are unchanged', () {
      expect(kMorningAdhkar.length, 20);
      expect(kEveningAdhkar.length, 26);
      expect(kDuas.length, 56);
    });

    for (final r in _regions) {
      test('${r.name} source text matches the recorded fingerprint', () {
        final region = _extract(File(r.file).readAsStringSync(), r.start);
        expect(
          sha256.convert(utf8.encode(region)).toString(),
          r.sha256,
          reason: '${r.name} changed. Religious texts must not change without '
              "the project owner's explicit approval.",
        );
      });

      test('${r.name} matches the backup copy', () {
        final region = _extract(File(r.file).readAsStringSync(), r.start);
        final backup = File('docs/content-backup/${r.name}.dart.txt').readAsStringSync();
        expect(region, backup);
      });
    }

    test('no placeholder text replaced the content', () {
      const placeholders = <String>['قيد الربط', 'placeholder', 'TODO', 'Lorem'];
      final all = <String>[
        for (final d in <Dhikr>[...kMorningAdhkar, ...kEveningAdhkar]) d.text,
        for (final d in kDuas) d.text,
      ];
      for (final t in all) {
        for (final p in placeholders) {
          expect(t.contains(p), isFalse, reason: t);
        }
      }
    });
  });
}
