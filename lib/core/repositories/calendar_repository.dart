/// مستودع التقويم الشهري: يجمع نشاط الشهر من السجلات الموجودة. **قراءة فقط**.
///
/// لا يكتب ولا يحذف ولا ينشئ سجلات. يقرأ كل مجموعة مرة واحدة لنافذة الشهر
/// كاملة (42 يومًا) بدل استعلام لكل يوم، ويقيّد كل قراءة بـ`userId` الحساب.
///
/// ما يُستبعد عمدًا: المذكرات والمزاج (خصوصية)، ونص ملاحظات الوجبات،
/// والسجلات القديمة التي لا تحمل `userId` (لا نفترض ملكيتها لهذا الحساب).
library glowara.repositories.calendar;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/habit_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';

class CalendarRepository {
  CalendarRepository(this._db) : _habitRules = HabitRepository(_db);

  final LocalDatabase _db;
  final HabitRepository _habitRules;

  /// نشاط الشهر الذي يعرضه [month] مع أيام الأطراف المجاورة في الشبكة.
  /// [today] لاختبار العادات المجدولة في المستقبل (افتراضيًا الآن).
  Future<MonthSnapshot> monthSnapshot({
    required String userId,
    required DateTime month,
    required int weekStart,
    DateTime? today,
  }) async {
    final days = monthGridDays(month, weekStart);
    final start = days.first;
    final endExclusive = addDays(days.last, 1);
    final startKey = dateKey(start);
    final endKey = dateKey(endExclusive);
    // هامش يوم على كل جانب للمقارنة النصية بتواريخ ISO (UTC)، ثم نصفّي بدقة
    // بالتاريخ المحلي في الذاكرة.
    final lo = start.subtract(const Duration(days: 1)).toUtc().toIso8601String();
    final hi = endExclusive.add(const Duration(days: 1)).toUtc().toIso8601String();
    bool inWindow(DateTime local) => !local.isBefore(start) && local.isBefore(endExclusive);

    final map = <String, DayActivity>{};
    DayActivity at(String key) => map.putIfAbsent(key, DayActivity.new);

    await _addTasks(userId, days, hi, at);
    await _addHabits(userId, days, startKey, endKey, today ?? DateTime.now(), at);
    final subjectNames = await _addStudy(userId, lo, hi, inWindow, at);
    await _addCare(userId, startKey, endKey, at);
    await _addWater(userId, startKey, endKey, at);
    await _addMeals(userId, lo, hi, inWindow, at);
    await _addWorship(userId, lo, hi, inWindow, at);

    return MonthSnapshot(
      gridStart: start,
      gridEndExclusive: endExclusive,
      days: map,
      subjectNames: subjectNames,
    );
  }

