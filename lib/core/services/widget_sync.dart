/// ودجت الشاشة الرئيسية في أندرويد (اختياري ومعطّل افتراضيًا).
///
/// لا يعرض إلا سطرًا واحدًا: عدد مهام اليوم غير المنجزة. لا مزاج ولا مذكرات ولا
/// عبادة ولا ركني ولا أي نص من مهامك. يكتب التطبيق هذا السطر في
/// `shared_preferences` (مفاتيح `glowara_widget_*`) ويقرؤه الودجت الأصلي.
/// يتفعّل فقط في البناء الذي يحقن `GLOWARA_WIDGET=true` (لأن الجزء الأصلي
/// يُضاف في CI لذلك البناء وحده)، وفقط على أندرويد.
library glowara.services.widget_sync;

import 'package:flutter/foundation.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/repositories/task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kWidgetBuild = bool.fromEnvironment('GLOWARA_WIDGET');
const String kWidgetTitleKey = 'glowara_widget_title';
const String kWidgetLineKey = 'glowara_widget_line';

String widgetEnabledKey(String userId) => 'widget_enabled_$userId';

abstract class WidgetStore {
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefsWidgetStore implements WidgetStore {
  @override
  Future<void> write(String key, String value) async => (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async => (await SharedPreferences.getInstance()).remove(key);
}

/// نص سطر الودجت. عام ولا يحمل أي عنوان مهمة.
String widgetLine(int tasksLeft, String locale) {
  if (locale == 'ar') {
    if (tasksLeft <= 0) return 'يوم هادئ، لا مهام اليوم';
    if (tasksLeft == 1) return 'مهمة واحدة اليوم';
    if (tasksLeft == 2) return 'مهمتان اليوم';
    if (tasksLeft <= 10) return '$tasksLeft مهام اليوم';
    return '$tasksLeft مهمة اليوم';
  }
  if (tasksLeft <= 0) return 'A quiet day, no tasks today';
  if (tasksLeft == 1) return '1 task today';
  return '$tasksLeft tasks today';
}

class WidgetSync {
  WidgetSync({required SettingsRepository settings, required LocalDatabase db, WidgetStore? store, bool? supported})
      : _settings = settings,
        _db = db,
        _store = store ?? debugStore ?? SharedPrefsWidgetStore(),
        supported = supported ?? platformSupported;

  /// للاختبارات فقط.
  @visibleForTesting
  static WidgetStore? debugStore;
  @visibleForTesting
  static bool? debugSupported;

  static bool get platformSupported =>
      debugSupported ?? (kWidgetBuild && !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final SettingsRepository _settings;
  final LocalDatabase _db;
  final WidgetStore _store;
  final bool supported;

  Future<bool> enabled(String userId) async => supported && await _settings.get<String>(widgetEnabledKey(userId)) == '1';

  Future<void> setEnabled(String userId, bool on, String locale, {DateTime? now}) async {
    await _settings.set(widgetEnabledKey(userId), on ? '1' : '0');
    if (on) {
      await refresh(userId, locale, now: now);
    } else {
      await clear();
    }
  }

  /// يحدّث نص الودجت إن كان مفعّلًا لهذه المستخدمة، وإلا يمسحه. يبتلع الأخطاء.
  Future<void> refresh(String userId, String locale, {DateTime? now}) async {
    if (!supported) return;
    try {
      if (!await enabled(userId)) {
        await clear();
        return;
      }
      final t = now ?? DateTime.now();
      final day = DateTime(t.year, t.month, t.day);
      final end = DateTime(t.year, t.month, t.day, 23, 59, 59);
      final left = (await TaskRepository(_db).forRange(userId, day, end)).where((x) => x.state != TaskState.done).length;
      await _store.write(kWidgetTitleKey, locale == 'ar' ? 'غلوارا' : 'Glowara');
      await _store.write(kWidgetLineKey, widgetLine(left, locale));
    } catch (_) {
      // الودجت اختياري ولا يؤثر على التطبيق.
    }
  }

  /// يمسح نص الودجت (يعود إلى الاسم فقط).
  Future<void> clear() async {
    try {
      await _store.remove(kWidgetTitleKey);
      await _store.remove(kWidgetLineKey);
    } catch (_) {}
  }

  /// عند تسجيل الخروج أو حذف الحساب: لا يبقى سطر مستخدمة سابقة على الشاشة.
  static Future<void> clearForLogout() async {
    if (!platformSupported) return;
    try {
      final store = debugStore ?? SharedPrefsWidgetStore();
      await store.remove(kWidgetTitleKey);
      await store.remove(kWidgetLineKey);
    } catch (_) {}
  }
}
