/// قاعدة بيانات Glowara المحلية (sembast).
///
/// - على Android: ملف `glowara.db` في مجلد المستندات.
/// - على الويب: IndexedDB (سعة أكبر من localStorage).
///
/// كل مجموعة (collection) عبارة عن store من نوع `String -> Map`.
/// القيم يجب أن تكون JSON-compatible (نستخدم toJson في الموديلات).
///
/// عمليات الكتابة المتعددة (الاستيراد، المسح، حذف مستخدم) تتم داخل معاملة
/// واحدة (transaction): إما أن تكتمل كلها أو لا يتغير شيء.
library glowara.db;

import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'collection_registry.dart';
import 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.html) 'db_factory_web.dart';

class LocalDatabase {
  LocalDatabase(this._db);

  final Database _db;

  /// المجموعات المعروفة (تُستخدم في التصدير والمسح). تُشتق من السجل المركزي
  /// [CollectionRegistry] فلا تُحدَّث قائمة يدوية أخرى.
  static final List<String> collections = CollectionRegistry.names;

  /// مفاتيح إعدادات لا تُصدَّر ولا تُستورد (بيانات حساسة أو حالة أمنية).
  static const Set<String> privateSettingKeys = <String>{
    'current_user',
    'pin_hash',
    'pin_salt',
    'pin_version',
    'pin_iterations',
    'pin_failed',
    'pin_locked_until',
  };

  /// بادئات مفاتيح إعدادات لا تُصدَّر لأنها نسخ مؤقتة قابلة لإعادة الجلب
  /// (مثل كاش سور القرآن) وتُضخّم النسخة الاحتياطية دون فائدة.
  static const List<String> nonExportedSettingPrefixes = <String>[
    'quran_cache_',
    // حالة واجهة على الجهاز (إخفاء بطاقة المراجعة الأسبوعية)، لا تُنقل.
    'weekly_reset_hidden_',
  ];

  /// هل يُسمح بتصدير/استيراد هذا المفتاح؟
  static bool isExportableSetting(String key) {
    if (privateSettingKeys.contains(key)) return false;
    for (final prefix in nonExportedSettingPrefixes) {
      if (key.startsWith(prefix)) return false;
    }
    return true;
  }

  static Future<LocalDatabase> open() async {
    final db = await openGlowaraDatabase();
    return LocalDatabase(db);
  }

  StoreRef<String, Map<String, Object?>> _store(String name) {
    // في الاختبارات وبناءات التطوير فقط: مجموعة غير مسجَّلة تعني أنها ستسقط
    // من التصدير والحذف دون تنبيه، فنفشل مبكرًا.
    assert(
      CollectionRegistry.isRegistered(name),
      'Collection "$name" is not registered in CollectionRegistry '
      '(see docs/ADDING_A_COLLECTION.md)',
    );
    return stringMapStoreFactory.store(name);
  }

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

  Future<void> setSetting(String key, Object? value) => _writeSetting(_db, key, value);

  Future<void> _writeSetting(DatabaseClient client, String key, Object? value) async {
    if (value == null) {
      await _settings.record(key).delete(client);
      return;
    }
    final safe = jsonDecode(jsonEncode(value));
    await _settings.record(key).put(client, <String, Object?>{'value': safe});
  }

  // ---------------------------------------------------------------------------
  // التصدير والاستيراد
  // ---------------------------------------------------------------------------

