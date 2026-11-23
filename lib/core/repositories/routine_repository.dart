/// مستودع «روتيناتي». يكتب `routines` و`routineDays` وحدهما. لا ينشئ مهامًا ولا
/// إشعارات ولا يقرأ أي ميزة أخرى.
library glowara.repositories.routine;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/routine_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class RoutineRepository {
  RoutineRepository(this._db);

  final LocalDatabase _db;

  static const String _routines = 'routines';
  static const String _days = 'routineDays';

  Future<List<Routine>> all(String userId) async {
    final list = await _db.list(_routines, Routine.fromJson, filter: Filter.equals('userId', userId));
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<Routine?> byId(String userId, String id) async {
    final r = await _db.byId(_routines, id, Routine.fromJson);
    return r != null && r.userId == userId ? r : null;
  }

  /// يحفظ روتينًا (جديدًا إن كان [id] فارغًا). يهذّب النصوص ويقصّها ويحدّ عدد الخطوات.
  /// يرمي [StateError] إن بلغت الحدّ الأقصى للروتينات أو كان الاسم فارغًا.
  Future<Routine> save({
    required String userId,
    String? id,
    required String name,
    required String kind,
    required List<String> steps,
    List<int> days = const <int>[],
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    var cleanName = name.trim();
    if (cleanName.isEmpty) throw StateError('empty name');
    if (cleanName.length > kRoutineNameMax) cleanName = cleanName.substring(0, kRoutineNameMax);
    final existing = id == null ? null : await byId(userId, id);
    if (existing == null && (await all(userId)).length >= kRoutineMaxRoutines) {
      throw StateError('too many routines');
    }
    final oldSteps = <String, String>{for (final s in existing?.steps ?? const <RoutineStep>[]) s.text: s.id};
    final cleanSteps = <RoutineStep>[];
    for (final raw in steps) {
      var t = raw.trim();
      if (t.isEmpty) continue;
      if (t.length > kRoutineStepMax) t = t.substring(0, kRoutineStepMax);
      if (cleanSteps.length >= kRoutineMaxSteps) break;
      // نصّ لم يتغيّر يحتفظ بمعرّفه كي لا تضيع علاماتها السابقة.
      final reused = oldSteps.remove(t);
      cleanSteps.add(RoutineStep(id: reused ?? uniqueId(), text: t));
    }
    final routine = Routine(
      id: existing?.id ?? uniqueId(),
      userId: userId,
      name: cleanName,
      kind: kRoutineKinds.contains(kind) ? kind : 'custom',
      steps: cleanSteps,
      days: (days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort()),
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );
    await _db.put(_routines, routine.id, routine.toJson());
    return routine;
  }

  /// يحذف الروتين وعلاماته في كل الأيام (بطلبها).
  Future<void> delete(String userId, String id) async {
    final r = await byId(userId, id);
    if (r == null) return;
    await _db.delete(_routines, id);
    final days = await _db.list(_days, RoutineDay.fromJson, filter: Filter.equals('userId', userId));
    for (final d in days.where((d) => d.done.containsKey(id))) {
      final rest = Map<String, List<String>>.of(d.done)..remove(id);
      if (rest.isEmpty) {
        await _db.delete(_days, d.id);
      } else {
        await _db.put(_days, d.id, RoutineDay(id: d.id, userId: userId, date: d.date, done: rest, updatedAt: DateTime.now()).toJson());
      }
    }
  }

  Future<RoutineDay?> dayFor(String userId, DateTime day) =>
      _db.byId(_days, RoutineDay.idFor(userId, dateKey(day)), RoutineDay.fromJson);

  /// يعلّم خطوة منجزة أو يزيل العلامة. يوم بلا علامات لا يُخزَّن.
  Future<RoutineDay?> setStepDone({
    required String userId,
    required DateTime day,
    required String routineId,
    required String stepId,
    required bool done,
    DateTime? now,
  }) async {
    final key = dateKey(day);
    final id = RoutineDay.idFor(userId, key);
    final current = await dayFor(userId, day);
    final map = <String, List<String>>{
      for (final e in (current?.done ?? const <String, List<String>>{}).entries) e.key: List<String>.of(e.value),
    };
    final ids = map.putIfAbsent(routineId, () => <String>[]);
    if (done) {
      if (!ids.contains(stepId)) ids.add(stepId);
    } else {
      ids.remove(stepId);
    }
    if (ids.isEmpty) map.remove(routineId);
    if (map.isEmpty) {
      if (current != null) await _db.delete(_days, id);
      return null;
    }
    final out = RoutineDay(id: id, userId: userId, date: key, done: map, updatedAt: now ?? DateTime.now());
    await _db.put(_days, id, out.toJson());
    return out;
  }
}
