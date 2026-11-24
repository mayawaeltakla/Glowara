/// مستودع «أحلامي». يكتب سجلات `dreams` وحدها (الخطوات داخل سجل الحلم).
/// لا ينشئ مهامًا ولا تذكيرات ولا يغذّي ميزة أخرى.
library glowara.repositories.dream;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/dream_models.dart';

class DreamRepository {
  DreamRepository(this._db);

  final LocalDatabase _db;

  static const String _store = 'dreams';

  Future<List<Dream>> all(String userId) async {
    final list = await _db.list(_store, Dream.fromJson, filter: Filter.equals('userId', userId));
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<Dream?> byId(String userId, String id) async {
    final d = await _db.byId(_store, id, Dream.fromJson);
    return d != null && d.userId == userId ? d : null;
  }

  String _cut(String s, int max) {
    final t = s.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  /// يحفظ حلمًا (جديدًا إن كان [id] فارغًا). العنوان مطلوب. الوصول إلى «تحقق»
  /// يضع تاريخ التحقق مرة، والرجوع منه يمسحه. الخطوات تبقى كما هي.
  Future<Dream> save({
    required String userId,
    String? id,
    required String title,
    String wish = '',
    String stage = 'dreaming',
    String? targetDate,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final cleanTitle = _cut(title, kDreamTitleMax);
    if (cleanTitle.isEmpty) throw StateError('empty title');
    final existing = id == null ? null : await byId(userId, id);
    if (existing == null && (await all(userId)).length >= kMaxDreams) throw StateError('too many dreams');
    final st = kDreamStages.contains(stage) ? stage : 'dreaming';
    final target = targetDate != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(targetDate) ? targetDate : null;
    final dream = Dream(
      id: existing?.id ?? uniqueId(),
      userId: userId,
      title: cleanTitle,
      wish: _cut(wish, kDreamWishMax),
      stage: st,
      targetDate: target,
      steps: existing?.steps ?? const <DreamStep>[],
      achievedAt: st == 'achieved' ? (existing?.achievedAt ?? stamp) : null,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );
    await _db.put(_store, dream.id, dream.toJson());
    return dream;
  }

  Future<void> delete(String userId, String id) async {
    if (await byId(userId, id) != null) await _db.delete(_store, id);
  }

  Future<Dream> _require(String userId, String id) async {
    final d = await byId(userId, id);
    if (d == null) throw StateError('no such dream');
    return d;
  }

  Future<Dream> _put(Dream d) async {
    await _db.put(_store, d.id, d.toJson());
    return d;
  }

  Future<Dream> addStep({required String userId, required String dreamId, required String text, DateTime? now}) async {
    final d = await _require(userId, dreamId);
    final clean = _cut(text, kDreamStepMax);
    if (clean.isEmpty) throw StateError('empty step');
    if (d.steps.length >= kDreamMaxSteps) throw StateError('too many steps');
    return _put(d.copyWith(
      steps: <DreamStep>[...d.steps, DreamStep(id: uniqueId(), text: clean)],
      updatedAt: now ?? DateTime.now(),
    ));
  }

  Future<Dream> setStepDone({
    required String userId,
    required String dreamId,
    required String stepId,
    required bool done,
    DateTime? now,
  }) async {
    final d = await _require(userId, dreamId);
    return _put(d.copyWith(
      steps: <DreamStep>[for (final s in d.steps) s.id == stepId ? s.copyWith(done: done) : s],
      updatedAt: now ?? DateTime.now(),
    ));
  }

  Future<Dream> deleteStep({required String userId, required String dreamId, required String stepId}) async {
    final d = await _require(userId, dreamId);
    return _put(d.copyWith(steps: d.steps.where((s) => s.id != stepId).toList(), updatedAt: DateTime.now()));
  }
}
