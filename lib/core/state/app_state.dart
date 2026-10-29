/// حالة التطبيق العامة (المستخدم، الثيم، اللغة، الإعدادات، والمستودعات).
/// تُستخدم عبر ChangeNotifier وتُوفّر عبر InheritedWidget في شجر التطبيق.
library glowara.state;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:glowara/core/db/legacy_migration.dart';
import 'package:glowara/core/db/local_database.dart';
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

class AppState extends ChangeNotifier {
  AppState({
    required this.db,
    required this.auth,
    required this.settings,
    required this.privacy,
    required this.tasks,
    required this.habits,
    required this.worship,
    required this.journal,
    required this.study,
    required this.care,
    required this.health,
    required this.language,
    required this.progress,
  });

  final LocalDatabase db;
  final AuthRepository auth;
  final SettingsRepository settings;
  final PrivacyService privacy;
  final TaskRepository tasks;
  final HabitRepository habits;
  final WorshipRepository worship;
  final JournalRepository journal;
  final StudyRepository study;
  final CareRepository care;
  final HealthRepository health;
  final LanguageRepository language;
  final ProgressRepository progress;

  AppUser? _user;
  bool _isLoading = true;
  String? _initError;

  String _locale = 'ar';
  String _themeId = 'rose';
  ThemeMode _themeMode = ThemeMode.system;
  ReminderSettings _reminders = const ReminderSettings();
  DisplaySettings _display = const DisplaySettings();
  int _waterGoalMl = 2000;
  int _cupSizeMl = 250;
  bool _pinSet = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get initError => _initError;

  String get locale => _locale;
  String get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;
  ReminderSettings get reminders => _reminders;
  DisplaySettings get display => _display;
  int get waterGoalMl => _waterGoalMl;
  int get cupSizeMl => _cupSizeMl;
  bool get pinSet => _pinSet;

  bool get isLoggedIn => _user != null;

  /// معرف المستخدم الحالي (لازم لأن التطبيق يتطلب حسابًا محليًا).
  String get userId => _user?.id ?? 'local';

  /// تهيئة الحالة عند تشغيل التطبيق.
  Future<void> initialize() async {
    // لا نُظهر شاشة تحميل عند إعادة التهيئة بعد الاستيراد: الشاشة الحالية
    // ستبقى حيّة، ثم تُحدَّث بياناتها بعد انتهاء العملية.
    if (_user == null) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _user = await auth.currentUser();
      _locale = (await settings.get<String>('locale')) ?? 'ar';
      _themeId = (await settings.get<String>('themeId')) ?? 'rose';
      final mode = await settings.get<String>('themeMode');
      _themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _reminders = await settings.reminders();
      _display = await settings.display();
      _waterGoalMl = await settings.waterGoalMl();
      _cupSizeMl = await settings.cupSizeMl();
      _pinSet = await privacy.isPinSet();
      _initError = null;
    } catch (e) {
      _initError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // المصادقة
  // ---------------------------------------------------------------------------

  Future<AuthResult> login({required String email, required String password}) async {
    final result = await auth.login(email: email, password: password);
    if (result.ok) {
      _user = result.user;
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await auth.register(email: email, password: password, name: name);
    if (result.ok) {
      _user = result.user;
      notifyListeners();
    }
    return result;
  }

  Future<void> logout() async {
    await auth.logout();
    _user = null;
    notifyListeners();
  }

  /// حذف الحساب المحلي وكل البيانات.
  Future<void> deleteAccount() async {
    await auth.deleteAccount();
    try {
      await LegacyMigration.clearLegacy();
    } catch (_) {
      // الحذف الأساسي تم؛ تعذّر تنظيف مفاتيح النسخة القديمة لا يغيّر النتيجة.
    }
    _user = null;
    _pinSet = false;
    _locale = 'ar';
    _themeId = 'rose';
    _themeMode = ThemeMode.system;
    _reminders = const ReminderSettings();
    _display = const DisplaySettings();
    _waterGoalMl = 2000;
    _cupSizeMl = 250;
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    if (_user == null) return;
    _user = _user!.copyWith(displayName: name, lastModified: DateTime.now());
    await auth.updateProfile(_user!);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // التفضيلات
  // ---------------------------------------------------------------------------

  Future<void> setLocale(String locale) async {
    _locale = locale;
    await settings.set('locale', locale);
    notifyListeners();
  }

  Future<void> setTheme(String themeId, ThemeMode mode) async {
    _themeId = themeId;
    _themeMode = mode;
    await settings.set('themeId', themeId);
    await settings.set(
      'themeMode',
      mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system',
    );
    notifyListeners();
  }

  Future<void> setReminders(ReminderSettings value) async {
    _reminders = value;
    await settings.saveReminders(value);
    notifyListeners();
  }

  Future<void> setDisplay(DisplaySettings value) async {
    _display = value;
    await settings.saveDisplay(value);
    notifyListeners();
  }

  Future<void> setWaterGoalMl(int value) async {
    _waterGoalMl = value.clamp(500, 6000).toInt();
    await settings.setWaterGoalMl(_waterGoalMl);
    notifyListeners();
  }

  Future<void> setCupSizeMl(int value) async {
    _cupSizeMl = value.clamp(100, 1000).toInt();
    await settings.setCupSizeMl(_cupSizeMl);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // الخصوصية
  // ---------------------------------------------------------------------------

  Future<void> setPin(String pin) async {
    await privacy.setPin(pin);
    _pinSet = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) => privacy.verifyPin(pin);

  Future<void> removePin() async {
    await privacy.removePin();
    _pinSet = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // إدارة البيانات
  // ---------------------------------------------------------------------------

  Future<String> exportData() async {
    final data = await db.exportAll();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<int> importData(String source) async {
    if (_user == null) {
      throw StateError('Login is required before importing data');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('JSON root must be an object');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['app'] != 'glowara') {
      throw const FormatException('This is not a Glowara backup');
    }
    final version = data['schemaVersion'];
    if (version is int && version > 2) {
      throw const FormatException('Unsupported backup schema version');
    }
    final count = await db.importAll(data, targetUserId: userId);
    await initialize();
    return count;
  }

  Future<void> clearAllData() async {
    await db.clearAll();
    try {
      await LegacyMigration.clearLegacy();
    } catch (_) {
      // لا نمنع اكتمال الحذف إذا تعذّر الوصول إلى SharedPreferences.
    }
    _user = null;
    _pinSet = false;
    _locale = 'ar';
    _themeId = 'rose';
    _themeMode = ThemeMode.system;
    _reminders = const ReminderSettings();
    _display = const DisplaySettings();
    _waterGoalMl = 2000;
    _cupSizeMl = 250;
    notifyListeners();
  }

  Future<int> storageBytes() => db.estimatedSizeBytes();

  /// تُستدعى بعد أي تعديل في البيانات لإعادة بناء الشاشات المعتمدة.
  void refresh() => notifyListeners();
}

/// توفير AppState للشجرة عبر InheritedNotifier.
/// يستمع إلى تغييرات ChangeNotifier ويُعيد بناء كل من يعتمد عليه
/// (اللغة، الثيم، تسجيل الدخول، قفل المذكرات...).
class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppStateProvider>();
    assert(provider != null, 'AppStateProvider not found in widget tree');
    return provider!.notifier!;
  }
}
