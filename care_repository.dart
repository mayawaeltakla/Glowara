/// مستودع العناية بالنفس والبشرة.
library glowara.repositories.care;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class CareRepository {
  CareRepository(this._db);

  final LocalDatabase _db;
  static const String _steps = 'careSteps';
  static const String _logs = 'careLogs';

  Future<List<SelfCareStep>> steps(String userId, {String? period}) async {
    final list = await _db.list(
      _steps,
      SelfCareStep.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.equals('isActive', true),
      ]),
      sortOrders: <SortOrder>[SortOrder('order')],
    );
    if (period == null) return list;
    return list.where((s) => s.period == period).toList();
  }

  Future<void> saveStep(SelfCareStep step) async {
    await _db.put(_steps, step.id, step.copyWith(lastModified: DateTime.now()).toJson());
  }

  Future<void> deleteStep(String id) async {
    await _db.delete(_steps, id);
    final logs = await _db.list(_logs, SelfCareLog.fromJson, filter: Filter.equals('stepId', id));
    for (final log in logs) {
      await _db.delete(_logs, log.id);
    }
  }

  String _logId(String stepId, String date) => '${stepId}_$date';

  Future<bool> isDone(String stepId, DateTime day) async {
    final log = await _db.byId(_logs, _logId(stepId, dateKey(day)), SelfCareLog.fromJson);
    return log?.done ?? false;
  }

  Future<Set<String>> doneStepIds(DateTime day, {String? userId}) async {
    final logs = await _db.list(
      _logs,
      SelfCareLog.fromJson,
      filter: Filter.equals('date', dateKey(day)),
    );
    return logs
        .where((l) => l.done && (userId == null || l.userId == userId))
        .map((l) => l.stepId)
        .toSet();
  }

  Future<void> toggleStep({
    required String userId,
    required String stepId,
    required DateTime day,
    required bool done,
  }) async {
    final id = _logId(stepId, dateKey(day));
    final existing = await _db.byId(_logs, id, SelfCareLog.fromJson);
    final log = SelfCareLog(
      id: id,
      userId: userId,
      stepId: stepId,
      date: dateKey(day),
      done: done,
      createdAt: existing?.createdAt ?? DateTime.now(),
      syncStatus: SyncStatus.local,
    );
    await _db.put(_logs, id, log.toJson());
  }
}
