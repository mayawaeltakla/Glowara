/// نماذج أكاديمية English. المحتوى مضمّن في التطبيق (ملف أصول)، وما يُخزَّن في
/// قاعدة البيانات هو تقدّم المستخدمة فقط ([AcademyProgress]).
library glowara.models.academy;

class AcademyWord {
  const AcademyWord({required this.en, required this.ar, required this.exEn, required this.exAr});

  final String en;
  final String ar;
  final String exEn;
  final String exAr;

  factory AcademyWord.fromJson(Map<String, dynamic> j) => AcademyWord(
        en: j['en'] as String,
        ar: j['ar'] as String,
        exEn: j['exEn'] as String,
        exAr: j['exAr'] as String,
      );
}

/// عبارة أو مثال: إنجليزي مع ترجمته.
class AcademyExample {
  const AcademyExample({required this.en, required this.ar});

  final String en;
  final String ar;

  factory AcademyExample.fromJson(Map<String, dynamic> j) =>
      AcademyExample(en: j['en'] as String, ar: j['ar'] as String);
}

class AcademyGrammar {
  const AcademyGrammar({required this.titleAr, required this.bodyAr, required this.examples});

  final String titleAr;
  final String bodyAr;
  final List<AcademyExample> examples;

  factory AcademyGrammar.fromJson(Map<String, dynamic> j) => AcademyGrammar(
        titleAr: j['titleAr'] as String,
        bodyAr: j['bodyAr'] as String,
        examples: (j['examples'] as List<dynamic>)
            .map((e) => AcademyExample.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AcademyQuestion {
  const AcademyQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.why,
  });

  final String id;
  final String prompt;
  final List<String> options;

  /// فهرس الإجابة الصحيحة في [options].
  final int answer;
  final String why;

  String get correctOption => options[answer];

  factory AcademyQuestion.fromJson(Map<String, dynamic> j) => AcademyQuestion(
        id: j['id'] as String,
        prompt: j['prompt'] as String,
        options: (j['options'] as List<dynamic>).map((e) => e as String).toList(),
        answer: (j['answer'] as num).toInt(),
        why: j['why'] as String,
      );
}

class AcademyUnit {
  const AcademyUnit({
    required this.id,
    required this.order,
    required this.level,
    required this.titleEn,
    required this.titleAr,
    required this.summaryAr,
    required this.vocab,
    required this.phrases,
    required this.grammar,
    required this.questions,
  });

  /// معرّف ثابت بلا شرطة سفلية (يدخل في مفتاح سجل التقدّم).
  final String id;
  final int order;
  final String level;
  final String titleEn;
  final String titleAr;
  final String summaryAr;
  final List<AcademyWord> vocab;
  final List<AcademyExample> phrases;
  final AcademyGrammar grammar;
  final List<AcademyQuestion> questions;

  factory AcademyUnit.fromJson(Map<String, dynamic> j) => AcademyUnit(
        id: j['id'] as String,
        order: (j['order'] as num).toInt(),
        level: j['level'] as String,
        titleEn: j['titleEn'] as String,
        titleAr: j['titleAr'] as String,
        summaryAr: j['summaryAr'] as String,
        vocab: (j['vocab'] as List<dynamic>)
            .map((e) => AcademyWord.fromJson(e as Map<String, dynamic>))
            .toList(),
        phrases: (j['phrases'] as List<dynamic>)
            .map((e) => AcademyExample.fromJson(e as Map<String, dynamic>))
            .toList(),
        grammar: AcademyGrammar.fromJson(j['grammar'] as Map<String, dynamic>),
        questions: (j['questions'] as List<dynamic>)
            .map((e) => AcademyQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AcademyCurriculum {
  const AcademyCurriculum({required this.level, required this.units});

  final String level;
  final List<AcademyUnit> units;

  AcademyUnit? unit(String id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  factory AcademyCurriculum.fromJson(Map<String, dynamic> j) => AcademyCurriculum(
        level: j['level'] as String,
        units: (j['units'] as List<dynamic>)
            .map((e) => AcademyUnit.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
      );
}

/// تقدّم مستخدمة في وحدة. المفتاح `<userId>_<unitId>`. بلا درجات: ما نخزّنه
/// هو هل درست الدرس، وهل أكملت التمرين، وما أخطأت فيه لتراجعه.
class AcademyProgress {
  const AcademyProgress({
    required this.id,
    required this.userId,
    required this.unitId,
    this.studiedAt,
    this.practicedAt,
    this.missed = const <String>[],
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String unitId;
  final DateTime? studiedAt;
  final DateTime? practicedAt;

  /// معرّفات الأسئلة التي أخطأت فيها آخر مرة ولم تصحّحها بعد.
  final List<String> missed;
  final DateTime updatedAt;

  static String idFor(String userId, String unitId) => '${userId}_$unitId';

  bool get studied => studiedAt != null;
  bool get practiced => practicedAt != null;

  /// الوحدة مكتملة: درست الدرس وأكملت التمرين مرة على الأقل.
  bool get completed => studied && practiced;

  AcademyProgress copyWith({
    DateTime? studiedAt,
    DateTime? practicedAt,
    List<String>? missed,
    DateTime? updatedAt,
  }) =>
      AcademyProgress(
        id: id,
        userId: userId,
        unitId: unitId,
        studiedAt: studiedAt ?? this.studiedAt,
        practicedAt: practicedAt ?? this.practicedAt,
        missed: missed ?? this.missed,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'unitId': unitId,
        'studiedAt': studiedAt?.toUtc().toIso8601String(),
        'practicedAt': practicedAt?.toUtc().toIso8601String(),
        'missed': missed,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory AcademyProgress.fromJson(Map<String, dynamic> j) {
    DateTime? when(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final rawMissed = j['missed'];
    return AcademyProgress(
      id: j['id'] as String,
      userId: j['userId'] as String,
      unitId: j['unitId'] as String,
      studiedAt: when(j['studiedAt']),
      practicedAt: when(j['practicedAt']),
      missed: rawMissed is List ? rawMissed.whereType<String>().toList() : const <String>[],
      updatedAt: when(j['updatedAt']) ?? DateTime.now(),
    );
  }
}
