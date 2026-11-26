// يمنع استعمال مجموعة بيانات في الكود دون تسجيلها في CollectionRegistry.
//
// يقرأ ملفات lib/ ويستخرج أسماء المجموعات من استدعاءات قاعدة البيانات
// (`_db.list/byId/put/delete/count/clearCollection`)، سواء كُتب الاسم نصًا
// مباشرة أو عبر ثابت `static const String _x = '...'` في الملف نفسه، ثم
// يقارنها بالسجل. اسم لا يمكن حلّه يُفشل الاختبار بدل أن يُتجاهل.
//
// هذا مسح نصي، قد لا يلتقط اسمًا يُركَّب ديناميكيًا؛ لذلك يوجد أيضًا تحقق وقت
// التشغيل (assert) في LocalDatabase.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/collection_registry.dart';

final RegExp _constPattern =
    RegExp(r"static\s+const\s+String\s+(_\w+)\s*=\s*'(\w+)'\s*;");

final RegExp _callPattern = RegExp(
  r"\b(?:_db|db)\.(?:list|byId|put|delete|count|clearCollection)\s*(?:<[^()]*>)?\(\s*(?:'(\w+)'|(\w+))",
);

/// الملفات المستثناة من المسح مع السبب:
///  * local_database.dart يستعمل أسماء ديناميكية داخليًا ويتحقق منها بـassert.
///  * legacy_migration.dart يمرّر الاسم من خريطة؛ تُفحص قيم الخريطة أدناه.
const Set<String> _skipped = <String>{
  'lib/core/db/local_database.dart',
  'lib/core/db/legacy_migration.dart',
};

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _normalized(String path) => path.replaceAll(r'\', '/');

void main() {
  test('every collection used in lib/ is registered', () {
    final used = <String, Set<String>>{}; // اسم المجموعة -> الملفات
    final unresolved = <String>[];

    for (final file in _dartFiles()) {
      final path = _normalized(file.path);
      if (_skipped.contains(path)) continue;
      final text = file.readAsStringSync();
      final consts = <String, String>{
        for (final m in _constPattern.allMatches(text)) m.group(1)!: m.group(2)!,
      };
      for (final match in _callPattern.allMatches(text)) {
        final literal = match.group(1);
        final identifier = match.group(2);
        final name = literal ?? consts[identifier];
        if (name == null) {
          unresolved.add('$path: ${match.group(0)!.replaceAll(RegExp(r"\s+"), ' ')}');
          continue;
        }
        used.putIfAbsent(name, () => <String>{}).add(path);
      }
    }

    expect(unresolved, isEmpty,
        reason: 'Cannot resolve the collection name in these calls. Use a '
            "`static const String _x = 'name';` or a string literal:\n${unresolved.join('\n')}");

    // سلامة المسح نفسه: لو توقف عن اكتشاف الأسماء لما ظهر أي فشل.
    expect(used.keys, containsAll(<String>['tasks', 'habits', 'journals', 'users']));
    expect(used.length, greaterThanOrEqualTo(15));

    final missing = used.keys.where((n) => !CollectionRegistry.isRegistered(n)).toList()..sort();
    expect(missing, isEmpty,
        reason: 'Unregistered collections (add them to CollectionRegistry, see '
            'docs/ADDING_A_COLLECTION.md): ${missing.map((n) => '$n in ${used[n]}').join('; ')}');
  });

  test('legacy migration targets are registered', () {
    final text = File('lib/core/db/legacy_migration.dart').readAsStringSync();
    final start = text.indexOf('_collections = <String, String>{');
    expect(start, greaterThan(-1), reason: 'legacy map moved; update this test');
    final end = text.indexOf('};', start);
    final block = text.substring(start, end);
    final targets = RegExp(r"'\w+'\s*:\s*'(\w+)'")
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toList();
    expect(targets, isNotEmpty);
    for (final name in targets) {
      expect(CollectionRegistry.isRegistered(name), isTrue, reason: name);
    }
  });
}
