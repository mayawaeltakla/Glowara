import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/nutrition_models.dart';
import 'package:glowara/core/repositories/nutrition_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';
final DateTime _sun = DateTime(2026, 11, 15);
final DateTime _sat = DateTime(2026, 11, 21);

void main() {
  group('meal ideas', () {
    test('are unique, cover every plan meal type and use valid groups', () {
      expect(kMealIdeas.map((i) => i.id).toSet().length, kMealIdeas.length);
      for (final type in kPlanMealTypes) {
        expect(kMealIdeas.where((i) => i.mealType == type).length, greaterThanOrEqualTo(4), reason: type);
      }
      for (final i in kMealIdeas) {
        expect(kPlanMealTypes, contains(i.mealType));
        expect(i.groups, isNotEmpty);
        expect(i.groups.every(kFoodGroups.contains), isTrue, reason: i.id);
        expect(i.ar.trim(), isNotEmpty);
        expect(i.en.trim(), isNotEmpty);
        expect(i.text('ar'), i.ar);
        expect(i.text('en'), i.en);
      }
    });

    test('carry no calories, quantities, diet or weight language', () {
      final banned = RegExp(
        r'(calor|kcal|diet|weight|slim|detox|fast|سعر|حمية|رجيم|وزن|نحاف|تنحيف|دايت|\d)',
        caseSensitive: false,
      );
      for (final i in kMealIdeas) {
        expect(banned.hasMatch(i.ar), isFalse, reason: i.ar);
        expect(banned.hasMatch(i.en), isFalse, reason: i.en);
      }
    });

    test('every food group has a label key', () {
      expect(kFoodGroupLabelKeys.keys.toSet(), kFoodGroups.toSet());
    });
  });

  group('MealNote groups', () {
    test('round-trip', () {
      final m = MealNote(
        id: 'm1',
        userId: _a,
        dateTime: DateTime(2026, 11, 16, 9),
        mealType: 'breakfast',
        groups: const <String>['fruit', 'dairy'],
        createdAt: DateTime(2026, 11, 16, 9),
      );
      expect(MealNote.fromJson(m.toJson()).groups, <String>['fruit', 'dairy']);
    });

    test('an older record without groups still loads', () {
      final json = MealNote(
        id: 'm1',
        userId: _a,
        dateTime: DateTime(2026, 11, 16),
        createdAt: DateTime(2026, 11, 16),
      ).toJson()
        ..remove('groups');
      expect(MealNote.fromJson(json).groups, isEmpty);
      json['groups'] = 'oops';
      expect(MealNote.fromJson(json).groups, isEmpty);
      json['groups'] = <Object?>['fruit', 3, null];
      expect(MealNote.fromJson(json).groups, <String>['fruit']);
    });
  });

  group('plan', () {
    late LocalDatabase db;
    late NutritionRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = NutritionRepository(db);
    });

    Future<MealPlan?> set(String user, String day, String type, String text) => repo.setCell(
          userId: user,
          weekStart: _sun,
          weekEnd: _sat,
          day: day,
          mealType: type,
          text: text,
        );

    test('saves a cell by explicit date and meal type', () async {
      final plan = await set(_a, '2026-11-16', 'lunch', '  أرز وسلطة  ');
      expect(plan!.id, 'ua_2026-11-15');
      expect(plan.cell('2026-11-16', 'lunch'), 'أرز وسلطة');
      expect(plan.cell('2026-11-16', 'dinner'), isNull);
      expect((await repo.planFor(_a, _sun))!.cell('2026-11-16', 'lunch'), 'أرز وسلطة');
    });

    test('empty text clears the cell and a blank plan is not stored', () async {
      await set(_a, '2026-11-16', 'lunch', 'x');
      await set(_a, '2026-11-17', 'dinner', 'y');
      await set(_a, '2026-11-16', 'lunch', '   ');
      expect((await repo.planFor(_a, _sun))!.days.keys, <String>['2026-11-17']);
      await set(_a, '2026-11-17', 'dinner', '');
      expect(await repo.planFor(_a, _sun), isNull);
      expect(await db.count('mealPlans'), 0);
    });

    test('caps long text and rejects an unknown meal type', () async {
      final plan = await set(_a, '2026-11-16', 'snack', 'ا' * 500);
      expect(plan!.cell('2026-11-16', 'snack')!.length, kPlanCellMax);
      expect(() => set(_a, '2026-11-16', 'brunch', 'x'), throwsArgumentError);
    });

    test('accounts are isolated', () async {
      await set(_a, '2026-11-16', 'lunch', 'a');
      await set(_b, '2026-11-16', 'lunch', 'b');
      expect((await repo.planFor(_a, _sun))!.cell('2026-11-16', 'lunch'), 'a');
      expect((await repo.planFor(_b, _sun))!.cell('2026-11-16', 'lunch'), 'b');
    });
  });

  group('summary', () {
    late LocalDatabase db;
    late NutritionRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = NutritionRepository(db);
    });

    Future<void> meal(String id, String user, DateTime when, {List<String> groups = const <String>[], String? note}) =>
        db.put(
          'meals',
          id,
          MealNote(id: id, userId: user, dateTime: when, groups: groups, note: note, createdAt: when).toJson(),
        );

    test('is empty with no records', () async {
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.isEmpty, isTrue);
      expect(s.groupsSeen, isEmpty);
    });

    test('counts days, meals, groups and water days for the week only', () async {
      await meal('m1', _a, DateTime(2026, 11, 15, 8), groups: <String>['fruit']);
      await meal('m2', _a, DateTime(2026, 11, 15, 13), groups: <String>['protein', 'bogus']);
      await meal('m3', _a, DateTime(2026, 11, 21, 23, 30));
      await meal('out', _a, DateTime(2026, 11, 22, 0, 5), groups: <String>['dairy']);
      await meal('other', _b, DateTime(2026, 11, 16, 9), groups: <String>['grains']);
      for (final entry in <List<Object>>[
        ['w1', '2026-11-16', 250],
        ['w2', '2026-11-17', 0],
        ['w3', '2026-11-22', 500],
      ]) {
        await db.put(
          'water',
          entry[0] as String,
          WaterLog(
            id: entry[0] as String,
            userId: _a,
            date: entry[1] as String,
            amountMl: entry[2] as int,
            createdAt: DateTime(2026, 11, 16),
          ).toJson(),
        );
      }
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.mealsLogged, 3);
      expect(s.daysWithMeals, 2);
      expect(s.groupsSeen, <String>{'fruit', 'protein'});
      expect(s.waterDays, 1);
      expect(s.isEmpty, isFalse);
    });

    test('never exposes meal note text', () async {
      await meal('m1', _a, DateTime(2026, 11, 16, 8), note: 'سر خاص', groups: <String>['fruit']);
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.toString(), isNot(contains('سر خاص')));
      expect(s.groupsSeen, <String>{'fruit'});
    });
  });

  group('export and import', () {
    late LocalDatabase db;
    late NutritionRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = NutritionRepository(db);
    });

    Future<void> set(String user, String text) =>
        repo.setCell(userId: user, weekStart: _sun, weekEnd: _sat, day: '2026-11-16', mealType: 'lunch', text: text);

    test('account export holds only that account\'s plan and restores it', () async {
      await set(_a, 'خطتي');
      await set(_b, 'خطتها');
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['mealPlans'] as Map).keys, <String>['ua_2026-11-15']);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      expect((await NutritionRepository(fresh).planFor(_a, _sun))!.cell('2026-11-16', 'lunch'), 'خطتي');
    });

    test('importing into another account re-keys the plan', () async {
      await set(_a, 'خطتي');
      final export = await db.exportAll(onlyUserId: _a);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _b, allowDifferentSource: true);
      final moved = await NutritionRepository(fresh).planFor(_b, _sun);
      expect(moved!.userId, _b);
      expect(moved.id, 'ub_2026-11-15');
      expect(await NutritionRepository(fresh).planFor(_a, _sun), isNull);
    });

    test('deleting an account removes its plan and keeps the other', () async {
      await set(_a, 'a');
      await set(_b, 'b');
      await db.deleteUserData(_a);
      expect(await repo.planFor(_a, _sun), isNull);
      expect(await repo.planFor(_b, _sun), isNotNull);
    });
  });
}
