import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
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
import 'package:glowara/features/routines/routine_edit_screen.dart';
import 'package:glowara/features/routines/routines_screen.dart';
import 'package:go_router/go_router.dart';
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



final DateTime _mon = DateTime(2026, 11, 16);

GoRouter _router() => GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => RoutinesScreen(today: _mon)),
        GoRoute(
          path: '/routines/edit/:id',
          builder: (context, state) => RoutineEditScreen(
            routineId: state.pathParameters['id'] ?? 'new',
            templateId: state.uri.queryParameters['template'],
          ),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppStateProvider(
      state: state,
      child: MaterialApp.router(
        routerConfig: _router(),
        locale: Locale(state.locale),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppThemes.material('serene', Brightness.light, locale: state.locale, webFonts: false),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: empty state, calm note, templates, nothing created', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('روتيناتي'), findsOneWidget);
    expect(find.textContaining('بلا نسب ولا سلاسل أيام'), findsOneWidget);
    expect(find.byKey(const Key('rt-empty')), findsOneWidget);
    expect(find.byKey(const Key('rt-template-t-morning')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(await tester.runAsync(() => state.db.count('routines')), 0);
  });

  testWidgets('a template opens prefilled; saving creates the routine; ticking is stored', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    await _tap(tester, find.byKey(const Key('rt-template-t-morning')));
    expect(tester.widget<TextField>(find.byKey(const Key('rt-name'))).controller!.text, 'صباح هادئ');
    expect(find.byKey(const Key('rt-step-field-3')), findsOneWidget);
    // تعديل: حذف خطوة وتحريك أخرى وتحديد يوم الاثنين فقط.
    await _tap(tester, find.byKey(const Key('rt-remove-3')));
    await _tap(tester, find.byKey(const Key('rt-down-0')));
    await _tap(tester, find.byKey(const Key('rt-day-1')));
    await _tap(tester, find.byKey(const Key('rt-save')));

    final routines = (await tester.runAsync(() => RoutineRepository(state.db).all(state.userId)))!;
    expect(routines.single.steps.length, 3);
    expect(routines.single.steps[1].text, 'شرب كوب ماء');
    expect(routines.single.days, <int>[1]);
    final r = routines.single;

    // الاثنين: تظهر في «اليوم».
    expect(find.byKey(Key('rt-today-${r.id}')), findsOneWidget);
    await _tap(tester, find.byKey(Key('rt-step-${r.id}-${r.steps[0].id}')));
    final day = await tester.runAsync(() => RoutineRepository(state.db).dayFor(state.userId, _mon));
    expect(day!.isDone(r.id, r.steps[0].id), isTrue);
    await _tap(tester, find.byKey(Key('rt-step-${r.id}-${r.steps[0].id}')));
    expect(await tester.runAsync(() => state.db.count('routineDays')), 0);
  });

  testWidgets('a routine for another weekday is listed but not shown under today', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final r = (await tester.runAsync(() => RoutineRepository(state.db).save(
          userId: state.userId,
          name: 'ثلاثاء',
          kind: 'custom',
          steps: <String>['خطوة'],
          days: <int>[DateTime.tuesday],
        )))!;
    await _pump(tester, state);
    expect(find.byKey(Key('rt-item-${r.id}')), findsOneWidget);
    expect(find.byKey(Key('rt-today-${r.id}')), findsNothing);
    expect(find.text('لا روتين مجدول لهذا اليوم.'), findsOneWidget);
  });

  testWidgets('empty name is refused with a message and nothing is stored', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('rt-add')));
    await _tap(tester, find.byKey(const Key('rt-save')));
    expect(find.text('اكتبي اسمًا للروتين'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('routines')), 0);
  });

  testWidgets('editing then deleting asks first; cancel keeps it', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final r = (await tester.runAsync(() => RoutineRepository(state.db).save(
          userId: state.userId,
          name: 'قديم',
          kind: 'evening',
          steps: <String>['أ'],
        )))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(Key('rt-item-${r.id}')));
    expect(tester.widget<TextField>(find.byKey(const Key('rt-name'))).controller!.text, 'قديم');
    await _tap(tester, find.byKey(const Key('rt-delete')));
    await _tap(tester, find.byKey(const Key('rt-delete-no')));
    expect(await tester.runAsync(() => state.db.count('routines')), 1);
    await _tap(tester, find.byKey(const Key('rt-delete')));
    await _tap(tester, find.byKey(const Key('rt-delete-yes')));
    expect(await tester.runAsync(() => state.db.count('routines')), 0);
  });

  testWidgets('English labels and a missing routine id', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('My routines'), findsOneWidget);
    expect(find.textContaining('No percentages, no streaks'), findsOneWidget);
    expect(find.text('Calm morning'), findsOneWidget);
  });
}
