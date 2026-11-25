import 'dart:typed_data';

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
import 'package:glowara/core/repositories/image_repository.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/widgets/photo_slot.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/features/dreams/dream_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'photos_test.dart' show kPng;
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




Future<void> _pump(WidgetTester tester, AppState state, String id) async {
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
        home: DreamScreen(dreamId: id),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  tearDown(() => PhotoSlot.debugPicker = null);

  testWidgets('a new unsaved dream has no photo slot; a saved one can add, replace and remove', (tester) async {
    final state = (await tester.runAsync(_state))!;
    await _pump(tester, state, 'new');
    expect(find.byKey(const Key('photo-add')), findsNothing);

    final dream = (await tester.runAsync(() => DreamRepository(state.db).save(userId: state.userId, title: 'سفر')))!;
    await _pump(tester, state, dream.id);
    expect(find.byKey(const Key('photo-add')), findsOneWidget);
    expect(find.byKey(const Key('photo-image')), findsNothing);
    expect(find.textContaining('تبقى الصورة على جهازك'), findsOneWidget);

    PhotoSlot.debugPicker = () async => kPng;
    await tester.tap(find.byKey(const Key('photo-add')));
    await _settle(tester);
    expect(find.byKey(const Key('photo-image')), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('images')), 1);

    await tester.tap(find.byKey(const Key('photo-remove')));
    await _settle(tester);
    expect(find.byKey(const Key('photo-image')), findsNothing);
    expect(await tester.runAsync(() => state.db.count('images')), 0);
  });

  testWidgets('a file that is not an image shows a message and stores nothing', (tester) async {
    final state = (await tester.runAsync(_state))!;
    final dream = (await tester.runAsync(() => DreamRepository(state.db).save(userId: state.userId, title: 'سفر')))!;
    await _pump(tester, state, dream.id);
    PhotoSlot.debugPicker = () async => Uint8List.fromList(List<int>.filled(40, 65));
    await tester.tap(find.byKey(const Key('photo-add')));
    await _settle(tester);
    expect(find.byKey(const Key('photo-error')), findsOneWidget);
    expect(await tester.runAsync(() => state.db.count('images')), 0);
    expect(await tester.runAsync(() => ImageRepository(state.db).get(state.userId, dream.id)), isNull);
  });
}
