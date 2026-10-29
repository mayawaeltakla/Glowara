/// قاعدة بيانات Glowara المحلية (sembast).
///
/// - على Android: ملف `glowara.db` في مجلد المستندات.
/// - على الويب: IndexedDB (سعة أكبر من localStorage).
///
/// كل مجموعة (collection) عبارة عن store من نوع `String -> Map`.
/// القيم يجب أن تكون JSON-compatible (نستخدم toJson في الموديلات).
library glowara.db;

import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.html) 'db_factory_web.dart';

class LocalDatabase {
  LocalDatabase(this._db);

  final Database _db;

  /// المجموعات المعروفة (تُستخدم في التصدير والمسح).
  static const List<String> collections = <String>[
    'tasks',
    'habits',
    'habitLogs',
    'worship',
    'readingLogs',
    'moods',
    'journals',
    'subjects',
    'units',
    'sessions',
    'careSteps',
    'careLogs',
    'water',
    'meals',
    'decks',
    'cards',
    'lessons',
    'quizAttempts',
    'goals',
    'profiles',
    'sync',
    'users',
  ];

  /// مفاتيح إعدادات لا تُصدَّر (بيانات حساسة).
  static const Set<String> privateSettingKeys = <String>{
    'current_user',
    'pin_hash',
    'pin_salt',
  };

  static Future<LocalDatabase> open() async {
    final db = await openGlowaraDatabase();
    return LocalDatabase(db);
  }

  StoreRef<String, Map<String, Object?>> _store(String name) =>
      stringMapStoreFactory.store(name);

  StoreRef<String, Map<String, Object?>> get _settings =>
      stringMapStoreFactory.store('settings');

  // ---------------------------------------------------------------------------
  // CRUD أساسي
  // ---------------------------------------------------------------------------

  Future<List<T>> list<T>(
    String collection,
    T Function(Map<String, Object?>) fromJson, {
    Filter? filter,
    List<SortOrder>? sortOrders,
    int? limit,
  }) async {
    final snapshots = await _store(collection).find(
      _db,
      finder: Finder(filter: filter, sortOrders: sortOrders, limit: limit),
    );
    return snapshots.map((s) => fromJson(s.value)).toList();
  }

  Future<T?> byId<T>(
    String collection,
    String id,
    T Function(Map<String, Object?>) fromJson,
  ) async {
    final value = await _store(collection).record(id).get(_db);
    return value == null ? null : fromJson(value);
  }

  Future<void> put(String collection, String id, Map<String, dynamic> value) async {
    // نمرّر القيمة عبر JSON لضمان توافق الأنواع مع sembast.
    final safe = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
    await _store(collection)
        .record(id)
        .put(_db, Map<String, Object?>.from(safe));
  }

  Future<void> delete(String collection, String id) async {
    await _store(collection).record(id).delete(_db);
  }

  Future<void> clearCollection(String collection) async {
    await _store(collection).delete(_db);
  }

  Future<int> count(String collection, {Filter? filter}) async {
    return _store(collection).count(_db, filter: filter);
  }

  // ---------------------------------------------------------------------------
  // الإعدادات
  // ---------------------------------------------------------------------------

  Future<Object?> getSetting(String key) async {
    final value = await _settings.record(key).get(_db);
    return value?['value'];
  }

  Future<void> setSetting(String key, Object? value) async {
    if (value == null) {
      await _settings.record(key).delete(_db);
      return;
    }
    final safe = jsonDecode(jsonEncode(value));
    await _settings.record(key).put(_db, <String, Object?>{'value': safe});
  }

  // ---------------------------------------------------------------------------
  // التصدير والاستيراد
  // ---------------------------------------------------------------------------

  /// تصدير كل البيانات (دون كلمات المرور أو مفاتيح الخصوصية).
  Future<Map<String, dynamic>> exportAll() async {
    final output = <String, dynamic>{
      'app': 'glowara',
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    for (final name in collections) {
      if (name == 'users') continue; // لا تُصدَّر كلمات المرور أو الحسابات.
      final snapshots = await _store(name).find(_db);
      final records = <String, dynamic>{};
      for (final s in snapshots) {
        records[s.key] = s.value;
      }
      output[name] = records;
    }
    final settingsSnapshots = await _settings.find(_db);
    final settings = <String, dynamic>{};
    for (final s in settingsSnapshots) {
      if (privateSettingKeys.contains(s.key)) continue;
      settings[s.key] = s.value['value'];
    }
    output['settings'] = settings;
    return output;
  }

  /// استيراد بيانات (دمج افتراضيًا، دون مسح الموجود).
  ///
  /// إذا مُرّر [targetUserId] تُعاد بيانات كل السجلات إلى هذا المستخدم،
  /// حتى تعمل الاستعادة على جهاز/حساب جديدين. تُعاد أيضًا مفاتيح
  /// السجلات المركّبة (الماء/المزاج/الملف الشخصي) لأنها تحتوي userId.
  Future<int> importAll(
    Map<String, dynamic> data, {
    bool merge = true,
    String? targetUserId,
  }) async {
    var imported = 0;
    for (final name in collections) {
      if (name == 'users') continue; // لا نستورد حسابات/كلمات مرور.
      final raw = data[name];
      if (raw is! Map) continue;
      if (!merge) await _store(name).delete(_db);
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final safe = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
        var recordKey = entry.key.toString();
        if (targetUserId != null) {
          final oldId = (safe['id'] ?? recordKey).toString();
          safe['userId'] = targetUserId;
          if (name == 'water' || name == 'moods') {
            // المعرّف القديم: <userId>_<YYYY-MM-DD>، وuserId نفسه يحتوي _.
            final split = oldId.lastIndexOf('_');
            final datePart = split >= 0 ? oldId.substring(split + 1) : oldId;
            recordKey = '${targetUserId}_$datePart';
            safe['id'] = recordKey;
          } else if (name == 'profiles') {
            recordKey = 'profile_$targetUserId';
            safe['id'] = recordKey;
          }
        }
        await _store(name)
            .record(recordKey)
            .put(_db, Map<String, Object?>.from(safe));
        imported++;
      }
    }
    final settings = data['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        if (privateSettingKeys.contains(entry.key.toString())) continue;
        await setSetting(entry.key.toString(), entry.value);
      }
    }
    return imported;
  }

  /// حجم البيانات التقريبي بالبايت (للشفافية وإدارة التخزين).
  Future<int> estimatedSizeBytes() async {
    final data = await exportAll();
    return utf8.encode(jsonEncode(data)).length;
  }

  /// مسح كل البيانات (يُستخدم في "حذف كل البيانات").
  Future<void> clearAll() async {
    for (final name in collections) {
      await _store(name).delete(_db);
    }
    await _settings.delete(_db);
  }
}
