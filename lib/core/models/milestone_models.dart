/// نماذج المعالم (الإنجازات). بلا نقاط ولا مستويات ولا ترتيب ولا مقارنة.
///
/// المعالم تُحسب من السجلات الحقيقية لهذه المستخدمة فقط، وتراكمية: ما تحقق يبقى
/// مسجّلًا ولا يُسحب إن حُذف سجل لاحقًا أو انقطع نشاط. لا عبادات ولا مزاج ولا
/// مذكرات تدخل في أي معلم.
library glowara.models.milestone;

enum MilestoneCategory { start, consistency, study, care, goals }

/// ما يُعدّ: كل مقياس عدد صحيح تراكمي.
enum MilestoneMetric {
  tasksDone,
  habitLogs,
  studySessions,
  careDone,
  goalsCreated,
  activeDays,
  studyMinutes,
  goalsCompleted,
}

class MilestoneDef {
  const MilestoneDef(this.id, this.category, this.metric, this.threshold);

  /// معرّف ثابت بلا شرطة سفلية (يدخل في مفتاح السجل `<userId>_<id>`).
  final String id;
  final MilestoneCategory category;
  final MilestoneMetric metric;
  final int threshold;

  String get titleKey => 'ms:$id';
  String get bodyKey => 'ms:$id:body';
}

/// كتالوج المعالم. لا تُغيَّر معرّفات موجودة بعد النشر (تُخزَّن في السجلات).
const List<MilestoneDef> kMilestones = <MilestoneDef>[
  MilestoneDef('first-task', MilestoneCategory.start, MilestoneMetric.tasksDone, 1),
  MilestoneDef('first-habit', MilestoneCategory.start, MilestoneMetric.habitLogs, 1),
  MilestoneDef('first-study', MilestoneCategory.start, MilestoneMetric.studySessions, 1),
  MilestoneDef('first-care', MilestoneCategory.start, MilestoneMetric.careDone, 1),
  MilestoneDef('first-goal', MilestoneCategory.start, MilestoneMetric.goalsCreated, 1),
  MilestoneDef('days-7', MilestoneCategory.consistency, MilestoneMetric.activeDays, 7),
  MilestoneDef('days-30', MilestoneCategory.consistency, MilestoneMetric.activeDays, 30),
  MilestoneDef('days-100', MilestoneCategory.consistency, MilestoneMetric.activeDays, 100),
  MilestoneDef('study-60', MilestoneCategory.study, MilestoneMetric.studyMinutes, 60),
  MilestoneDef('study-600', MilestoneCategory.study, MilestoneMetric.studyMinutes, 600),
  MilestoneDef('study-3000', MilestoneCategory.study, MilestoneMetric.studyMinutes, 3000),
  MilestoneDef('care-10', MilestoneCategory.care, MilestoneMetric.careDone, 10),
  MilestoneDef('care-50', MilestoneCategory.care, MilestoneMetric.careDone, 50),
  MilestoneDef('care-200', MilestoneCategory.care, MilestoneMetric.careDone, 200),
  MilestoneDef('goal-done-1', MilestoneCategory.goals, MilestoneMetric.goalsCompleted, 1),
  MilestoneDef('goal-done-5', MilestoneCategory.goals, MilestoneMetric.goalsCompleted, 5),
];

/// سجل معلم تحقق لدى مستخدمة. المفتاح `<userId>_<milestoneId>`.
class EarnedMilestone {
  const EarnedMilestone({
    required this.id,
    required this.userId,
    required this.milestoneId,
    required this.earnedAt,
  });

  final String id;
  final String userId;
  final String milestoneId;

  /// وقت تسجيل المعلم في التطبيق (لا وقت الحدث الأصلي، فقد يكون سُجّل لاحقًا).
  final DateTime earnedAt;

  static String idFor(String userId, String milestoneId) => '${userId}_$milestoneId';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'milestoneId': milestoneId,
        'earnedAt': earnedAt.toUtc().toIso8601String(),
      };

  factory EarnedMilestone.fromJson(Map<String, dynamic> j) => EarnedMilestone(
        id: j['id'] as String,
        userId: j['userId'] as String,
        milestoneId: j['milestoneId'] as String,
        earnedAt: (j['earnedAt'] is String ? DateTime.tryParse(j['earnedAt'] as String)?.toLocal() : null) ??
            DateTime.now(),
      );
}

/// صف في شاشة المعالم.
class MilestoneEntry {
  const MilestoneEntry({
    required this.def,
    required this.current,
    this.earnedAt,
    this.isNew = false,
  });

  final MilestoneDef def;

  /// القيمة الحالية للمقياس (للعرض «٣ من ٧»).
  final int current;
  final DateTime? earnedAt;

  /// تحقق في هذه الزيارة للشاشة.
  final bool isNew;

  bool get earned => earnedAt != null;
}
