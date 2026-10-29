/// مستودع الصحة: الماء والوجبات.
library glowara.repositories.health;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class HealthRepository {
  HealthRepository(this._db);

  final LocalDatabase _db;
  static const String _water = 'water';
  static const String _meals = 'meals';

  String _waterId(String userId, String date) => '${userId}_$date';

  Future<WaterLog?> waterFor(String userId, DateTime day) =>
      _db.byId(_water, _waterId(userId, dateKey(day)), WaterLog.fromJson);

  Future<int> waterTotal(String userId, DateTime day) async {
    final log = await waterFor(userId, day);
    return log?.amountMl ?? 0;
  }

  Future<void> setWater({
    required String userId,
    required DateTime day,
    required int amountMl,
  }) async {
    final id = _waterId(userId, dateKey(day));
    final existing = await _db.byId(_water, id, WaterLog.fromJson);
    final log = WaterLog(
      id: id,
      userId: userId,
      date: dateKey(day),
      amountMl: amountMl < 0 ? 0 : amountMl,
      createdAt: existing?.createdAt ?? DateTime.now(),
      syncStatus: SyncStatus.local,
      lastModified: DateTime.now(),
    );
    await _db.put(_water, id, log.toJson());
  }

  Future<void> addWater({
    required String userId,
    required DateTime day,
    required int deltaMl,
  }) async {
    final current = await waterTotal(userId, day);
    await setWater(userId: userId, day: day, amountMl: current + deltaMl);
  }

  Future<List<WaterLog>> waterRange(String userId, DateTime from, DateTime to) async {
    final list = await _db.list(
      _water,
      WaterLog.fromJson,
      filter: Filter.equals('userId', userId),
    );
    final fromKey = dateKey(from);
    final toKey = dateKey(to);
    return list.where((w) => w.date.compareTo(fromKey) >= 0 && w.date.compareTo(toKey) <= 0).toList();
  }

  Future<List<MealNote>> meals(String userId, {DateTime? from, DateTime? to}) async {
    final list = await _db.list(
      _meals,
      MealNote.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('dateTime', false)],
    );
    if (from == null && to == null) return list;
    return list.where((m) => inRange(m.dateTime, from ?? DateTime(2000), to ?? DateTime(2100))).toList();
  }

  Future<void> saveMeal(MealNote note) async {
    await _db.put(_meals, note.id, note.toJson());
  }

  Future<void> deleteMeal(String id) => _db.delete(_meals, id);
}
