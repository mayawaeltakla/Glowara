/// نماذج «أحلامي»: حلم بعنوان ورغبة ومرحلة وموعد مستهدف اختياري، مقسّم إلى
/// خطوات صغيرة. بلا نسب ولا درجات ولا تنبيهات تأخير ولا مشاركة تلقائية.
library glowara.models.dream;

const List<String> kDreamStages = <String>['dreaming', 'planning', 'working', 'achieved'];

const int kDreamTitleMax = 80;
const int kDreamWishMax = 500;
const int kDreamStepMax = 80;
const int kDreamMaxSteps = 15;
const int kMaxDreams = 30;

class DreamStep {
  const DreamStep({required this.id, required this.text, this.done = false});

  final String id;
  final String text;
  final bool done;

  DreamStep copyWith({bool? done}) => DreamStep(id: id, text: text, done: done ?? this.done);

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'text': text, 'done': done};

  static DreamStep? tryParse(Object? v) {
    if (v is! Map) return null;
    final id = v['id'];
    final text = v['text'];
    if (id is! String || id.isEmpty || text is! String || text.trim().isEmpty) return null;
    return DreamStep(id: id, text: text, done: v['done'] == true);
  }
}

class Dream {
  const Dream({
    required this.id,
    required this.userId,
    required this.title,
    this.wish = '',
    this.stage = 'dreaming',
    this.targetDate,
    this.steps = const <DreamStep>[],
    this.achievedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;

  /// لماذا هذا الحلم يعنيني (نص حرّ).
  final String wish;

  /// dreaming | planning | working | achieved
  final String stage;

  /// `YYYY-MM-DD` أو null. موعد للتوجيه فقط، لا يترتب عليه تنبيه ولا حكم.
  final String? targetDate;
  final List<DreamStep> steps;
  final DateTime? achievedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get stepsDone => steps.where((s) => s.done).length;

  Dream copyWith({List<DreamStep>? steps, DateTime? updatedAt}) => Dream(
        id: id,
        userId: userId,
        title: title,
        wish: wish,
        stage: stage,
        targetDate: targetDate,
        steps: steps ?? this.steps,
        achievedAt: achievedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'title': title,
        'wish': wish,
        'stage': stage,
        'targetDate': targetDate,
        'steps': steps.map((s) => s.toJson()).toList(),
        'achievedAt': achievedAt?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Dream.fromJson(Map<String, dynamic> j) {
    DateTime? opt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final stage = j['stage'];
    final target = j['targetDate'];
    return Dream(
      id: j['id'] as String,
      userId: j['userId'] as String,
      title: (j['title'] as String?) ?? '',
      wish: (j['wish'] as String?) ?? '',
      stage: stage is String && kDreamStages.contains(stage) ? stage : 'dreaming',
      targetDate: target is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(target) ? target : null,
      steps: j['steps'] is List
          ? (j['steps'] as List<dynamic>).map(DreamStep.tryParse).whereType<DreamStep>().toList()
          : const <DreamStep>[],
      achievedAt: opt(j['achievedAt']),
      createdAt: opt(j['createdAt']) ?? DateTime.now(),
      updatedAt: opt(j['updatedAt']) ?? DateTime.now(),
    );
  }
}
