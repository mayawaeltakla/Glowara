// اختبار سلوكي دائم لكل مجموعة بيانات مسجَّلة في CollectionRegistry.
//
// لكل مجموعة، ببيانات حسابين A وB على الجهاز نفسه:
//   * تصدير A لا يحمل بيانات B.
//   * تصدير الجهاز يحمل الحسابين.
//   * استيراد تصدير A في قاعدة فارغة يعيد بيانات A وحدها.
//   * حذف A لا يحذف بيانات B.
//
// مجموعة جديدة تُسجَّل في السجل فتدخل هذه الاختبارات تلقائيًا. إن لم تنجح
// في أي منها فهي لا تُصدَّر أو لا تُحذف أو لا تُعزل كما يجب.
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/collection_registry.dart';
import 'package:glowara/core/db/local_database.dart';

import 'support/test_db.dart';

const String _a = 'ua';
const String _b = 'ub';

String _keyFor(CollectionSpec spec, String user) {
  switch (spec.keyShape) {
    case CollectionKeyShape.userDate:
      return '${user}_2026-11-01';
    case CollectionKeyShape.profile:
      return 'profile_$user';
    case CollectionKeyShape.plain:
      return '${spec.name}_$user';
  }
}

String _legacyKey(CollectionSpec spec) => 'legacy_${spec.name}';

Future<void> _seed(LocalDatabase db, String user) async {
  for (final spec in CollectionRegistry.specs) {
    final key = _keyFor(spec, user);
    switch (spec.ownership) {
      case CollectionOwnership.userId:
        await db.put(spec.name, key, <String, dynamic>{'id': key, 'userId': user});
      case CollectionOwnership.parent:
        await db.put(spec.name, key, <String, dynamic>{
          'id': key,
          spec.parentField!: _keyFor(CollectionRegistry.byName(spec.parent!), user),
        });
      case CollectionOwnership.account:
        await db.put(spec.name, user, <String, dynamic>{'id': user, 'email': '$user@example.com'});
      case CollectionOwnership.none:
        await db.put(spec.name, key, <String, dynamic>{'id': key, 'shared': user});
    }
  }
}

Future<void> _seedLegacyOwnerless(LocalDatabase db) async {
  for (final spec in CollectionRegistry.specs.where((s) => s.legacyOwnerless)) {
    final key = _legacyKey(spec);
    await db.put(spec.name, key, <String, dynamic>{'id': key, 'userId': ''});
  }
}

Set<String> _keys(Map<String, dynamic> export, String name) {
  final raw = export[name];
  return raw is Map ? raw.keys.map((k) => k.toString()).toSet() : <String>{};
}

void main() {
  group('registry consistency', () {
    test('names are unique', () {
      expect(CollectionRegistry.names.toSet().length, CollectionRegistry.names.length);
    });

    test('LocalDatabase.collections is the registry', () {
      expect(LocalDatabase.collections, CollectionRegistry.names);
    });

    test('parent-owned collections point to a plain, user-owned parent', () {
      for (final spec in CollectionRegistry.specs) {
        if (spec.ownership != CollectionOwnership.parent) continue;
        final parent = CollectionRegistry.byName(spec.parent!);
        expect(parent.ownership, CollectionOwnership.userId, reason: '${spec.name} parent');
        expect(parent.keyShape, CollectionKeyShape.plain, reason: '${spec.name} parent');
      }
    });

    test('only users is an account collection', () {
      final accounts = CollectionRegistry.specs
          .where((s) => s.ownership == CollectionOwnership.account)
          .map((s) => s.name);
      expect(accounts, <String>['users']);
    });

    test('every ownerless exception is documented with a note', () {
      for (final spec in CollectionRegistry.specs) {
        if (spec.ownership == CollectionOwnership.none || spec.legacyOwnerless) {
          expect(spec.note, isNotNull, reason: '${spec.name} needs an explanation');
        }
      }
    });
  });

  for (final spec in CollectionRegistry.specs) {
    group('collection ${spec.name} (${spec.ownership.name})', () {
      late LocalDatabase db;

      setUp(() async {
        db = await openTestDatabase();
        await _seed(db, _a);
        await _seed(db, _b);
        await _seedLegacyOwnerless(db);
      });

      test('account export holds only that account', () async {
        final data = await db.exportAll(onlyUserId: _a);
        final keys = _keys(data, spec.name);
        switch (spec.ownership) {
          case CollectionOwnership.userId:
          case CollectionOwnership.parent:
            expect(keys, contains(_keyFor(spec, _a)));
            expect(keys, isNot(contains(_keyFor(spec, _b))));
          case CollectionOwnership.account:
            expect(data.containsKey(spec.name), isFalse);
          case CollectionOwnership.none:
            expect(keys, isEmpty);
        }
        if (spec.legacyOwnerless) {
          expect(keys, isNot(contains(_legacyKey(spec))),
              reason: 'ownerless legacy records are never exported with an account');
        }
      });

      test('device export holds every account', () async {
        final data = await db.exportAll();
        if (spec.ownership == CollectionOwnership.account) {
          expect(data.containsKey(spec.name), isFalse);
          return;
        }
        final keys = _keys(data, spec.name);
        expect(keys, contains(_keyFor(spec, _a)));
        expect(keys, contains(_keyFor(spec, _b)));
      });

      test('restoring the account export into an empty database brings back only it', () async {
        final export = await db.exportAll(onlyUserId: _a);
        final fresh = await openTestDatabase();
        await fresh.importAll(export, targetUserId: _a);

        final restored = await fresh.exportAll();
        final keys = _keys(restored, spec.name);
        switch (spec.ownership) {
          case CollectionOwnership.userId:
          case CollectionOwnership.parent:
            expect(keys, contains(_keyFor(spec, _a)));
            expect(keys, isNot(contains(_keyFor(spec, _b))));
          case CollectionOwnership.account:
            expect(await fresh.byId(spec.name, _a, (m) => m), isNull,
                reason: 'accounts are never imported');
          case CollectionOwnership.none:
            expect(keys, isEmpty);
        }
        if (spec.legacyOwnerless) {
          expect(keys, isNot(contains(_legacyKey(spec))));
        }
      });

      test('deleting an account keeps the other account untouched', () async {
        await db.deleteUserData(_a);

        switch (spec.ownership) {
          case CollectionOwnership.userId:
          case CollectionOwnership.parent:
            {
              final keys = _keys(await db.exportAll(), spec.name);
              expect(keys, isNot(contains(_keyFor(spec, _a))));
              expect(keys, contains(_keyFor(spec, _b)));
            }
          case CollectionOwnership.account:
            expect(await db.byId(spec.name, _a, (m) => m), isNull);
            expect(await db.byId(spec.name, _b, (m) => m), isNotNull);
          case CollectionOwnership.none:
            {
              final keys = _keys(await db.exportAll(), spec.name);
              expect(keys, contains(_keyFor(spec, _a)),
                  reason: 'ownerless shared data is not deleted with an account');
              expect(keys, contains(_keyFor(spec, _b)));
            }
        }
        if (spec.legacyOwnerless) {
          expect(_keys(await db.exportAll(), spec.name), contains(_legacyKey(spec)),
              reason: 'ownerless legacy records are never deleted automatically');
        }
      });
    });
  }
}
