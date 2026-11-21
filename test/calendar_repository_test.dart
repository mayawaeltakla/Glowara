import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/calendar_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/calendar_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

final DateTime _nov = DateTime(2026, 11);
final DateTime _today = DateTime(2026, 11, 10);

DayActivity _day(MonthSnapshot s, int y, int m, int d) => s.dayFor(DateTime(y, m, d));

void main() {
  late LocalDatabase db;
  late CalendarRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = CalendarRepository(db);
  });

  Future<MonthSnapshot> snapshot({
    String userId = _a,
    DateTime? month,
    int weekStart = DateTime.sunday,
  }) =>
      repo.monthSnapshot(
        userId: userId,
        month: month ?? _nov,
        weekStart: weekStart,
        today: _today,
      );

  Future<void> putTask(TaskItem t) => db.put('tasks', t.id, t.toJson());

  group('tasks', () {
    test('a single task shows on its day only, with its time and state', () async {
      await putTask(TaskItem(
        id: 't1',
        userId: _a,
        title: 'مهمة',
        dueDateTime: DateTime(2026, 11, 12, 10, 30),
        createdAt: DateTime(2026, 11, 1),
      ));
      await putTask(TaskItem(
        id: 't2',
        userId: _a,
        title: 'منجزة',
        dueDateTime: DateTime(2026, 11, 14),
        state: TaskState.done,
        createdAt: DateTime(2026, 11, 1),
      ));
      final s = await snapshot();
      final tasks = _day(s, 2026, 11, 12).tasks;
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'مهمة');
      expect(tasks.single.done, isFalse);
      expect(tasks.single.time, DateTime(2026, 11, 12, 10, 30));
      expect(_day(s, 2026, 11, 13).tasks, isEmpty);
      // موعد منتصف الليل لا يُعرض كوقت.
      final done = _day(s, 2026, 11, 14).tasks.single;
      expect(done.done, isTrue);
      expect(done.time, isNull);
    });

    test('daily tasks repeat from their start with per-day done state', () async {
      await putTask(TaskItem(
        id: 'daily',
        userId: _a,
        title: 'يومية',
        dueDateTime: DateTime(2026, 11, 5, 8),
        repeat: RepeatPattern.daily,
        doneDays: const <String>['2026-11-07'],
        createdAt: DateTime(2026, 11, 1),
      ));
      final s = await snapshot();
      expect(_day(s, 2026, 11, 4).tasks, isEmpty);
      expect(_day(s, 2026, 11, 5).tasks, hasLength(1));
      expect(_day(s, 2026, 11, 7).tasks.single.done, isTrue);
      expect(_day(s, 2026, 11, 8).tasks.single.done, isFalse);
      expect(_day(s, 2026, 12, 12).tasks, hasLength(1));
    });

    test('weekly and custom-day tasks follow their weekdays', () async {
      await putTask(TaskItem(
        id: 'weekly',
        userId: _a,
        title: 'أسبوعية',
        dueDateTime: DateTime(2026, 11, 2, 9), // اثنين
        repeat: RepeatPattern.weekly,
        createdAt: DateTime(2026, 11, 1),
      ));
      await putTask(TaskItem(
        id: 'custom',
        userId: _a,
        title: 'مخصصة',
        dueDateTime: DateTime(2026, 11, 2, 9),
        repeat: RepeatPattern.customDays,
        customDays: const <int>[DateTime.monday, DateTime.wednesday],
        createdAt: DateTime(2026, 11, 1),
      ));
      final s = await snapshot();
      List<String> titles(int d) => _day(s, 2026, 11, d).tasks.map((t) => t.title).toList()..sort();
      expect(titles(2), <String>['أسبوعية', 'مخصصة']);
      expect(titles(4), <String>['مخصصة']); // الأربعاء
      expect(titles(9), <String>['أسبوعية', 'مخصصة']);
      expect(titles(3), isEmpty);
      expect(titles(5), isEmpty);
    });

    test('a task after the grid window never appears', () async {
      await putTask(TaskItem(
        id: 'later',
        userId: _a,
        title: 'لاحقًا',
        dueDateTime: DateTime(2027, 3, 1, 9),
        repeat: RepeatPattern.daily,
        createdAt: DateTime(2026, 11, 1),
      ));
      final s = await snapshot();
      expect(s.days.values.every((d) => d.tasks.isEmpty), isTrue);
    });
  });

  group('occursOn keeps the original recurrence behavior', () {
    TaskItem task(RepeatPattern repeat, {List<int> custom = const <int>[]}) => TaskItem(
          id: 'x',
          userId: _a,
          title: 'x',
          dueDateTime: DateTime(2026, 11, 2, 9),
          repeat: repeat,
          customDays: custom,
          createdAt: DateTime(2026, 11, 1),
        );

    test('table of cases', () {
      final none = task(RepeatPattern.none);
      expect(TaskRepository.occursOn(none, DateTime(2026, 11, 2)), isTrue);
      expect(TaskRepository.occursOn(none, DateTime(2026, 11, 3)), isFalse);
      expect(TaskRepository.occursOn(none, DateTime(2026, 11, 1)), isFalse);

      final daily = task(RepeatPattern.daily);
      expect(TaskRepository.occursOn(daily, DateTime(2026, 11, 1)), isFalse);
      expect(TaskRepository.occursOn(daily, DateTime(2026, 11, 2)), isTrue);
      expect(TaskRepository.occursOn(daily, DateTime(2027, 5, 5)), isTrue);

      final weekly = task(RepeatPattern.weekly);
      expect(TaskRepository.occursOn(weekly, DateTime(2026, 11, 9)), isTrue);
      expect(TaskRepository.occursOn(weekly, DateTime(2026, 11, 10)), isFalse);

      final custom = task(RepeatPattern.customDays, custom: const <int>[DateTime.friday]);
      expect(TaskRepository.occursOn(custom, DateTime(2026, 11, 6)), isTrue);
      expect(TaskRepository.occursOn(custom, DateTime(2026, 11, 7)), isFalse);
    });

    test('forDay agrees with occursOn', () async {
      final taskRepo = TaskRepository(db);
      for (final t in <TaskItem>[
        task(RepeatPattern.none),
        TaskItem(
          id: 'd',
          userId: _a,
          title: 'd',
          dueDateTime: DateTime(2026, 11, 2, 9),
          repeat: RepeatPattern.daily,
          createdAt: DateTime(2026, 11, 1),
        ),
      ]) {
        await putTask(t);
      }
      final ids = (await taskRepo.forDay(_a, DateTime(2026, 11, 2))).map((t) => t.id).toSet();
      expect(ids, <String>{'x', 'd'});
      final later = (await taskRepo.forDay(_a, DateTime(2026, 11, 3))).map((t) => t.id).toSet();
      expect(later, <String>{'d'});
    });
  });

  group('habits', () {
    Future<void> putHabit(Habit h) => db.put('habits', h.id, h.toJson());
    Future<void> putLog(String habitId, String date, WorshipState state) => db.put(
          'habitLogs',
          '${habitId}_$date',
          HabitLog(
            id: '${habitId}_$date',
            habitId: habitId,
            date: date,
            state: state,
            createdAt: DateTime(2026, 11, 1),
          ).toJson(),
        );

    test('past days show only completed logs; today and later show what is scheduled', () async {
      await putHabit(Habit(id: 'h1', userId: _a, name: 'قديمة', createdAt: DateTime(2026, 10, 1)));
      await putHabit(Habit(id: 'h2', userId: _a, name: 'جديدة', createdAt: DateTime(2026, 11, 12)));
      await putLog('h1', '2026-11-03', WorshipState.completed);
      await putLog('h1', '2026-11-04', WorshipState.skipped);
      await putLog('h1', '2026-09-01', WorshipState.completed); // خارج النافذة
      final s = await snapshot();

      expect(_day(s, 2026, 11, 3).habits.single.logged, isTrue);
      expect(_day(s, 2026, 11, 4).habits, isEmpty, reason: 'skipped is not shown');
      expect(_day(s, 2026, 11, 5).habits, isEmpty, reason: 'no ghost for unlogged past days');

      final todayHabits = _day(s, 2026, 11, 10).habits;
      expect(todayHabits.map((h) => h.name), <String>['قديمة']);
      expect(todayHabits.single.logged, isFalse);

      // العادة الجديدة لا تظهر قبل يوم إنشائها.
      expect(_day(s, 2026, 11, 11).habits.map((h) => h.name), <String>['قديمة']);
      expect(_day(s, 2026, 11, 12).habits.map((h) => h.name).toSet(), <String>{'قديمة', 'جديدة'});
    });

    test('a completed log today is not duplicated by the schedule', () async {
      await putHabit(Habit(id: 'h1', userId: _a, name: 'عادة', createdAt: DateTime(2026, 10, 1)));
      await putLog('h1', '2026-11-10', WorshipState.completed);
      final s = await snapshot();
      final habits = _day(s, 2026, 11, 10).habits;
      expect(habits, hasLength(1));
      expect(habits.single.logged, isTrue);
    });
  });

  group('study', () {
    test('minutes add up per subject and use the end time when needed', () async {
      await db.put(
        'subjects',
        's1',
        StudySubject(id: 's1', userId: _a, name: 'رياضيات', createdAt: DateTime(2026, 11, 1)).toJson(),
      );
      Future<void> session(String id, DateTime start, {int? minutes, DateTime? end}) => db.put(
            'sessions',
            id,
            StudySession(
              id: id,
              userId: _a,
              subjectId: 's1',
              startedAt: start,
              endedAt: end,
              durationMinutes: minutes,
              createdAt: start,
            ).toJson(),
          );
      await session('a', DateTime(2026, 11, 6, 9), minutes: 30);
      await session('b', DateTime(2026, 11, 6, 18), minutes: 45);
      await session('c', DateTime(2026, 11, 7, 9), end: DateTime(2026, 11, 7, 9, 20));
      final s = await snapshot();
      expect(_day(s, 2026, 11, 6).studyMinutesBySubject, <String, int>{'s1': 75});
      expect(_day(s, 2026, 11, 7).studyMinutesBySubject, <String, int>{'s1': 20});
      expect(s.subjectNames['s1'], 'رياضيات');
    });
  });

  group('self care, water and meals', () {
    test('care counts only done logs of existing steps, once each', () async {
      await db.put(
        'careSteps',
        'step1',
        SelfCareStep(
          id: 'step1',
          userId: _a,
          title: 'ترطيب',
          period: 'morning',
          createdAt: DateTime(2026, 11, 1),
        ).toJson(),
      );
      Future<void> log(String id, String stepId, String date, {bool done = true}) => db.put(
            'careLogs',
            id,
            SelfCareLog(
              id: id,
              userId: _a,
              stepId: stepId,
              date: date,
              done: done,
              createdAt: DateTime(2026, 11, 1),
            ).toJson(),
          );
      await log('l1', 'step1', '2026-11-08');
      await log('l2', 'step1', '2026-11-08');
      await log('l3', 'step1', '2026-11-09', done: false);
      await log('l4', 'deleted-step', '2026-11-08');
      final s = await snapshot();
      expect(_day(s, 2026, 11, 8).care, <String>['ترطيب']);
      expect(_day(s, 2026, 11, 9).care, isEmpty);
    });

    test('meals expose the type and a note flag, never the note text', () async {
      await db.put(
        'meals',
        'm1',
        MealNote(
          id: 'm1',
          userId: _a,
          dateTime: DateTime(2026, 11, 8, 13),
          mealType: 'lunch',
          note: 'نص خاص جدًا',
          createdAt: DateTime(2026, 11, 8),
        ).toJson(),
      );
      await db.put(
        'meals',
        'm2',
        MealNote(
          id: 'm2',
          userId: _a,
          dateTime: DateTime(2026, 11, 8, 19),
          mealType: 'dinner',
          createdAt: DateTime(2026, 11, 8),
        ).toJson(),
      );
      await db.put(
        'water',
        '${_a}_2026-11-08',
        WaterLog(id: '${_a}_2026-11-08', userId: _a, date: '2026-11-08', amountMl: 750, createdAt: DateTime(2026, 11, 8))
            .toJson(),
      );
      final s = await snapshot();
      final day = _day(s, 2026, 11, 8);
      expect(day.meals.map((m) => m.mealType), <String>['lunch', 'dinner']);
      expect(day.meals.map((m) => m.hasNote), <bool>[true, false]);
      expect(day.waterMl, 750);
      expect(day.layers, contains(CalendarLayer.nutrition));
      // لا يتسرب نص الملاحظة إلى أي ناتج نصي.
      expect(day.meals.map((m) => '${m.mealType}${m.hasNote}').join(), isNot(contains('خاص')));
    });
  });

  group('worship', () {
    test('records are classified by item, with no counts', () async {
      Future<void> log(String id, String itemId, DateTime at) => db.put(
            'readingLogs',
            id,
            ReadingLog(id: id, userId: _a, itemId: itemId, completedAt: at).toJson(),
          );
      await log('p', 'prayer_fajr', DateTime(2026, 11, 8, 5));
      await log('q', 'quran_surah_2', DateTime(2026, 11, 8, 9));
      await log('k', 'adhkar_morning', DateTime(2026, 11, 9, 7));
      await log('o', 'dua_1', DateTime(2026, 11, 9, 8));
      final s = await snapshot();
      final d8 = _day(s, 2026, 11, 8);
      expect(d8.prayers, isTrue);
      expect(d8.quran, isTrue);
      expect(d8.adhkar, isFalse);
      final d9 = _day(s, 2026, 11, 9);
      expect(d9.adhkar, isTrue);
      expect(d9.otherWorship, isTrue);
      expect(d9.prayers, isFalse);
      expect(d9.layers, <CalendarLayer>[CalendarLayer.worship]);
    });
  });

  group('account isolation', () {
    Future<void> seedFor(String user) async {
      await putTask(TaskItem(
        id: 'task_$user',
        userId: user,
        title: 'مهمة $user',
        dueDateTime: DateTime(2026, 11, 8, 9),
        createdAt: DateTime(2026, 11, 1),
      ));
      await db.put('habits', 'habit_$user',
          Habit(id: 'habit_$user', userId: user, name: 'عادة $user', createdAt: DateTime(2026, 10, 1)).toJson());
      await db.put(
        'habitLogs',
        'log_$user',
        HabitLog(
          id: 'log_$user',
          habitId: 'habit_$user',
          date: '2026-11-03',
          state: WorshipState.completed,
          createdAt: DateTime(2026, 11, 3),
        ).toJson(),
      );
      await db.put('subjects', 'subject_$user',
          StudySubject(id: 'subject_$user', userId: user, name: 'مادة $user', createdAt: DateTime(2026, 11, 1)).toJson());
      await db.put(
        'sessions',
        'session_$user',
        StudySession(
          id: 'session_$user',
          userId: user,
          subjectId: 'subject_$user',
          startedAt: DateTime(2026, 11, 8, 9),
          durationMinutes: 30,
          createdAt: DateTime(2026, 11, 8),
        ).toJson(),
      );
      await db.put('careSteps', 'step_$user',
          SelfCareStep(id: 'step_$user', userId: user, title: 'خطوة $user', period: 'morning', createdAt: DateTime(2026, 11, 1))
              .toJson());
      await db.put(
        'careLogs',
        'carelog_$user',
        SelfCareLog(id: 'carelog_$user', userId: user, stepId: 'step_$user', date: '2026-11-08', createdAt: DateTime(2026, 11, 8))
            .toJson(),
      );
      await db.put('water', '${user}_2026-11-08',
          WaterLog(id: '${user}_2026-11-08', userId: user, date: '2026-11-08', amountMl: 500, createdAt: DateTime(2026, 11, 8)).toJson());
      await db.put('meals', 'meal_$user',
          MealNote(id: 'meal_$user', userId: user, dateTime: DateTime(2026, 11, 8, 13), createdAt: DateTime(2026, 11, 8)).toJson());
      await db.put('readingLogs', 'reading_$user',
          ReadingLog(id: 'reading_$user', userId: user, itemId: 'prayer_fajr', completedAt: DateTime(2026, 11, 8, 5)).toJson());
    }

    test('another account data never appears', () async {
      await seedFor(_b);
      final s = await snapshot();
      expect(s.days.values.every((d) => d.isEmpty), isTrue);
      expect(s.subjectNames, isEmpty);
    });

    test('each account sees only its own data', () async {
      await seedFor(_a);
      await seedFor(_b);
      final a = await snapshot();
      final b = await snapshot(userId: _b);
      expect(_day(a, 2026, 11, 8).tasks.single.title, 'مهمة $_a');
      expect(_day(b, 2026, 11, 8).tasks.single.title, 'مهمة $_b');
      expect(_day(a, 2026, 11, 3).habits.single.name, 'عادة $_a');
      expect(a.subjectNames.values, <String>['مادة $_a']);
      expect(_day(a, 2026, 11, 8).care, <String>['خطوة $_a']);
      expect(_day(a, 2026, 11, 8).waterMl, 500);
    });

    test('legacy records without an owner are not assumed to be hers', () async {
      await db.put('readingLogs', 'old',
          ReadingLog(id: 'old', itemId: 'prayer_fajr', completedAt: DateTime(2026, 11, 8, 5)).toJson());
      await db.put(
        'sessions',
        'oldsession',
        StudySession(
          id: 'oldsession',
          subjectId: 'x',
          startedAt: DateTime(2026, 11, 8, 9),
          durationMinutes: 40,
          createdAt: DateTime(2026, 11, 8),
        ).toJson(),
      );
      final s = await snapshot();
      expect(s.days.values.every((d) => d.isEmpty), isTrue);
    });
  });

  group('window and boundaries', () {
    test('items on the edges of the grid are placed by local date', () async {
      Future<void> task(String id, DateTime due) => putTask(TaskItem(
            id: id,
            userId: _a,
            title: id,
            dueDateTime: due,
            createdAt: DateTime(2026, 10, 1),
          ));
      await task('before', DateTime(2026, 10, 31, 23, 59));
      await task('first', DateTime(2026, 11, 1, 0, 30));
      await task('last', DateTime(2026, 12, 12, 23, 59));
      await task('after', DateTime(2026, 12, 13, 0, 30));
      final s = await snapshot(); // الأحد أول الأسبوع: 1 نوفمبر إلى 12 ديسمبر
      expect(_day(s, 2026, 11, 1).tasks.map((t) => t.title), <String>['first']);
      expect(_day(s, 2026, 12, 12).tasks.map((t) => t.title), <String>['last']);
      final all = s.days.values.expand((d) => d.tasks).map((t) => t.title).toSet();
      expect(all, <String>{'first', 'last'});
    });

    test('the Monday-first grid also shows the end of October', () async {
      await putTask(TaskItem(
        id: 'oct',
        userId: _a,
        title: 'oct',
        dueDateTime: DateTime(2026, 10, 27, 9),
        createdAt: DateTime(2026, 10, 1),
      ));
      final monday = await snapshot(weekStart: DateTime.monday);
      final sunday = await snapshot();
      expect(_day(monday, 2026, 10, 27).tasks, hasLength(1));
      expect(sunday.days.values.every((d) => d.tasks.isEmpty), isTrue);
    });

    test('a December grid includes January of the next year', () async {
      await putTask(TaskItem(
        id: 'jan',
        userId: _a,
        title: 'jan',
        dueDateTime: DateTime(2027, 1, 3, 9),
        createdAt: DateTime(2026, 10, 1),
      ));
      final s = await snapshot(month: DateTime(2026, 12));
      expect(_day(s, 2027, 1, 3).tasks, hasLength(1));
    });
  });

  group('read only', () {
    test('building a snapshot never changes the database', () async {
      await putTask(TaskItem(
        id: 't',
        userId: _a,
        title: 't',
        dueDateTime: DateTime(2026, 11, 8, 9),
        repeat: RepeatPattern.daily,
        createdAt: DateTime(2026, 11, 1),
      ));
      await db.put('habits', 'h', Habit(id: 'h', userId: _a, name: 'h', createdAt: DateTime(2026, 10, 1)).toJson());
      Future<String> dump() async {
        final data = await db.exportAll();
        data.remove('exportedAt');
        return jsonEncode(data);
      }

      final before = await dump();
      await snapshot();
      await snapshot(month: DateTime(2026, 12));
      await snapshot(weekStart: DateTime.monday);
      expect(await dump(), before);
    });
  });

  group('size', () {
    test('a large month builds without trouble', () async {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 600; i++) {
        await putTask(TaskItem(
          id: 'bulk$i',
          userId: _a,
          title: 'bulk$i',
          dueDateTime: DateTime(2026, 11, 1 + i % 28, 9),
          repeat: i % 5 == 0 ? RepeatPattern.weekly : RepeatPattern.none,
          createdAt: DateTime(2026, 10, 1),
        ));
      }
      for (var i = 0; i < 1500; i++) {
        await db.put(
          'meals',
          'meal$i',
          MealNote(id: 'meal$i', userId: _a, dateTime: DateTime(2026, 11, 1 + i % 28, 12), createdAt: DateTime(2026, 11, 1))
              .toJson(),
        );
      }
      watch.reset();
      final s = await snapshot();
      final elapsed = watch.elapsed;
      expect(s.days, isNotEmpty);
      // سقف سخيّ لاكتشاف انهيار الأداء فقط؛ القياس الفعلي على جهاز حقيقي لم يُجرَ بعد.
      expect(elapsed, lessThan(const Duration(seconds: 10)));
    });
  });
}
