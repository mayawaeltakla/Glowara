/// مستودع الدراسة: المواد، المحاضرات/الوحدات، وجلسات الدراسة.
library glowara.repositories.study;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

/// تقدم مادة دراسية.
class StudyProgress {
  const StudyProgress({required this.done, required this.total});
  final int done;
  final int total;
  double get ratio => total == 0 ? 0.0 : done / total;
}

class StudyRepository {
  StudyRepository(this._db);

  final LocalDatabase _db;
  static const String _subjects = 'subjects';
  static const String _units = 'units';
  static const String _sessions = 'sessions';

  // ---- المواد ----
  Future<List<StudySubject>> subjects(String userId) async {
    final list = await _db.list(
      _subjects,
      StudySubject.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
    return list;
  }

  Future<StudySubject?> subject(String id) =>
      _db.byId(_subjects, id, StudySubject.fromJson);

  Future<void> saveSubject(StudySubject subject) async {
    await _db.put(_subjects, subject.id, subject.copyWith(lastModified: DateTime.now()).toJson());
  }

  Future<void> deleteSubject(String id) async {
    final units = await this.units(id);
    for (final unit in units) {
      await _db.delete(_units, unit.id);
    }
    final sessions = await this.sessions(subjectId: id);
    for (final session in sessions) {
      await _db.delete(_sessions, session.id);
    }
    await _db.delete(_subjects, id);
  }

  // ---- الوحدات/المحاضرات ----
  Future<List<StudyUnit>> units(String subjectId) async {
    final list = await _db.list(
      _units,
      StudyUnit.fromJson,
      filter: Filter.equals('subjectId', subjectId),
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
    return list;
  }

  Future<void> saveUnit(StudyUnit unit) async {
    await _db.put(_units, unit.id, unit.copyWith(lastModified: DateTime.now()).toJson());
  }

  Future<void> deleteUnit(String id) => _db.delete(_units, id);

  Future<void> setUnitState(StudyUnit unit, TaskState state) async {
    await saveUnit(unit.copyWith(state: state));
  }

  // ---- الجلسات ----
  Future<List<StudySession>> sessions({String? subjectId, DateTime? from, DateTime? to, String? userId}) async {
    final list = await _db.list(
      _sessions,
      StudySession.fromJson,
      filter: subjectId == null ? null : Filter.equals('subjectId', subjectId),
      sortOrders: <SortOrder>[SortOrder('startedAt', false)],
    );
    var filtered = list;
    if (userId != null) {
      filtered = filtered.where((s) => s.userId.isEmpty || s.userId == userId).toList();
    }
    if (from == null && to == null) return filtered;
    return filtered.where((s) => inRange(s.startedAt, from ?? DateTime(2000), to ?? DateTime(2100))).toList();
  }

  Future<void> saveSession(StudySession session) async {
    await _db.put(_sessions, session.id, session.copyWith(lastModified: DateTime.now()).toJson());
  }

  Future<void> deleteSession(String id) => _db.delete(_sessions, id);

  // ---- تقدم ----
  Future<StudyProgress> progress(String subjectId) async {
    final units = await this.units(subjectId);
    final done = units.where((u) => u.state == TaskState.done).length;
    return StudyProgress(done: done, total: units.length);
  }

  Future<Map<String, StudyProgress>> progressForAll(String userId) async {
    final list = await subjects(userId);
    final result = <String, StudyProgress>{};
    for (final subject in list) {
      result[subject.id] = await progress(subject.id);
    }
    return result;
  }

  /// مجموع دقائق الدراسة في نطاق زمني.
  Future<int> minutesForRange(DateTime from, DateTime to, {String? userId}) async {
    final list = await sessions(from: from, to: to, userId: userId);
    return list.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));
  }
}
