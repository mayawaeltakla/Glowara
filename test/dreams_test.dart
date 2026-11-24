import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/dream_models.dart';
import 'package:glowara/core/repositories/dream_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

void main() {
  group('models', () {
    test('Dream round-trips and tolerates bad data', () {
      final d = Dream(
        id: 'd1',
        userId: _a,
        title: 't',
        wish: 'w',
        stage: 'working',
        targetDate: '2027-01-31',
        steps: const <DreamStep>[DreamStep(id: 's1', text: 'a', done: true), DreamStep(id: 's2', text: 'b')],
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );
      final back = Dream.fromJson(d.toJson());
      expect(back.targetDate, '2027-01-31');
      expect(back.stepsDone, 1);
      expect(back.steps.length, 2);
      final json = d.toJson()
        ..['stage'] = 'weird'
        ..['targetDate'] = 'tomorrow'
        ..['steps'] = <Object?>[1, <String, Object?>{'id': 's', 'text': ' '}, <String, Object?>{'id': 's3', 'text': 'ok', 'done': 'yes'}];
      final t = Dream.fromJson(json);
      expect(t.stage, 'dreaming');
      expect(t.targetDate, isNull);
      expect(t.steps.single.done, isFalse);
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late DreamRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = DreamRepository(db);
    });

    test('title is required; texts are trimmed and capped; bad date dropped', () async {
      expect(() => repo.save(userId: _a, title: ' '), throwsStateError);
      final d = await repo.save(userId: _a, title: '  ${'ح' * 200}', wish: 'و' * 900, targetDate: 'soon');
      expect(d.title.length, kDreamTitleMax);
      expect(d.wish.length, kDreamWishMax);
      expect(d.targetDate, isNull);
    });

    test('the dream limit applies per account', () async {
      for (var i = 0; i < kMaxDreams; i++) {
        await repo.save(userId: _a, title: 'd$i');
      }
      expect(() => repo.save(userId: _a, title: 'more'), throwsStateError);
      await repo.save(userId: _b, title: 'other');
    });

    test('achieved sets the date once and leaving it clears; steps survive edits', () async {
      final t0 = DateTime(2026, 11, 1);
      final d = await repo.save(userId: _a, title: 't', now: t0);
      await repo.addStep(userId: _a, dreamId: d.id, text: 'خطوة');
      final a = await repo.save(userId: _a, id: d.id, title: 't', stage: 'achieved', targetDate: '2027-02-01', now: DateTime(2026, 11, 5));
      expect(a.achievedAt, DateTime(2026, 11, 5));
      expect(a.steps.length, 1);
      expect(a.targetDate, '2027-02-01');
      final a2 = await repo.save(userId: _a, id: d.id, title: 't', stage: 'achieved', now: DateTime(2026, 11, 9));
      expect(a2.achievedAt, DateTime(2026, 11, 5));
      final back = await repo.save(userId: _a, id: d.id, title: 't', stage: 'working');
      expect(back.achievedAt, isNull);
      expect(back.createdAt, t0);
    });

    test('steps: add, tick, untick, delete, caps, empty, other account', () async {
      final d = await repo.save(userId: _a, title: 't');
      var cur = await repo.addStep(userId: _a, dreamId: d.id, text: '  أولى  ');
      expect(cur.steps.single.text, 'أولى');
      final id = cur.steps.single.id;
      cur = await repo.setStepDone(userId: _a, dreamId: d.id, stepId: id, done: true);
      expect(cur.stepsDone, 1);
      cur = await repo.setStepDone(userId: _a, dreamId: d.id, stepId: id, done: false);
      expect(cur.stepsDone, 0);
      expect(() => repo.addStep(userId: _a, dreamId: d.id, text: ' '), throwsStateError);
      expect(() => repo.addStep(userId: _b, dreamId: d.id, text: 'x'), throwsStateError);
      for (var i = 1; i < kDreamMaxSteps; i++) {
        await repo.addStep(userId: _a, dreamId: d.id, text: 's$i');
      }
      expect(() => repo.addStep(userId: _a, dreamId: d.id, text: 'more'), throwsStateError);
      cur = await repo.deleteStep(userId: _a, dreamId: d.id, stepId: id);
      expect(cur.steps.length, kDreamMaxSteps - 1);
    });

    test('only the owner can read or delete', () async {
      final d = await repo.save(userId: _a, title: 't');
      expect(await repo.byId(_b, d.id), isNull);
      await repo.delete(_b, d.id);
      expect(await repo.all(_a), hasLength(1));
      await repo.delete(_a, d.id);
      expect(await db.count('dreams'), 0);
    });
  });

  group('export, import and delete account', () {
    test('export, restore, re-key and account deletion', () async {
      final db = await openTestDatabase();
      final repo = DreamRepository(db);
      final a = await repo.save(userId: _a, title: 'حلمي');
      await repo.addStep(userId: _a, dreamId: a.id, text: 'خطوة');
      await repo.save(userId: _b, title: 'حلمها');
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['dreams'] as Map).keys, <String>[a.id]);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      expect((await DreamRepository(fresh).all(_a)).single.steps.single.text, 'خطوة');
      final other = await openTestDatabase();
      await other.importAll(export, targetUserId: _b, allowDifferentSource: true);
      expect((await DreamRepository(other).all(_b)).single.userId, _b);
      await db.deleteUserData(_a);
      expect(await repo.all(_a), isEmpty);
      expect(await repo.all(_b), hasLength(1));
    });
  });
}
