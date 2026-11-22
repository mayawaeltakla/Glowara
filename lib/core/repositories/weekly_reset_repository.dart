/// مستودع المراجعة الأسبوعية.
///
/// - الملخص من السجلات الحقيقية عبر [ProgressRepository.stats] لكن لا يُمرَّر منه
///   إلا الأعداد المسموحة (بلا مزاج ولا مذكرات)، وتُستبعد السجلات القديمة بلا مالك.
/// - لا ينشئ مهامًا ولا إشعارات.
library glowara.repositories.weekly_reset;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/weekly_reset_models.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';

class WeeklyResetRepository {
  WeeklyResetRepository(this._db, this._progress);

  final LocalDatabase _db;
  final ProgressRepository _progress;

  static const String _store = 'weeklyResets';

  Future<WeeklyReset?> forWeek(String userId, DateTime weekStart) =>
      _db.byId(_store, WeeklyReset.idFor(userId, dateKey(weekStart)), WeeklyReset.fromJson);

  /// أحدث المراجعات لهذه المستخدمة، الأحدث أسبوعًا أولًا.
  Future<List<WeeklyReset>> recent(String userId, {int limit = 8}) async {
    final list = await _db.list(
      _store,
      WeeklyReset.fromJson,
      filter: Filter.equals('userId', userId),
    );
    list.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return list.take(limit).toList();
  }

  /// يحفظ مراجعة الأسبوع [weekStart]..[weekEnd]. يُنظّف النصوص ويقصّ الأولويات إلى
  /// ثلاث، ويُسقط تركيز عادة لا تخص هذه المستخدمة. مراجعة فارغة تمامًا لا تُحفظ
  /// (وتحذف السجل إن كان موجودًا) فلا تتراكم سجلات فارغة.
  Future<WeeklyReset?> save({
    required String userId,
    required DateTime weekStart,
    required DateTime weekEnd,
    String wentWell = '',
    String needsAdjustment = '',
    List<String> priorities = const <String>[],
    WeeklyFocusType focusType = WeeklyFocusType.none,
    String? focusHabitId,
    String focusText = '',
    String studyPlan = '',
    String personalPlan = '',
  }) async {
    String clean(String v, int max) {
      final t = v.trim();
      return t.length <= max ? t : t.substring(0, max);
    }

    final cleanedPriorities = <String>[
      for (final p in priorities)
        if (clean(p, kWeeklyPriorityMax).isNotEmpty) clean(p, kWeeklyPriorityMax),
    ].take(kWeeklyMaxPriorities).toList();

    var type = focusType;
    String? habitId;
    var text = '';
    if (type == WeeklyFocusType.habit) {
      final habits = await _db.list(
        'habits',
        Habit.fromJson,
        filter: Filter.and(<Filter>[
          Filter.equals('userId', userId),
          Filter.equals('id', focusHabitId ?? ''),
        ]),
      );
      if (habits.isEmpty) {
        type = WeeklyFocusType.none;
      } else {
        habitId = habits.first.id;
      }
    } else if (type == WeeklyFocusType.text) {
      text = clean(focusText, kWeeklyPriorityMax);
      if (text.isEmpty) type = WeeklyFocusType.none;
    }

    final id = WeeklyReset.idFor(userId, dateKey(weekStart));
    final existing = await _db.byId(_store, id, WeeklyReset.fromJson);
    final now = DateTime.now();
    final reset = WeeklyReset(
      id: id,
      userId: userId,
      weekStart: dateKey(weekStart),
      weekEnd: dateKey(weekEnd),
      wentWell: clean(wentWell, kWeeklyNoteMax),
      needsAdjustment: clean(needsAdjustment, kWeeklyNoteMax),
      priorities: cleanedPriorities,
      focusType: type,
      focusHabitId: habitId,
      focusText: text,
      studyPlan: clean(studyPlan, kWeeklyNoteMax),
      personalPlan: clean(personalPlan, kWeeklyNoteMax),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (reset.isBlank) {
      if (existing != null) await _db.delete(_store, id);
      return null;
    }
    await _db.put(_store, id, reset.toJson());
    return reset;
  }

  /// يحذف مراجعة هذه المستخدمة فقط.
  Future<void> delete(String userId, DateTime weekStart) =>
      _db.delete(_store, WeeklyReset.idFor(userId, dateKey(weekStart)));

  /// ملخص الأسبوع من السجلات. لا مزاج ولا مذكرات، ولا سجلات قديمة بلا مالك.
  Future<WeekSummary> summary(String userId, DateTime weekStart, DateTime weekEnd) async {
    final s = await _progress.stats(
      userId: userId,
      from: weekStart,
      to: weekEnd,
      includeLegacyOwnerless: false,
    );
    return WeekSummary(
      tasksDone: s.tasksDone,
      habitDays: s.habitsDone,
      studyMinutes: s.studyMinutes,
      quranDays: s.quranDays,
      adhkarCompleted: s.adhkarCompleted,
      waterDays: s.waterDays,
      careStepsDone: s.careStepsDone,
      lessonsCompleted: s.lessonsCompleted,
    );
  }
}
