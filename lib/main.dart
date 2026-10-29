import 'package:flutter/material.dart';
import 'package:glowara/app.dart';
import 'package:glowara/core/db/legacy_migration.dart';
import 'package:glowara/core/db/local_database.dart';
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
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  try {
    final db = await LocalDatabase.open();
    try {
      await LegacyMigration.runIfNeeded(db);
    } catch (_) {
      // ترحيل اختياري من النسخة القديمة: فشله لا يمنع فتح قاعدة البيانات.
    }

    final settings = SettingsRepository(db);
    final state = AppState(
      db: db,
      auth: AuthRepository(db),
      settings: settings,
      privacy: PrivacyService(db),
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
    await state.initialize();

    runApp(AppStateProvider(state: state, child: const GlowaraApp()));
  } catch (error) {
    runApp(_BootstrapErrorApp(message: error.toString()));
  }
}

/// شاشة خطأ تظهر إذا تعذّر فتح قاعدة البيانات المحلية.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.storage, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذّر فتح قاعدة البيانات المحلية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Could not open the local database.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      message,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
