import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/routine_models.dart';
import 'package:glowara/core/repositories/routine_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';
final DateTime _mon = DateTime(2026, 11, 16);

void main() {
  group('templates', () {
    test('are well formed, optional text only, no health or diet language', () {
      expect(kRoutineTemplates.map((t) => t.id).toSet().length, kRoutineTemplates.length);
      final banned = RegExp(r'(calor|diet|weight|سعر|حمية|وزن|صلاة|قرآن|prayer|quran)', caseSensitive: false);
      for (final t in kRoutineTemplates) {
        expect(kRoutineKinds, contains(t.kind));
        expect(t.stepsAr.length, t.stepsEn.length);
        expect(t.stepsAr.length, lessThanOrEqualTo(kRoutineMaxSteps));
        for (final s in <String>[t.nameAr, t.nameEn, ...t.stepsAr, ...t.stepsEn]) {
          expect(s.trim(), isNotEmpty);
          expect(banned.hasMatch(s), isFalse, reason: s);
        }
      }
    });
  });

  group('models', () {
    test('Routine round-trips and tolerates bad data', () {
      final r = Routine(
        id: 'r1',
        userId: _a,
        name: 'x',
        kind: 'morning',
        steps: const <RoutineStep>[RoutineStep(id: 's1', text: 'a')],
        days: const <int>[1, 3],
        createdAt: _mon,
        updatedAt: _mon,
      );
      final back = Routine.fromJson(r.toJson());
      expect(back.steps.single.text, 'a');
      expect(back.days, <int>[1, 3]);
      final json = r.toJson()
        ..['kind'] = 'weird'
        ..['steps'] = <Object?>[1, <String, Object?>{'id': 's', 'text': '  '}, <String, Object?>{'id': 's2', 'text': 'ok'}]
        ..['days'] = <Object?>[0, 9, 2, 2, 'x'];
      final tolerant = Routine.fromJson(json);
      expect(tolerant.kind, 'custom');
      expect(tolerant.steps.map((s) => s.id), <String>['s2']);
      expect(tolerant.days, <int>[2]);
    });

    test('runsOn: empty days means every day', () {
      final base = Routine(id: 'r', userId: _a, name: 'n', createdAt: _mon, updatedAt: _mon);
      expect(base.runsOn(_mon), isTrue);
      expect(base.copyWith(days: <int>[DateTime.tuesday]).runsOn(_mon), isFalse);
      expect(base.copyWith(days: <int>[DateTime.monday]).runsOn(_mon), isTrue);
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late RoutineRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = RoutineRepository(db);
    });

    Future<Routine> make(String user, {String name = 'صباحي', List<String> steps = const <String>['أ', 'ب']}) =>
        repo.save(userId: user, name: name, kind: 'morning', steps: steps);

    test('save trims, drops blanks, caps and orders steps', () async {
      final r = await repo.save(
        userId: _a,
        name: '  ${'ا' * 80}  ',
        kind: 'bogus',
        steps: <String>['  one ', '', '   ', 'two', 'ب' * 200, ...List<String>.generate(20, (i) => 's$i')],
        days: <int>[5, 1, 1, 9],
      );
      expect(r.name.length, kRoutineNameMax);
      expect(r.kind, 'custom');
      expect(r.steps.length, kRoutineMaxSteps);
      expect(r.steps.first.text, 'one');
      expect(r.steps[1].text, 'two');
      expect(r.steps[2].text.length, kRoutineStepMax);
      expect(r.days, <int>[1, 5]);
    });

    test('empty name and the routine limit are refused', () async {
      expect(() => make(_a, name: '  '), throwsStateError);
      for (var i = 0; i < kRoutineMaxRoutines; i++) {
        await make(_a, name: 'r$i');
      }
      expect(() => make(_a), throwsStateError);
      await make(_b); // حساب آخر غير متأثر
    });

    test('editing keeps unchanged steps\' ids so earlier ticks survive', () async {
      final r = await make(_a);
      await repo.setStepDone(userId: _a, day: _mon, routineId: r.id, stepId: r.steps[0].id, done: true);
      final edited = await repo.save(userId: _a, id: r.id, name: 'جديد', kind: 'evening', steps: <String>['أ', 'ج']);
      expect(edited.id, r.id);
      expect(edited.createdAt, r.createdAt);
      expect(edited.steps[0].id, r.steps[0].id);
      expect(edited.steps[1].id, isNot(r.steps[1].id));
      expect((await repo.dayFor(_a, _mon))!.isDone(r.id, r.steps[0].id), isTrue);
    });

    test('another account cannot read or edit a routine by id', () async {
      final r = await make(_a);
      expect(await repo.byId(_b, r.id), isNull);
      final other = await repo.save(userId: _b, id: r.id, name: 'x', kind: 'custom', steps: <String>['y']);
      expect(other.id, isNot(r.id));
      expect((await repo.byId(_a, r.id))!.name, 'صباحي');
    });

    test('ticking and unticking; a day with no ticks is not stored', () async {
      final r = await make(_a);
      final s0 = r.steps[0].id;
      await repo.setStepDone(userId: _a, day: _mon, routineId: r.id, stepId: s0, done: true);
      await repo.setStepDone(userId: _a, day: _mon, routineId: r.id, stepId: s0, done: true);
      expect((await repo.dayFor(_a, _mon))!.done[r.id], <String>[s0]);
      await repo.setStepDone(userId: _a, day: _mon, routineId: r.id, stepId: s0, done: false);
      expect(await repo.dayFor(_a, _mon), isNull);
      expect(await db.count('routineDays'), 0);
    });

    test('deleting a routine removes its ticks only', () async {
      final r1 = await make(_a, name: 'one');
      final r2 = await make(_a, name: 'two');
      await repo.setStepDone(userId: _a, day: _mon, routineId: r1.id, stepId: r1.steps[0].id, done: true);
      await repo.setStepDone(userId: _a, day: _mon, routineId: r2.id, stepId: r2.steps[0].id, done: true);
      await repo.delete(_a, r1.id);
      expect((await repo.all(_a)).map((r) => r.id), <String>[r2.id]);
      final day = (await repo.dayFor(_a, _mon))!;
      expect(day.done.keys, <String>[r2.id]);
    });
  });

  group('export, import and delete account', () {
    late LocalDatabase db;
    late RoutineRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = RoutineRepository(db);
    });

    test('account export carries only its routines and ticks; restores them', () async {
      final a = await repo.save(userId: _a, name: 'a', kind: 'custom', steps: <String>['x']);
      await repo.save(userId: _b, name: 'b', kind: 'custom', steps: <String>['y']);
      await repo.setStepDone(userId: _a, day: _mon, routineId: a.id, stepId: a.steps[0].id, done: true);
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['routines'] as Map).length, 1);
      expect((export['routineDays'] as Map).keys, <String>['ua_2026-11-16']);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      final freshRepo = RoutineRepository(fresh);
      expect((await freshRepo.all(_a)).single.name, 'a');
      expect((await freshRepo.dayFor(_a, _mon))!.isDone(a.id, a.steps[0].id), isTrue);
    });

    test('importing into another account re-keys the day record', () async {
      final a = await repo.save(userId: _a, name: 'a', kind: 'custom', steps: <String>['x']);
      await repo.setStepDone(userId: _a, day: _mon, routineId: a.id, stepId: a.steps[0].id, done: true);
      final export = await db.exportAll(onlyUserId: _a);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _b, allowDifferentSource: true);
      final freshRepo = RoutineRepository(fresh);
      expect(await freshRepo.dayFor(_b, _mon), isNotNull);
      expect(await freshRepo.dayFor(_a, _mon), isNull);
      expect((await freshRepo.all(_b)).single.userId, _b);
    });

    test('deleting an account removes its routines and keeps the other\'s', () async {
      final a = await repo.save(userId: _a, name: 'a', kind: 'custom', steps: <String>['x']);
      await repo.save(userId: _b, name: 'b', kind: 'custom', steps: <String>['y']);
      await repo.setStepDone(userId: _a, day: _mon, routineId: a.id, stepId: a.steps[0].id, done: true);
      await db.deleteUserData(_a);
      expect(await repo.all(_a), isEmpty);
      expect(await repo.dayFor(_a, _mon), isNull);
      expect(await repo.all(_b), hasLength(1));
    });
  });
}
