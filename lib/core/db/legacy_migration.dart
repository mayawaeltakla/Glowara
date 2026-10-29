/// ترحيل بيانات النسخة القديمة المخزنة في shared_preferences إلى sembast.
///
/// الترحيل **غير هدّام**: ينسخ البيانات ولا يحذف المفاتيح القديمة،
/// ويُسجّل علامة `migration_prefs_v1_done` لعدم تكراره.
library glowara.db.migration;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_database.dart';

class LegacyMigration {
  LegacyMigration._();

  static const String _flag = 'migration_prefs_v1_done';

  /// خريطة أسماء المجموعات القديمة إلى الجديدة.
  static const Map<String, String> _collections = <String, String>{
    'task': 'tasks',
    'habit': 'habits',
    'habitLog': 'habitLogs',
    'worship': 'worship',
    'readingLog': 'readingLogs',
    'mood': 'moods',
    'journal': 'journals',
    'subject': 'subjects',
    'unit': 'units',
    'session': 'sessions',
    'water': 'water',
    'meal': 'meals',
    'sync': 'sync',
  };

  /// يمسح مفاتيح النسخة القديمة بعد طلب المستخدمة حذف كل البيانات،
  /// كي لا يعيد الترحيل بيانات قديمة عند التشغيل التالي.
  static Future<void> clearLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _collections.keys) {
      await prefs.remove('glowara_list:$key');
    }
    await prefs.remove('user_current');
    for (final key in <String>['locale', 'themeId', 'themeMode']) {
      await prefs.remove('setting:$key');
    }
  }

  /// ينفّذ الترحيل مرة واحدة ويعيد عدد السجلات المنسوخة.
  static Future<int> runIfNeeded(LocalDatabase db) async {
    final done = await db.getSetting(_flag);
    if (done == true) return 0;

    final prefs = await SharedPreferences.getInstance();
    var imported = 0;

    for (final entry in _collections.entries) {
      final raw = prefs.getString('glowara_list:${entry.key}');
      if (raw == null) continue;
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final id = map['id']?.toString();
          if (id == null || id.isEmpty) continue;
          await db.put(entry.value, id, map);
          imported++;
        }
      } catch (_) {
        // سجل تالف لا يجب أن يمنع تشغيل التطبيق.
      }
    }

    // المستخدم الحالي
    final user = prefs.getString('user_current');
    if (user != null) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(user) as Map);
        await db.setSetting('current_user', map);
      } catch (_) {}
    }

    // الإعدادات القديمة
    for (final key in <String>['locale', 'themeId', 'themeMode']) {
      final raw = prefs.getString('setting:$key');
      if (raw == null) continue;
      try {
        await db.setSetting(key, jsonDecode(raw));
      } catch (_) {}
    }

    await db.setSetting(_flag, true);
    return imported;
  }
}
