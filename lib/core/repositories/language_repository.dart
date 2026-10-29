/// مستودع تعلم اللغة: الملف، المجموعات، البطاقات، الدروس، الاختبارات.
library glowara.repositories.language;

import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/models/feature_models.dart';
import 'package:glowara/core/utils/date_utils.dart';

/// سؤال اختياري مولّد من بطاقات المجموعة (محتوى المستخدمة، لا محتوى خارجي).
class QuizItem {
  const QuizItem({required this.card, required this.options, required this.correctIndex});
  final WordCard card;
  final List<String> options;
  final int correctIndex;
}

class VocabularyStats {
  const VocabularyStats({required this.mastered, required this.total});
  final int mastered;
  final int total;
}

class LanguageRepository {
  LanguageRepository(this._db);

  final LocalDatabase _db;
  static const String _decks = 'decks';
  static const String _cards = 'cards';
  static const String _lessons = 'lessons';
  static const String _attempts = 'quizAttempts';

  String _profileId(String userId) => 'profile_$userId';

  Future<LanguageProfile> profile(String userId) async {
    final existing = await _db.byId('profiles', _profileId(userId), LanguageProfile.fromJson);
    if (existing != null) return existing;
    final profile = LanguageProfile(
      id: _profileId(userId),
      userId: userId,
      createdAt: DateTime.now(),
    );
    await _db.put('profiles', profile.id, profile.toJson());
    return profile;
  }

  Future<void> saveProfile(LanguageProfile profile) =>
      _db.put('profiles', profile.id, profile.toJson());

  // ---- المجموعات ----
  Future<List<WordDeck>> decks(String userId) async {
    final list = await _db.list(
      _decks,
      WordDeck.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
    return list;
  }

  Future<void> saveDeck(WordDeck deck) => _db.put(_decks, deck.id, deck.toJson());

  Future<void> deleteDeck(String id) async {
    final cards = await this.cards(id);
    for (final card in cards) {
      await _db.delete(_cards, card.id);
    }
    await _db.delete(_decks, id);
  }

  // ---- البطاقات ----
  Future<List<WordCard>> cards(String deckId) async {
    return _db.list(
      _cards,
      WordCard.fromJson,
      filter: Filter.equals('deckId', deckId),
      sortOrders: <SortOrder>[SortOrder('createdAt')],
    );
  }

  Future<void> saveCard(WordCard card) => _db.put(_cards, card.id, card.toJson());

  Future<void> deleteCard(String id) => _db.delete(_cards, id);

  Future<VocabularyStats> vocabularyStats(String userId) async {
    final deckList = await decks(userId);
    var mastered = 0;
    var total = 0;
    for (final deck in deckList) {
      final list = await cards(deck.id);
      total += list.length;
      mastered += list.where((c) => c.isMastered).length;
    }
    return VocabularyStats(mastered: mastered, total: total);
  }

  /// بطاقات أخطأت فيها المستخدمة (للمراجعة).
  Future<List<WordCard>> wrongCards(String userId, {String? deckId}) async {
    final deckList = await decks(userId);
    final result = <WordCard>[];
    for (final deck in deckList) {
      if (deckId != null && deck.id != deckId) continue;
      final list = await cards(deck.id);
      result.addAll(list.where((c) => c.wrongCount > 0 && !c.isMastered));
    }
    return result;
  }

  // ---- الدروس ----
  Future<List<LanguageLesson>> lessons(String userId) async {
    final list = await _db.list(
      _lessons,
      LanguageLesson.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('order')],
    );
    return list;
  }

  Future<void> saveLesson(LanguageLesson lesson) =>
      _db.put(_lessons, lesson.id, lesson.toJson());

  Future<void> deleteLesson(String id) => _db.delete(_lessons, id);

  Future<void> setLessonCompleted(LanguageLesson lesson, bool completed) async {
    await saveLesson(
      lesson.copyWith(
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
      ),
    );
  }

  // ---- الاختبارات ----
  Future<List<QuizAttempt>> attempts(String userId, {DateTime? from}) async {
    final list = await _db.list(
      _attempts,
      QuizAttempt.fromJson,
      filter: Filter.equals('userId', userId),
      sortOrders: <SortOrder>[SortOrder('createdAt', false)],
    );
    if (from == null) return list;
    return list.where((a) => !a.createdAt.isBefore(from)).toList();
  }

  Future<int> weeklyAttempts(String userId) async {
    final from = DateTime.now().subtract(const Duration(days: 7));
    return (await attempts(userId, from: from)).length;
  }

  /// بناء اختبار من بطاقات مجموعة (على الأقل بطاقتان ليكون للخيارات معنى).
  Future<List<QuizItem>> buildQuiz(String deckId, {int count = 10}) async {
    final list = await cards(deckId);
    if (list.length < 2) return <QuizItem>[];
    final random = Random();
    final pool = List<WordCard>.from(list)..shuffle(random);
    final selected = pool.take(count).toList();
    final meanings = list.map((c) => c.meaning).toSet().toList();
    final items = <QuizItem>[];
    for (final card in selected) {
      final distractors = meanings.where((m) => m != card.meaning).toList()..shuffle(random);
      final options = <String>[card.meaning, ...distractors.take(3)]..shuffle(random);
      items.add(QuizItem(
        card: card,
        options: options,
        correctIndex: options.indexOf(card.meaning),
      ));
    }
    return items;
  }

  Future<void> recordAnswer({
    required String userId,
    required WordCard card,
    required bool correct,
  }) async {
    final updated = card.copyWith(
      correctCount: card.correctCount + (correct ? 1 : 0),
      wrongCount: card.wrongCount + (correct ? 0 : 1),
      // لا تُلغى الإتقانة بسبب خطأ لاحق؛ المراجعة تبقى متاحة عبر wrongCount.
      isMastered: card.isMastered || (correct && (card.correctCount + 1) >= 3),
      lastReviewedAt: DateTime.now(),
    );
    await saveCard(updated);
    final attempt = QuizAttempt(
      id: uniqueId(),
      userId: userId,
      cardId: card.id,
      isCorrect: correct,
      createdAt: DateTime.now(),
    );
    await _db.put(_attempts, attempt.id, attempt.toJson());
  }

  /// عدد الدروس المكتملة.
  Future<int> completedLessons(String userId) async {
    final list = await lessons(userId);
    return list.where((l) => l.isCompleted).length;
  }

  /// أيام النشاط التعليمي (محاولات) ضمن نطاق.
  Future<int> activeDays(String userId, DateTime from, DateTime to) async {
    final list = await attempts(userId, from: from);
    return list
        .where((a) => !a.createdAt.isAfter(to))
        .map((a) => dateKey(a.createdAt))
        .toSet()
        .length;
  }
}
