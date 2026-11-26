/// مستودع «ركني الصغير». يكتب سجلات `corner` وحدها. لا يقرأ ميزة أخرى ولا يُنشئ
/// تنبيهات.
library glowara.repositories.corner;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/repositories/image_repository.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/corner_models.dart';

class CornerRepository {
  CornerRepository(this._db);

  final LocalDatabase _db;

  static const String _store = 'corner';

  Future<List<CornerEntry>> all(String userId) async {
    final list = await _db.list(_store, CornerEntry.fromJson, filter: Filter.equals('userId', userId));
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<CornerEntry?> byId(String userId, String id) async {
    final e = await _db.byId(_store, id, CornerEntry.fromJson);
    return e != null && e.userId == userId ? e : null;
  }

  String _cut(String s, int max) {
    final t = s.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  /// يحفظ مدخلًا (جديدًا إن كان [id] فارغًا). النص مطلوب. تاريخ فتح غير صالح يُهمل.
  Future<CornerEntry> save({
    required String userId,
    String? id,
    required String kind,
    String title = '',
    required String text,
    String? openOn,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final cleanText = _cut(text, kCornerTextMax);
    if (cleanText.isEmpty) throw StateError('empty text');
    final existing = id == null ? null : await byId(userId, id);
    if (existing == null && (await all(userId)).length >= kCornerMaxEntries) throw StateError('too many entries');
    final entry = CornerEntry(
      id: existing?.id ?? uniqueId(),
      userId: userId,
      kind: kCornerKinds.contains(kind) ? kind : 'letter',
      title: _cut(title, kCornerTitleMax),
      text: cleanText,
      openOn: isValidCornerDate(openOn) ? openOn : null,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );
    await _db.put(_store, entry.id, entry.toJson());
    return entry;
  }

  Future<void> delete(String userId, String id) async {
    if (await byId(userId, id) != null) {
      await _db.delete(_store, id);
      await ImageRepository(_db).remove(userId, id);
    }
  }
}
