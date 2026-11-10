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
import 'package:glowara/features/home/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/test_db.dart';

Future<AppState> _stateWithData() async {
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

  final now = DateTime.now();
  await state.tasks.save(TaskItem(
    id: 't1',
    userId: state.userId,
    title: 'مراجعة الدرس ثم كتابة ملخص طويل جدًا يختبر التفاف النص داخل الصف',
    dueDateTime: DateTime(now.year, now.month, now.day, 9, 30),
    createdAt: now,
  ));
  await state.tasks.save(TaskItem(
    id: 't2',
    userId: state.userId,
    title: 'Call the clinic',
    dueDateTime: DateTime(now.year, now.month, now.day, 14),
    state: TaskState.done,
    createdAt: now,
  ));
  await state.health.addWater(userId: state.userId, day: now, deltaMl: 750);
  return state;
}

Future<void> _pumpHome(
  WidgetTester tester,
  AppState state, {
  required String language,
  required Brightness brightness,
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AppStateProvider(
      state: state,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppThemes.material('serene', brightness, locale: language, webFonts: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  // تحميل البيانات من قاعدة الذاكرة ثم إنهاء الحركات.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late AppState state;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  setUp(() async {
    state = await _stateWithData();
  });

  // (اللغة، الوضع، العرض، تكبير الخط)
  final configs = <(String, Brightness, double, double)>[
    ('ar', Brightness.light, 360, 1.0),
    ('ar', Brightness.dark, 360, 1.0),
    ('en', Brightness.light, 360, 1.0),
    ('en', Brightness.dark, 412, 1.0),
    ('ar', Brightness.light, 320, 1.4),
    ('en', Brightness.dark, 320, 1.3),
  ];

  for (final (language, brightness, width, scale) in configs) {
    testWidgets('home renders without overflow: $language ${brightness.name} ${width.toInt()}px x$scale',
        (tester) async {
      await _pumpHome(
        tester,
        state,
        language: language,
        brightness: brightness,
        width: width,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(language == 'ar' ? 'إشراقة يومك' : 'Your day’s glow'), findsOneWidget);
      // أيقونة تبديل إنجاز المهمة ظاهرة، والبيانات المحمّلة حقيقية.
      // نسبة التوازن: مهمة من اثنتين + ماء 750 من 2000 → متوسط ≈ 44%.
      expect(find.textContaining('%'), findsWidgets);
      // القائمة كسولة: نمرّر حتى تظهر المهمة (وهذا يختبر بقية الصفحة أيضًا).
      await tester.scrollUntilVisible(find.text('Call the clinic'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Call the clinic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
