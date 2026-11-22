/// مستودع المعالم.
///
/// يقرأ سجلات هذه المستخدمة فقط (تُستبعد السجلات القديمة بلا مالك)، ويحسب المقاييس،
/// ويكتب سجل معلم جديدًا عند بلوغ حدّه. لا يكتب شيئًا سوى سجلات `milestones`.
/// لا تدخل العبادات ولا المزاج ولا المذكرات في أي مقياس.
library glowara.repositories.milestone;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/models/milestone_models.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';

class MilestoneRepository {
  MilestoneRepository(this._db, this._progress);

  final LocalDatabase _db;
  final ProgressRepository _progress;

  static const String _store = 'milestones';

  Future<Map<String, EarnedMilestone>> earned(String userId) async {
    final list = await _db.list(
      _store,
      EarnedMilestone.fromJson,
      filter: Filter.equals('userId', userId),
    );
    // إن وُجد تكرار (بعد استيراد مثلًا) نُبقي الأقدم.
    final byMilestone = <String, EarnedMilestone>{};
    for (final e in list) {
      final existing = byMilestone[e.milestoneId];
      if (existing == null || e.earnedAt.isBefore(existing.earnedAt)) {
        byMilestone[e.milestoneId] = e;
      }
    }
    return byMilestone;
  }

  /// المقاييس الحالية من السجلات الحقيقية.
  Future<Map<MilestoneMetric, int>> metrics(String userId) async {
    final activeDays = <String>{};

    // المهام
    final tasks = await _db.list('tasks', TaskItem.fromJson, filter: Filter.equals('userId', userId));
    var tasksDone = 0;
    for (final t in tasks) {
      if (t.deletedAt != null) continue;
      if (t.state == TaskState.done) {
        tasksDone++;
        activeDays.add(dateKey(t.dueDateTime ?? t.updatedAt ?? t.createdAt));
      }
      for (final day in t.doneDays) {
        tasksDone++;
        activeDays.add(day);
      }
    }

    // العادات
    final habits = await _db.list('habits', Habit.fromJson, filter: Filter.equals('userId', userId));
    final habitIds = habits.map((h) => h.id).toList();
    var habitLogs = 0;
    if (habitIds.isNotEmpty) {
      final logs = await _db.list('habitLogs', HabitLog.fromJson, filter: Filter.inList('habitId', habitIds));
      for (final l in logs) {
        if (l.state != WorshipState.completed) continue;
        habitLogs++;
        activeDays.add(l.date);
      }
    }

    // الدراسة (تطابق صريح مع userId: لا سجلات قديمة بلا مالك)
    final sessions = await _db.list('sessions', StudySession.fromJson, filter: Filter.equals('userId', userId));
    var studyMinutes = 0;
    for (final s in sessions) {
      studyMinutes += s.durationMinutes ?? 0;
      activeDays.add(dateKey(s.startedAt));
    }

    // العناية
    final careLogs = await _db.list('careLogs', SelfCareLog.fromJson, filter: Filter.equals('userId', userId));
    var careDone = 0;
    for (final l in careLogs) {
      if (!l.done) continue;
      careDone++;
      activeDays.add(l.date);
    }

    // الماء (يوم فيه تسجيل ماء يُعدّ يومًا حاضرًا)
    final water = await _db.list('water', WaterLog.fromJson, filter: Filter.equals('userId', userId));
    for (final w in water) {
      if (w.amountMl > 0) activeDays.add(w.date);
    }

    // الأهداف
    final goals = await _db.list('goals', MonthlyGoal.fromJson, filter: Filter.equals('userId', userId));
    var goalsCompleted = 0;
    final statsByMonth = <String, PeriodStats>{};
    final thisMonth = monthKey(DateTime.now());
    for (final g in goals) {
      if (g.target <= 0 || g.month.compareTo(thisMonth) > 0) continue;
      final first = DateTime.tryParse('${g.month}-01');
      if (first == null) continue;
      final stats = statsByMonth[g.month] ??= await _progress.stats(
        userId: userId,
        from: first,
        to: endOfMonth(first),
        includeLegacyOwnerless: false,
      );
      if (_progress.goalValue(g, stats) >= g.target) goalsCompleted++;
    }

    return <MilestoneMetric, int>{
      MilestoneMetric.tasksDone: tasksDone,
      MilestoneMetric.habitLogs: habitLogs,
      MilestoneMetric.studySessions: sessions.length,
      MilestoneMetric.careDone: careDone,
      MilestoneMetric.goalsCreated: goals.length,
      MilestoneMetric.activeDays: activeDays.length,
      MilestoneMetric.studyMinutes: studyMinutes,
      MilestoneMetric.goalsCompleted: goalsCompleted,
    };
  }

  /// يقيّم المعالم: يكتب ما بلغ حدّه ولم يُسجَّل بعد، ويعيد كل المعالم بحالتها.
  /// لا يسحب معلمًا سُجّل سابقًا مهما تغيّرت السجلات.
  Future<List<MilestoneEntry>> evaluate(String userId, {DateTime? now}) async {
    final values = await metrics(userId);
    final already = await earned(userId);
    final stamp = now ?? DateTime.now();
    final entries = <MilestoneEntry>[];
    for (final def in kMilestones) {
      final current = values[def.metric] ?? 0;
      var record = already[def.id];
      var isNew = false;
      if (record == null && current >= def.threshold) {
        record = EarnedMilestone(
          id: EarnedMilestone.idFor(userId, def.id),
          userId: userId,
          milestoneId: def.id,
          earnedAt: stamp,
        );
        await _db.put(_store, record.id, record.toJson());
        isNew = true;
      }
      entries.add(MilestoneEntry(
        def: def,
        current: current,
        earnedAt: record?.earnedAt,
        isNew: isNew,
      ));
    }
    return entries;
  }
}
