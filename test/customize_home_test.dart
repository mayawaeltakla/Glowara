import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/home_layout.dart';
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
import 'package:glowara/features/home/customize_home_screen.dart';
import 'package:glowara/features/home/home_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

Future<AppState> _state() async {
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
  await state.setLocale('ar');
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

GoRouter _router() => GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/customize-home', builder: (context, state) => const CustomizeHomeScreen()),
      ],
    );

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 4000);
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
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('default Home shows every section and a customize link', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('إشراقة يومك'), findsOneWidget);
    expect(find.text('كيف مزاجك اليوم؟'), findsOneWidget);
    expect(find.text('عبادة اليوم'), findsOneWidget);
    expect(find.byKey(const Key('home-customize')), findsOneWidget);
  });

  testWidgets('a saved layout hides and reorders Home sections without deleting data', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final layout = HomeLayout.defaults.toggle('worship').move('mood', -3);
    await tester.runAsync(() => state.settings.set(homeLayoutKey(state.userId), layout.toStorage()));
    await _pump(tester, state);
    expect(find.text('عبادة اليوم'), findsNothing);
    final moodY = tester.getTopLeft(find.text('كيف مزاجك اليوم؟')).dy;
    final glowY = tester.getTopLeft(find.text('إشراقة يومك')).dy;
    expect(moodY, lessThan(glowY), reason: 'mood was moved above the day glow');
  });

  testWidgets('a corrupted stored layout falls back to the default', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() => state.settings.set(homeLayoutKey(state.userId), '{broken'));
    await _pump(tester, state);
    expect(find.text('عبادة اليوم'), findsOneWidget);
  });

  testWidgets('customize screen: toggling and moving saves at once; reset clears the key', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('home-customize')));
    expect(find.byKey(const Key('hc-note')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('hc-reset'))).onPressed, isNull);

    await _tap(tester, find.byKey(const Key('hc-switch-worship')));
    await _tap(tester, find.byKey(const Key('hc-down-dayGlow')));
    var raw = await tester.runAsync<String?>(() => state.settings.get<String>(homeLayoutKey(state.userId)));
    var saved = HomeLayout.parse(raw);
    expect(saved.hidden, <String>{'worship'});
    expect(saved.order.first, 'water');
    expect(saved.order[1], 'dayGlow');

    await _tap(tester, find.byKey(const Key('hc-reset')));
    raw = await tester.runAsync<String?>(() => state.settings.get<String>(homeLayoutKey(state.userId)));
    expect(raw, isNull);
    saved = HomeLayout.parse(raw);
    expect(saved.isDefault, isTrue);

    // العودة إلى الرئيسية تعرض ما حُفظ.
    await _tap(tester, find.byKey(const Key('hc-switch-mood')));
    await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(find.text('كيف مزاجك اليوم؟'), findsNothing);
  });
}
