import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/academy_repository.dart';
import 'package:glowara/core/services/academy_content.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

void main() {
  late AcademyCurriculum curriculum;
  late AcademyUnit unit;
  late LocalDatabase db;
  late AcademyRepository repo;

  setUpAll(() {
    curriculum = AcademyContent.parse(File(AcademyContent.a1Asset).readAsStringSync());
    unit = curriculum.unit('a1-u01')!;
  });

  setUp(() async {
    db = await openTestDatabase();
    repo = AcademyRepository(db);
  });

  group('progress', () {
    test('a new account has no progress and nothing is written by reading', () async {
      expect(await repo.all(_a), isEmpty);
      expect(await repo.forUnit(_a, unit.id), isNull);
      expect(await db.count('academyProgress'), 0);
    });

    test('marking studied is remembered, idempotent, and keeps the first time', () async {
      final first = await repo.markStudied(_a, unit.id, now: DateTime(2026, 11, 1));
      final again = await repo.markStudied(_a, unit.id, now: DateTime(2026, 11, 9));
      expect(first.studied, isTrue);
      expect(again.studiedAt, DateTime(2026, 11, 1));
      expect(await db.count('academyProgress'), 1);
      expect(first.id, 'ua_a1-u01');
    });

    test('a unit is completed only when studied and practiced', () async {
      await repo.markStudied(_a, unit.id);
      expect((await repo.forUnit(_a, unit.id))!.completed, isFalse);
      await repo.recordPractice(userId: _a, unitId: unit.id, results: <String, bool>{'a1-u01-q1': true});
      expect((await repo.forUnit(_a, unit.id))!.completed, isTrue);
    });

    test('practicing first and studying later also completes it', () async {
      await repo.recordPractice(userId: _a, unitId: unit.id, results: <String, bool>{'a1-u01-q1': true});
      expect((await repo.forUnit(_a, unit.id))!.completed, isFalse);
      await repo.markStudied(_a, unit.id);
      expect((await repo.forUnit(_a, unit.id))!.completed, isTrue);
    });

    test('mistakes are saved for review and cleared when answered correctly', () async {
      await repo.recordPractice(
        userId: _a,
        unitId: unit.id,
        results: <String, bool>{'a1-u01-q1': true, 'a1-u01-q2': false, 'a1-u01-q3': false},
      );
      expect((await repo.forUnit(_a, unit.id))!.missed, <String>['a1-u01-q2', 'a1-u01-q3']);

      // مراجعة: q2 صحيحة الآن، q3 ما زالت خاطئة.
      await repo.recordPractice(
        userId: _a,
        unitId: unit.id,
        results: <String, bool>{'a1-u01-q2': true, 'a1-u01-q3': false},
      );
      expect((await repo.forUnit(_a, unit.id))!.missed, <String>['a1-u01-q3']);

      // تمرين كامل جديد لا يمسح ما لم يُجَب عنه.
      await repo.recordPractice(userId: _a, unitId: unit.id, results: <String, bool>{'a1-u01-q1': false});
      expect((await repo.forUnit(_a, unit.id))!.missed, <String>['a1-u01-q1', 'a1-u01-q3']);
    });

    test('no scores are stored', () async {
      await repo.recordPractice(userId: _a, unitId: unit.id, results: <String, bool>{'a1-u01-q1': true});
      final json = (await db.exportAll())['academyProgress'] as Map;
      final record = json.values.single as Map;
      expect(record.keys.toSet(), <String>{'id', 'userId', 'unitId', 'studiedAt', 'practicedAt', 'missed', 'updatedAt'});
    });

    test('one account never sees or changes another account\'s progress', () async {
      await repo.markStudied(_b, unit.id);
      await repo.recordPractice(userId: _b, unitId: unit.id, results: <String, bool>{'a1-u01-q1': false});
      expect(await repo.all(_a), isEmpty);
      await repo.markStudied(_a, unit.id);
      expect((await repo.forUnit(_a, unit.id))!.missed, isEmpty);
      expect((await repo.forUnit(_b, unit.id))!.missed, <String>['a1-u01-q1']);
    });

    test('duplicates after an import keep the most recently updated', () async {
      final old = AcademyProgress(id: 'k1', userId: _a, unitId: unit.id, updatedAt: DateTime(2026, 1, 1), missed: const <String>['x']);
      final recent = AcademyProgress(id: 'k2', userId: _a, unitId: unit.id, updatedAt: DateTime(2026, 6, 1));
      await db.put('academyProgress', 'k1', old.toJson());
      await db.put('academyProgress', 'k2', recent.toJson());
      expect((await repo.forUnit(_a, unit.id))!.missed, isEmpty);
    });

    test('progress only writes academyProgress', () async {
      Future<String> others() async {
        final data = await db.exportAll();
        data.remove('exportedAt');
        data.remove('academyProgress');
        return jsonEncode(data);
      }

      final before = await others();
      await repo.markStudied(_a, unit.id);
      await repo.recordPractice(userId: _a, unitId: unit.id, results: <String, bool>{'a1-u01-q1': false});
      expect(await others(), before);
    });
  });

  group('add vocabulary to cards', () {
    test('creates one new deck with the ten words, on request', () async {
      final added = await repo.addVocabularyToCards(userId: _a, unit: unit, now: DateTime(2026, 11, 1));
      expect(added, 10);
      final decks = await db.list('decks', WordDeck.fromJson);
      expect(decks, hasLength(1));
      expect(decks.single.userId, _a);
      expect(decks.single.language, 'English');
      expect(decks.single.name, 'English A1 — Greetings and Introductions');
      final cards = await db.list('cards', WordCard.fromJson);
      expect(cards, hasLength(10));
      expect(cards.every((c) => c.deckId == decks.single.id), isTrue);
      final hello = cards.firstWhere((c) => c.term == 'hello');
      expect(hello.meaning, 'مرحبًا');
      expect(hello.example, 'Hello, I am Sara.');
    });

    test('adding twice does not duplicate', () async {
      expect(await repo.addVocabularyToCards(userId: _a, unit: unit), 10);
      expect(await repo.addVocabularyToCards(userId: _a, unit: unit), 0);
      expect(await db.count('decks'), 1);
      expect(await db.count('cards'), 10);
    });

    test('after deleting the deck she can add it again', () async {
      await repo.addVocabularyToCards(userId: _a, unit: unit);
      final deck = (await db.list('decks', WordDeck.fromJson)).single;
      for (final card in await db.list('cards', WordCard.fromJson)) {
        await db.delete('cards', card.id);
      }
      await db.delete('decks', deck.id);
      expect(await repo.addVocabularyToCards(userId: _a, unit: unit), 10);
    });

    test('her existing decks, cards and lessons are never touched', () async {
      await db.put('decks', 'mine', WordDeck(id: 'mine', userId: _a, name: 'مفرداتي', createdAt: DateTime(2026, 1, 1)).toJson());
      await db.put(
        'cards',
        'c1',
        WordCard(id: 'c1', deckId: 'mine', term: 'hello', meaning: 'أهلًا بطريقتي', createdAt: DateTime(2026, 1, 1)).toJson(),
      );
      await db.put(
        'lessons',
        'l1',
        LanguageLesson(id: 'l1', userId: _a, title: 'درسي', content: 'نصي', createdAt: DateTime(2026, 1, 1)).toJson(),
      );
      final deckBefore = jsonEncode(await db.byId('decks', 'mine', (m) => m));
      final cardBefore = jsonEncode(await db.byId('cards', 'c1', (m) => m));
      final lessonBefore = jsonEncode(await db.byId('lessons', 'l1', (m) => m));

      await repo.addVocabularyToCards(userId: _a, unit: unit);

      expect(jsonEncode(await db.byId('decks', 'mine', (m) => m)), deckBefore);
      expect(jsonEncode(await db.byId('cards', 'c1', (m) => m)), cardBefore);
      expect(jsonEncode(await db.byId('lessons', 'l1', (m) => m)), lessonBefore);
      expect(await db.count('decks'), 2);
      expect(await db.count('cards'), 11);
    });

    test('each account gets its own deck', () async {
      await repo.addVocabularyToCards(userId: _a, unit: unit);
      await repo.addVocabularyToCards(userId: _b, unit: unit);
      final decks = await db.list('decks', WordDeck.fromJson);
      expect(decks.map((d) => d.userId).toSet(), <String>{_a, _b});
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['decks'] as Map).length, 1);
      expect((export['cards'] as Map).length, 10);
    });
  });

  group('export, import, delete', () {
    setUp(() async {
      for (final user in <String>[_a, _b]) {
        await repo.markStudied(user, unit.id);
        await repo.recordPractice(userId: user, unitId: unit.id, results: <String, bool>{'a1-u01-q2': false});
      }
    });

    test('account export holds only that account and restores it', () async {
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['academyProgress'] as Map).keys.toList(), <String>['ua_a1-u01']);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      final back = await AcademyRepository(fresh).forUnit(_a, unit.id);
      expect(back!.missed, <String>['a1-u01-q2']);
      expect(back.studied, isTrue);
    });

    test('importing into another account re-keys it and never duplicates', () async {
      final export = await db.exportAll(onlyUserId: _a);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _b, allowDifferentSource: true);
      expect(await fresh.byId('academyProgress', 'ub_a1-u01', AcademyProgress.fromJson), isNotNull);
      expect(await fresh.byId('academyProgress', 'ua_a1-u01', AcademyProgress.fromJson), isNull);
      final freshRepo = AcademyRepository(fresh);
      await freshRepo.markStudied(_b, unit.id);
      expect(await fresh.count('academyProgress'), 1);
    });

    test('deleting an account removes its progress and keeps the other account\'s', () async {
      await db.deleteUserData(_a);
      expect(await repo.all(_a), isEmpty);
      expect(await repo.all(_b), isNotEmpty);
    });
  });
}
