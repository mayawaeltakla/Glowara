import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/localization/extra_strings.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/models/milestone_models.dart';
import 'package:glowara/core/repositories/milestone_repository.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/repositories/settings_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

void main() {
  group('catalog', () {
    test('ids are unique and never contain an underscore', () {
      final ids = kMilestones.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.any((id) => id.contains('_')), isFalse, reason: 'ids go into <userId>_<id> keys');
    });

    test('every milestone has a title and body in both languages', () {
      for (final lang in <String>['ar', 'en']) {
        final strings = extraStrings[lang]!;
        for (final m in kMilestones) {
          expect(strings[m.titleKey], isNotNull, reason: '$lang ${m.titleKey}');
          expect(strings[m.bodyKey], isNotNull, reason: '$lang ${m.bodyKey}');
        }
        for (final c in <String>[
          'msCatStart', 'msCatConsistency', 'msCatStudy', 'msCatCare', 'msCatGoals',
          'msUnitTasks', 'msUnitHabits', 'msUnitSessions', 'msUnitCare', 'msUnitGoals',
          'msUnitDays', 'msUnitMinutes', 'msTitle', 'msNote', 'msEmpty', 'msNew',
        ]) {
          expect(strings[c], isNotNull, reason: '$lang $c');
        }
      }
    });

    test('thresholds grow within each metric and category', () {
      for (final metric in MilestoneMetric.values) {
        final list = kMilestones.where((m) => m.metric == metric).map((m) => m.threshold).toList();
        final sorted = List<int>.of(list)..sort();
        expect(list, sorted, reason: metric.name);
      }
    });

    test('no worship, mood or journal metric exists, and texts never score', () {
      final names = MilestoneMetric.values.map((m) => m.name.toLowerCase()).join(' ');
      for (final word in <String>['worship', 'quran', 'adhkar', 'prayer', 'mood', 'journal', 'dua']) {
        expect(names.contains(word), isFalse, reason: word);
      }
      for (final lang in <String>['ar', 'en']) {
        final texts = extraStrings[lang]!
            .entries
            .where((e) => e.key.startsWith('ms'))
            .map((e) => e.value)
            .join(' ');
        for (final bad in <String>['نقاط', 'نقطة', 'ترتيب', 'مستوى', 'points', 'level', 'rank', 'score', '%']) {
          // msNote تنفي هذه الكلمات صراحةً، وهي الوحيدة المسموح بها.
          final withoutNote = texts.replaceAll(extraStrings[lang]!['msNote']!, '');
          expect(withoutNote.contains(bad), isFalse, reason: '$lang $bad');
        }
      }
    });
  });

  group('repository', () {
    late LocalDatabase db;
    late MilestoneRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = MilestoneRepository(db, ProgressRepository(db, SettingsRepository(db)));
    });

    Future<void> task(String id, String user,
        {TaskState state = TaskState.done,
        DateTime? due,
        List<String> doneDays = const <String>[],
        DateTime? deletedAt}) {
      return db.put(
        'tasks',
        id,
        TaskItem(
          id: id,
          userId: user,
          title: 'م',
          dueDateTime: due ?? DateTime(2026, 11, 3, 10),
          state: state,
          doneDays: doneDays,
          deletedAt: deletedAt,
          createdAt: DateTime(2026, 11, 1),
        ).toJson(),
      );
    }

    Future<void> habit(String user) => db.put('habits', 'h_$user',
        Habit(id: 'h_$user', userId: user, name: 'ع', createdAt: DateTime(2026, 10, 1)).toJson());

    Future<void> habitLog(String user, String date, {WorshipState state = WorshipState.completed}) => db.put(
          'habitLogs',
          'hl_${user}_$date',
          HabitLog(id: 'hl_${user}_$date', habitId: 'h_$user', date: date, state: state, createdAt: DateTime(2026, 11, 1))
              .toJson(),
        );

    Future<void> session(String id, String user, DateTime at, int minutes) => db.put(
          'sessions',
          id,
          StudySession(
            id: id,
            userId: user,
            subjectId: 's',
            startedAt: at,
            durationMinutes: minutes,
            createdAt: at,
          ).toJson(),
        );

    Set<String> earnedIds(List<MilestoneEntry> e) => e.where((x) => x.earned).map((x) => x.def.id).toSet();

    test('a new account has nothing and nothing is written', () async {
      final entries = await repo.evaluate(_a);
      expect(earnedIds(entries), isEmpty);
      expect(entries, hasLength(kMilestones.length));
      expect(entries.every((e) => e.current == 0), isTrue);
      expect(await db.count('milestones'), 0);
    });

    test('a completed task earns the first-task milestone', () async {
      await task('t1', _a);
      final entries = await repo.evaluate(_a);
      expect(earnedIds(entries), <String>{'first-task'});
      expect(entries.firstWhere((e) => e.def.id == 'first-task').isNew, isTrue);
      expect(await db.count('milestones'), 1);
    });

    test('open tasks and soft-deleted tasks do not count', () async {
      await task('open', _a, state: TaskState.open);
      await task('gone', _a, deletedAt: DateTime(2026, 11, 5));
      expect(earnedIds(await repo.evaluate(_a)), isEmpty);
    });

    test('per-day completions of recurring tasks count', () async {
      await task('rec', _a, state: TaskState.open, doneDays: const <String>['2026-11-02', '2026-11-04']);
      final entries = await repo.evaluate(_a);
      expect(earnedIds(entries), <String>{'first-task'});
      expect(entries.firstWhere((e) => e.def.id == 'first-task').current, 2);
    });

    test('only completed habit logs count', () async {
      await habit(_a);
      await habitLog(_a, '2026-11-02', state: WorshipState.none);
      expect(earnedIds(await repo.evaluate(_a)), isEmpty);
      await habitLog(_a, '2026-11-03');
      expect(earnedIds(await repo.evaluate(_a)), <String>{'first-habit'});
    });

    test('study sessions and minutes, legacy ownerless sessions excluded', () async {
      await session('s1', _a, DateTime(2026, 11, 2, 9), 40);
      await session('s2', _a, DateTime(2026, 11, 3, 9), 20);
      await db.put(
        'sessions',
        'old',
        StudySession(id: 'old', subjectId: 'x', startedAt: DateTime(2026, 11, 4, 9), durationMinutes: 5000, createdAt: DateTime(2026, 11, 4))
            .toJson(),
      );
      final entries = await repo.evaluate(_a);
      expect(earnedIds(entries), <String>{'first-study', 'study-60'});
      expect(entries.firstWhere((e) => e.def.id == 'study-60').current, 60);
    });

    test('care steps count only when done', () async {
      Future<void> log(String id, bool done) => db.put(
            'careLogs',
            id,
            SelfCareLog(id: id, userId: _a, stepId: 'st', date: '2026-11-0${id.length}', done: done, createdAt: DateTime(2026, 11, 1))
                .toJson(),
          );
      await log('a', false);
      expect(earnedIds(await repo.evaluate(_a)), isEmpty);
      await log('bb', true);
      expect(earnedIds(await repo.evaluate(_a)), <String>{'first-care'});
    });

    test('active days are distinct days across sources, not events', () async {
      await habit(_a);
      // يوم واحد فيه مهمة وعادة وماء وجلسة: يُعدّ يومًا واحدًا.
      await task('t1', _a, due: DateTime(2026, 11, 1, 9));
      await habitLog(_a, '2026-11-01');
      await db.put('water', '${_a}_2026-11-01',
          WaterLog(id: '${_a}_2026-11-01', userId: _a, date: '2026-11-01', amountMl: 250, createdAt: DateTime(2026, 11, 1)).toJson());
      await session('s1', _a, DateTime(2026, 11, 1, 18), 10);
      var entries = await repo.evaluate(_a);
      expect(entries.firstWhere((e) => e.def.id == 'days-7').current, 1);

      for (var d = 2; d <= 7; d++) {
        await habitLog(_a, '2026-11-0$d');
      }
      entries = await repo.evaluate(_a);
      expect(entries.firstWhere((e) => e.def.id == 'days-7').current, 7);
      expect(earnedIds(entries), contains('days-7'));
      expect(earnedIds(entries), isNot(contains('days-30')));
    });

    test('goals: creating one and reaching one are separate milestones', () async {
      await db.put(
        'goals',
        'g1',
        MonthlyGoal(id: 'g1', userId: _a, month: '2026-11', title: 'ه', metric: 'tasks', target: 1, createdAt: DateTime(2026, 11, 1))
            .toJson(),
      );
      expect(earnedIds(await repo.evaluate(_a)), <String>{'first-goal'});
      await task('t1', _a, due: DateTime(2026, 11, 10, 9));
      expect(earnedIds(await repo.evaluate(_a)), <String>{'first-goal', 'first-task', 'goal-done-1'});
    });

    test('a milestone stays after the source record is deleted, and never repeats', () async {
      await task('t1', _a);
      final first = await repo.evaluate(_a);
      final stamp = first.firstWhere((e) => e.def.id == 'first-task').earnedAt;
      await db.delete('tasks', 't1');
      final second = await repo.evaluate(_a);
      final entry = second.firstWhere((e) => e.def.id == 'first-task');
      expect(entry.earned, isTrue);
      expect(entry.isNew, isFalse);
      expect(entry.current, 0, reason: 'the live count dropped, the milestone did not');
      expect(entry.earnedAt, stamp);
      expect(await db.count('milestones'), 1);
    });

    test('one account never earns from, or sees, another account', () async {
      await task('t1', _b);
      await habit(_b);
      await habitLog(_b, '2026-11-02');
      expect(earnedIds(await repo.evaluate(_a)), isEmpty);
      expect(await repo.earned(_a), isEmpty);
      expect(earnedIds(await repo.evaluate(_b)), <String>{'first-task', 'first-habit'});
      expect((await repo.earned(_a)).isEmpty, isTrue);
    });

    test('worship, mood and journals earn nothing', () async {
      await db.put('readingLogs', 'r1',
          ReadingLog(id: 'r1', userId: _a, itemId: 'quran_1', completedAt: DateTime(2026, 11, 2, 6)).toJson());
      await db.put('moods', '${_a}_2026-11-02',
          MoodEntry(id: '${_a}_2026-11-02', userId: _a, date: '2026-11-02', value: 5, createdAt: DateTime(2026, 11, 2)).toJson());
      await db.put('journals', 'j1',
          JournalEntry(id: 'j1', userId: _a, title: 'ع', content: 'م', createdAt: DateTime(2026, 11, 2)).toJson());
      final entries = await repo.evaluate(_a);
      expect(earnedIds(entries), isEmpty);
      expect(entries.every((e) => e.current == 0), isTrue);
    });

    test('evaluating writes nothing outside milestones', () async {
      await task('t1', _a);
      Future<String> others() async {
        final data = await db.exportAll();
        data.remove('exportedAt');
        data.remove('milestones');
        return jsonEncode(data);
      }

      final before = await others();
      await repo.evaluate(_a);
      expect(await others(), before);
    });

    test('duplicates after an import keep the oldest', () async {
      final old = EarnedMilestone(id: 'k1', userId: _a, milestoneId: 'first-task', earnedAt: DateTime(2026, 1, 1));
      final newer = EarnedMilestone(id: 'k2', userId: _a, milestoneId: 'first-task', earnedAt: DateTime(2026, 6, 1));
      await db.put('milestones', 'k2', newer.toJson());
      await db.put('milestones', 'k1', old.toJson());
      final map = await repo.earned(_a);
      expect(map['first-task']!.earnedAt, DateTime(2026, 1, 1));
    });
  });

  group('export, import, delete', () {
    late LocalDatabase db;
    late MilestoneRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = MilestoneRepository(db, ProgressRepository(db, SettingsRepository(db)));
      for (final user in <String>[_a, _b]) {
        await db.put('tasks', 't_$user',
            TaskItem(id: 't_$user', userId: user, title: 'م', dueDateTime: DateTime(2026, 11, 3), state: TaskState.done, createdAt: DateTime(2026, 11, 1))
                .toJson());
        await repo.evaluate(user);
      }
    });

    test('account export holds only that account and restores it', () async {
      final export = await db.exportAll(onlyUserId: _a);
      expect((export['milestones'] as Map).keys.toList(), <String>['ua_first-task']);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _a);
      final back = await fresh.byId('milestones', 'ua_first-task', EarnedMilestone.fromJson);
      expect(back!.milestoneId, 'first-task');
    });

    test('importing into another account re-keys the record and never duplicates', () async {
      final export = await db.exportAll(onlyUserId: _a);
      final fresh = await openTestDatabase();
      await fresh.importAll(export, targetUserId: _b, allowDifferentSource: true);
      expect(await fresh.byId('milestones', 'ub_first-task', EarnedMilestone.fromJson), isNotNull);
      expect(await fresh.byId('milestones', 'ua_first-task', EarnedMilestone.fromJson), isNull);

      final freshRepo = MilestoneRepository(fresh, ProgressRepository(fresh, SettingsRepository(fresh)));
      expect((await freshRepo.earned(_b)).keys, <String>['first-task']);
      await freshRepo.evaluate(_b);
      expect(await fresh.count('milestones'), 1);
    });

    test('deleting an account removes its milestones and keeps the other account\'s', () async {
      await db.deleteUserData(_a);
      expect((await repo.earned(_a)), isEmpty);
      expect((await repo.earned(_b)).keys, <String>['first-task']);
    });
  });
}