  /// تصدير البيانات (دون كلمات المرور أو مفاتيح الخصوصية أو الكاش المؤقت).
  ///
  /// بدون [onlyUserId] تُصدَّر بيانات **كل الحسابات** على الجهاز (نطاق
  /// `device`). مع [onlyUserId] تُصدَّر بيانات ذلك الحساب فقط (نطاق `account`)،
  /// وهو ما يستعمله التطبيق افتراضيًا. الصيغة والـschemaVersion لم تتغيّرا؛
  /// حقل `scope` إضافي تتجاهله النسخ القديمة.
  Future<Map<String, dynamic>> exportAll({String? onlyUserId}) async {
    final output = <String, dynamic>{
      'app': 'glowara',
      'schemaVersion': 2,
      'scope': onlyUserId == null ? 'device' : 'account',
      // مصدر النسخة: يستعمله الاستيراد لمعرفة هل تعود النسخة إلى الحساب نفسه.
      'source': <String, dynamic>{
        'kind': 'glowara-export',
        'accountId': onlyUserId,
      },
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final owned = onlyUserId == null ? null : await _ownedKeys(_db, onlyUserId);
    for (final name in collections) {
      if (name == 'users') continue; // لا تُصدَّر كلمات المرور أو الحسابات.
      final snapshots = await _store(name).find(_db);
      final records = <String, dynamic>{};
      for (final s in snapshots) {
        if (owned != null && !owned.owns(name, s.key, s.value)) continue;
        records[s.key] = s.value;
      }
      output[name] = records;
    }
    final settingsSnapshots = await _settings.find(_db);
    final settings = <String, dynamic>{};
    for (final s in settingsSnapshots) {
      if (!isExportableSetting(s.key)) continue;
      settings[s.key] = s.value['value'];
    }
    output['settings'] = settings;
    return output;
  }

  /// استيراد بيانات (دمج افتراضيًا، دون مسح الموجود).
  ///
  /// يُتحقق من شكل الملف كاملًا قبل أي كتابة، ثم تُنفَّذ الكتابة داخل معاملة
  /// واحدة: عند أي فشل لا يتغير شيء (لا استيراد نصفي، ولا مسح دون استبدال).
  ///
  /// إذا مُرّر [targetUserId] تُعاد بيانات كل السجلات إلى هذا المستخدم،
  /// حتى تعمل الاستعادة على جهاز/حساب جديدين. تُعاد أيضًا مفاتيح
  /// السجلات المركّبة (الماء/المزاج/الملف الشخصي) لأنها تحتوي userId.
  ///
  /// **مصدر النسخة:** الملف الصادر من حساب معيّن يحمل `source.accountId`.
  /// إذا كان [targetUserId] يختلف عن مصدر الملف، أو كان المصدر غير معروف (ملف
  /// قديم أو تصدير كل الحسابات)، يُرفض الاستيراد بـ[ImportSourceMismatch] ولا
  /// يُكتب شيء، إلا إذا مُرّر [allowDifferentSource] بعد تأكيد صريح من المستخدمة.
  /// حتى بعد التأكيد لا يُكتب فوق سجلات حساب آخر.
  Future<int> importAll(
    Map<String, dynamic> data, {
    bool merge = true,
    String? targetUserId,
    bool allowDifferentSource = false,
  }) async {
    _validateImport(data);
    if (targetUserId != null && !allowDifferentSource) {
      final source = data['source'];
      final sourceId = source is Map ? source['accountId'] : null;
      if (sourceId is! String || sourceId != targetUserId || data['scope'] == 'device') {
        throw ImportSourceMismatch(sourceId is String ? sourceId : null);
      }
    }
    lastImportSkipped = 0;

    return _db.transaction<int>((txn) async {
      var imported = 0;
      var skipped = 0;
      for (final name in collections) {
        if (name == 'users') continue; // لا نستورد حسابات/كلمات مرور.
        final raw = data[name];
        if (raw is! Map) continue;
        if (!merge) {
          if (targetUserId == null) {
            await _store(name).delete(txn);
          } else {
            // مع حساب هدف لا نمسح إلا سجلاته، لا سجلات الحسابات الأخرى.
            final owned = await _ownedKeys(txn, targetUserId);
            final existing = await _store(name).find(txn);
            for (final s in existing) {
              if (owned.owns(name, s.key, s.value)) {
                await _store(name).record(s.key).delete(txn);
              }
            }
          }
        }
        for (final entry in raw.entries) {
          final value = entry.value;
          if (value is! Map) continue;
          final safe = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
          var recordKey = entry.key.toString();
          if (targetUserId != null) {
            final oldId = (safe['id'] ?? recordKey).toString();
            safe['userId'] = targetUserId;
            final shape = CollectionRegistry.byName(name).keyShape;
            if (shape == CollectionKeyShape.userDate || shape == CollectionKeyShape.userSuffix) {
              // المعرّف القديم: <userId>_<YYYY-MM-DD> أو <userId>_<suffix>، وuserId نفسه يحتوي _.
              final split = oldId.lastIndexOf('_');
              final datePart = split >= 0 ? oldId.substring(split + 1) : oldId;
              recordKey = '${targetUserId}_$datePart';
              safe['id'] = recordKey;
            } else if (shape == CollectionKeyShape.profile) {
              recordKey = 'profile_$targetUserId';
              safe['id'] = recordKey;
            }
          }
          if (targetUserId != null) {
            // لا نكتب فوق سجل يخص حسابًا آخر على الجهاز (مثلًا عند استيراد ملف
            // حساب آخر له المعرّفات نفسها): نتجاوزه بدل نقل ملكيته.
            final existing = await _store(name).record(recordKey).get(txn);
            final owner = existing?['userId'];
            if (existing != null && owner is String && owner != targetUserId) {
              skipped++;
              continue;
            }
          }
          await _store(name)
              .record(recordKey)
              .put(txn, Map<String, Object?>.from(safe));
          imported++;
        }
      }
      final settings = data['settings'];
      if (settings is Map) {
        for (final entry in settings.entries) {
          final key = entry.key.toString();
          if (!isExportableSetting(key)) continue;
          await _writeSetting(txn, key, entry.value);
        }
      }
      lastImportSkipped = skipped;
      return imported;
    });
  }

  /// عدد السجلات التي تجاوزها آخر استيراد لأنها تخص حسابًا آخر على الجهاز.
  int lastImportSkipped = 0;

  /// يتحقق من شكل ملف الاستيراد قبل لمس التخزين.
  static void _validateImport(Map<String, dynamic> data) {
    final app = data['app'];
    if (app != null && app != 'glowara') {
      throw const FormatException('This is not a Glowara backup');
    }
    final version = data['schemaVersion'];
    if (version != null && (version is! int || version > 2 || version < 1)) {
      throw const FormatException('Unsupported backup schema version');
    }
    for (final name in collections) {
      if (name == 'users') continue;
      final raw = data[name];
      if (raw == null) continue;
      if (raw is! Map) {
        throw FormatException('Collection "$name" must be an object');
      }
      for (final entry in raw.entries) {
        if (entry.value is! Map) {
          throw FormatException('Record "${entry.key}" in "$name" must be an object');
        }
      }
    }
    final settings = data['settings'];
    if (settings != null && settings is! Map) {
      throw const FormatException('"settings" must be an object');
    }
  }

  /// مفاتيح السجلات التابعة لحساب [userId]، بما فيها السجلات التي لا تحمل
  /// userId (سجلات العادات، وحدات الدراسة، بطاقات المفردات).
  Future<_Owned> _ownedKeys(DatabaseClient client, String userId) async {
    Future<Set<String>> keysOf(String name) async => (await _store(name).findKeys(
          client,
          finder: Finder(filter: Filter.equals('userId', userId)),
        ))
            .toSet();
    return _Owned(
      userId,
      habits: await keysOf('habits'),
      subjects: await keysOf('subjects'),
      decks: await keysOf('decks'),
    );
  }

  /// حجم البيانات التقريبي بالبايت (للشفافية وإدارة التخزين).
  Future<int> estimatedSizeBytes() async {
    final data = await exportAll();
    return utf8.encode(jsonEncode(data)).length;
  }

  // ---------------------------------------------------------------------------
  // الحذف
  // ---------------------------------------------------------------------------

  /// يحذف سجل مستخدم واحد وكل بياناته، دون المساس بالمستخدمين الآخرين
  /// ولا بالتفضيلات المشتركة. يشمل السجلات التابعة التي لا تحمل userId
  /// (سجلات العادات، وحدات الدراسة، بطاقات المفردات).
  Future<void> deleteUserData(String userId) async {
    await _db.transaction((txn) async {
      Future<List<String>> keysOf(String name) => _store(name).findKeys(
            txn,
            finder: Finder(filter: Filter.equals('userId', userId)),
          );

      final habitIds = await keysOf('habits');
      final subjectIds = await keysOf('subjects');
      final deckIds = await keysOf('decks');

      if (habitIds.isNotEmpty) {
        await _store('habitLogs').delete(
          txn,
          finder: Finder(filter: Filter.inList('habitId', habitIds)),
        );
      }
      if (subjectIds.isNotEmpty) {
        await _store('units').delete(
          txn,
          finder: Finder(filter: Filter.inList('subjectId', subjectIds)),
        );
      }
      if (deckIds.isNotEmpty) {
        await _store('cards').delete(
          txn,
          finder: Finder(filter: Filter.inList('deckId', deckIds)),
        );
      }

      // السجلات المركّبة (الماء/المزاج) مفتاحها يبدأ بـ <userId>_.
      final prefix = '${userId}_';
      for (final name in collections) {
        if (name == 'users') continue;
        await _store(name).delete(
          txn,
          finder: Finder(
            filter: Filter.or(<Filter>[
              Filter.equals('userId', userId),
              Filter.custom((record) => record.key.toString().startsWith(prefix)),
            ]),
          ),
        );
      }
      await _store('users').record(userId).delete(txn);
    });
  }

  /// مسح كل البيانات (يُستخدم في "حذف كل البيانات").
  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      for (final name in collections) {
        await _store(name).delete(txn);
      }
      await _settings.delete(txn);
    });
  }
}

