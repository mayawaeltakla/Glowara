import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';
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
import 'package:glowara/features/insights/insights_screen.dart';
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




final DateTime _today = DateTime(2026, 11, 23);

Future<void> _put(AppState state, DateTime d, int v, {int? energy}) => state.db.put(
      'moods',
      '${state.userId}_${dateKey(d)}',
      MoodEntry(id: '${state.userId}_${dateKey(d)}', userId: state.userId, date: dateKey(d), value: v, energy: energy, createdAt: d).toJson(),
    );

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
        home: InsightsScreen(today: _today),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: empty state with the not-a-diagnosis note; nothing written', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('فهم المزاج والطاقة'), findsOneWidget);
    expect(find.textContaining('ليس تشخيصًا طبيًا أو نفسيًا'), findsOneWidget);
    expect(find.byKey(const Key('in-empty')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(await tester.runAsync(() => state.db.count('moods')), 0);
  });

  testWidgets('shows counts, energy and a weekday pattern only with enough entries', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      for (var i = 0; i < 28; i++) {
        final d = DateTime(2026, 10, 26 + i);
        final v = d.weekday == DateTime.friday ? 5 : (d.weekday == DateTime.monday ? 2 : 3);
        await _put(state, d, v, energy: i < 4 ? 4 : null);
      }
    });
    await _pump(tester, state);
    expect(find.text('سجّلتِ مزاجك في 28 يومًا من آخر 30 يومًا'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('in-mood-count-5'))).data, '4');
    expect(tester.widget<Text>(find.byKey(const Key('in-mood-count-3'))).data, '20');
    expect(tester.widget<Text>(find.byKey(const Key('in-energy-count-4'))).data, '4');
    expect(find.byKey(const Key('in-highest')), findsOneWidget);
    expect(find.textContaining('الجمعة'), findsWidgets);
    expect(find.byKey(const Key('in-lowest')), findsOneWidget);
    expect(find.byKey(const Key('in-study-days')), findsNothing, reason: 'study link is off by default');
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('with few entries it says more are needed instead of inventing a pattern', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await _put(state, DateTime(2026, 11, 10 + i), 4);
      }
    });
    await _pump(tester, state);
    expect(find.byKey(const Key('in-need-more')), findsOneWidget);
    expect(find.byKey(const Key('in-highest')), findsNothing);
  });

  testWidgets('study link is optional and says counts only, not cause', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      for (var i = 0; i < 28; i++) {
        final d = DateTime(2026, 10, 26 + i);
        await _put(state, d, d.weekday == DateTime.friday ? 5 : 3);
        if (d.weekday == DateTime.friday || d.weekday == DateTime.tuesday) {
          await state.db.put(
            'sessions',
            's$i',
            StudySession(id: 's$i', userId: state.userId, subjectId: 'x', startedAt: DateTime(d.year, d.month, d.day, 9), durationMinutes: 30, createdAt: d).toJson(),
          );
        }
      }
    });
    await _pump(tester, state);
    expect(find.byKey(const Key('in-study-days')), findsNothing);
    await _tap(tester, find.byKey(const Key('in-study-switch')));
    expect(find.text('في أيام الدراسة: 4 من 8 يومًا كان المزاج فيها جيدًا أو رائعًا.'), findsOneWidget);
    expect(find.text('في بقية الأيام: 0 من 20 يومًا.'), findsOneWidget);
    expect(find.textContaining('لا تعني أن الدراسة سبب'), findsOneWidget);
  });

  testWidgets('English labels and the 90-day window', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('Mood and energy insights'), findsOneWidget);
    expect(find.textContaining('not a medical or psychological diagnosis'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('in-days-90')));
    expect(find.text('You logged your mood on 0 of the last 90 days'), findsOneWidget);
  });
}
