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
import 'package:glowara/core/repositories/library_repository.dart';
import 'package:glowara/core/repositories/progress_repository.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/study_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:glowara/core/repositories/worship_repository.dart';
import 'package:glowara/core/security/privacy_service.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/library/book_screen.dart';
import 'package:glowara/features/library/library_screen.dart';
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
        GoRoute(path: '/', builder: (context, state) => const LibraryScreen()),
        GoRoute(
          path: '/library/book/:id',
          builder: (context, state) => BookScreen(bookId: state.pathParameters['id'] ?? 'new'),
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

  testWidgets('Arabic: empty library with a calm note and no percentages', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(find.text('مكتبتي'), findsOneWidget);
    expect(find.textContaining('بلا أهداف قراءة ولا نسب'), findsOneWidget);
    expect(find.byKey(const Key('lb-empty')), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(await tester.runAsync(() => state.db.count('books')), 0);
  });

  testWidgets('adding a book, then a note; pages shown as text only', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(const Key('lb-add')));
    expect(find.byKey(const Key('lb-save-first')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('lb-save')));
    expect(find.text('اكتبي عنوان الكتاب'), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('books')), 0);

    await tester.enterText(find.byKey(const Key('lb-title')), 'كتاب تجريبي');
    await tester.enterText(find.byKey(const Key('lb-category')), 'تطوير');
    await _tap(tester, find.byKey(const Key('lb-set-reading')));
    await tester.enterText(find.byKey(const Key('lb-current')), '40');
    await tester.enterText(find.byKey(const Key('lb-total')), '200');
    await _tap(tester, find.byKey(const Key('lb-save')));
    expect(find.byKey(const Key('lb-add-note')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('lb-add-note')));
    await _tap(tester, find.byKey(const Key('lb-kind-quote')));
    await tester.enterText(find.byKey(const Key('lb-note-text')), 'جملة أعجبتني');
    await tester.enterText(find.byKey(const Key('lb-note-page')), '12');
    await _tap(tester, find.byKey(const Key('lb-note-save')));
    expect(find.text('جملة أعجبتني'), findsOneWidget);
    expect(find.text('اقتباس · 12'), findsOneWidget);

    final books = (await tester.runAsync(() => LibraryRepository(state.db).all(state.userId)))!;
    expect(books.single.status, 'reading');
    expect(books.single.currentPage, 40);
    expect(books.single.notes.single.kind, 'quote');

    // ارجعي إلى القائمة: الصفحة نصًّا بلا نسبة.
    await _tap(tester, find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(find.text('أقرؤه الآن · الصفحة 40 من 200 · تطوير'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('filters by status and category', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final repo = LibraryRepository(state.db);
    await tester.runAsync(() async {
      await repo.save(userId: state.userId, title: 'أ', status: 'reading', category: 'علوم');
      await repo.save(userId: state.userId, title: 'ب', status: 'finished', category: 'أدب');
      await repo.save(userId: state.userId, title: 'ج');
    });
    await _pump(tester, state);
    expect(find.text('أ'), findsOneWidget);
    expect(find.text('ب'), findsOneWidget);
    expect(find.text('ج'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('lb-status-finished')));
    expect(find.text('ب'), findsOneWidget);
    expect(find.text('أ'), findsNothing);

    await _tap(tester, find.byKey(const Key('lb-status-all')));
    await _tap(tester, find.byKey(const Key('lb-cat-علوم')));
    expect(find.text('أ'), findsOneWidget);
    expect(find.text('ب'), findsNothing);
    await _tap(tester, find.byKey(const Key('lb-status-finished')));
    expect(find.byKey(const Key('lb-empty-filter')), findsOneWidget);
  });

  testWidgets('deleting a note, and deleting a book asks first', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final repo = LibraryRepository(state.db);
    final b = (await tester.runAsync(() async {
      final book = await repo.save(userId: state.userId, title: 'كتاب');
      return repo.addNote(userId: state.userId, bookId: book.id, kind: 'note', text: 'ملاحظتي');
    }))!;
    await _pump(tester, state);
    await _tap(tester, find.byKey(Key('lb-book-${b.id}')));
    expect(find.text('ملاحظتي'), findsOneWidget);
    await _tap(tester, find.byKey(Key('lb-note-del-${b.notes.single.id}')));
    expect(find.text('ملاحظتي'), findsNothing);

    await _tap(tester, find.byKey(const Key('lb-delete')));
    await _tap(tester, find.byKey(const Key('lb-delete-no')));
    expect(await tester.runAsync(() => state.db.count('books')), 1);
    await _tap(tester, find.byKey(const Key('lb-delete')));
    await _tap(tester, find.byKey(const Key('lb-delete-yes')));
    expect(await tester.runAsync(() => state.db.count('books')), 0);
  });

  testWidgets('English labels', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);
    expect(find.text('My library'), findsOneWidget);
    expect(find.textContaining('No reading goals'), findsOneWidget);
  });
}
