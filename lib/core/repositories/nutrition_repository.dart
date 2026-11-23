/// مستودع التغذية المتوازنة: خطة الوجبات الأسبوعية وملخص أسبوع هادئ.
///
/// لا سعرات ولا أهداف. الملخص يقرأ أعدادًا وعلامات مجموعات فقط ولا يخرج منه
/// نص أي وجبة. يكتب سجلات `mealPlans` وحدها.
library glowara.repositories.nutrition;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/nutrition_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class NutritionRepository {
  NutritionRepository(this._db);

  final LocalDatabase _db;

  static const String _store = 'mealPlans';

  Future<MealPlan?> planFor(String userId, DateTime weekStart) =>
      _db.byId(_store, MealPlan.idFor(userId, dateKey(weekStart)), MealPlan.fromJson);

  /// يضع نص خانة (يوم + وجبة) في خطة الأسبوع. نص فارغ يمسح الخانة. خطة بلا أي
  /// خانة لا تُحفظ (وتُحذف إن كانت موجودة).
  Future<MealPlan?> setCell({
    required String userId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required String day,
    required String mealType,
    required String text,
    DateTime? now,
  }) async {
    if (!kPlanMealTypes.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType', 'unknown meal type');
    }
    final stamp = now ?? DateTime.now();
    final existing = await planFor(userId, weekStart);
    final days = <String, Map<String, String>>{
      for (final e in (existing?.days ?? const <String, Map<String, String>>{}).entries)
        e.key: Map<String, String>.of(e.value),
    };
    var clean = text.trim();
    if (clean.length > kPlanCellMax) clean = clean.substring(0, kPlanCellMax);
    final cells = days.putIfAbsent(day, () => <String, String>{});
    if (clean.isEmpty) {
      cells.remove(mealType);
    } else {
      cells[mealType] = clean;
    }
    if (cells.isEmpty) days.remove(day);

    final id = MealPlan.idFor(userId, dateKey(weekStart));
    if (days.isEmpty) {
      if (existing != null) await _db.delete(_store, id);
      return null;
    }
    final plan = MealPlan(
      id: id,
      userId: userId,
      weekStart: dateKey(weekStart),
      weekEnd: dateKey(weekEnd),
      days: days,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );
    await _db.put(_store, id, plan.toJson());
    return plan;
  }

  /// ملخص هادئ لأيام [from]..[to]: أيام فيها وجبات، ومجموعات الطعام التي علّمتها،
  /// وأيام الماء. أعداد فقط.
  Future<NutritionWeekSummary> summary(String userId, DateTime from, DateTime to) async {
    final meals = await _db.list('meals', MealNote.fromJson, filter: Filter.equals('userId', userId));
    final inWeek = meals.where((m) => inRange(m.dateTime, from, to)).toList();
    final groups = <String>{
      for (final m in inWeek) ...m.groups.where(kFoodGroups.contains),
    };
    final mealDays = inWeek.map((m) => dateKey(m.dateTime)).toSet();

    final fromKey = dateKey(from);
    final toKey = dateKey(to);
    final water = await _db.list('water', WaterLog.fromJson, filter: Filter.equals('userId', userId));
    final waterDays = water
        .where((w) => w.amountMl > 0 && w.date.compareTo(fromKey) >= 0 && w.date.compareTo(toKey) <= 0)
        .map((w) => w.date)
        .toSet();

    return NutritionWeekSummary(
      daysWithMeals: mealDays.length,
      mealsLogged: inWeek.length,
      groupsSeen: groups,
      waterDays: waterDays.length,
    );
  }
}
