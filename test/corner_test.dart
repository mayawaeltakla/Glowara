import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/corner_models.dart';
import 'package:glowara/core/repositories/corner_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

void main() {
  group('models', () {
    test('round-trip, tolerance and sealing rule', () {
      final e = CornerEntry(
        id: 'c1',
        userId: _a,
        kind: 'letter',
        title: 't',
        text: 'x',
        openOn: '2027-03-01',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );
      expect(CornerEntry.fromJson(e.toJson()).openOn, '2027-03-01');
      expect(e.isSealed('2027-02-28'), isTrue);
      expect(e.isSealed('2027-03-01'), isFalse, reason: 'opens on its date');
      expect(e.isSealed('2027-03-02'), isFalse);
      final bad = e.toJson()
        ..['kind'] = 'zzz'
        ..['openOn'] = 'later';
      final t = CornerEntry.fromJson(bad);
      expect(t.kind, 'letter');
      expect(t.openOn, isNull);
      expect(t.isSealed('2000-01-01'), isFalse);
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late CornerRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = CornerRepository(db);
    });

    test('text is required; texts trimmed and capped; bad date dropped', () async {
      expect(() => repo.save(userId: _a, kind: 'letter', text: '  '), throwsStateError);
      final e = await repo.save(userId: _a, kind: 'bogus', title: 'ع' * 100, text: '  ${'ن' * 3000}', openOn: 'x');
      expect(e.kind, 'letter');
      expect(e.title.length, kCornerTitleMax);
      expect(e.text.length, kCornerTextMax);
      expect(e.openOn, isNull);
    });

    test('limit per account; editing keeps createdAt and id', () async {
      final first = await repo.save(userId: _a, kind: 'memory', text: 'a', now: DateTime(2026, 11, 1));
      for (var i = 1; i < kCornerMaxEntries; i++) {
        await repo.save(userId: _a, kind: 'wish', text: 'w$i');
      }
      expect(() => repo.save(userId: _a, kind: 'wish', text: 'more'), throwsStateError);
      await repo.save(userId: _b, kind: 'wish', text: 'other');
      final edited = await repo.save(userId: _a, id: first.id, kind: 'letter', text: 'b', openOn: '2027-01-01');
      expect(edited.id, first.id);
      expect(edited.createdAt, DateTime(2026, 11, 1));
      expect(edited.openOn, '2027-01-01');
    });

    test('only the owner can read or delete', () async {
      final e = await repo.save(userId: _a, kind: 'letter', text: 'x');
      expect(await repo.byId(_b, e.id), isNull);
      await repo.delete(_b, e.id);
      expect(await repo.all(_a), hasLength(1));
      await repo.delete(_a, e.id);
      expect(await db.count('corner'), 0);
    });
  });

  test('export, restore, re-key and account deletion', () async {
    final db = await openTestDatabase();
    final repo = CornerRepository(db);
    final a = await repo.save(userId: _a, kind: 'letter', text: 'لنفسي', openOn: '2027-05-05');
    await repo.save(userId: _b, kind: 'letter', text: 'لها');
    final export = await db.exportAll(onlyUserId: _a);
    expect((export['corner'] as Map).keys, <String>[a.id]);
    final fresh = await openTestDatabase();
    await fresh.importAll(export, targetUserId: _a);
    expect((await CornerRepository(fresh).all(_a)).single.openOn, '2027-05-05');
    final other = await openTestDatabase();
    await other.importAll(export, targetUserId: _b, allowDifferentSource: true);
    expect((await CornerRepository(other).all(_b)).single.userId, _b);
    await db.deleteUserData(_a);
    expect(await repo.all(_a), isEmpty);
    expect(await repo.all(_b), hasLength(1));
  });
}