/// يُرمى عند محاولة استعادة نسخة إلى حساب غير مصدرها، أو نسخة مصدرها مجهول.
/// يحمل [sourceAccountId] (null عندما يكون المصدر غير معروف).
class ImportSourceMismatch implements Exception {
  const ImportSourceMismatch(this.sourceAccountId);

  final String? sourceAccountId;

  bool get unknownSource => sourceAccountId == null;

  @override
  String toString() => 'ImportSourceMismatch(source: ${sourceAccountId ?? 'unknown'})';
}

/// يحدد ما إذا كان سجل ما يخص حسابًا معيّنًا.
class _Owned {
  _Owned(this.userId, {required this.habits, required this.subjects, required this.decks});

  final String userId;
  final Set<String> habits;
  final Set<String> subjects;
  final Set<String> decks;

  bool owns(String collection, String key, Map<String, Object?> value) {
    if (value['userId'] == userId) return true;
    if (key.startsWith('${userId}_')) return true; // ماء/مزاج مركّبة
    if (collection == 'profiles' && key == 'profile_$userId') return true;
    switch (collection) {
      case 'habitLogs':
        return habits.contains(value['habitId']);
      case 'units':
        return subjects.contains(value['subjectId']);
      case 'cards':
        return decks.contains(value['deckId']);
    }
    return false;
  }
}
