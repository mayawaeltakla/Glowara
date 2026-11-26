/// ملخص «حياتك» (My Lifestyle Dashboard): قراءة فقط من أقسام متعددة، بلا مجموع
/// حياة ولا درجة ولا نسبة ولا مقارنة. لا يدخل فيه المزاج ولا المذكرات ولا
/// العبادة ولا ركني الصغير.
library glowara.models.dashboard;

import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/dream_models.dart';
import 'package:glowara/core/models/library_models.dart';
import 'package:glowara/core/models/routine_models.dart';

/// أقصى عدد عناصر لكل بطاقة.
const int kDashboardMaxItems = 5;

/// أيام المهام القادمة المعروضة (من اليوم).
const int kDashboardUpcomingDays = 7;

class RoutineToday {
  const RoutineToday({required this.routine, required this.stepsDone});

  final Routine routine;
  final int stepsDone;
}

class LifestyleSummary {
  const LifestyleSummary({
    this.upcomingTasks = const <TaskItem>[],
    this.studyMinutesWeek = 0,
    this.habitsScheduled = 0,
    this.habitsDone = 0,
    this.routinesToday = const <RoutineToday>[],
    this.waterMl = 0,
    this.dreamsInProgress = const <Dream>[],
    this.booksReading = const <Book>[],
  });

  final List<TaskItem> upcomingTasks;
  final int studyMinutesWeek;
  final int habitsScheduled;
  final int habitsDone;
  final List<RoutineToday> routinesToday;
  final int waterMl;
  final List<Dream> dreamsInProgress;
  final List<Book> booksReading;

  bool get isEmpty =>
      upcomingTasks.isEmpty &&
      studyMinutesWeek == 0 &&
      habitsScheduled == 0 &&
      routinesToday.isEmpty &&
      waterMl == 0 &&
      dreamsInProgress.isEmpty &&
      booksReading.isEmpty;
}
