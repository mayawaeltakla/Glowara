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
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/features/calendar/month_calendar_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

const String _taskTitle = 'مهمة الاختبار';
final DateTime _day20 = DateTime(2026, 11, 20);

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
  await state.tasks.save(TaskItem(
    id: 't1',
    userId: state.userId,
    title: _taskTitle,
    dueDateTime: DateTime(2026, 11, 20, 10, 30),
    createdAt: DateTime(2026, 11, 1),
  ));
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pump(
  WidgetTester tester,
  AppState state, {
  Size size = const Size(400, 3000),
}) async {
  tester.view.physicalSize = size;
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
        home: MonthCalendarScreen(initialDay: _day20),
      ),
    ),
  );
  await _settle(tester);
}

Finder _cell(int y, int m, int d) =>
    find.byKey(ValueKey<String>('cal-day-${dateKey(DateTime(y, m, d))}'));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('Arabic: the week starts on Sunday on the right', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    expect(_cell(2026, 11, 1), findsOneWidget);
    // 1 نوفمبر 2026 أحد: أول عمود، وهو على اليمين في RTL.
    expect(tester.getCenter(_cell(2026, 11, 1)).dx, greaterThan(tester.getCenter(_cell(2026, 11, 2)).dx));
    expect(find.text(formatMonthYear(DateTime(2026, 11), 'ar')), findsOneWidget);
  });

  testWidgets('English: the week starts on Monday on the left', (tester) async {
    final state = (await tester.runAsync(() => _state(locale: 'en')))!;
    await _pump(tester, state);

    // الاثنين 26 أكتوبر أول خلية.
    expect(_cell(2026, 10, 26), findsOneWidget);
    expect(tester.getCenter(_cell(2026, 10, 26)).dx, lessThan(tester.getCenter(_cell(2026, 10, 27)).dx));
    expect(find.text(formatMonthYear(DateTime(2026, 11), 'en')), findsOneWidget);
  });

  testWidgets('tapping a day opens its details and a quiet day says so', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    await tester.tap(_cell(2026, 11, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(_taskTitle), findsOneWidget);
    // أغلقي الورقة بالنقر خارجها ثم اختاري يومًا فارغًا.
    await tester.tapAt(const Offset(200, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_cell(2026, 11, 22));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('يوم هادئ. لا شيء مسجّل هنا'), findsOneWidget);
    expect(find.text(_taskTitle), findsNothing);
  });

  testWidgets('month navigation crosses into December and back', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    await tester.tap(find.byTooltip('الشهر التالي'));
    await _settle(tester);
    expect(find.text(formatMonthYear(DateTime(2026, 12), 'ar')), findsOneWidget);

    await tester.tap(find.byTooltip('الشهر السابق'));
    await _settle(tester);
    expect(find.text(formatMonthYear(DateTime(2026, 11), 'ar')), findsOneWidget);
  });

  testWidgets('tapping a day of the next month moves to that month', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state);

    // 5 ديسمبر ضمن شبكة نوفمبر (الأحد أول الأسبوع).
    await tester.tap(_cell(2026, 12, 5));
    await _settle(tester);
    expect(find.text(formatMonthYear(DateTime(2026, 12), 'ar')), findsWidgets);
  });

  testWidgets('wide layout shows the selected day without tapping', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, size: const Size(1400, 1000));

    expect(find.text(_taskTitle), findsOneWidget);
  });

  testWidgets('journals and mood never show up in the calendar', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await tester.runAsync(() async {
      await state.journal.saveMood(userId: state.userId, day: _day20, value: 5, note: 'ملاحظة مزاج سرية');
    });
    await _pump(tester, state, size: const Size(1400, 1000));

    expect(find.textContaining('سرية'), findsNothing);
  });

  testWidgets('opening the calendar and browsing writes nothing', (tester) async {
    final state = (await tester.runAsync(_state))!;
    Future<String> dump() async {
      final data = await state.db.exportAll();
      data.remove('exportedAt');
      return jsonEncode(data);
    }

    final before = (await tester.runAsync(dump))!;
    await _pump(tester, state);
    await tester.tap(_cell(2026, 11, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(200, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('الشهر التالي'));
    await _settle(tester);
    final after = (await tester.runAsync(dump))!;
    expect(after, before);
  });
}
