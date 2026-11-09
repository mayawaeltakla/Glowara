import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';

import 'support/test_db.dart';

void main() {
  late LocalDatabase db;

  setUp(() async {
    db = await openTestDatabase();
  });

  group('export', () {
    test('leaves out private settings and the Quran cache', () async {
      await db.setSetting('locale', 'ar');
      await db.setSetting('pin_hash', 'secret');
      await db.setSetting('pin_failed', 3);
      await db.setSetting('current_user', <String, dynamic>{'id': 'u1'});
      await db.setSetting('quran_cache_1', '{"big":"payload"}');
      await db.setSetting('quran_last_surah', '2');

      final data = await db.exportAll();
      final settings = data['settings'] as Map<String, dynamic>;

      expect(settings.keys, unorderedEquals(<String>['locale', 'quran_last_surah']));
      expect(data.containsKey('users'), isFalse);
    });

    test('does not count the Quran cache in the reported size', () async {
      final before = await db.estimatedSizeBytes();
      await db.setSetting('quran_cache_2', 'x' * 50000);
      expect(await db.estimatedSizeBytes(), before);
    });
  });

  group('import', () {
    test('rebinds records and composite keys to the target user', () async {
      final imported = await db.importAll(
        <String, dynamic>{
          'app': 'glowara',
          'tasks': <String, dynamic>{
            't1': <String, dynamic>{'id': 't1', 'userId': 'old'},
          },
          'water': <String, dynamic>{
            'old_9_2026-11-01': <String, dynamic>{'id': 'old_9_2026-11-01', 'userId': 'old'},
          },
          'settings': <String, dynamic>{
            'locale': 'en',
            'pin_hash': 'must-be-ignored',
            'quran_cache_1': 'must-be-ignored',
          },
        },
        targetUserId: 'new_1',
      );

      expect(imported, 2);
      final task = await db.byId('tasks', 't1', (m) => m);
      expect(task!['userId'], 'new_1');
      final water = await db.byId('water', 'new_1_2026-11-01', (m) => m);
      expect(water!['userId'], 'new_1');
      expect(await db.getSetting('locale'), 'en');
      expect(await db.getSetting('pin_hash'), isNull);
      expect(await db.getSetting('quran_cache_1'), isNull);
    });

    test('a malformed file changes nothing, even with merge disabled', () async {
      await db.put('tasks', 'keep', <String, dynamic>{'id': 'keep', 'userId': 'u1'});

      await expectLater(
        db.importAll(
          <String, dynamic>{
            'tasks': <String, dynamic>{'bad': 5},
          },
          merge: false,
        ),
        throwsFormatException,
      );
      await expectLater(
        db.importAll(<String, dynamic>{'habits': 'not-an-object'}),
        throwsFormatException,
      );

      expect(await db.count('tasks'), 1);
      expect(await db.byId('tasks', 'keep', (m) => m), isNotNull);
    });

    test('merge disabled replaces the existing collection', () async {
      await db.put('tasks', 'old', <String, dynamic>{'id': 'old', 'userId': 'u1'});
      await db.importAll(
        <String, dynamic>{
          'tasks': <String, dynamic>{
            'fresh': <String, dynamic>{'id': 'fresh', 'userId': 'u1'},
          },
        },
        merge: false,
      );
      expect(await db.byId('tasks', 'old', (m) => m), isNull);
      expect(await db.byId('tasks', 'fresh', (m) => m), isNotNull);
    });
  });

  group('clear', () {
    test('clearAll removes records and settings', () async {
      await db.put('tasks', 't1', <String, dynamic>{'id': 't1'});
      await db.put('users', 'u1', <String, dynamic>{'id': 'u1'});
      await db.setSetting('locale', 'en');

      await db.clearAll();

      expect(await db.count('tasks'), 0);
      expect(await db.count('users'), 0);
      expect(await db.getSetting('locale'), isNull);
    });
  });
}
