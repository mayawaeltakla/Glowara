/// نماذج الأقسام الوظيفية: الدراسة، العناية، الصحة، اللغة، الأهداف الشهرية.
///
/// كل النماذج immutable وتُسلسل إلى JSON قابلة للتخزين في sembast.
library glowara.feature_models;

import 'dart:convert';
import 'package:glowara/core/models/app_models.dart';

String _toIso(DateTime? d) => d?.toUtc().toIso8601String() ?? '';
DateTime? _fromIso(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  try {
    return DateTime.parse(v).toLocal();
  } catch (_) {
    return null;
  }
}

List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const <String>[];
}

// =============================================================================
// العناية بالنفس والبشرة
// =============================================================================

/// خطوة داخل روتين العناية (صباحي أو مسائي).
class SelfCareStep {
  const SelfCareStep({
    required this.id,
    required this.userId,
    required this.title,
    required this.period, // morning | evening
    this.category = 'skin', // skin | personal
    this.order = 0,
    this.isActive = true,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String title;
  final String period;
  final String category;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'title': title,
        'period': period,
        'category': category,
        'order': order,
        'isActive': isActive,
        'createdAt': _toIso(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
        'lastModified': _toIso(lastModified),
      };

  factory SelfCareStep.fromJson(Map<String, dynamic> j) => SelfCareStep(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        period: (j['period'] as String?) ?? 'morning',
        category: (j['category'] as String?) ?? 'skin',
        order: (j['order'] as num?)?.toInt() ?? 0,
        isActive: (j['isActive'] as bool?) ?? true,
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(j['syncStatus'] as String? ?? 'local'),
        lastModified: _fromIso(j['lastModified']),
      );

  SelfCareStep copyWith({
    String? title,
    String? period,
    String? category,
    int? order,
    bool? isActive,
    SyncStatus? syncStatus,
    DateTime? lastModified,
  }) =>
      SelfCareStep(
        id: id,
        userId: userId,
        title: title ?? this.title,
        period: period ?? this.period,
        category: category ?? this.category,
        order: order ?? this.order,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        lastModified: lastModified ?? this.lastModified,
      );
}

/// سجل إنجاز خطوة عناية في يوم محدد.
class SelfCareLog {
  const SelfCareLog({
    required this.id,
    required this.userId,
    required this.stepId,
    required this.date,
    this.done = true,
    required this.createdAt,
    this.syncStatus = SyncStatus.local,
  });

  final String id;
  final String userId;
  final String stepId;
  final String date;
  final bool done;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'stepId': stepId,
        'date': date,
        'done': done,
        'createdAt': _toIso(createdAt),
        'syncStatus': syncStatus.toJsonValue(),
      };

  factory SelfCareLog.fromJson(Map<String, dynamic> j) => SelfCareLog(
        id: j['id'] as String,
        userId: j['userId'] as String,
        stepId: j['stepId'] as String,
        date: j['date'] as String,
        done: (j['done'] as bool?) ?? true,
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
        syncStatus: SyncStatusX.fromJsonValue(j['syncStatus'] as String? ?? 'local'),
      );
}

// =============================================================================
// تعلم اللغة
// =============================================================================

/// ملف تعلّم اللغة (لغة مستهدفة ومستوى وهدف أسبوعي).
class LanguageProfile {
  const LanguageProfile({
    required this.id,
    required this.userId,
    this.targetLanguage = 'English',
    this.level = 'beginner',
    this.weeklyGoal = 20,
    required this.createdAt,
    this.lastModified,
  });

  final String id;
  final String userId;
  final String targetLanguage;
  final String level;
  final int weeklyGoal;
  final DateTime createdAt;
  final DateTime? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'targetLanguage': targetLanguage,
        'level': level,
        'weeklyGoal': weeklyGoal,
        'createdAt': _toIso(createdAt),
        'lastModified': _toIso(lastModified),
      };

  factory LanguageProfile.fromJson(Map<String, dynamic> j) => LanguageProfile(
        id: j['id'] as String,
        userId: j['userId'] as String,
        targetLanguage: (j['targetLanguage'] as String?) ?? 'English',
        level: (j['level'] as String?) ?? 'beginner',
        weeklyGoal: (j['weeklyGoal'] as num?)?.toInt() ?? 20,
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
        lastModified: _fromIso(j['lastModified']),
      );

