/// مستودع المهام (التقويم).
library glowara.repositories.tasks;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class TaskRepository {
  TaskRepository(this._db);

  final LocalDatabase _db;
  static const String _collection = 'tasks';

  Future<List<TaskItem>> all(String userId) async {
    final list = await _db.list(
      _collection,
      TaskItem.fromJson,
      filter: Filter.equals('userId', userId),
    );
    list.sort((a, b) {
      final ad = a.dueDateTime ?? a.createdAt;
      final bd = b.dueDateTime ?? b.createdAt;
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<List<TaskItem>> forDay(String userId, DateTime day) async {
    final all = await this.all(userId);
    return all.where((task) => _occursOn(task, day)).toList();
  }

  /// هل تظهر المهمة في هذا اليوم؟ يشمل تكرار السلسلة بعد تاريخ البداية.
  /// ملاحظة: حالة الإنجاز مشتركة بين كل تكرارات السلسلة في هذه النسخة.
  static bool _occursOn(TaskItem task, DateTime day) {
    final due = task.dueDateTime;
    if (due == null) return false;
    final target = startOfDay(day);
    final start = startOfDay(due);
    if (target.isBefore(start)) return false;
    if (isSameDay(target, start)) return true;
    switch (task.repeat) {
      case RepeatPattern.none:
        return false;
      case RepeatPattern.daily:
        return true;
      case RepeatPattern.weekly:
        return target.weekday == start.weekday;
      case RepeatPattern.customDays:
        return task.customDays.contains(target.weekday);
    }
  }

  Future<List<TaskItem>> forRange(String userId, DateTime from, DateTime to) async {
    final all = await this.all(userId);
    return all.where((t) {
      final due = t.dueDateTime;
      return due != null && inRange(due, from, to);
    }).toList();
  }

  Future<TaskItem?> byId(String id) => _db.byId(_collection, id, TaskItem.fromJson);

  Future<void> save(TaskItem task) async {
    final now = DateTime.now();
    await _db.put(_collection, task.id, task.copyWith(
      updatedAt: now,
      lastModified: now,
      syncStatus: SyncStatus.local,
    ).toJson());
  }

  Future<void> toggle(TaskItem task) async {
    final next = task.state == TaskState.done ? TaskState.open : TaskState.done;
    await save(task.copyWith(state: next));
  }

  Future<void> delete(String id) => _db.delete(_collection, id);

  /// المهام المتأخرة (فات موعدها ولم تُنجز) — تُعرض بلطف دون توبيخ.
  Future<List<TaskItem>> overdue(String userId) async {
    final all = await this.all(userId);
    final now = DateTime.now();
    return all.where((t) {
      final due = t.dueDateTime;
      return due != null && due.isBefore(now) && t.state != TaskState.done;
    }).toList();
  }
}
