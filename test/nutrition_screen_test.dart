import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/nutrition_models.dart';
import 'package:glowara/core/repositories/auth_repository.dart';
import 'package:glowara/core/repositories/care_repository.dart';
import 'package:glowara/core/repositories/habit_repository.dart';
import 'package:glowara/core/repositories/health_repository.dart';
import 'package:glowara/core/repositories/journal_repository.dart';
import 'package:glowara/core/repositories/language_repository.dart';
import 'package:glowara/core/repositories/nutrition_repository.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/repositories/worship_repository.dart';
import 'package:glowara/core/security/privacy_service.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/nutrition/nutrition_screen.dart';
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


Future<void> _pump(WidgetTester tester, AppState state, DateTime weekStart) async {
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
        home: NutritionScreen(initialWeekStart: weekStart),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

// أسبوع الأحد 2026-11-15..21 (ماضٍ بالنسبة لتاريخ الجهاز الحالي دائمًا).
final DateTime _sun = DateTime(2026, 11, 15);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: calm note, empty summary and seven day cards', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, _sun);

    expect(find.text('التغذية المتوازنة'), findsOneWidget);
    expect(find.textContaining('ليست نصيحة طبية ولا حمية'), findsOneWidget);
    expect(find.byKey(const Key('nt-summary')), findsOneWidget);
    expect(find.textContaining('لا بأس به'), findsOneWidget);
    for (var d = 15; d <= 21; d++) {
      expect(find.byKey(Key('nt-day-2026-11-$d')), findsOneWidget);
    }
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('tapping a slot, picking an idea and saving stores the plan; clear removes it', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, _sun);

    await _tap(tester, find.byKey(const Key('nt-cell-2026-11-16-lunch')));
    expect(find.byKey(const Key('nt-edit-field')), findsOneWidget);
    expect(find.byKey(const Key('nt-clear')), findsNothing);
    await _tap(tester, find.byKey(const Key('nt-idea-l2')));
    final idea = kMealIdeas.firstWhere((i) => i.id == 'l2');
    expect(tester.widget<TextField>(find.byKey(const Key('nt-edit-field'))).controller!.text, idea.ar);
    await _tap(tester, find.byKey(const Key('nt-save')));

    expect(find.text(idea.ar), findsOneWidget);
    final plan = await tester.runAsync(() => NutritionRepository(state.db).planFor(state.userId, _sun));
    expect(plan!.cell('2026-11-16', 'lunch'), idea.ar);

    await _tap(tester, find.byKey(const Key('nt-cell-2026-11-16-lunch')));
    await _tap(tester, find.byKey(const Key('nt-clear')));
    expect(find.text(idea.ar), findsNothing);
    final after = await tester.runAsync(() => NutritionRepository(state.db).planFor(state.userId, _sun));
    expect(after, isNull);
  });

  testWidgets('cancel leaves the plan unchanged and nothing is created by opening the screen', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, _sun);
    expect(await tester.runAsync(() => state.db.count('mealPlans')), 0);

    await _tap(tester, find.byKey(const Key('nt-cell-2026-11-16-dinner')));
    await tester.enterText(find.byKey(const Key('nt-edit-field')), 'شيء');
    await _tap(tester, find.byKey(const Key('nt-cancel')));
    expect(await tester.runAsync(() => state.db.count('mealPlans')), 0);
  });

  testWidgets('English: summary shows counts and groups but never meal note text', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    // أسبوع الاثنين 2026-11-09..15 في الإنجليزية.
    await tester.runAsync(() async {
      await state.db.put(
        'meals',
        'm1',
        MealNote(
          id: 'm1',
          userId: state.userId,
          dateTime: DateTime(2026, 11, 10, 9),
          mealType: 'breakfast',
          note: 'private note text',
          groups: const <String>['fruit', 'dairy'],
          createdAt: DateTime(2026, 11, 10, 9),
        ).toJson(),
      );
    });
    await _pump(tester, state, DateTime(2026, 11, 9));

    expect(find.text('Balanced nutrition'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(find.text('Days you logged meals: 1'), findsOneWidget);
    expect(find.byKey(const Key('nt-group-fruit')), findsOneWidget);
    expect(find.byKey(const Key('nt-group-dairy')), findsOneWidget);
    expect(find.byKey(const Key('nt-group-protein')), findsNothing);
    expect(find.textContaining('private note text'), findsNothing);
  });

  testWidgets('week navigation moves by seven days and planning stops eight weeks ahead', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, _sun);
    final before = tester.widget<Text>(find.byKey(const Key('nt-range'))).data;
    await _tap(tester, find.byKey(const Key('nt-prev')));
    expect(find.byKey(const Key('nt-day-2026-11-08')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('nt-range'))).data, isNot(before));
    await _tap(tester, find.byKey(const Key('nt-next')));
    expect(find.byKey(const Key('nt-day-2026-11-15')), findsOneWidget);

    // أسبوع بعد الحد: زر التالي معطَّل، ولا ملخص لأسبوع مستقبلي.
    await tester.pumpWidget(const SizedBox());
    final far = DateTime.now().add(const Duration(days: 7 * 12));
    await _pump(tester, state, far);
    expect(tester.widget<IconButton>(find.byKey(const Key('nt-next'))).onPressed, isNull);
    expect(find.byKey(const Key('nt-summary')), findsNothing);
  });
}