  LanguageProfile copyWith({
    String? targetLanguage,
    String? level,
    int? weeklyGoal,
  }) =>
      LanguageProfile(
        id: id,
        userId: userId,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        level: level ?? this.level,
        weeklyGoal: weeklyGoal ?? this.weeklyGoal,
        createdAt: createdAt,
        lastModified: DateTime.now(),
      );
}

/// مجموعة كلمات/مفردات.
class WordDeck {
  const WordDeck({
    required this.id,
    required this.userId,
    required this.name,
    this.language = '',
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String language;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'name': name,
        'language': language,
        'createdAt': _toIso(createdAt),
      };

  factory WordDeck.fromJson(Map<String, dynamic> j) => WordDeck(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['name'] as String,
        language: (j['language'] as String?) ?? '',
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
      );
}

/// بطاقة مفردة داخل مجموعة.
class WordCard {
  const WordCard({
    required this.id,
    required this.deckId,
    required this.term,
    required this.meaning,
    this.example = '',
    this.isMastered = false,
    this.wrongCount = 0,
    this.correctCount = 0,
    this.lastReviewedAt,
    required this.createdAt,
  });

  final String id;
  final String deckId;
  final String term;
  final String meaning;
  final String example;
  final bool isMastered;
  final int wrongCount;
  final int correctCount;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'deckId': deckId,
        'term': term,
        'meaning': meaning,
        'example': example,
        'isMastered': isMastered,
        'wrongCount': wrongCount,
        'correctCount': correctCount,
        'lastReviewedAt': _toIso(lastReviewedAt),
        'createdAt': _toIso(createdAt),
      };

  factory WordCard.fromJson(Map<String, dynamic> j) => WordCard(
        id: j['id'] as String,
        deckId: j['deckId'] as String,
        term: j['term'] as String,
        meaning: j['meaning'] as String,
        example: (j['example'] as String?) ?? '',
        isMastered: (j['isMastered'] as bool?) ?? false,
        wrongCount: (j['wrongCount'] as num?)?.toInt() ?? 0,
        correctCount: (j['correctCount'] as num?)?.toInt() ?? 0,
        lastReviewedAt: _fromIso(j['lastReviewedAt']),
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
      );

  WordCard copyWith({
    String? term,
    String? meaning,
    String? example,
    bool? isMastered,
    int? wrongCount,
    int? correctCount,
    DateTime? lastReviewedAt,
  }) =>
      WordCard(
        id: id,
        deckId: deckId,
        term: term ?? this.term,
        meaning: meaning ?? this.meaning,
        example: example ?? this.example,
        isMastered: isMastered ?? this.isMastered,
        wrongCount: wrongCount ?? this.wrongCount,
        correctCount: correctCount ?? this.correctCount,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        createdAt: createdAt,
      );
}