  Future<void> _addTasks(
    String userId,
    List<DateTime> days,
    String hi,
    DayActivity Function(String) at,
  ) async {
    // مهمة موعدها بعد نهاية النافذة لا يمكن أن تظهر فيها (حتى المتكررة).
    final tasks = await _db.list(
      'tasks',
      TaskItem.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.lessThan('dueDateTime', hi),
      ]),
    );
    for (final task in tasks) {
      final due = task.dueDateTime;
      if (due == null) continue;
      final hasTime = due.hour != 0 || due.minute != 0;
      for (final day in days) {
        if (!TaskRepository.occursOn(task, day)) continue;
        final key = dateKey(day);
        final done = task.repeat == RepeatPattern.none
            ? task.state == TaskState.done
            : task.doneDays.contains(key);
        at(key).tasks.add(CalendarTask(
              title: task.title,
              time: hasTime ? due : null,
              done: done,
            ));
      }
    }
  }

  Future<void> _addHabits(
    String userId,
    List<DateTime> days,
    String startKey,
    String endKey,
    DateTime today,
    DayActivity Function(String) at,
  ) async {
    final habits = await _db.list(
      'habits',
      Habit.fromJson,
      filter: Filter.equals('userId', userId),
    );
    if (habits.isEmpty) return;
    final byId = <String, Habit>{for (final h in habits) h.id: h};
    // سجلات العادة لا تحمل userId: نقيّدها بعادات هذا الحساب عبر habitId.
    final logs = await _db.list(
      'habitLogs',
      HabitLog.fromJson,
      filter: Filter.and(<Filter>[
        Filter.inList('habitId', byId.keys.toList()),
        Filter.greaterThanOrEquals('date', startKey),
        Filter.lessThan('date', endKey),
      ]),
    );
    final logged = <String>{};
    for (final log in logs) {
      // الماضي: عادة سُجّل إنجازها فقط. لا تظهر «ظلال» عادات لم تُسجَّل.
      if (log.state != WorshipState.completed) continue;
      final habit = byId[log.habitId];
      if (habit == null) continue;
      logged.add('${log.habitId}|${log.date}');
      at(log.date).habits.add(CalendarHabit(name: habit.name, logged: true));
    }
    // اليوم والمستقبل: العادات المجدولة (بعد تاريخ إنشائها).
    final todayStart = startOfDay(today);
    for (final day in days) {
      if (day.isBefore(todayStart)) continue;
      final key = dateKey(day);
      for (final habit in habits) {
        if (day.isBefore(startOfDay(habit.createdAt))) continue;
        if (!_habitRules.isScheduled(habit, day)) continue;
        if (logged.contains('${habit.id}|$key')) continue;
        at(key).habits.add(CalendarHabit(name: habit.name, logged: false));
      }
    }
  }

  Future<Map<String, String>> _addStudy(
    String userId,
    String lo,
    String hi,
    bool Function(DateTime) inWindow,
    DayActivity Function(String) at,
  ) async {
    final subjects = await _db.list(
      'subjects',
      StudySubject.fromJson,
      filter: Filter.equals('userId', userId),
    );
    final names = <String, String>{for (final s in subjects) s.id: s.name};
    // userId مطابق تمامًا: الجلسات القديمة بلا userId لا تظهر.
    final sessions = await _db.list(
      'sessions',
      StudySession.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.greaterThanOrEquals('startedAt', lo),
        Filter.lessThan('startedAt', hi),
      ]),
    );
    for (final session in sessions) {
      if (!inWindow(session.startedAt)) continue;
      final ended = session.endedAt;
      final minutes = session.durationMinutes ??
          (ended == null ? 0 : ended.difference(session.startedAt).inMinutes);
      final day = at(dateKey(session.startedAt));
      day.studyMinutesBySubject.update(
        session.subjectId,
        (int v) => v + minutes,
        ifAbsent: () => minutes,
      );
    }
    return names;
  }

  Future<void> _addCare(
    String userId,
    String startKey,
    String endKey,
    DayActivity Function(String) at,
  ) async {
    final steps = await _db.list(
      'careSteps',
      SelfCareStep.fromJson,
      filter: Filter.equals('userId', userId),
    );
    if (steps.isEmpty) return;
    final titles = <String, String>{for (final s in steps) s.id: s.title};
    final logs = await _db.list(
      'careLogs',
      SelfCareLog.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.greaterThanOrEquals('date', startKey),
        Filter.lessThan('date', endKey),
      ]),
    );
    for (final log in logs) {
      if (!log.done) continue;
      final title = titles[log.stepId];
      if (title == null) continue;
      final day = at(log.date);
      if (!day.care.contains(title)) day.care.add(title);
    }
  }

  Future<void> _addWater(
    String userId,
    String startKey,
    String endKey,
    DayActivity Function(String) at,
  ) async {
    final logs = await _db.list(
      'water',
      WaterLog.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.greaterThanOrEquals('date', startKey),
        Filter.lessThan('date', endKey),
      ]),
    );
    for (final log in logs) {
      if (log.amountMl > 0) at(log.date).waterMl += log.amountMl;
    }
  }

  Future<void> _addMeals(
    String userId,
    String lo,
    String hi,
    bool Function(DateTime) inWindow,
    DayActivity Function(String) at,
  ) async {
    final meals = await _db.list(
      'meals',
      MealNote.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.greaterThanOrEquals('dateTime', lo),
        Filter.lessThan('dateTime', hi),
      ]),
    );
    for (final meal in meals) {
      if (!inWindow(meal.dateTime)) continue;
      at(dateKey(meal.dateTime)).meals.add(CalendarMeal(
            mealType: meal.mealType,
            hasNote: (meal.note ?? '').trim().isNotEmpty,
          ));
    }
  }

  Future<void> _addWorship(
    String userId,
    String lo,
    String hi,
    bool Function(DateTime) inWindow,
    DayActivity Function(String) at,
  ) async {
    // userId مطابق تمامًا: السجلات القديمة بلا userId لا تظهر.
    final logs = await _db.list(
      'readingLogs',
      ReadingLog.fromJson,
      filter: Filter.and(<Filter>[
        Filter.equals('userId', userId),
        Filter.greaterThanOrEquals('completedAt', lo),
        Filter.lessThan('completedAt', hi),
      ]),
    );
    for (final log in logs) {
      if (!inWindow(log.completedAt)) continue;
      final day = at(dateKey(log.completedAt));
      if (log.itemId.startsWith('prayer_')) {
        day.prayers = true;
      } else if (log.itemId.startsWith('quran')) {
        day.quran = true;
      } else if (log.itemId.startsWith('adhkar')) {
        day.adhkar = true;
      } else {
        day.otherWorship = true;
      }
    }
  }
}
