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
        allowDifferentSource: true,
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

  group('account scoped export, import and delete', () {
    Future<void> seedTwoUsers() async {
      for (final u in <String>['a_1', 'b_2']) {
        await db.put('users', u, <String, dynamic>{'id': u});
        await db.put('tasks', 'task-$u', <String, dynamic>{'id': 'task-$u', 'userId': u});
        await db.put('habits', 'habit-$u', <String, dynamic>{'id': 'habit-$u', 'userId': u});
        await db.put('habitLogs', 'log-$u', <String, dynamic>{'id': 'log-$u', 'habitId': 'habit-$u'});
        await db.put('subjects', 'subj-$u', <String, dynamic>{'id': 'subj-$u', 'userId': u});
        await db.put('units', 'unit-$u', <String, dynamic>{'id': 'unit-$u', 'subjectId': 'subj-$u'});
        await db.put('decks', 'deck-$u', <String, dynamic>{'id': 'deck-$u', 'userId': u});
        await db.put('cards', 'card-$u', <String, dynamic>{'id': 'card-$u', 'deckId': 'deck-$u'});
        await db.put('water', '${u}_2026-11-01', <String, dynamic>{'id': '${u}_2026-11-01', 'userId': u});
        await db.put('profiles', 'profile_$u', <String, dynamic>{'id': 'profile_$u', 'userId': u});
        await db.put('journals', 'j-$u', <String, dynamic>{'id': 'j-$u', 'userId': u, 'body': 'secret of $u'});
      }
    }

    test('account export contains only that account and its dependents', () async {
      await seedTwoUsers();
      final data = await db.exportAll(onlyUserId: 'a_1');
      expect(data['scope'], 'account');
      expect(data['schemaVersion'], 2);
      for (final name in <String>[
        'tasks', 'habits', 'habitLogs', 'subjects', 'units', 'decks', 'cards', 'water', 'profiles', 'journals',
      ]) {
        final records = data[name] as Map<String, dynamic>;
        expect(records, hasLength(1), reason: name);
        expect(records.keys.single, isNot(contains('b_2')), reason: name);
      }
      expect(data.containsKey('users'), isFalse);
      expect(data.toString(), isNot(contains('secret of b_2')));
    });

    test('device export still includes every account', () async {
      await seedTwoUsers();
      final data = await db.exportAll();
      expect(data['scope'], 'device');
      expect(data['tasks'] as Map, hasLength(2));
    });

    test('restoring another account file needs confirmation and writes nothing without it', () async {
      await seedTwoUsers();
      final fileFromA = await db.exportAll(onlyUserId: 'a_1');
      expect((fileFromA['source'] as Map)['accountId'], 'a_1');
      final before = await db.count('journals');

      await expectLater(
        db.importAll(fileFromA, targetUserId: 'b_2'),
        throwsA(isA<ImportSourceMismatch>().having((e) => e.unknownSource, 'unknownSource', false)),
      );

      expect(await db.count('journals'), before);
      expect(await db.byId('tasks', 'task-a_1', (m) => m), isNotNull);
    });

    test('after confirmation it still never takes over the other account records', () async {
      await seedTwoUsers();
      final fileFromA = await db.exportAll(onlyUserId: 'a_1');

      await db.importAll(fileFromA, targetUserId: 'b_2', allowDifferentSource: true);

      final stillA = await db.byId('tasks', 'task-a_1', (m) => m);
      expect(stillA!['userId'], 'a_1');
      expect(db.lastImportSkipped, greaterThan(0));
    });

    test('records with non-colliding ids are not moved silently either', () async {
      await seedTwoUsers();
      final fileFromA = await db.exportAll(onlyUserId: 'a_1');
      await db.deleteUserData('a_1'); // ملفها لم يعد يتعارض مع شيء على الجهاز.

      await expectLater(
        db.importAll(fileFromA, targetUserId: 'b_2'),
        throwsA(isA<ImportSourceMismatch>()),
      );
      expect(await db.byId('journals', 'j-a_1', (m) => m), isNull,
          reason: 'declining must leave B without account A data');

      await db.importAll(fileFromA, targetUserId: 'b_2', allowDifferentSource: true);
      final moved = await db.byId('journals', 'j-a_1', (m) => m);
      expect(moved!['userId'], 'b_2');
    });

    test('restoring a file back into its own account needs no confirmation', () async {
      await seedTwoUsers();
      final fileFromA = await db.exportAll(onlyUserId: 'a_1');
      await db.deleteUserData('a_1');
      await db.put('users', 'a_1', <String, dynamic>{'id': 'a_1'});

      final count = await db.importAll(fileFromA, targetUserId: 'a_1');
      expect(count, greaterThan(0));
    });

    test('a file with unknown or device scope source needs confirmation', () async {
      await seedTwoUsers();
      final deviceFile = await db.exportAll();
      await expectLater(
        db.importAll(deviceFile, targetUserId: 'a_1'),
        throwsA(isA<ImportSourceMismatch>().having((e) => e.unknownSource, 'unknownSource', true)),
      );
      await expectLater(
        db.importAll(
          <String, dynamic>{'app': 'glowara', 'schemaVersion': 2},
          targetUserId: 'a_1',
        ),
        throwsA(isA<ImportSourceMismatch>()),
      );
    });

    test('importing the same file twice does not duplicate records', () async {
      await seedTwoUsers();
      final file = await db.exportAll(onlyUserId: 'a_1');
      await db.importAll(file, targetUserId: 'a_1'); // مصدرها هذا الحساب نفسه
      final firstCount = await db.count('tasks');
      await db.importAll(file, targetUserId: 'a_1');
      expect(await db.count('tasks'), firstCount);
      expect(await db.count('journals'), 2);
    });

    test('merge disabled with a target user keeps other accounts intact', () async {
      await seedTwoUsers();
      await db.importAll(
        <String, dynamic>{
          'tasks': <String, dynamic>{
            'fresh': <String, dynamic>{'id': 'fresh', 'userId': 'a_1'},
          },
        },
        merge: false,
        targetUserId: 'a_1',
        allowDifferentSource: true,
      );
      expect(await db.byId('tasks', 'task-a_1', (m) => m), isNull);
      expect(await db.byId('tasks', 'task-b_2', (m) => m), isNotNull);
      expect(await db.byId('tasks', 'fresh', (m) => m), isNotNull);
    });

    test('wrong app or unsupported schema is rejected and changes nothing', () async {
      await seedTwoUsers();
      final before = await db.count('tasks');
      await expectLater(
        db.importAll(<String, dynamic>{'app': 'other'}),
        throwsFormatException,
      );
      await expectLater(
        db.importAll(<String, dynamic>{'app': 'glowara', 'schemaVersion': 99}),
        throwsFormatException,
      );
      await expectLater(
        db.importAll(<String, dynamic>{'app': 'glowara', 'schemaVersion': 'two'}),
        throwsFormatException,
      );
      expect(await db.count('tasks'), before);
    });

    test('an older file without scope still imports', () async {
      final count = await db.importAll(
        <String, dynamic>{
          'app': 'glowara',
          'schemaVersion': 2,
          'tasks': <String, dynamic>{
            't9': <String, dynamic>{'id': 't9', 'userId': 'old'},
          },
        },
        targetUserId: 'a_1',
        allowDifferentSource: true,
      );
      expect(count, 1);
    });

    test('deleting one user removes only that user and dependents', () async {
      await seedTwoUsers();
      await db.deleteUserData('a_1');

      for (final name in <String>[
        'tasks', 'habits', 'habitLogs', 'subjects', 'units', 'decks', 'cards', 'water', 'profiles', 'journals',
      ]) {
        expect(await db.count(name), 1, reason: name);
      }
      expect(await db.byId('users', 'a_1', (m) => m), isNull);
      expect(await db.byId('users', 'b_2', (m) => m), isNotNull);
      expect(await db.byId('journals', 'j-b_2', (m) => m), isNotNull);
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
