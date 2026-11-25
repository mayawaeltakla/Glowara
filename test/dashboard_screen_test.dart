import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/auth_repository.dart';
import 'package:glowara/core/repositories/care_repository.dart';
import 'package:glowara/core/repositories/habit_repository.dart';
import 'package:glowara/core/repositories/health_repository.dart';
import 'package:glowara/core/repositories/journal_repository.dart';
import 'package:glowara/core/repositories/language_repository.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/repositories/routine_repository.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/repositories/worship_repository.dart';
import 'package:glowara/core/security/privacy_service.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/dashboard/dashboard_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

Future<AppState> _state({String locale = 'ar'}) async {
  final db = await openTestDatabase();
  final settings = SettingsRepository(db);
  final state = AppState(
    db: db,
    auth: AuthRepository(db, iterations: 10),
    settings: settings,
    privacy: PrivacyService(db, iterations: 10),
    tasks: TaskRepository(db),
    habits: HabitRepository(db),
    worship: WorshipRepository(db),
    journal: JournalRepository(db),
    study: StudyRepository(db),
    care: CareRepository(db),
    health: HealthRepository(db),
    language: LanguageRepository(db),
    progress: ProgressRepository(db, settings),
  );
  await state.register(email: 'maya@example.com', password: 'secret1', name: 'مايا');
  await state.initialize();
  await state.setLocale(locale);
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}




final DateTime _today = DateTime(2026, 11, 23, 10);

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppStateProvider(
      state: state,
      child: MaterialApp(
        locale: Locale(state.locale),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppThemes.material('serene', Brightness.light, locale: state.locale, webFonts: false),
        home: DashboardScreen(today: _today),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: empty account shows a calm note and no cards', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('ملخص حياتك'), findsOneWidget);
    expect(find.textContaining('بلا مجموع ولا درجة ولا مقارنة'), findsOneWidget);
    expect(find.byKey(const Key('db-empty')), findsOneWidget);
    expect(find.byKey(const Key('db-card-tasks')), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('cards appear only for sections that have content, with counts as text', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      final habits = HabitRepository(state.db);
      await habits.save(Habit(id: 'h1', userId: state.userId, name: 'عادة', createdAt: _today));
      await habits.setLog(habitId: 'h1', day: _today, state: WorshipState.completed);
      final routines = RoutineRepository(state.db);
      final r = await routines.save(userId: state.userId, name: 'صباحي', kind: 'morning', steps: <String>['أ', 'ب']);
      await routines.setStepDone(userId: state.userId, day: _today, routineId: r.id, stepId: r.steps[0].id, done: true);
      await state.tasks.save(TaskItem(id: 't1', userId: state.userId, title: 'مهمة قادمة', dueDateTime: DateTime(2026, 11, 24, 9), createdAt: _today));
    });
    await _pump(tester, state);
    expect(find.byKey(const Key('db-card-tasks')), findsOneWidget);
    expect(find.textContaining('مهمة قادمة'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('db-habits-line'))).data, '1 من 1');
    expect(find.textContaining('صباحي · 1 من 2 خطوات'), findsOneWidget);
    expect(find.byKey(const Key('db-card-study')), findsNothing);
    expect(find.byKey(const Key('db-card-water')), findsNothing);
    expect(find.byKey(const Key('db-empty')), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('English labels', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('Your life at a glance'), findsOneWidget);
    expect(find.textContaining('No total, no score, no comparison'), findsOneWidget);
  });
}
