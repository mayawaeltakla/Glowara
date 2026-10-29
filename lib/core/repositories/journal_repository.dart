/// مستودع المزاج والمذكرات (بيانات خاصة).
library glowara.repositories.journal;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

class JournalRepository {
  JournalRepository(this._db);

  final LocalDatabase _db;
  static const String _moods = 'moods';
  static const String _journals = 'journals';

  String _moodId(String userId, String date) => '${userId}_$date';

  Future<MoodEntry?> moodFor(String userId, DateTime day) =>
      _db.byId(_moods, _moodId(userId, dateKey(day)), MoodEntry.fromJson);

  Future<List<MoodEntry>> moods(String userId, {DateTime? from, DateTime? to}) async {
    final list = await _db.list(
      _moods,
      MoodEntry.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('date')],
    );
    if (from == null && to == null) return list;
    final fromKey = from == null ? '0000-00-00' : dateKey(from);
    final toKey = to == null ? '9999-99-99' : dateKey(to);
    return list.where((m) => m.date.compareTo(fromKey) >= 0 && m.date.compareTo(toKey) <= 0).toList();
  }

  Future<void> saveMood({
    required String userId,
    required DateTime day,
    required int value,
    String? note,
  }) async {
    final id = _moodId(userId, dateKey(day));
    final existing = await _db.byId(_moods, id, MoodEntry.fromJson);
    final entry = MoodEntry(
      id: id,
      userId: userId,
      date: dateKey(day),
      value: value.clamp(1, 5).toInt(),
      note: note,
      createdAt: existing?.createdAt ?? DateTime.now(),
      syncStatus: SyncStatus.local,
      lastModified: DateTime.now(),
    );
    await _db.put(_moods, id, entry.toJson());
  }

  Future<void> deleteMood(String userId, DateTime day) =>
      _db.delete(_moods, _moodId(userId, dateKey(day)));

  Future<List<JournalEntry>> journals(String userId, {String query = ''}) async {
    final list = await _db.list(
      _journals,
      JournalEntry.fromJson,
      filter: Filter.equals('userId', userId),
    );
    list.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase();
    return list
        .where((j) => j.title.toLowerCase().contains(q) || j.content.toLowerCase().contains(q))
        .toList();
  }

  Future<void> saveJournal(JournalEntry entry) async {
    final now = DateTime.now();
    await _db.put(_journals, entry.id, entry.copyWith(
      updatedAt: now,
      lastModified: now,
      content: entry.content,
      title: entry.title,
    ).toJson());
  }

  Future<void> deleteJournal(String id) => _db.delete(_journals, id);
}
