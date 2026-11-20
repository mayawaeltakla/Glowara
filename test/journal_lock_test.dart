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
import 'package:glowara/features/journal/journal_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

const _secretTitle = 'عنوان سري جدا';

Future<AppState> _stateWithPinAndJournal({bool withPin = true}) async {
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
  await state.journal.saveJournal(JournalEntry(
    id: 'j1',
    userId: state.userId,
    title: _secretTitle,
    content: 'محتوى خاص',
    createdAt: DateTime.now(),
  ));
  if (withPin) await state.setPin('1234');
  return state;
}

Future<void> _pumpJournal(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(400, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppStateProvider(
      state: state,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppThemes.material('serene', Brightness.light, locale: 'ar', webFonts: false),
        home: const JournalScreen(),
      ),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// المذكرات في التبويب الثاني؛ تعود الشاشة إلى تبويب المزاج بعد كل فتح.
Future<void> _openJournalsTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_note).first);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _unlock(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '1234');
  await tester.tap(find.byType(FilledButton));
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  test('only leaving the foreground locks; inactive and resumed do not', () {
    expect(JournalScreen.locksOn(AppLifecycleState.hidden), isTrue);
    expect(JournalScreen.locksOn(AppLifecycleState.paused), isTrue);
    expect(JournalScreen.locksOn(AppLifecycleState.detached), isTrue);
    expect(JournalScreen.locksOn(AppLifecycleState.inactive), isFalse);
    expect(JournalScreen.locksOn(AppLifecycleState.resumed), isFalse);
  });

  testWidgets('journals stay hidden until the PIN is entered', (tester) async {
    final state = (await tester.runAsync(_stateWithPinAndJournal))!;
    await _pumpJournal(tester, state);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.textContaining(_secretTitle), findsNothing);
  });

  testWidgets('going to the background relocks and clears what was shown', (tester) async {
    final state = (await tester.runAsync(_stateWithPinAndJournal))!;
    await _pumpJournal(tester, state);
    await _unlock(tester);
    await _openJournalsTab(tester);
    expect(find.textContaining(_secretTitle), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.textContaining(_secretTitle), findsOneWidget, reason: 'inactive must not lock');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining(_secretTitle), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // العودة لا تُظهر المذكرات قبل إدخال الرمز من جديد.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining(_secretTitle), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // لم يُحذف شيء من قاعدة البيانات.
    final stored = await tester.runAsync(() => state.journal.journals(state.userId));
    expect(stored, hasLength(1));

    // وبعد إدخال الرمز تعود كما كانت.
    await _unlock(tester);
    await _openJournalsTab(tester);
    expect(find.textContaining(_secretTitle), findsOneWidget);
  });

  testWidgets('an open editor with unsaved text is closed on lock', (tester) async {
    final state = (await tester.runAsync(_stateWithPinAndJournal))!;
    await _pumpJournal(tester, state);
    await _unlock(tester);
    await _openJournalsTab(tester);

    await tester.ensureVisible(find.textContaining(_secretTitle));
    await tester.tap(find.textContaining(_secretTitle));
    await tester.pump(const Duration(milliseconds: 500));
    final editorFields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(editorFields, findsWidgets);
    await tester.enterText(editorFields.first, 'مسودة خاصة');
    await tester.pump();
    expect(find.text('مسودة خاصة'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('مسودة خاصة'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('without a PIN nothing locks', (tester) async {
    final state = (await tester.runAsync(() => _stateWithPinAndJournal(withPin: false)))!;
    await _pumpJournal(tester, state);
    await _openJournalsTab(tester);
    expect(find.textContaining(_secretTitle), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining(_secretTitle), findsOneWidget);
  });
}
