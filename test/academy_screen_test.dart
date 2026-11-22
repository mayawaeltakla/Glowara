import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/repositories/academy_repository.dart';
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
import 'package:glowara/core/services/academy_content.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/academy/academy_practice_screen.dart';
import 'package:glowara/features/academy/academy_screen.dart';
import 'package:glowara/features/academy/academy_unit_screen.dart';
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

late AcademyCurriculum _curriculum;
late AcademyUnit _u1;

GoRouter _router() => GoRouter(
      initialLocation: '/academy',
      routes: <RouteBase>[
        GoRoute(path: '/academy', builder: (context, state) => const AcademyScreen()),
        GoRoute(
          path: '/academy/unit/:id',
          builder: (context, state) => AcademyUnitScreen(unitId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/academy/practice/:id',
          builder: (context, state) => AcademyPracticeScreen(
            unitId: state.pathParameters['id'] ?? '',
            reviewOnly: state.uri.queryParameters['mode'] == 'review',
          ),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 7000);
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

/// يجيب عن السؤال المعروض: صحيحًا أو خطأً عمدًا.
Future<void> _answer(WidgetTester tester, {required bool correct}) async {
  final promptText = tester.widget<Text>(find.byKey(const Key('ac-prompt'))).data!;
  final q = _u1.questions.firstWhere((q) => q.prompt == promptText);
  final option = correct ? q.correctOption : q.options.firstWhere((o) => o != q.correctOption);
  await _tap(tester, find.text(option));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    _curriculum = AcademyContent.parse(File(AcademyContent.a1Asset).readAsStringSync());
    _u1 = _curriculum.unit('a1-u01')!;
    AcademyContent.overrideA1(_curriculum);
  });

  tearDownAll(() => AcademyContent.overrideA1(null));

  testWidgets('Arabic: lists the twelve units with a calm progress line', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    expect(find.text('الأكاديمية'), findsOneWidget);
    expect(find.textContaining('بلا درجات ولا ترتيب ولا مقارنة'), findsOneWidget);
    expect(find.text('أكملتِ 0 من 12 وحدة'), findsOneWidget);
    expect(find.byKey(const Key('ac-unit-a1-u01')), findsOneWidget);
    expect(find.text('Greetings and Introductions'), findsOneWidget);
    expect(find.text('التحيات والتعارف'), findsOneWidget);
    expect(find.text('لم تبدئي بعد'), findsNWidgets(12));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('opening a unit shows words, phrases and grammar; studying is remembered', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    await _tap(tester, find.byKey(const Key('ac-unit-a1-u01')));
    expect(find.byKey(const Key('ac-word-hello')), findsOneWidget);
    expect(find.text('مرحبًا'), findsOneWidget);
    expect(find.text('Nice to meet you.'), findsWidgets);
    expect(find.text('الفعل to be: am / is / are'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('ac-mark-studied')));
    expect(find.text('تمّت دراسة الدرس'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('ac-mark-studied'))).onPressed, isNull);
    final p = await tester.runAsync(() => AcademyRepository(state.db).forUnit(state.userId, 'a1-u01'));
    expect(p!.studied, isTrue);
  });

  testWidgets('practice shows feedback, saves only mistakes, review clears them', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('ac-unit-a1-u01')));
    await _tap(tester, find.byKey(const Key('ac-mark-studied')));

    await _tap(tester, find.byKey(const Key('ac-start-practice')));
    expect(find.byKey(const Key('ac-position')), findsOneWidget);
    expect(find.text('1 من 8'), findsOneWidget);

    // السؤال الأول صحيح.
    await _answer(tester, correct: true);
    expect(find.text('صحيح'), findsOneWidget);
    expect(find.textContaining('الإجابة الصحيحة'), findsNothing);
    await _tap(tester, find.byKey(const Key('ac-next')));

    // السؤال الثاني خطأ عمدًا: يظهر الشرح والإجابة الصحيحة، بلا درجة.
    await _answer(tester, correct: false);
    expect(find.text('ليست هذه الإجابة'), findsOneWidget);
    expect(find.textContaining('الإجابة الصحيحة'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('ac-next')));

    for (var i = 3; i <= 8; i++) {
      await _answer(tester, correct: true);
      await _tap(tester, find.byKey(const Key('ac-next')));
    }

    expect(find.byKey(const Key('ac-done-title')), findsOneWidget);
    expect(find.text('1 للمراجعة'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    var p = await tester.runAsync(() => AcademyRepository(state.db).forUnit(state.userId, 'a1-u01'));
    expect(p!.missed, <String>['a1-u01-q2']);
    expect(p.completed, isTrue);

    // عودة إلى الوحدة، ثم مراجعة سؤال واحد.
    await _tap(tester, find.byKey(const Key('ac-back')));
    expect(find.byKey(const Key('ac-review')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('ac-review')));
    expect(find.text('1 من 1'), findsOneWidget);
    await _answer(tester, correct: true);
    await _tap(tester, find.byKey(const Key('ac-next')));
    expect(find.byKey(const Key('ac-done-title')), findsOneWidget);
    expect(find.byKey(const Key('ac-to-review')), findsNothing);
    p = await tester.runAsync(() => AcademyRepository(state.db).forUnit(state.userId, 'a1-u01'));
    expect(p!.missed, isEmpty);

    // القائمة تعرض الوحدة مكتملة.
    await _tap(tester, find.byKey(const Key('ac-back')));
    await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(find.text('أكملتِ 1 من 12 وحدة'), findsOneWidget);
    expect(find.text('أكملتِ الوحدة'), findsOneWidget);
  });

  testWidgets('review with nothing missed says so calmly', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    // نفتح المراجعة مباشرة عبر الموجّه.
    final context = tester.element(find.byType(AcademyScreen));
    GoRouter.of(context).push('/academy/practice/a1-u01?mode=review');
    await _settle(tester);
    expect(find.byKey(const Key('ac-nothing')), findsOneWidget);
    expect(find.text('لا شيء للمراجعة الآن.'), findsOneWidget);
  });

  testWidgets('an unknown unit shows a friendly message', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    final context = tester.element(find.byType(AcademyScreen));
    GoRouter.of(context).push('/academy/unit/zzz');
    await _settle(tester);
    expect(find.byKey(const Key('ac-not-found')), findsOneWidget);
  });

  testWidgets('adding words to cards asks first, creates one deck, never duplicates', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.db.put('decks', 'mine', WordDeck(id: 'mine', userId: state.userId, name: 'مفرداتي', createdAt: DateTime(2026, 1, 1)).toJson());
    });
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('ac-unit-a1-u01')));

    await _tap(tester, find.byKey(const Key('ac-add-cards')));
    expect(find.textContaining('لن تتغير بطاقاتك ولا دروسك الحالية'), findsOneWidget);
    await _tap(tester, find.text('إلغاء'));
    expect(await tester.runAsync(() => state.db.count('decks')), 1, reason: 'cancel creates nothing');

    await _tap(tester, find.byKey(const Key('ac-add-cards')));
    await _tap(tester, find.text('تأكيد'));
    expect(find.text('تمت إضافة البطاقات'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('decks')), 2);
    expect(await tester.runAsync(() => state.db.count('cards')), 10);

    await _tap(tester, find.byKey(const Key('ac-add-cards')));
    await _tap(tester, find.text('تأكيد'));
    expect(find.text('هذه المفردات مضافة من قبل في بطاقاتك'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('cards')), 10);
  });

  testWidgets('English: translated and LTR', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);

    expect(find.text('Academy'), findsOneWidget);
    expect(find.text('Completed 0 of 12 units'), findsOneWidget);
    expect(find.text('Not started'), findsNWidgets(12));
    expect(Directionality.of(tester.element(find.byKey(const Key('ac-note')))), TextDirection.ltr);
  });
}
