import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/insights_models.dart';
import 'package:glowara/core/repositories/insights_repository.dart';
import 'package:glowara/core/repositories/journal_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';
final DateTime _today = DateTime(2026, 11, 23); // الاثنين

MoodEntry _mood(DateTime d, int v, {int? energy, String user = _a}) => MoodEntry(
      id: '${user}_${dateKey(d)}',
      userId: user,
      date: dateKey(d),
      value: v,
      energy: energy,
      createdAt: d,
    );

/// 28 يومًا (2026-10-26..2026-11-22): الجمعة 5، الاثنين 2، والبقية 3.
List<MoodEntry> _pattern({String user = _a}) {
  final out = <MoodEntry>[];
  for (var i = 0; i < 28; i++) {
    final d = DateTime(2026, 10, 26 + i);
    final v = d.weekday == DateTime.friday ? 5 : (d.weekday == DateTime.monday ? 2 : 3);
    out.add(_mood(d, v, user: user));
  }
  return out;
}

void main() {
  group('MoodEntry energy', () {
    test('round-trips and old records have none', () {
      final m = _mood(DateTime(2026, 11, 1), 4, energy: 2);
      expect(MoodEntry.fromJson(m.toJson()).energy, 2);
      final old = m.toJson()..remove('energy');
      expect(MoodEntry.fromJson(old).energy, isNull);
      for (final bad in <Object?>[0, 6, 'x', 2.5]) {
        expect(MoodEntry.fromJson(m.toJson()..['energy'] = bad).energy, isNull, reason: '$bad');
      }
    });

    test('saveMood stores a clamped optional energy and keeps none when omitted', () async {
      final db = await openTestDatabase();
      final repo = JournalRepository(db);
      await repo.saveMood(userId: _a, day: DateTime(2026, 11, 1), value: 3, energy: 9);
      expect((await repo.moodFor(_a, DateTime(2026, 11, 1)))!.energy, 5);
      await repo.saveMood(userId: _a, day: DateTime(2026, 11, 1), value: 3);
      expect((await repo.moodFor(_a, DateTime(2026, 11, 1)))!.energy, isNull);
    });
  });

  group('computeMoodInsights', () {
    final from = DateTime(2026, 10, 25);

    test('empty input is empty', () {
      final r = computeMoodInsights(moods: const <MoodEntry>[], from: from, to: _today);
      expect(r.recordedDays, 0);
      expect(r.periodDays, 30);
      expect(r.highestWeekday, isNull);
      expect(r.hasEnoughForPatterns, isFalse);
      expect(r.study, isNull);
    });

    test('counts levels and energy; ignores days outside the period', () {
      final r = computeMoodInsights(
        moods: <MoodEntry>[
          _mood(DateTime(2026, 11, 1), 5, energy: 4),
          _mood(DateTime(2026, 11, 2), 5),
          _mood(DateTime(2026, 11, 3), 1, energy: 4),
          _mood(DateTime(2026, 10, 1), 3, energy: 1), // قبل الفترة
        ],
        from: from,
        to: _today,
      );
      expect(r.recordedDays, 3);
      expect(r.moodCounts[5], 2);
      expect(r.moodCounts[1], 1);
      expect(r.moodCounts[3], 0);
      expect(r.energyRecordedDays, 2);
      expect(r.energyCounts[4], 2);
      expect(r.energyCounts[1], 0);
    });

    test('weekday pattern appears only with enough data and a clear unique gap', () {
      final few = computeMoodInsights(moods: _pattern().take(10).toList(), from: from, to: _today);
      expect(few.hasEnoughForPatterns, isFalse);
      expect(few.highestWeekday, isNull);

      final r = computeMoodInsights(moods: _pattern(), from: from, to: _today);
      expect(r.hasEnoughForPatterns, isTrue);
      expect(r.highestWeekday, DateTime.friday);
      expect(r.lowestWeekday, DateTime.monday);
    });

    test('no pattern when all weekdays look the same or the top is tied', () {
      final flat = <MoodEntry>[for (var i = 0; i < 28; i++) _mood(DateTime(2026, 10, 26 + i), 3)];
      final r = computeMoodInsights(moods: flat, from: from, to: _today);
      expect(r.highestWeekday, isNull);
      expect(r.lowestWeekday, isNull);

      final tied = <MoodEntry>[
        for (var i = 0; i < 28; i++)
          _mood(
            DateTime(2026, 10, 26 + i),
            (DateTime(2026, 10, 26 + i).weekday == DateTime.friday || DateTime(2026, 10, 26 + i).weekday == DateTime.saturday) ? 5 : 3,
          ),
      ];
      final t = computeMoodInsights(moods: tied, from: from, to: _today);
      expect(t.highestWeekday, isNull, reason: 'two weekdays share the top');
    });

    test('study link needs both groups to be large enough and never names a cause', () {
      final moods = _pattern();
      final studyDays = <String>{
        for (final m in moods)
          if (DateTime.parse(m.date).weekday == DateTime.friday || DateTime.parse(m.date).weekday == DateTime.tuesday) m.date,
      };
      final r = computeMoodInsights(moods: moods, from: from, to: _today, studyDays: studyDays);
      expect(r.study!.studyDays, 8);
      expect(r.study!.studyHigh, 4);
      expect(r.study!.otherDays, 20);
      expect(r.study!.otherHigh, 0);

      final small = computeMoodInsights(moods: moods, from: from, to: _today, studyDays: <String>{moods.first.date});
      expect(small.study, isNull);
      final off = computeMoodInsights(moods: moods, from: from, to: _today);
      expect(off.study, isNull);
    });
  });

  group('InsightsRepository', () {
    late LocalDatabase db;
    late InsightsRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = InsightsRepository(db);
      for (final m in _pattern()) {
        await db.put('moods', m.id, m.toJson());
      }
      for (final m in _pattern(user: _b)) {
        await db.put('moods', m.id, MoodEntry.fromJson(m.toJson()..['value'] = 1).toJson());
      }
    });

    test('reads only this account and writes nothing', () async {
      final before = await db.count('moods');
      final r = await repo.compute(_a, today: _today);
      expect(r.recordedDays, 28);
      expect(r.moodCounts[1], 0, reason: 'the other account has only level 1');
      expect(await db.count('moods'), before);
    });

    test('study link uses real sessions, excludes ownerless and zero-length ones', () async {
      Future<void> session(String id, String user, DateTime d, int? minutes) => db.put(
            'sessions',
            id,
            StudySession(
              id: id,
              userId: user,
              subjectId: 's',
              startedAt: DateTime(d.year, d.month, d.day, 10),
              durationMinutes: minutes,
              createdAt: d,
            ).toJson(),
          );
      for (var i = 0; i < 28; i++) {
        final d = DateTime(2026, 10, 26 + i);
        if (d.weekday == DateTime.friday) await session('s$i', _a, d, 30);
        if (d.weekday == DateTime.tuesday) await session('s$i', '', d, 30); // قديمة بلا مالك
        if (d.weekday == DateTime.wednesday) await session('s$i', _a, d, 0);
        if (d.weekday == DateTime.thursday) await session('s$i', _b, d, 30);
      }
      final off = await repo.compute(_a, today: _today);
      expect(off.study, isNull);
      final withStudy = await repo.compute(_a, today: _today, includeStudy: true);
      // 4 جمعات فقط تُحتسب، أقل من الحد الأدنى للمجموعة.
      expect(withStudy.study, isNull);
      for (var i = 0; i < 28; i++) {
        final d = DateTime(2026, 10, 26 + i);
        if (d.weekday == DateTime.saturday) await session('x$i', _a, d, 20);
      }
      final enough = await repo.compute(_a, today: _today, includeStudy: true);
      expect(enough.study!.studyDays, 8);
    });

    test('90 days is a longer window', () async {
      final r = await repo.compute(_a, today: _today, days: 90);
      expect(r.periodDays, 90);
      expect(r.recordedDays, 28);
    });
  });
}
