import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/repositories/auth_repository.dart';
import 'package:glowara/core/repositories/care_repository.dart';
import 'package:glowara/core/repositories/corner_repository.dart';
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
import 'package:glowara/features/corner/corner_entry_screen.dart';
import 'package:glowara/features/corner/corner_screen.dart';
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
        GoRoute(path: '/', builder: (context, state) => const CornerScreen()),
        GoRoute(
          path: '/corner/entry/:id',
          builder: (context, state) => CornerEntryScreen(entryId: state.pathParameters['id'] ?? 'new'),
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

  testWidgets('Arabic: empty corner with a privacy note; nothing created', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('ركني الصغير'), findsOneWidget);
    expect(find.textContaining('الختم لطيف وليس تشفيرًا'), findsOneWidget);
    expect(find.byKey(const Key('cn-empty')), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('corner')), 0);
  });

  testWidgets('writing a letter saves it; empty text is refused', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('cn-add')));
    await _tap(tester, find.byKey(const Key('cn-save')));
    expect(find.text('اكتبي شيئًا أولًا'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('corner')), 0);

    await tester.enterText(find.byKey(const Key('cn-title')), 'إلى نفسي');
    await tester.enterText(find.byKey(const Key('cn-text')), 'أنتِ تفعلين جيدًا');
    await _tap(tester, find.byKey(const Key('cn-save')));
    final list = (await tester.runAsync(() => CornerRepository(state.db).all(state.userId)))!;
    expect(list.single.title, 'إلى نفسي');
    expect(find.text('إلى نفسي'), findsOneWidget);
    expect(find.text('أنتِ تفعلين جيدًا'), findsOneWidget);
  });

  testWidgets('a sealed letter never shows its text in the list; open-now reveals it for the session only', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final e = (await tester.runAsync(() => CornerRepository(state.db).save(
          userId: state.userId,
          kind: 'letter',
          title: 'بعد سنة',
          text: 'نص سري للمستقبل',
          openOn: '2999-01-01',
        )))!;
    await _pump(tester, state);
    expect(find.text('بعد سنة'), findsOneWidget);
    expect(find.text('نص سري للمستقبل'), findsNothing);
    expect(find.textContaining('مختومة حتى'), findsOneWidget);

    await _tap(tester, find.byKey(Key('cn-item-${e.id}')));
    expect(find.byKey(const Key('cn-sealed')), findsOneWidget);
    expect(find.text('نص سري للمستقبل'), findsNothing);
    await _tap(tester, find.byKey(const Key('cn-open-now')));
    expect(find.text('نص سري للمستقبل'), findsOneWidget);
    // لم يتغيّر السجل: ما زال مختومًا.
    final saved = await tester.runAsync(() => CornerRepository(state.db).byId(state.userId, e.id));
    expect(saved!.openOn, '2999-01-01');
  });

  testWidgets('a letter whose date has passed opens normally', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final e = (await tester.runAsync(() => CornerRepository(state.db).save(
          userId: state.userId,
          kind: 'letter',
          text: 'رسالة قديمة',
          openOn: '2020-01-01',
        )))!;
    await _pump(tester, state);
    expect(find.text('رسالة قديمة'), findsOneWidget);
    await _tap(tester, find.byKey(Key('cn-item-${e.id}')));
    expect(find.byKey(const Key('cn-sealed')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('cn-text'))).controller!.text, 'رسالة قديمة');
    await _settle(tester); // the photo slot finishes its local read
  });

  testWidgets('filter by kind, and deleting asks first', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final repo = CornerRepository(state.db);
    final w = (await tester.runAsync(() async {
      await repo.save(userId: state.userId, kind: 'memory', text: 'ذكرى جميلة');
      return repo.save(userId: state.userId, kind: 'wish', text: 'أمنية صغيرة');
    }))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('cn-kind-wish')));
    expect(find.text('أمنية صغيرة'), findsOneWidget);
    expect(find.text('ذكرى جميلة'), findsNothing);

    await _tap(tester, find.byKey(Key('cn-item-${w.id}')));
    await _tap(tester, find.byKey(const Key('cn-delete')));
    await _tap(tester, find.byKey(const Key('cn-delete-no')));
    expect(await tester.runAsync(() => state.db.count('corner')), 2);
    await _tap(tester, find.byKey(const Key('cn-delete')));
    await _tap(tester, find.byKey(const Key('cn-delete-yes')));
    expect(await tester.runAsync(() => state.db.count('corner')), 1);
  });

  testWidgets('English labels', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('My little corner'), findsOneWidget);
    expect(find.textContaining('The seal is gentle, not encryption'), findsOneWidget);
  });
}
