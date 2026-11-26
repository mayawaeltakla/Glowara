/// نماذج المراجعة الأسبوعية. نصوص كتبتها المستخدمة بنفسها، بلا درجات.
library glowara.models.weekly_reset;

import 'package:glowara/core/utils/date_utils.dart';

/// نوع تركيز الأسبوع القادم.
enum WeeklyFocusType { none, habit, text }

/// أقصى عدد للأولويات، وأقصى أطوال النصوص (حدود معقولة لا تُقصّ كتابتها فعليًا).
const int kWeeklyMaxPriorities = 3;
const int kWeeklyPriorityMax = 120;
const int kWeeklyNoteMax = 1000;

class WeeklyReset {
  const WeeklyReset({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    this.wentWell = '',
    this.needsAdjustment = '',
    this.priorities = const <String>[],
    this.focusType = WeeklyFocusType.none,
    this.focusHabitId,
    this.focusText = '',
    this.studyPlan = '',
    this.personalPlan = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// `<userId>_<weekStart>` — معرّف ثابت، فمراجعة الأسبوع الواحد سجل واحد.
  final String id;
  final String userId;

  /// مفتاحا أول وآخر يوم في الأسبوع المُراجَع (`YYYY-MM-DD`)، يُحفظان صراحةً
  /// حتى لا يتغيّر معنى سجل قديم إن تغيّرت قاعدة بداية الأسبوع (لغة التطبيق).
  final String weekStart;
  final String weekEnd;

  final String wentWell;
  final String needsAdjustment;

  /// حتى [kWeeklyMaxPriorities] أولويات نصية فقط (لا تُنشأ منها مهام).
  final List<String> priorities;
  final WeeklyFocusType focusType;
  final String? focusHabitId;
  final String focusText;
  final String studyPlan;
  final String personalPlan;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String idFor(String userId, String weekStart) => '${userId}_$weekStart';

  /// هل فيها أي شيء كتبته المستخدمة؟
  bool get isBlank =>
      wentWell.isEmpty &&
      needsAdjustment.isEmpty &&
      priorities.isEmpty &&
      focusType == WeeklyFocusType.none &&
      studyPlan.isEmpty &&
      personalPlan.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'wentWell': wentWell,
        'needsAdjustment': needsAdjustment,
        'priorities': priorities,
        'focusType': focusType.name,
        'focusHabitId': focusHabitId,
        'focusText': focusText,
        'studyPlan': studyPlan,
        'personalPlan': personalPlan,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory WeeklyReset.fromJson(Map<String, dynamic> j) {
    String text(Object? v) => v is String ? v : '';
    DateTime when(Object? v) => (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();
    final rawPriorities = j['priorities'];
    final typeName = j['focusType'];
    return WeeklyReset(
      id: j['id'] as String,
      userId: j['userId'] as String,
      weekStart: j['weekStart'] as String,
      weekEnd: j['weekEnd'] as String,
      wentWell: text(j['wentWell']),
      needsAdjustment: text(j['needsAdjustment']),
      priorities: rawPriorities is List
          ? rawPriorities.whereType<String>().take(kWeeklyMaxPriorities).toList()
          : const <String>[],
      focusType: WeeklyFocusType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => WeeklyFocusType.none,
      ),
      focusHabitId: j['focusHabitId'] as String?,
      focusText: text(j['focusText']),
      studyPlan: text(j['studyPlan']),
      personalPlan: text(j['personalPlan']),
      createdAt: when(j['createdAt']),
      updatedAt: when(j['updatedAt']),
    );
  }
}

/// ملخص أسبوع: أعداد حقيقية فقط. لا نسب ولا درجات، وبلا مزاج ولا مذكرات.
class WeekSummary {
  const WeekSummary({
    this.tasksDone = 0,
    this.habitDays = 0,
    this.studyMinutes = 0,
    this.quranDays = 0,
    this.adhkarCompleted = 0,
    this.waterDays = 0,
    this.careStepsDone = 0,
    this.lessonsCompleted = 0,
  });

  final int tasksDone;
  final int habitDays;
  final int studyMinutes;
  final int quranDays;
  final int adhkarCompleted;
  final int waterDays;
  final int careStepsDone;
  final int lessonsCompleted;

  bool get isEmpty =>
      tasksDone == 0 &&
      habitDays == 0 &&
      studyMinutes == 0 &&
      quranDays == 0 &&
      adhkarCompleted == 0 &&
      waterDays == 0 &&
      careStepsDone == 0 &&
      lessonsCompleted == 0;
}

/// هل تُعرض بطاقة الرئيسية؟ في أول يومين من الأسبوع، إن لم تُحفظ مراجعة للأسبوع
/// السابق ولم تُخفَ. دالة نقية لتُختبر بلا واجهة.
bool shouldOfferWeeklyReset({
  required DateTime today,
  required int weekStart,
  required bool previousWeekReviewed,
  required bool hidden,
}) {
  if (previousWeekReviewed || hidden) return false;
  final daysIntoWeek = (today.weekday - weekStart + 7) % 7;
  return daysIntoWeek <= 1;
}

String weeklyResetHiddenKey(String userId, DateTime weekStartDay) =>
    'weekly_reset_hidden_${userId}_${dateKey(weekStartDay)}';
