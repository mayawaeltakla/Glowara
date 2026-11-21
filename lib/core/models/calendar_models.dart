/// نماذج عرض التقويم الشهري. للقراءة فقط وغير مخزَّنة في قاعدة البيانات.
library glowara.models.calendar;

import 'package:glowara/core/utils/date_utils.dart';

/// طبقات التقويم. المذكرات والمزاج غير موجودين عمدًا (خصوصية).
enum CalendarLayer { tasks, study, habits, worship, care, nutrition }

class CalendarTask {
  const CalendarTask({required this.title, this.time, this.done = false});

  final String title;

  /// وقت الاستحقاق إن كان محددًا (غير منتصف الليل).
  final DateTime? time;
  final bool done;
}

class CalendarHabit {
  const CalendarHabit({required this.name, required this.logged});

  final String name;

  /// `true`: سُجّلت اليوم. `false`: عادة مجدولة لهذا اليوم (يوم اليوم أو المستقبل).
  final bool logged;
}

class CalendarMeal {
  const CalendarMeal({required this.mealType, this.hasNote = false});

  final String mealType;

  /// يوجد نص ملاحظة، لكن النص نفسه لا يُعرض في التقويم.
  final bool hasNote;
}

/// ما يخص يومًا واحدًا. يُبنى في المستودع ثم يُقرأ فقط.
class DayActivity {
  final List<CalendarTask> tasks = <CalendarTask>[];
  final List<CalendarHabit> habits = <CalendarHabit>[];

  /// دقائق الدراسة حسب معرّف المادة.
  final Map<String, int> studyMinutesBySubject = <String, int>{};
  final List<String> care = <String>[];
  final List<CalendarMeal> meals = <CalendarMeal>[];
  int waterMl = 0;

  /// العبادات: وجود سجل فقط. لا أعداد ولا تقييم.
  bool prayers = false;
  bool quran = false;
  bool adhkar = false;
  bool otherWorship = false;

  bool get hasWorship => prayers || quran || adhkar || otherWorship;

  bool get hasNutrition => meals.isNotEmpty || waterMl > 0;

  /// الطبقات الحاضرة بترتيب العرض الثابت.
  List<CalendarLayer> get layers => <CalendarLayer>[
        if (tasks.isNotEmpty) CalendarLayer.tasks,
        if (studyMinutesBySubject.isNotEmpty) CalendarLayer.study,
        if (habits.isNotEmpty) CalendarLayer.habits,
        if (hasWorship) CalendarLayer.worship,
        if (care.isNotEmpty) CalendarLayer.care,
        if (hasNutrition) CalendarLayer.nutrition,
      ];

  bool get isEmpty => layers.isEmpty;
}

class MonthSnapshot {
  MonthSnapshot({
    required this.gridStart,
    required this.gridEndExclusive,
    required this.days,
    required this.subjectNames,
  });

  final DateTime gridStart;
  final DateTime gridEndExclusive;
  final Map<String, DayActivity> days;

  /// أسماء مواد الدراسة (معرّف إلى اسم) لعرض تفاصيل اليوم.
  final Map<String, String> subjectNames;

  DayActivity dayFor(DateTime day) => days[dateKey(day)] ?? DayActivity();
}
