/// مستودع التقدم والإحصائيات — يحسب من السجلات الحقيقية فقط.
library glowara.repositories.progress;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';

class ProgressRepository {
  ProgressRepository(this._db, this._settings);

  final LocalDatabase _db;
  final SettingsRepository _settings;

  Future<PeriodStats> stats({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromKey = dateKey(from);
    final toKey = dateKey(to);
    final start = startOfDay(from);
    final end = startOfDay(to);

    // المهام
    final tasks = await _db.list('tasks', TaskItem.fromJson, filter: Filter.equals('userId', userId));
    final periodTasks = tasks.where((t) {
      final due = t.dueDateTime;
      return due != null && inRange(due, start, end);
    }).toList();
    final tasksDone = periodTasks.where((t) => t.state == TaskState.done).length;

    // العادات
    final habits = await _db.list(
      'habits',
      Habit.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.equals('isActive', true),
      ]),
    );
    final logs = await _db.list('habitLogs', HabitLog.fromJson);
    final periodLogs = logs
        .where((l) => l.date.compareTo(fromKey) >= 0 && l.date.compareTo(toKey) <= 0)
        .toList();
    var scheduled = 0;
    var habitsDone = 0;
    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      for (final habit in habits) {
        if (_isScheduled(habit, day)) {
          scheduled++;
          final key = dateKey(day);
          if (periodLogs.any((l) =>
              l.habitId == habit.id &&
              l.date == key &&
              l.state == WorshipState.completed)) {
            habitsDone++;
          }
        }
      }
    }

    // الدراسة
    final sessions = await _db.list('sessions', StudySession.fromJson);
    final studyMinutes = sessions
        .where((s) => s.userId.isEmpty || s.userId == userId)
        .where((s) => inRange(s.startedAt, start, end))
        .fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

    // القرآن
    final readings = await _db.list('readingLogs', ReadingLog.fromJson);
    final periodReadings = readings
        .where((r) => r.userId.isEmpty || r.userId == userId)
        .where((r) => inRange(r.completedAt, start, end))
        .toList();
    final quranReadings = periodReadings.where((r) => r.itemId.startsWith('quran')).length;
    final quranDays = periodReadings
        .where((r) => r.itemId.startsWith('quran'))
        .map((r) => dateKey(r.completedAt))
        .toSet()
        .length;

    // الماء
    final water = await _db.list('water', WaterLog.fromJson, filter: Filter.equals('userId', userId));
    final periodWater = water.where((w) => w.date.compareTo(fromKey) >= 0 && w.date.compareTo(toKey) <= 0).toList();
    final waterTotal = periodWater.fold<int>(0, (sum, w) => sum + w.amountMl);
    final waterDays = periodWater.where((w) => w.amountMl > 0).map((w) => w.date).toSet().length;

    // المذكرات والمزاج
    final journals = await _db.list('journals', JournalEntry.fromJson, filter: Filter.equals('userId', userId));
    final journalEntries = journals.where((j) {
      final d = j.updatedAt ?? j.createdAt;
      return inRange(d, start, end);
    }).length;

    final moods = await _db.list('moods', MoodEntry.fromJson, filter: Filter.equals('userId', userId));
    final moodEntries = moods.where((m) => m.date.compareTo(fromKey) >= 0 && m.date.compareTo(toKey) <= 0).length;

    // الدروس
    final lessons = await _db.list('lessons', LanguageLesson.fromJson, filter: Filter.equals('userId', userId));
    final lessonsCompleted = lessons
        .where((l) => l.completedAt != null && inRange(l.completedAt!, start, end))
        .length;

    // العناية
    final steps = await _db.list(
      'careSteps',
      SelfCareStep.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.equals('isActive', true),
      ]),
    );
    final careLogs = await _db.list('careLogs', SelfCareLog.fromJson);
    final periodCare = careLogs
        .where((l) =>
            l.userId == userId &&
            l.done &&
            l.date.compareTo(fromKey) >= 0 &&
            l.date.compareTo(toKey) <= 0)
        .toList();
    var careTotal = 0;
    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      careTotal += steps.length;
    }

    return PeriodStats(
      tasksTotal: periodTasks.length,
      tasksDone: tasksDone,
      habitsScheduled: scheduled,
      habitsDone: habitsDone,
      studyMinutes: studyMinutes,
      quranReadings: quranReadings,
      quranDays: quranDays,
      waterTotalMl: waterTotal,
      waterDays: waterDays,
      journalEntries: journalEntries,
      moodEntries: moodEntries,
      lessonsCompleted: lessonsCompleted,
      careStepsDone: periodCare.length,
      careStepsTotal: careTotal,
    );
  }

  bool _isScheduled(Habit habit, DateTime day) {
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

  Future<Map<String, StudyProgress>> subjectProgress(String userId) async {
    final subjects = await _db.list('subjects', StudySubject.fromJson, filter: Filter.equals('userId', userId));
    final units = await _db.list('units', StudyUnit.fromJson);
    final result = <String, StudyProgress>{};
    for (final subject in subjects) {
      final subjectUnits = units.where((u) => u.subjectId == subject.id).toList();
      result[subject.id] = StudyProgress(
        done: subjectUnits.where((u) => u.state == TaskState.done).length,
        total: subjectUnits.length,
      );
    }
    return result;
  }

  // ---- الأهداف الشهرية ----
  Future<List<MonthlyGoal>> goals(String userId, String month) async {
    final list = await _db.list(
      'goals',
      MonthlyGoal.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.equals('month', month),
      ]),
    );
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> saveGoal(MonthlyGoal goal) => _db.put('goals', goal.id, goal.toJson());

  Future<void> deleteGoal(String id) => _db.delete('goals', id);

  int goalValue(MonthlyGoal goal, PeriodStats stats) {
    switch (goal.metric) {
      case 'tasks':
        return stats.tasksDone;
      case 'studyMinutes':
        return stats.studyMinutes;
      case 'quranDays':
        return stats.quranDays;
      case 'waterDays':
        return stats.waterDays;
      case 'lessons':
        return stats.lessonsCompleted;
      case 'habitDays':
        return stats.habitsDone;
      default:
        return 0;
    }
  }

  /// تقدير الماء اليومي المتوسط (للعرض فقط، من السجلات).
  Future<int> averageWater(String userId, DateTime from, DateTime to) async {
    final water = await _db.list('water', WaterLog.fromJson, filter: Filter.equals('userId', userId));
    final fromKey = dateKey(from);
    final toKey = dateKey(to);
    final period = water.where((w) => w.date.compareTo(fromKey) >= 0 && w.date.compareTo(toKey) <= 0).toList();
    if (period.isEmpty) return 0;
    final total = period.fold<int>(0, (sum, w) => sum + w.amountMl);
    final days = to.difference(from).inDays + 1;
    return days <= 0 ? 0 : (total / days).round();
  }

  Future<int> waterGoalMl() => _settings.waterGoalMl();
}
