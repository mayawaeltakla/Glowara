import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/weekly_reset_models.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/weekly_reset_repository.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

// 2026-11-15 أحد. أسبوع الأحد: 15..21، أسبوع الاثنين: 16..22.
final DateTime _sun = DateTime(2026, 11, 15);
final DateTime _sat = DateTime(2026, 11, 21);

void main() {
  group('week layout', () {
    test('Sunday-start weeks (Arabic)', () {
      for (var d = 15; d <= 21; d++) {
        expect(weekStartOf(DateTime(2026, 11, d, 23, 59), DateTime.sunday), _sun, reason: 'day $d');
      }
      expect(weekStartOf(DateTime(2026, 11, 22), DateTime.sunday), DateTime(2026, 11, 22));
      expect(weekEndOf(_sun), _sat);
    });

    test('Monday-start weeks (English)', () {
      expect(weekStartOf(DateTime(2026, 11, 15), DateTime.monday), DateTime(2026, 11, 9));
      expect(weekStartOf(DateTime(2026, 11, 16), DateTime.monday), DateTime(2026, 11, 16));
      expect(weekEndOf(DateTime(2026, 11, 16)), DateTime(2026, 11, 22));
    });

    test('weeks cross month and year boundaries without drifting', () {
      expect(weekStartOf(DateTime(2027, 1, 1), DateTime.sunday), DateTime(2026, 12, 27));
      expect(weekEndOf(DateTime(2026, 12, 27)), DateTime(2027, 1, 2));
      // حول تغيّر التوقيت الصيفي.
      expect(weekEndOf(DateTime(2026, 10, 25)), DateTime(2026, 10, 31));
      expect(weekStartOf(DateTime(2026, 3, 30), DateTime.sunday), DateTime(2026, 3, 29));
    });
  });

  group('home offer rule', () {
    // الأحد 15 نوفمبر هو أول يوم في أسبوع يبدأ بالأحد.
    test('offered on the first two days of the week only', () {
      for (var offset = 0; offset < 7; offset++) {
        final today = DateTime(2026, 11, 15 + offset);
        final shown = shouldOfferWeeklyReset(
          today: today,
          weekStart: DateTime.sunday,
          previousWeekReviewed: false,
          hidden: false,
        );
        expect(shown, offset <= 1, reason: 'offset $offset');
      }
    });

    test('Monday-start weeks use Monday as the first day', () {
      bool at(int day) => shouldOfferWeeklyReset(
            today: DateTime(2026, 11, day),
            weekStart: DateTime.monday,
            previousWeekReviewed: false,
            hidden: false,
          );
      expect(at(15), isFalse); // الأحد: آخر يوم في أسبوع الاثنين
      expect(at(16), isTrue);
      expect(at(17), isTrue);
      expect(at(18), isFalse);
    });

    test('not offered once reviewed or hidden', () {
      expect(
        shouldOfferWeeklyReset(
            today: _sun, weekStart: DateTime.sunday, previousWeekReviewed: true, hidden: false),
        isFalse,
      );
      expect(
        shouldOfferWeeklyReset(
            today: _sun, weekStart: DateTime.sunday, previousWeekReviewed: false, hidden: true),
        isFalse,
      );
    });
  });

  group('model', () {
    test('json round trip keeps everything', () {
      final r = WeeklyReset(
        id: 'ua_2026-11-15',
        userId: _a,
        weekStart: '2026-11-15',
        weekEnd: '2026-11-21',
        wentWell: 'جيد',
        needsAdjustment: 'تعديل',
        priorities: const <String>['أ', 'ب'],
        focusType: WeeklyFocusType.text,
        focusText: 'نوم مبكر',
        studyPlan: 'دراسة',
        personalPlan: 'لنفسي',
        createdAt: DateTime(2026, 11, 21, 10),
        updatedAt: DateTime(2026, 11, 21, 11),
      );
      final back = WeeklyReset.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), r.toJson());
      expect(back.createdAt, r.createdAt);
    });

    test('reading tolerates bad or missing fields', () {
      final r = WeeklyReset.fromJson(<String, dynamic>{
        'id': 'x',
        'userId': _a,
        'weekStart': '2026-11-15',
        'weekEnd': '2026-11-21',
        'priorities': <Object?>['1', 2, '3', '4', '5'],
        'focusType': 'unknown',
        'wentWell': 5,
      });
      expect(r.priorities, <String>['1', '3', '4']);
      expect(r.focusType, WeeklyFocusType.none);
      expect(r.wentWell, '');
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late WeeklyResetRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = WeeklyResetRepository(db, ProgressRepository(db, SettingsRepository(db)));
    });

    Future<WeeklyReset?> save({
      String user = _a,
      DateTime? start,
      String wentWell = '',
      List<String> priorities = const <String>[],
      WeeklyFocusType focusType = WeeklyFocusType.none,
      String? focusHabitId,
      String focusText = '',
    }) =>
        repo.save(
          userId: user,
          weekStart: start ?? _sun,
          weekEnd: weekEndOf(start ?? _sun),
          wentWell: wentWell,
          priorities: priorities,
          focusType: focusType,
          focusHabitId: focusHabitId,
          focusText: focusText,
        );

    test('saves under a deterministic id with explicit week range', () async {
      final saved = await save(wentWell: '  هادئ  ');
      expect(saved!.id, 'ua_2026-11-15');
      expect(saved.weekStart, '2026-11-15');
      expect(saved.weekEnd, '2026-11-21');
      expect(saved.wentWell, 'هادئ');
      final back = await repo.forWeek(_a, _sun);
      expect(back!.wentWell, 'هادئ');
      expect(await db.count('weeklyResets'), 1);
    });

    test('saving the same week again updates one record and keeps createdAt', () async {
      final first = await save(wentWell: 'أول');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await save(wentWell: 'ثانٍ');
      expect(await db.count('weeklyResets'), 1);
      expect(second!.wentWell, 'ثانٍ');
      expect(second.createdAt, first!.createdAt);
      expect(second.updatedAt.isAfter(first.updatedAt) || second.updatedAt == first.updatedAt, isTrue);
    });

    test('priorities are trimmed, empties dropped and capped at three', () async {
      final saved = await save(priorities: <String>[' أ ', '', 'ب', 'ج', 'د', 'هـ']);
      expect(saved!.priorities, <String>['أ', 'ب', 'ج']);
    });

    test('long text is cut to the limits', () async {
      final saved = await save(
        wentWell: 'x' * (kWeeklyNoteMax + 50),
        priorities: <String>['y' * (kWeeklyPriorityMax + 50)],
      );
      expect(saved!.wentWell.length, kWeeklyNoteMax);
      expect(saved.priorities.single.length, kWeeklyPriorityMax);
    });

    test('a blank review is not stored, and blanking an existing one removes it', () async {
      expect(await save(), isNull);
      expect(await db.count('weeklyResets'), 0);
      await save(wentWell: 'شيء');
      expect(await db.count('weeklyResets'), 1);
      expect(await save(wentWell: '   '), isNull);
      expect(await db.count('weeklyResets'), 0);
    });

    test('focus habit must belong to the same account', () async {
      await db.put('habits', 'ha', Habit(id: 'ha', userId: _a, name: 'عادتي', createdAt: DateTime(2026, 10, 1)).toJson());
      await db.put('habits', 'hb', Habit(id: 'hb', userId: _b, name: 'عادة أخرى', createdAt: DateTime(2026, 10, 1)).toJson());

      final ok = await save(wentWell: 'x', focusType: WeeklyFocusType.habit, focusHabitId: 'ha');
      expect(ok!.focusType, WeeklyFocusType.habit);
      expect(ok.focusHabitId, 'ha');

      final foreign = await save(wentWell: 'x', focusType: WeeklyFocusType.habit, focusHabitId: 'hb');
      expect(foreign!.focusType, WeeklyFocusType.none);
      expect(foreign.focusHabitId, isNull);

      final missing = await save(wentWell: 'x', focusType: WeeklyFocusType.habit, focusHabitId: 'zzz');
      expect(missing!.focusType, WeeklyFocusType.none);
    });

    test('free-text focus with no text falls back to none', () async {
      final empty = await save(wentWell: 'x', focusType: WeeklyFocusType.text, focusText: '  ');
      expect(empty!.focusType, WeeklyFocusType.none);
      final filled = await save(wentWell: 'x', focusType: WeeklyFocusType.text, focusText: ' نوم ');
      expect(filled!.focusText, 'نوم');
    });

    test('recent lists only this account, newest week first', () async {
      await save(start: DateTime(2026, 11, 1), wentWell: 'a');
      await save(start: DateTime(2026, 11, 15), wentWell: 'b');
      await save(start: DateTime(2026, 11, 8), wentWell: 'c');
      await save(user: _b, start: DateTime(2026, 11, 22), wentWell: 'other');
      final list = await repo.recent(_a);
      expect(list.map((r) => r.weekStart), <String>['2026-11-15', '2026-11-08', '2026-11-01']);
      expect(list.every((r) => r.userId == _a), isTrue);
    });

    test('delete removes only that account\'s record for that week', () async {
      await save(wentWell: 'a');
      await save(user: _b, wentWell: 'b');
      await repo.delete(_a, _sun);
      expect(await repo.forWeek(_a, _sun), isNull);
      expect(await repo.forWeek(_b, _sun), isNotNull);
    });

    test('one account never reads another account\'s review', () async {
      await save(user: _b, wentWell: 'سر');
      expect(await repo.forWeek(_a, _sun), isNull);
      expect(await repo.recent(_a), isEmpty);
    });

    test('saving writes nothing outside weeklyResets', () async {
      await db.put('tasks', 't', TaskItem(id: 't', userId: _a, title: 'x', createdAt: DateTime(2026, 11, 1)).toJson());
      Future<Map<String, dynamic>> dump() async {
        final data = await db.exportAll();
        data.remove('exportedAt');
        data.remove('weeklyResets');
        return data;
      }

      final before = jsonEncode(await dump());
      await save(wentWell: 'x', priorities: <String>['a', 'b', 'c']);
      expect(jsonEncode(await dump()), before, reason: 'no tasks, reminders or other data are created');
    });
  });

  group('summary', () {
    late LocalDatabase db;
    late WeeklyResetRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = WeeklyResetRepository(db, ProgressRepository(db, SettingsRepository(db)));
    });

    Future<void> seed(String user, {int taskDay = 17, int minutes = 30}) async {
      await db.put(
        'tasks',
        'task_$user',
        TaskItem(
          id: 'task_$user',
          userId: user,
          title: 'م',
          dueDateTime: DateTime(2026, 11, taskDay, 10),
          state: TaskState.done,
          createdAt: DateTime(2026, 11, 1),
        ).toJson(),
      );
      await db.put('habits', 'habit_$user',
          Habit(id: 'habit_$user', userId: user, name: 'ع', createdAt: DateTime(2026, 10, 1)).toJson());
      await db.put(
        'habitLogs',
        'log_$user',
        HabitLog(
          id: 'log_$user',
          habitId: 'habit_$user',
          date: '2026-11-17',
          state: WorshipState.completed,
          createdAt: DateTime(2026, 11, 17),
        ).toJson(),
      );
      await db.put(
        'sessions',
        'session_$user',
        StudySession(
          id: 'session_$user',
          userId: user,
          subjectId: 's',
          startedAt: DateTime(2026, 11, 18, 9),
          durationMinutes: minutes,
          createdAt: DateTime(2026, 11, 18),
        ).toJson(),
      );
    }

    test('counts tasks, habits and study minutes of this week', () async {
      await seed(_a);
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.tasksDone, 1);
      expect(s.habitDays, 1);
      expect(s.studyMinutes, 30);
      expect(s.isEmpty, isFalse);
    });

    test('a task outside the week is not counted', () async {
      await seed(_a, taskDay: 25);
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.tasksDone, 0);
    });

    test('another account\'s records are not counted', () async {
      await seed(_b);
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.isEmpty, isTrue);
    });

    test('legacy records without an owner are excluded', () async {
      await db.put(
        'sessions',
        'old',
        StudySession(
          id: 'old',
          subjectId: 'x',
          startedAt: DateTime(2026, 11, 18, 9),
          durationMinutes: 40,
          createdAt: DateTime(2026, 11, 18),
        ).toJson(),
      );
      await db.put('readingLogs', 'oldr',
          ReadingLog(id: 'oldr', itemId: 'quran_1', completedAt: DateTime(2026, 11, 18, 5)).toJson());
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.studyMinutes, 0);
      expect(s.quranDays, 0);
    });

    test('mood and journals never reach the summary', () async {
      await db.put('moods', '${_a}_2026-11-17',
          MoodEntry(id: '${_a}_2026-11-17', userId: _a, date: '2026-11-17', value: 1, note: 'سر', createdAt: DateTime(2026, 11, 17))
              .toJson());
      await db.put(
        'journals',
        'j1',
        JournalEntry(id: 'j1', userId: _a, title: 'عنوان سري', content: 'محتوى سري', createdAt: DateTime(2026, 11, 17)).toJson(),
      );
      final s = await repo.summary(_a, _sun, _sat);
      expect(s.isEmpty, isTrue, reason: 'only mood and journals exist; nothing may show');
    });
  });

  group('export and import', () {
    late LocalDatabase db;
    late WeeklyResetRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = WeeklyResetRepository(db, ProgressRepository(db, SettingsRepository(db)));
    });

    Future<void> save(String user, String text) => repo.save(
          userId: user,
          weekStart: _sun,
          weekEnd: _sat,
          wentWell: text,
        ).then((_) {});

    test('account export holds only that account\'s resets and restores them', () async {
      await save(_a, 'مراجعتي');
      await save(_b, 'مراجعتها');
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['weeklyResets'] as Map).keys, <String>['ua_2026-11-15']);

      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      final back = await fresh.byId('weeklyResets', 'ua_2026-11-15', WeeklyReset.fromJson);
      expect(back!.wentWell, 'مراجعتي');
      expect(back.weekStart, '2026-11-15');
      expect(back.weekEnd, '2026-11-21');
    });

    test('importing into a different account re-keys the record to that account', () async {
      await save(_a, 'مراجعتي');
      final export = await db.exportAll(onlyUserId: _a);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _b, allowDifferentSource: true);
      final moved = await fresh.byId('weeklyResets', 'ub_2026-11-15', WeeklyReset.fromJson);
      expect(moved, isNotNull);
      expect(moved!.userId, _b);
      expect(moved.id, 'ub_2026-11-15');
      expect(await fresh.byId('weeklyResets', 'ua_2026-11-15', WeeklyReset.fromJson), isNull);
      final freshRepo = WeeklyResetRepository(fresh, ProgressRepository(fresh, SettingsRepository(fresh)));
      expect((await freshRepo.forWeek(_b, _sun))!.wentWell, 'مراجعتي');
    });

    test('deleting an account removes its resets and keeps the other account\'s', () async {
      await save(_a, 'a');
      await save(_b, 'b');
      await db.deleteUserData(_a);
      expect(await repo.forWeek(_a, _sun), isNull);
      expect(await repo.forWeek(_b, _sun), isNotNull);
    });

    test('an export with a collection this version does not know is still imported', () async {
      final export = <String, dynamic>{
        'app': 'glowara',
        'schemaVersion': 2,
        'someFutureCollection': <String, dynamic>{'k': <String, dynamic>{'x': 1}},
        'weeklyResets': <String, dynamic>{},
      };
      await db.importAll(export);
      expect(await db.count('weeklyResets'), 0);
    });

    test('the hidden-card flag is device UI state and is not exported', () async {
      await SettingsRepository(db).set(weeklyResetHiddenKey(_a, _sun), '1');
      final export = await db.exportAll();
      final settings = export['settings'] as Map;
      expect(settings.keys.where((k) => k.toString().startsWith('weekly_reset_hidden_')), isEmpty);
    });
  });
}
