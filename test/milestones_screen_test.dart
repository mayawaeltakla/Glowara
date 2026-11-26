import 'dart:convert';

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
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/repositories/worship_repository.dart';
import 'package:glowara/core/security/privacy_service.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/milestones/milestones_screen.dart';
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

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 3600);
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
        home: const MilestonesScreen(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _doneTask(WidgetTester tester, AppState state) => tester.runAsync(() => state.db.put(
      'tasks',
      't1',
      TaskItem(
        id: 't1',
        userId: state.userId,
        title: 'م',
        dueDateTime: DateTime(2026, 11, 3, 10),
        state: TaskState.done,
        createdAt: DateTime(2026, 11, 1),
      ).toJson(),
    ));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: a new account sees a calm empty state and the privacy note', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    expect(find.text('معالمي'), findsOneWidget);
    expect(find.byKey(const Key('ms-empty')), findsOneWidget);
    expect(find.textContaining('بلا نقاط ولا ترتيب ولا مقارنة'), findsOneWidget);
    expect(find.byKey(const Key('ms-earned-first-task')), findsNothing);
    // أقرب معلم في كل فئة فقط، مع العدّ لا النسبة.
    expect(find.byKey(const Key('ms-next-first-task')), findsOneWidget);
    expect(find.byKey(const Key('ms-next-days-7')), findsOneWidget);
    expect(find.byKey(const Key('ms-next-days-30')), findsNothing);
    expect(find.text('0 من 7 أيام'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('a real record earns a milestone once; reopening does not mark it new again', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _doneTask(tester, state);
    await _pump(tester, state);

    expect(find.byKey(const Key('ms-earned-first-task')), findsOneWidget);
    expect(find.text('أول مهمة'), findsOneWidget);
    expect(find.byKey(const Key('ms-new-first-task')), findsOneWidget);
    expect(find.byKey(const Key('ms-empty')), findsNothing);
    expect(find.byKey(const Key('ms-next-first-task')), findsNothing);
    expect(find.text('1 من 7 أيام'), findsOneWidget);

    // أغلقي الشاشة تمامًا ثم افتحيها من جديد (وإلا أعاد Flutter استعمال الحالة نفسها).
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, state);
    expect(find.byKey(const Key('ms-earned-first-task')), findsOneWidget);
    expect(find.byKey(const Key('ms-new-first-task')), findsNothing);
    final count = await tester.runAsync(() => state.db.count('milestones'));
    expect(count, 1);
  });

  testWidgets('worship, mood and journals do not appear or earn anything', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.db.put('readingLogs', 'r1',
          ReadingLog(id: 'r1', userId: state.userId, itemId: 'quran_1', completedAt: DateTime(2026, 11, 2, 6)).toJson());
      await state.journal.saveMood(userId: state.userId, day: DateTime(2026, 11, 2), value: 5, note: 'مزاج سري');
      await state.db.put('journals', 'j1',
          JournalEntry(id: 'j1', userId: state.userId, title: 'سري', content: 'سري', createdAt: DateTime(2026, 11, 2)).toJson());
    });
    await _pump(tester, state);

    expect(find.byKey(const Key('ms-empty')), findsOneWidget);
    expect(find.textContaining('سري'), findsNothing);
    final count = await tester.runAsync(() => state.db.count('milestones'));
    expect(count, 0);
  });

  testWidgets('opening the screen writes nothing but milestone records', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _doneTask(tester, state);
    Future<String> others() async {
      final data = await state.db.exportAll();
      data.remove('exportedAt');
      data.remove('milestones');
      return jsonEncode(data);
    }

    final before = (await tester.runAsync(others))!;
    await _pump(tester, state);
    expect((await tester.runAsync(others))!, before);
  });

  testWidgets('English: translated and LTR', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _doneTask(tester, state);
    await _pump(tester, state);

    expect(find.text('My milestones'), findsOneWidget);
    expect(find.text('First task'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('1 of 7 days'), findsOneWidget);
    expect(find.textContaining('no points, no ranking'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('ms-note')))), TextDirection.ltr);
  });
}
