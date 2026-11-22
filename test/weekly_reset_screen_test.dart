import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/weekly_reset_models.dart';
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
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/features/weekly_reset/weekly_reset_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

// أسبوع الأحد: 2026-11-15 .. 2026-11-21. أسبوع الاثنين: 2026-11-16 .. 2026-11-22.
final DateTime _arWeek = DateTime(2026, 11, 15);
final DateTime _enWeek = DateTime(2026, 11, 16);

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

Future<void> _pump(WidgetTester tester, AppState state, {DateTime? week}) async {
  tester.view.physicalSize = const Size(400, 3200);
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
        home: WeeklyResetScreen(initialWeekStart: week),
      ),
    ),
  );
  await _settle(tester);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<WeeklyReset?> _stored(WidgetTester tester, AppState state, DateTime week) async {
  return tester.runAsync<WeeklyReset?>(() => state.db.byId<WeeklyReset>(
        'weeklyResets',
        WeeklyReset.idFor(state.userId, dateKey(week)),
        WeeklyReset.fromJson,
      ));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: shows the week, a calm empty summary and no next-week jump', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, week: _arWeek);

    expect(find.text('المراجعة الأسبوعية'), findsOneWidget);
    expect(
      find.text('${formatShortDate(_arWeek, 'ar')} – ${formatShortDate(DateTime(2026, 11, 21), 'ar')}'),
      findsOneWidget,
    );
    expect(find.textContaining('لا شيء مسجّل في هذا الأسبوع'), findsOneWidget);
    expect(find.textContaining('ليس مقفلًا بالرمز'), findsOneWidget);
    expect(find.textContaining('لن تُنشأ مهام ولا إشعارات'), findsOneWidget);
    // ثلاث أولويات لا أكثر.
    expect(find.byKey(const Key('wk-priority-2')), findsOneWidget);
    expect(find.byKey(const Key('wk-priority-3')), findsNothing);
    // لا حذف لمراجعة غير محفوظة.
    expect(find.byKey(const Key('wk-delete')), findsNothing);
  });

  testWidgets('the current week cannot move forward', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);
    expect(tester.widget<IconButton>(find.byKey(const Key('wk-next'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('wk-prev'))).onPressed, isNotNull);
  });

  testWidgets('summary shows real counts, worship as presence without numbers', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.db.put(
        'tasks',
        't1',
        TaskItem(
          id: 't1',
          userId: state.userId,
          title: 'م',
          dueDateTime: DateTime(2026, 11, 17, 10),
          state: TaskState.done,
          createdAt: DateTime(2026, 11, 1),
        ).toJson(),
      );
      await state.db.put(
        'sessions',
        's1',
        StudySession(
          id: 's1',
          userId: state.userId,
          subjectId: 'x',
          startedAt: DateTime(2026, 11, 18, 9),
          durationMinutes: 30,
          createdAt: DateTime(2026, 11, 18),
        ).toJson(),
      );
      await state.db.put(
        'readingLogs',
        'r1',
        ReadingLog(
          id: 'r1',
          userId: state.userId,
          itemId: 'quran_1',
          completedAt: DateTime(2026, 11, 19, 6),
        ).toJson(),
      );
    });
    await _pump(tester, state, week: _arWeek);

    expect(find.text('1 مهام أنجزتِها'), findsOneWidget);
    expect(find.text('30 دقائق دراسة'), findsOneWidget);
    expect(find.text('كان للقرآن والأذكار حضور في أسبوعك.'), findsOneWidget);
    expect(find.textContaining('لا شيء مسجّل في هذا الأسبوع'), findsNothing);
    expect(find.textContaining('%'), findsNothing, reason: 'no percentages');
  });

  testWidgets('writing and saving stores one trimmed record and creates nothing else', (tester) async {
    final state = (await tester.runAsync(_state))!;
    Future<String> others() async {
      final data = await state.db.exportAll();
      data.remove('exportedAt');
      data.remove('weeklyResets');
      return jsonEncode(data);
    }

    final before = (await tester.runAsync(others))!;
    await _pump(tester, state, week: _arWeek);

    await tester.enterText(find.byKey(const Key('wk-went-well')), '  قرأت كثيرًا  ');
    await tester.enterText(find.byKey(const Key('wk-needs-adjust')), 'النوم');
    await tester.enterText(find.byKey(const Key('wk-priority-0')), 'أولى');
    await tester.enterText(find.byKey(const Key('wk-priority-2')), 'ثالثة');
    await tester.enterText(find.byKey(const Key('wk-study-plan')), 'فصل');
    await tester.enterText(find.byKey(const Key('wk-personal-plan')), 'مشي');
    await tester.pump();

    await tester.tap(find.byKey(const Key('wk-save')));
    await _settle(tester);

    final stored = await _stored(tester, state, _arWeek);
    expect(stored, isNotNull);
    expect(stored!.wentWell, 'قرأت كثيرًا');
    expect(stored.needsAdjustment, 'النوم');
    expect(stored.priorities, <String>['أولى', 'ثالثة']);
    expect(stored.studyPlan, 'فصل');
    expect(stored.personalPlan, 'مشي');
    expect(stored.weekStart, '2026-11-15');
    expect(stored.weekEnd, '2026-11-21');
    expect(find.text('تم حفظ مراجعتك'), findsOneWidget);
    expect(find.byKey(const Key('wk-delete')), findsOneWidget);
    expect((await tester.runAsync(others))!, before, reason: 'no tasks, reminders or other data written');
  });

  testWidgets('reopening shows what was saved', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.db.put(
        'weeklyResets',
        WeeklyReset.idFor(state.userId, '2026-11-15'),
        WeeklyReset(
          id: WeeklyReset.idFor(state.userId, '2026-11-15'),
          userId: state.userId,
          weekStart: '2026-11-15',
          weekEnd: '2026-11-21',
          wentWell: 'محفوظ',
          priorities: const <String>['أ', 'ب'],
          focusType: WeeklyFocusType.text,
          focusText: 'تركيز',
          createdAt: DateTime(2026, 11, 21),
          updatedAt: DateTime(2026, 11, 21),
        ).toJson(),
      );
    });
    await _pump(tester, state, week: _arWeek);

    expect(_text(tester, 'wk-went-well'), 'محفوظ');
    expect(_text(tester, 'wk-priority-0'), 'أ');
    expect(_text(tester, 'wk-priority-1'), 'ب');
    expect(_text(tester, 'wk-priority-2'), '');
    expect(_text(tester, 'wk-focus-text'), 'تركيز');
    expect(find.byKey(Key('wk-history-${dateKey(_arWeek)}')), findsOneWidget);
  });

  testWidgets('mood and journal text never appear', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.journal.saveMood(
        userId: state.userId,
        day: DateTime(2026, 11, 17),
        value: 1,
        note: 'ملاحظة مزاج سرية',
      );
      await state.db.put(
        'journals',
        'j1',
        JournalEntry(
          id: 'j1',
          userId: state.userId,
          title: 'عنوان سري',
          content: 'محتوى سري',
          createdAt: DateTime(2026, 11, 17),
        ).toJson(),
      );
    });
    await _pump(tester, state, week: _arWeek);

    expect(find.textContaining('سري'), findsNothing);
    expect(find.textContaining('سرية'), findsNothing);
    // لا شيء سُجّل غير ذلك، فالملخص هادئ.
    expect(find.textContaining('لا شيء مسجّل في هذا الأسبوع'), findsOneWidget);
  });

  testWidgets('changing week with unsaved text asks first; cancel keeps it, confirm moves on', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, week: _arWeek);
    final prevRange =
        '${formatShortDate(DateTime(2026, 11, 8), 'ar')} – ${formatShortDate(DateTime(2026, 11, 14), 'ar')}';

    await tester.enterText(find.byKey(const Key('wk-went-well')), 'لم يُحفظ بعد');
    await tester.pump();
    await tester.tap(find.byTooltip('الأسبوع السابق'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('تجاهل ما كتبتِه ولم يُحفظ؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(prevRange), findsNothing);
    expect(_text(tester, 'wk-went-well'), 'لم يُحفظ بعد');

    await tester.tap(find.byTooltip('الأسبوع السابق'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('تأكيد'));
    await _settle(tester);
    expect(find.text(prevRange), findsOneWidget);
    expect(_text(tester, 'wk-went-well'), '');
    expect(await _stored(tester, state, _arWeek), isNull);
  });

  testWidgets('a habit can be the focus, and deleting removes only the review', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.db.put(
        'habits',
        'h1',
        Habit(id: 'h1', userId: state.userId, name: 'المشي', createdAt: DateTime(2026, 10, 1)).toJson(),
      );
    });
    await _pump(tester, state, week: _arWeek);

    await tester.tap(find.byKey(const Key('wk-focus-habit')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('المشي').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('wk-save')));
    await _settle(tester);

    final stored = await _stored(tester, state, _arWeek);
    expect(stored, isNotNull);
    expect(stored!.focusType, WeeklyFocusType.habit);
    expect(stored.focusHabitId, 'h1');

    await tester.tap(find.byKey(const Key('wk-delete')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await _settle(tester);

    expect(await _stored(tester, state, _arWeek), isNull);
    final habit = await tester.runAsync(() => state.db.byId('habits', 'h1', Habit.fromJson));
    expect(habit, isNotNull, reason: 'the habit is untouched');
  });

  testWidgets('English: Monday-first week, LTR and translated texts', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state, week: _enWeek);

    expect(find.text('Weekly reset'), findsOneWidget);
    expect(
      find.text('${formatShortDate(_enWeek, 'en')} – ${formatShortDate(DateTime(2026, 11, 22), 'en')}'),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing is logged for this week'), findsOneWidget);
    expect(find.text('Save reset'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('wk-save')))), TextDirection.ltr);
  });
}
