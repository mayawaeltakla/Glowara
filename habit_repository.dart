/// مستودع العادات وسجلاتها.
library glowara.repositories.habits;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class HabitRepository {
  HabitRepository(this._db);

  final LocalDatabase _db;
  static const String _habits = 'habits';
  static const String _logs = 'habitLogs';

  /// كل عادات المستخدمة، بما فيها غير النشطة (لتستطيع إعادة تفعيلها).
  Future<List<Habit>> all(String userId) async {
    return _db.list(
      _habits,
      Habit.fromJson,
      filter: Filter.equals('userId', userId),
    );
  }

  /// العادات النشطة فقط (للرئيسية والإحصاءات).
  Future<List<Habit>> active(String userId) async {
    return _db.list(
      _habits,
      Habit.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.equals('isActive', true),
      ]),
    );
  }

  Future<void> save(Habit habit) async {
    await _db.put(_habits, habit.id, habit.copyWith(lastModified: DateTime.now()).toJson());
  }

  Future<void> delete(String id) async {
    await _db.delete(_habits, id);
    final logs = await _db.list(_logs, HabitLog.fromJson, filter: Filter.equals('habitId', id));
    for (final log in logs) {
      await _db.delete(_logs, log.id);
    }
  }

  /// معرف سجل فريد لكل عادة/يوم (يمنع التكرار).
  String _logId(String habitId, String date) => '${habitId}_$date';

  Future<HabitLog?> logFor(String habitId, DateTime day) =>
      _db.byId(_logs, _logId(habitId, dateKey(day)), HabitLog.fromJson);

  Future<List<HabitLog>> logsForRange(DateTime from, DateTime to) async {
    final logs = await _db.list(_logs, HabitLog.fromJson);
    return logs.where((l) => l.date.compareTo(dateKey(from)) >= 0 && l.date.compareTo(dateKey(to)) <= 0).toList();
  }

  Future<void> setLog({
    required String habitId,
    required DateTime day,
    required WorshipState state,
  }) async {
    final id = _logId(habitId, dateKey(day));
    final existing = await _db.byId(_logs, id, HabitLog.fromJson);
    final log = HabitLog(
      id: id,
      habitId: habitId,
      date: dateKey(day),
      state: state,
      createdAt: existing?.createdAt ?? DateTime.now(),
      syncStatus: SyncStatus.local,
      lastModified: DateTime.now(),
    );
    await _db.put(_logs, id, log.toJson());
  }

  /// هل العادة مجدولة في يوم معيّن؟
  bool isScheduled(Habit habit, DateTime day) {
    if (!habit.isActive) return false;
    switch (habit.schedule) {
      case RepeatPattern.daily:
        return true;
      case RepeatPattern.weekly:
        return habit.customDays.isEmpty || habit.customDays.contains(day.weekday);
      case RepeatPattern.customDays:
        return habit.customDays.contains(day.weekday);
      case RepeatPattern.none:
        return false;
    }
  }
}
