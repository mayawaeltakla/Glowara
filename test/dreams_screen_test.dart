import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/repositories/auth_repository.dart';
import 'package:glowara/core/repositories/care_repository.dart';
import 'package:glowara/core/repositories/dream_repository.dart';
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
import 'package:glowara/features/dreams/dream_screen.dart';
import 'package:glowara/features/dreams/dreams_screen.dart';
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




GoRouter _router() => GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const DreamsScreen()),
        GoRoute(
          path: '/dreams/dream/:id',
          builder: (context, state) => DreamScreen(dreamId: state.pathParameters['id'] ?? 'new'),
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

  testWidgets('Arabic: empty list, private note, no percentages, nothing created', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('أحلامي'), findsOneWidget);
    expect(find.textContaining('بلا نسب ولا تنبيهات تأخير'), findsOneWidget);
    expect(find.byKey(const Key('dr-empty')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(await tester.runAsync(() => state.db.count('dreams')), 0);
  });

  testWidgets('creating a dream, adding and ticking steps; list shows counts as text', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('dr-add')));
    expect(find.byKey(const Key('dr-save-first')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('dr-save')));
    expect(find.text('اكتبي عنوان الحلم'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('dreams')), 0);

    await tester.enterText(find.byKey(const Key('dr-title')), 'تعلّم الرسم');
    await tester.enterText(find.byKey(const Key('dr-wish')), 'أحبه');
    await _tap(tester, find.byKey(const Key('dr-stage-planning')));
    await _tap(tester, find.byKey(const Key('dr-save')));
    expect(find.byKey(const Key('dr-step-field')), findsOneWidget);

    for (final s in <String>['شراء ألوان', 'درس أسبوعي']) {
      await tester.enterText(find.byKey(const Key('dr-step-field')), s);
      await _tap(tester, find.byKey(const Key('dr-add-step')));
    }
    final dream = (await tester.runAsync(() => DreamRepository(state.db).all(state.userId)))!.single;
    expect(dream.stage, 'planning');
    expect(dream.steps.map((s) => s.text), <String>['شراء ألوان', 'درس أسبوعي']);
    await _tap(tester, find.byKey(Key('dr-step-${dream.steps[0].id}')));
    expect(find.text('1 من 2 خطوات'), findsOneWidget);

    await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(find.text('أخطّط له · 1 من 2 خطوات'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('reaching achieved shows a warm message once', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final d = (await tester.runAsync(() => DreamRepository(state.db).save(userId: state.userId, title: 'حلم')))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(Key('dr-item-${d.id}')));
    await _tap(tester, find.byKey(const Key('dr-stage-achieved')));
    await _tap(tester, find.byKey(const Key('dr-save')));
    expect(find.text('ما شاء الله، تحقّق حلمك. هنيئًا لك.'), findsOneWidget);
    final saved = await tester.runAsync(() => DreamRepository(state.db).byId(state.userId, d.id));
    expect(saved!.achievedAt, isNotNull);
  });

  testWidgets('deleting a step, and deleting a dream asks first', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final repo = DreamRepository(state.db);
    final d = (await tester.runAsync(() async {
      final x = await repo.save(userId: state.userId, title: 'حلم');
      return repo.addStep(userId: state.userId, dreamId: x.id, text: 'خطوتي');
    }))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(Key('dr-item-${d.id}')));
    expect(find.text('خطوتي'), findsOneWidget);
    await _tap(tester, find.byKey(Key('dr-step-del-${d.steps.single.id}')));
    expect(find.text('خطوتي'), findsNothing);

    await _tap(tester, find.byKey(const Key('dr-delete')));
    await _tap(tester, find.byKey(const Key('dr-delete-no')));
    expect(await tester.runAsync(() => state.db.count('dreams')), 1);
    await _tap(tester, find.byKey(const Key('dr-delete')));
    await _tap(tester, find.byKey(const Key('dr-delete-yes')));
    expect(await tester.runAsync(() => state.db.count('dreams')), 0);
  });

  testWidgets('English labels', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('My dreams'), findsOneWidget);
    expect(find.textContaining('No percentages, no lateness alerts'), findsOneWidget);
  });
}
