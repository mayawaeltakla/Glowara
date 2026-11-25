import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/dashboard_models.dart';
import 'package:glowara/core/repositories/dashboard_repository.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
import 'package:glowara/core/repositories/habit_repository.dart';
import 'package:glowara/core/repositories/health_repository.dart';
import 'package:glowara/core/repositories/library_repository.dart';
import 'package:glowara/core/repositories/routine_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/features/calendar/calendar_layout.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';
final DateTime _today = DateTime(2026, 11, 23, 10); // الاثنين
final DateTime _ws = weekStartOf(_today, DateTime.sunday);

void main() {
  late LocalDatabase db;
  late DashboardRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = DashboardRepository(db);
  });

  Future<LifestyleSummary> build(String user) =>
      repo.build(user, today: _today, weekStart: _ws, weekEnd: weekEndOf(_ws));

  test('empty account gives an empty summary', () async {
    final s = await build(_a);
    expect(s.isEmpty, isTrue);
  });

  test('upcoming tasks: undone, within 7 days, soonest first, capped, own only', () async {
    final tasks = TaskRepository(db);
    Future<void> add(String id, String user, DateTime due, {TaskState state = TaskState.open}) =>
        tasks.save(TaskItem(id: id, userId: user, title: id, dueDateTime: due, state: state, createdAt: _today));
    await add('late', _a, DateTime(2026, 11, 30, 9));
    await add('soon', _a, DateTime(2026, 11, 23, 15));
    await add('done', _a, DateTime(2026, 11, 24, 9), state: TaskState.done);
    await add('far', _a, DateTime(2026, 12, 20, 9));
    await add('theirs', _b, DateTime(2026, 11, 24, 9));
    for (var i = 0; i < 8; i++) {
      await add('x$i', _a, DateTime(2026, 11, 25, 8 + i));
    }
    final s = await build(_a);
    expect(s.upcomingTasks.length, kDashboardMaxItems);
    expect(s.upcomingTasks.first.id, 'soon');
    expect(s.upcomingTasks.map((t) => t.id), isNot(contains('done')));
    expect(s.upcomingTasks.map((t) => t.id), isNot(contains('far')));
    expect(s.upcomingTasks.map((t) => t.id), isNot(contains('theirs')));
  });

  test('study minutes: this week only, this account only, ownerless legacy excluded', () async {
    Future<void> session(String id, String user, DateTime d, int min) => db.put(
          'sessions',
          id,
          StudySession(id: id, userId: user, subjectId: 's', startedAt: d, durationMinutes: min, createdAt: d).toJson(),
        );
    await session('1', _a, DateTime(2026, 11, 22, 9), 30); // الأحد = بداية الأسبوع
    await session('2', _a, DateTime(2026, 11, 23, 9), 45);
    await session('3', _a, DateTime(2026, 11, 14, 9), 99); // أسبوع سابق
    await session('4', '', DateTime(2026, 11, 23, 9), 60); // قديمة بلا مالك
    await session('5', _b, DateTime(2026, 11, 23, 9), 70);
    final s = await build(_a);
    expect(s.studyMinutesWeek, 75);
  });

  test('habits: scheduled and completed counts for today, own only', () async {
    final habits = HabitRepository(db);
    await habits.save(Habit(id: 'h1', userId: _a, name: 'a', createdAt: _today));
    await habits.save(Habit(id: 'h2', userId: _a, name: 'b', createdAt: _today));
    await habits.save(Habit(id: 'h3', userId: _a, name: 'c', isActive: false, createdAt: _today));
    await habits.save(Habit(id: 'h4', userId: _b, name: 'd', createdAt: _today));
    await habits.setLog(habitId: 'h1', day: _today, state: WorshipState.completed);
    await habits.setLog(habitId: 'h4', day: _today, state: WorshipState.completed);
    final s = await build(_a);
    expect(s.habitsScheduled, 2);
    expect(s.habitsDone, 1);
  });

  test('routines today with step counts; a routine for another weekday is left out', () async {
    final routines = RoutineRepository(db);
    final r = await routines.save(userId: _a, name: 'صباح', kind: 'morning', steps: <String>['أ', 'ب', 'ج']);
    await routines.save(userId: _a, name: 'ثلاثاء', kind: 'custom', steps: <String>['x'], days: <int>[DateTime.tuesday]);
    await routines.save(userId: _a, name: 'فارغ', kind: 'custom', steps: <String>[]);
    await routines.setStepDone(userId: _a, day: _today, routineId: r.id, stepId: r.steps[0].id, done: true);
    await routines.setStepDone(userId: _a, day: _today, routineId: r.id, stepId: r.steps[2].id, done: true);
    final s = await build(_a);
    expect(s.routinesToday.single.routine.name, 'صباح');
    expect(s.routinesToday.single.stepsDone, 2);
  });

  test('water, dreams in progress and books being read', () async {
    await HealthRepository(db).addWater(userId: _a, day: _today, deltaMl: 500);
    final dreams = DreamRepository(db);
    await dreams.save(userId: _a, title: 'يحلم', stage: 'dreaming');
    await dreams.save(userId: _a, title: 'يخطط', stage: 'planning');
    await dreams.save(userId: _a, title: 'يعمل', stage: 'working');
    await dreams.save(userId: _a, title: 'تحقق', stage: 'achieved');
    final books = LibraryRepository(db);
    await books.save(userId: _a, title: 'أقرؤه', status: 'reading', currentPage: 12);
    await books.save(userId: _a, title: 'أريده', status: 'want');
    await books.save(userId: _b, title: 'كتابها', status: 'reading');
    final s = await build(_a);
    expect(s.waterMl, 500);
    expect(s.dreamsInProgress.map((d) => d.title).toSet(), <String>{'يخطط', 'يعمل'});
    expect(s.booksReading.single.title, 'أقرؤه');
  });

  test('it reads only: building the summary writes nothing and never touches private sections', () async {
    await db.put('moods', 'ua_2026-11-23', <String, dynamic>{'id': 'ua_2026-11-23', 'userId': _a, 'date': '2026-11-23', 'value': 1});
    await db.put('corner', 'c1', <String, dynamic>{'id': 'c1', 'userId': _a, 'kind': 'letter', 'text': 'سر', 'createdAt': '2026-11-01T00:00:00Z', 'updatedAt': '2026-11-01T00:00:00Z'});
    final before = await db.exportAll();
    before.remove('exportedAt');
    final s = await build(_a);
    expect(s.isEmpty, isTrue, reason: 'mood and corner do not feed the dashboard');
    final after = await db.exportAll();
    after.remove('exportedAt');
    expect(after.toString(), before.toString());
  });
}
