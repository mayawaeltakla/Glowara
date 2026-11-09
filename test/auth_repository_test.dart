import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/repositories/auth_repository.dart';

import 'support/test_db.dart';

void main() {
  late LocalDatabase db;
  late AuthRepository auth;

  setUp(() async {
    db = await openTestDatabase();
    // عدد دورات صغير لتسريع الاختبارات؛ المنطق نفسه.
    auth = AuthRepository(db, iterations: 10);
  });

  group('register and login', () {
    test('registers, then logs in with the same credentials', () async {
      final registered = await auth.register(
        email: 'Maya@Example.com ',
        password: 'secret1',
        name: ' Maya ',
      );
      expect(registered.ok, isTrue);
      expect(registered.user!.email, 'maya@example.com');
      expect(registered.user!.displayName, 'Maya');

      await auth.logout();
      expect(await auth.currentUser(), isNull);

      final loggedIn = await auth.login(email: 'maya@example.com', password: 'secret1');
      expect(loggedIn.ok, isTrue);
      expect(loggedIn.user!.id, registered.user!.id);
      expect((await auth.currentUser())!.id, registered.user!.id);
    });

    test('stores a salted hash, never the password', () async {
      final registered = await auth.register(
        email: 'a@b.co',
        password: 'secret1',
        name: '',
      );
      final record = await db.byId('users', registered.user!.id, (m) => m);
      expect(record, isNotNull);
      expect(record!.values.contains('secret1'), isFalse);
      expect(record['salt'], isNotEmpty);
      expect(record['hash'], isNotEmpty);
      expect(record['iterations'], 10);
    });

    test('rejects invalid email, weak password and duplicates', () async {
      expect((await auth.register(email: 'nope', password: 'secret1', name: '')).error,
          'invalid_email');
      expect((await auth.register(email: 'a@b.co', password: '123', name: '')).error,
          'weak_password');
      await auth.register(email: 'a@b.co', password: 'secret1', name: '');
      expect((await auth.register(email: 'A@B.co', password: 'secret1', name: '')).error,
          'email_exists');
    });

    test('rejects a wrong password and an unknown account', () async {
      await auth.register(email: 'a@b.co', password: 'secret1', name: '');
      expect((await auth.login(email: 'a@b.co', password: 'wrong-one')).error,
          'wrong_password');
      expect((await auth.login(email: 'x@y.co', password: 'secret1')).error,
          'account_not_found');
    });

    test('a logged-in local account is never reported as synced', () async {
      await auth.register(email: 'a@b.co', password: 'secret1', name: '');
      await auth.logout();
      final result = await auth.login(email: 'a@b.co', password: 'secret1');
      expect(result.user!.syncStatus.name, 'local');
    });

    test('login upgrades a hash made with fewer iterations', () async {
      final registered = await auth.register(email: 'a@b.co', password: 'secret1', name: '');
      final oldRecord = await db.byId('users', registered.user!.id, (m) => m);

      final stronger = AuthRepository(db, iterations: 20);
      final result = await stronger.login(email: 'a@b.co', password: 'secret1');
      expect(result.ok, isTrue);

      final newRecord = await db.byId('users', registered.user!.id, (m) => m);
      expect(newRecord!['iterations'], 20);
      expect(newRecord['hash'], isNot(oldRecord!['hash']));
      expect(newRecord['salt'], isNot(oldRecord['salt']));

      // ما زال الدخول يعمل بعد الترقية، وكلمة المرور الخاطئة مرفوضة.
      expect((await stronger.login(email: 'a@b.co', password: 'secret1')).ok, isTrue);
      expect((await stronger.login(email: 'a@b.co', password: 'bad-pass')).ok, isFalse);
    });
  });

  group('deleteAccount', () {
    test('removes only the given account and its data', () async {
      final a = (await auth.register(email: 'a@b.co', password: 'secret1', name: '')).user!;
      final b = (await auth.register(email: 'b@b.co', password: 'secret1', name: '')).user!;

      Future<void> seed(String userId, String tag) async {
        await db.put('tasks', 'task_$tag', {'id': 'task_$tag', 'userId': userId});
        await db.put('habits', 'habit_$tag', {'id': 'habit_$tag', 'userId': userId});
        await db.put('habitLogs', 'log_$tag', {'id': 'log_$tag', 'habitId': 'habit_$tag'});
        await db.put('subjects', 'subject_$tag', {'id': 'subject_$tag', 'userId': userId});
        await db.put('units', 'unit_$tag', {'id': 'unit_$tag', 'subjectId': 'subject_$tag'});
        await db.put('decks', 'deck_$tag', {'id': 'deck_$tag', 'userId': userId});
        await db.put('cards', 'card_$tag', {'id': 'card_$tag', 'deckId': 'deck_$tag'});
        // سجل مركّب مفتاحه يبدأ بمعرّف المستخدم.
        await db.put('water', '${userId}_2026-11-09', {'id': '${userId}_2026-11-09'});
      }

      await seed(a.id, 'a');
      await seed(b.id, 'b');
      await db.setSetting('locale', 'en');

      await auth.deleteAccount(a.id);

      for (final collection in <String>[
        'tasks',
        'habits',
        'habitLogs',
        'subjects',
        'units',
        'decks',
        'cards',
        'water',
      ]) {
        expect(await db.count(collection), 1, reason: collection);
      }
      expect(await db.byId('tasks', 'task_b', (m) => m), isNotNull);
      expect(await db.byId('habitLogs', 'log_b', (m) => m), isNotNull);
      expect(await db.byId('cards', 'card_b', (m) => m), isNotNull);

      expect(await db.count('users'), 1);
      expect(await auth.currentUser(), isNull);
      // التفضيلات المشتركة لا تُمسح.
      expect(await db.getSetting('locale'), 'en');
    });
  });
}
