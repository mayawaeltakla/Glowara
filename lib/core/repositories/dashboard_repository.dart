/// يجمع ملخص «حياتك» من الأقسام الأخرى. للقراءة فقط: لا يكتب شيئًا. جلسات الدراسة
/// القديمة بلا مالك لا تدخل. لا يقرأ المزاج ولا المذكرات ولا العبادة ولا ركني.
library glowara.repositories.dashboard;

import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/dashboard_models.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
import 'package:glowara/core/repositories/habit_repository.dart';
import 'package:glowara/core/repositories/health_repository.dart';
import 'package:glowara/core/repositories/library_repository.dart';
import 'package:glowara/core/repositories/routine_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';

class DashboardRepository {
  DashboardRepository(this._db);

  final LocalDatabase _db;

  /// [weekStart]..[weekEnd] أسبوع الدراسة المعروض (حسب لغة المستخدمة).
  Future<LifestyleSummary> build(
    String userId, {
    required DateTime today,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final day = DateTime(today.year, today.month, today.day);

    // مهام قادمة: غير منجزة، من اليوم خلال الأيام القادمة، الأقرب أولًا.
    final tasks = TaskRepository(_db);
    final until = DateTime(day.year, day.month, day.day + kDashboardUpcomingDays, 23, 59, 59);
    final upcoming = (await tasks.forRange(userId, day, until)).where((t) => t.state != TaskState.done).toList()
      ..sort((a, b) => a.dueDateTime!.compareTo(b.dueDateTime!));

    // دراسة هذا الأسبوع (جلسات هذه المستخدمة فقط).
    final sessions = await StudyRepository(_db).sessions(from: weekStart, to: weekEnd);
    final minutes = sessions
        .where((s) => s.userId == userId)
        .fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

    // عادات اليوم.
    final habitRepo = HabitRepository(_db);
    final scheduled = (await habitRepo.active(userId)).where((h) => habitRepo.isScheduled(h, day)).toList();
    final logs = await habitRepo.logsForRange(day, day);
    final doneIds = logs.where((l) => l.state == WorshipState.completed).map((l) => l.habitId).toSet();
    final habitsDone = scheduled.where((h) => doneIds.contains(h.id)).length;

    // روتينات اليوم.
    final routineRepo = RoutineRepository(_db);
    final routines = (await routineRepo.all(userId)).where((r) => r.runsOn(day) && r.steps.isNotEmpty).toList();
    final routineDay = await routineRepo.dayFor(userId, day);
    final routinesToday = <RoutineToday>[
      for (final r in routines)
        RoutineToday(
          routine: r,
          stepsDone: r.steps.where((s) => routineDay?.isDone(r.id, s.id) ?? false).length,
        ),
    ];

    final water = await HealthRepository(_db).waterTotal(userId, day);
    final dreams = (await DreamRepository(_db).all(userId))
        .where((d) => d.stage == 'planning' || d.stage == 'working')
        .take(kDashboardMaxItems)
        .toList();
    final books = (await LibraryRepository(_db).all(userId)).where((b) => b.status == 'reading').take(kDashboardMaxItems).toList();

    return LifestyleSummary(
      upcomingTasks: upcoming.take(kDashboardMaxItems).toList(),
      studyMinutesWeek: minutes,
      habitsScheduled: scheduled.length,
      habitsDone: habitsDone,
      routinesToday: routinesToday.take(kDashboardMaxItems).toList(),
      waterMl: water,
      dreamsInProgress: dreams,
      booksReading: books,
    );
  }
}