/// درس قصير (نص/قواعد/أمثلة) من إعداد المستخدمة.
class LanguageLesson {
  const LanguageLesson({
    required this.id,
    required this.userId,
    required this.title,
    this.level = 'beginner',
    this.content = '',
    this.order = 0,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String level;
  final String content;
  final int order;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isCompleted => completedAt != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'title': title,
        'level': level,
        'content': content,
        'order': order,
        'completedAt': _toIso(completedAt),
        'createdAt': _toIso(createdAt),
      };

  factory LanguageLesson.fromJson(Map<String, dynamic> j) => LanguageLesson(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        level: (j['level'] as String?) ?? 'beginner',
        content: (j['content'] as String?) ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        completedAt: _fromIso(j['completedAt']),
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
      );

  LanguageLesson copyWith({
    String? title,
    String? level,
    String? content,
    int? order,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      LanguageLesson(
        id: id,
        userId: userId,
        title: title ?? this.title,
        level: level ?? this.level,
        content: content ?? this.content,
        order: order ?? this.order,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
        createdAt: createdAt,
      );
}

/// محاولة إجابة على بطاقة (تسجيل للتقدم والمراجعة).
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.isCorrect,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String cardId;
  final bool isCorrect;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'cardId': cardId,
        'isCorrect': isCorrect,
        'createdAt': _toIso(createdAt),
      };

  factory QuizAttempt.fromJson(Map<String, dynamic> j) => QuizAttempt(
        id: j['id'] as String,
        userId: j['userId'] as String,
        cardId: j['cardId'] as String,
        isCorrect: (j['isCorrect'] as bool?) ?? false,
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
      );
}

// =============================================================================
// الأهداف الشهرية
// =============================================================================

class MonthlyGoal {
  const MonthlyGoal({
    required this.id,
    required this.userId,
    required this.month, // yyyy-MM
    required this.title,
    required this.metric,
    required this.target,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String month;
  final String title;
  final String metric; // tasks | studyMinutes | quranDays | waterDays | lessons
  final int target;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'month': month,
        'title': title,
        'metric': metric,
        'target': target,
        'createdAt': _toIso(createdAt),
      };

  factory MonthlyGoal.fromJson(Map<String, dynamic> j) => MonthlyGoal(
        id: j['id'] as String,
        userId: j['userId'] as String,
        month: j['month'] as String,
        title: j['title'] as String,
        metric: j['metric'] as String,
        target: (j['target'] as num?)?.toInt() ?? 0,
        createdAt: _fromIso(j['createdAt']) ?? DateTime.now(),
      );

  MonthlyGoal copyWith({String? title, String? metric, int? target}) => MonthlyGoal(
        id: id,
        userId: userId,
        month: month,
        title: title ?? this.title,
        metric: metric ?? this.metric,
        target: target ?? this.target,
        createdAt: createdAt,
      );
}

// =============================================================================
// إحصاءات فترة (تُحسب من السجلات الحقيقية)
// =============================================================================

class PeriodStats {
  const PeriodStats({
    this.tasksTotal = 0,
    this.tasksDone = 0,
    this.habitsScheduled = 0,
    this.habitsDone = 0,
    this.studyMinutes = 0,
    this.quranReadings = 0,
    this.quranDays = 0,
    this.waterTotalMl = 0,
    this.waterDays = 0,
    this.journalEntries = 0,
    this.moodEntries = 0,
    this.lessonsCompleted = 0,
    this.careStepsDone = 0,
    this.careStepsTotal = 0,
  });

  final int tasksTotal;
  final int tasksDone;
  final int habitsScheduled;
  final int habitsDone;
  final int studyMinutes;
  final int quranReadings;
  final int quranDays;
  final int waterTotalMl;
  final int waterDays;
  final int journalEntries;
  final int moodEntries;
  final int lessonsCompleted;
  final int careStepsDone;
  final int careStepsTotal;

  double get taskRate => tasksTotal == 0 ? 0.0 : tasksDone / tasksTotal;
  double get habitRate => habitsScheduled == 0 ? 0.0 : habitsDone / habitsScheduled;
  double get careRate => careStepsTotal == 0 ? 0.0 : careStepsDone / careStepsTotal;

  /// هل الفترة تحتوي أي سجل حقيقي؟ (لا تُعرض إحصاءات وهمية).
  bool get hasData =>
      tasksTotal > 0 ||
      habitsScheduled > 0 ||
      studyMinutes > 0 ||
      quranReadings > 0 ||
      waterTotalMl > 0 ||
      journalEntries > 0 ||
      moodEntries > 0 ||
      lessonsCompleted > 0 ||
      careStepsDone > 0;
}

/// نتيجة اختبار قصير.
class QuizResult {
  const QuizResult({
    required this.total,
    required this.correct,
    required this.wrongCardIds,
  });

  final int total;
  final int correct;
  final List<String> wrongCardIds;

  int get wrong => total - correct;
  double get ratio => total == 0 ? 0.0 : correct / total;
}

/// تحويل JSON نصي آمن (للتصدير/الاستيراد).
Map<String, dynamic> safeJsonDecode(String source) {
  final decoded = jsonDecode(source);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw const FormatException('JSON root must be an object');
}

/// مساعدة لتحويل قائمة نصوص.
List<String> asStringList(dynamic value) => _stringList(value);
