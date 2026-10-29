/// مستودع العبادات: سجلات القراءة والأذكار.
library glowara.repositories.worship;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class WorshipRepository {
  WorshipRepository(this._db);

  final LocalDatabase _db;
  static const String _readings = 'readingLogs';

  Future<void> saveReading(ReadingLog log) async {
    await _db.put(_readings, log.id, log.toJson());
  }

  Future<void> deleteReading(String id) => _db.delete(_readings, id);

  Future<List<ReadingLog>> readings({String? itemId, String? userId}) async {
    final list = await _db.list(
      _readings,
      ReadingLog.fromJson,
      filter: itemId == null ? null : Filter.equals('itemId', itemId),
      sortOrders: <SortOrder>[SortOrder('completedAt', false)],
    );
    if (userId == null) return list;
    // السجلات القديمة (قبل إضافة userId) تُعامل كبيانات المستخدم الحالي.
    return list.where((r) => r.userId.isEmpty || r.userId == userId).toList();
  }

  /// عدد الأيام التي سُجّلت فيها قراءة قرآن ضمن نطاق.
  Future<int> quranDays(DateTime from, DateTime to) async {
    final list = await readings();
    return list
        .where((r) =>
            r.itemId.startsWith('quran') &&
            inRange(r.completedAt, from, to))
        .map((r) => dateKey(r.completedAt))
        .toSet()
        .length;
  }
}
