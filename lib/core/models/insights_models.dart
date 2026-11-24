/// فهم المزاج والطاقة: وصف لما سجّلتِه فقط. لا تشخيص ولا ادعاء سببية ولا درجة
/// شاملة. الأنماط لا تظهر إلا بعد سجلات كافية، وربط الدراسة اختياري ويعرض
/// أعدادًا جنبًا إلى جنب دون استنتاج.
library glowara.models.insights;

import 'package:glowara/core/models/app_models.dart';

/// أقل أيام مسجّلة لعرض نمط أيام الأسبوع.
const int kInsightMinDays = 14;

/// أقل سجلات ليوم أسبوع واحد ليدخل المقارنة.
const int kInsightMinPerWeekday = 3;

/// أقل فرق في متوسط المزاج بين أعلى يوم وأدنى يوم ليُذكر نمط.
const double kInsightMinGap = 0.5;

/// أقل أيام مسجّلة في كل مجموعة (دراسة / بدون دراسة) لعرض الربط.
const int kInsightMinPerGroup = 5;

class StudyLink {
  const StudyLink({
    required this.studyDays,
    required this.studyHigh,
    required this.otherDays,
    required this.otherHigh,
  });

  /// أيام سجّلتِ فيها مزاجًا وفيها جلسة دراسة، ومنها كم يومًا بمزاج 4–5.
  final int studyDays;
  final int studyHigh;

  /// أيام سجّلتِ فيها مزاجًا بلا جلسة دراسة، ومنها كم يومًا بمزاج 4–5.
  final int otherDays;
  final int otherHigh;
}

class MoodInsights {
  const MoodInsights({
    required this.periodDays,
    required this.recordedDays,
    required this.moodCounts,
    required this.energyRecordedDays,
    required this.energyCounts,
    this.highestWeekday,
    this.lowestWeekday,
    this.study,
  });

  final int periodDays;
  final int recordedDays;

  /// مستوى (1..5) -> عدد الأيام.
  final Map<int, int> moodCounts;
  final int energyRecordedDays;
  final Map<int, int> energyCounts;

  /// يوم الأسبوع (DateTime.weekday) الأعلى/الأدنى متوسط مزاج، أو null إن لم تكفِ
  /// السجلات أو تساوى أو كان الفرق صغيرًا.
  final int? highestWeekday;
  final int? lowestWeekday;
  final StudyLink? study;

  bool get hasEnoughForPatterns => recordedDays >= kInsightMinDays;
}

/// يحسب الوصف لفترة [from]..[to] (شاملة). [studyDays] مفاتيح أيام فيها جلسات دراسة؛
/// تُمرَّر فقط إن اختارت المستخدمة ربط الدراسة وإلا تُترك null.
MoodInsights computeMoodInsights({
  required List<MoodEntry> moods,
  required DateTime from,
  required DateTime to,
  Set<String>? studyDays,
}) {
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final fromKey = key(from);
  final toKey = key(to);
  final inRange = <String, MoodEntry>{};
  for (final m in moods) {
    if (m.date.compareTo(fromKey) >= 0 && m.date.compareTo(toKey) <= 0) inRange[m.date] = m;
  }
  final mood = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
  final energy = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
  var energyDays = 0;
  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final m in inRange.values) {
    final v = m.value.clamp(1, 5).toInt();
    mood[v] = mood[v]! + 1;
    final e = m.energy;
    if (e != null) {
      energy[e] = energy[e]! + 1;
      energyDays++;
    }
    final d = DateTime.tryParse(m.date);
    if (d != null) {
      sums[d.weekday] = (sums[d.weekday] ?? 0) + v;
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
  }

  int? highest;
  int? lowest;
  if (inRange.length >= kInsightMinDays) {
    final avg = <int, double>{
      for (final e in counts.entries)
        if (e.value >= kInsightMinPerWeekday) e.key: sums[e.key]! / e.value,
    };
    if (avg.length >= 2) {
      final values = avg.values.toList()..sort();
      final max = values.last;
      final min = values.first;
      if (max - min >= kInsightMinGap) {
        final tops = avg.entries.where((e) => e.value == max).toList();
        final bottoms = avg.entries.where((e) => e.value == min).toList();
        if (tops.length == 1) highest = tops.single.key;
        if (bottoms.length == 1) lowest = bottoms.single.key;
      }
    }
  }

  StudyLink? link;
  if (studyDays != null) {
    var sd = 0, sh = 0, od = 0, oh = 0;
    for (final m in inRange.values) {
      final high = m.value >= 4;
      if (studyDays.contains(m.date)) {
        sd++;
        if (high) sh++;
      } else {
        od++;
        if (high) oh++;
      }
    }
    if (sd >= kInsightMinPerGroup && od >= kInsightMinPerGroup) {
      link = StudyLink(studyDays: sd, studyHigh: sh, otherDays: od, otherHigh: oh);
    }
  }

  return MoodInsights(
    periodDays: to.difference(DateTime(from.year, from.month, from.day)).inDays + 1,
    recordedDays: inRange.length,
    moodCounts: mood,
    energyRecordedDays: energyDays,
    energyCounts: energy,
    highestWeekday: highest,
    lowestWeekday: lowest,
    study: link,
  );
}
