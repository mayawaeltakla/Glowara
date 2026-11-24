/// يقرأ المزاج (وجلسات الدراسة عند الطلب) ويحسب الوصف. للقراءة فقط: لا يكتب شيئًا.
library glowara.repositories.insights;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/insights_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class InsightsRepository {
  InsightsRepository(this._db);

  final LocalDatabase _db;

  /// [days] أيام تنتهي باليوم [today] (شاملًا). [includeStudy] يضيف ربط الدراسة؛
  /// جلسات بلا مالك (قديمة) لا تدخل أبدًا.
  Future<MoodInsights> compute(
    String userId, {
    required DateTime today,
    int days = 30,
    bool includeStudy = false,
  }) async {
    final to = DateTime(today.year, today.month, today.day);
    final from = DateTime(to.year, to.month, to.day - (days - 1));
    final moods = await _db.list('moods', MoodEntry.fromJson, filter: Filter.equals('userId', userId));
    Set<String>? studyDays;
    if (includeStudy) {
      final sessions = await _db.list('sessions', StudySession.fromJson, filter: Filter.equals('userId', userId));
      studyDays = <String>{
        for (final s in sessions)
          if (s.userId.isNotEmpty && (s.durationMinutes ?? 0) > 0) dateKey(s.startedAt),
      };
    }
    return computeMoodInsights(moods: moods, from: from, to: to, studyDays: studyDays);
  }
}
