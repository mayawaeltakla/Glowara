/// مستودع تقدّم الأكاديمية. لا يخزّن محتوى المنهج، فهو مضمّن في التطبيق.
///
/// يكتب فقط سجلات `academyProgress`، وعند طلب المستخدمة صراحةً طقم بطاقات جديدًا
/// (`decks` و`cards`). لا يعدّل بطاقاتها ولا دروسها الحالية أبدًا.
library glowara.repositories.academy;

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/academy_models.dart';
import 'package:glowara/core/models/feature_models.dart';

class AcademyRepository {
  AcademyRepository(this._db);

  final LocalDatabase _db;

  static const String _store = 'academyProgress';

  /// تقدّم هذه المستخدمة في كل وحدة (وحدة -> تقدّم). عند تكرار (بعد استيراد)
  /// يُؤخذ الأحدث تعديلًا.
  Future<Map<String, AcademyProgress>> all(String userId) async {
    final list = await _db.list(
      _store,
      AcademyProgress.fromJson,
      filter: Filter.equals('userId', userId),
    );
    final byUnit = <String, AcademyProgress>{};
    for (final p in list) {
      final existing = byUnit[p.unitId];
      if (existing == null || p.updatedAt.isAfter(existing.updatedAt)) byUnit[p.unitId] = p;
    }
    return byUnit;
  }

  Future<AcademyProgress?> forUnit(String userId, String unitId) async {
    return (await all(userId))[unitId];
  }

  AcademyProgress _blank(String userId, String unitId, DateTime now) => AcademyProgress(
        id: AcademyProgress.idFor(userId, unitId),
        userId: userId,
        unitId: unitId,
        updatedAt: now,
      );

  Future<AcademyProgress> _save(AcademyProgress p) async {
    await _db.put(_store, p.id, p.toJson());
    return p;
  }

  /// تعلّم أنها درست درس الوحدة (بطلبها). لا يُسحب لاحقًا.
  Future<AcademyProgress> markStudied(String userId, String unitId, {DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    final current = await forUnit(userId, unitId) ?? _blank(userId, unitId, stamp);
    if (current.studied) return current;
    return _save(current.copyWith(studiedAt: stamp, updatedAt: stamp));
  }

  /// يسجّل نتيجة تمرين: [results] من معرّف السؤال إلى صحيح/خطأ. الخطأ يُضاف
  /// إلى قائمة المراجعة، والصواب يُزيل السؤال منها. لا تُخزَّن درجات.
  Future<AcademyProgress> recordPractice({
    required String userId,
    required String unitId,
    required Map<String, bool> results,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final current = await forUnit(userId, unitId) ?? _blank(userId, unitId, stamp);
    final missed = <String>{...current.missed};
    results.forEach((String questionId, bool correct) {
      if (correct) {
        missed.remove(questionId);
      } else {
        missed.add(questionId);
      }
    });
    return _save(current.copyWith(
      practicedAt: stamp,
      missed: missed.toList()..sort(),
      updatedAt: stamp,
    ));
  }

  /// يضيف مفردات [unit] إلى بطاقاتها كطقم جديد، **بطلبها فقط**. إن كان الطقم
  /// مضافًا من قبل (ما زال موجودًا) لا يكرّره ويعيد 0. لا يمسّ أي بطاقة موجودة.
  /// يعيد عدد البطاقات المضافة.
  Future<int> addVocabularyToCards({
    required String userId,
    required AcademyUnit unit,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final deckId = 'academy_${userId}_${unit.id}';
    final existing = await _db.byId('decks', deckId, WordDeck.fromJson);
    if (existing != null) return 0;

    await _db.put(
      'decks',
      deckId,
      WordDeck(
        id: deckId,
        userId: userId,
        name: 'English ${unit.level} — ${unit.titleEn}',
        language: 'English',
        createdAt: stamp,
      ).toJson(),
    );
    var index = 0;
    for (final word in unit.vocab) {
      index++;
      final cardId = '${deckId}_$index';
      await _db.put(
        'cards',
        cardId,
        WordCard(
          id: cardId,
          deckId: deckId,
          term: word.en,
          meaning: word.ar,
          example: word.exEn,
          createdAt: stamp,
        ).toJson(),
      );
    }
    return unit.vocab.length;
  }
}
