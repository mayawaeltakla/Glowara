/// نماذج «روتيناتي»: قوائم خطوات تكتبها المستخدمة (صباحية/مسائية/مخصصة) وتعلّم
/// ما أنجزته كل يوم. بلا درجات ولا نسب ولا سلاسل أيام ولا مقارنة.
library glowara.models.routine;

const List<String> kRoutineKinds = <String>['morning', 'evening', 'custom'];
const int kRoutineNameMax = 40;
const int kRoutineStepMax = 80;
const int kRoutineMaxSteps = 12;
const int kRoutineMaxRoutines = 10;

class RoutineStep {
  const RoutineStep({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'text': text};

  static RoutineStep? tryParse(Object? v) {
    if (v is! Map) return null;
    final id = v['id'];
    final text = v['text'];
    if (id is! String || id.isEmpty || text is! String || text.trim().isEmpty) return null;
    return RoutineStep(id: id, text: text);
  }
}

class Routine {
  const Routine({
    required this.id,
    required this.userId,
    required this.name,
    this.kind = 'custom',
    this.steps = const <RoutineStep>[],
    this.days = const <int>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;

  /// morning | evening | custom
  final String kind;
  final List<RoutineStep> steps;

  /// أيام الأسبوع (1=الاثنين..7=الأحد، كما في DateTime.weekday). فارغة = كل يوم.
  final List<int> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool runsOn(DateTime day) => days.isEmpty || days.contains(day.weekday);

  Routine copyWith({String? name, String? kind, List<RoutineStep>? steps, List<int>? days, DateTime? updatedAt}) =>
      Routine(
        id: id,
        userId: userId,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        steps: steps ?? this.steps,
        days: days ?? this.days,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'name': name,
        'kind': kind,
        'steps': steps.map((s) => s.toJson()).toList(),
        'days': days,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Routine.fromJson(Map<String, dynamic> j) {
    DateTime when(Object? v) => (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();
    final kind = j['kind'];
    return Routine(
      id: j['id'] as String,
      userId: j['userId'] as String,
      name: (j['name'] as String?) ?? '',
      kind: kind is String && kRoutineKinds.contains(kind) ? kind : 'custom',
      steps: j['steps'] is List
          ? (j['steps'] as List<dynamic>).map(RoutineStep.tryParse).whereType<RoutineStep>().toList()
          : const <RoutineStep>[],
      days: j['days'] is List
          ? ((j['days'] as List<dynamic>).whereType<int>().where((d) => d >= 1 && d <= 7).toSet().toList()..sort())
          : const <int>[],
      createdAt: when(j['createdAt']),
      updatedAt: when(j['updatedAt']),
    );
  }
}

/// ما علّمته المستخدمة في يوم: روتين -> معرّفات الخطوات المنجزة. المفتاح
/// `<userId>_<YYYY-MM-DD>`.
class RoutineDay {
  const RoutineDay({
    required this.id,
    required this.userId,
    required this.date,
    this.done = const <String, List<String>>{},
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String date;
  final Map<String, List<String>> done;
  final DateTime updatedAt;

  static String idFor(String userId, String date) => '${userId}_$date';

  bool isDone(String routineId, String stepId) => done[routineId]?.contains(stepId) ?? false;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'date': date,
        'done': done,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory RoutineDay.fromJson(Map<String, dynamic> j) {
    final done = <String, List<String>>{};
    final raw = j['done'];
    if (raw is Map) {
      raw.forEach((Object? k, Object? v) {
        if (k is String && v is List) {
          final ids = v.whereType<String>().toList();
          if (ids.isNotEmpty) done[k] = ids;
        }
      });
    }
    return RoutineDay(
      id: j['id'] as String,
      userId: j['userId'] as String,
      date: j['date'] as String,
      done: done,
      updatedAt: (j['updatedAt'] is String ? DateTime.tryParse(j['updatedAt'] as String)?.toLocal() : null) ??
          DateTime.now(),
    );
  }
}

/// قالب اختياري: نصوص عامة تُنسخ إلى روتين جديد بطلبها فقط، ثم تعدّلها كما تشاء.
class RoutineTemplate {
  const RoutineTemplate(this.id, this.kind, this.nameAr, this.nameEn, this.stepsAr, this.stepsEn);

  final String id;
  final String kind;
  final String nameAr;
  final String nameEn;
  final List<String> stepsAr;
  final List<String> stepsEn;

  String name(String locale) => locale == 'ar' ? nameAr : nameEn;
  List<String> steps(String locale) => locale == 'ar' ? stepsAr : stepsEn;
}

const List<RoutineTemplate> kRoutineTemplates = <RoutineTemplate>[
  RoutineTemplate(
    't-morning',
    'morning',
    'صباح هادئ',
    'Calm morning',
    <String>['شرب كوب ماء', 'ترتيب السرير', 'تمدد خفيف', 'نظرة على خطة اليوم'],
    <String>['Drink a glass of water', 'Make the bed', 'Gentle stretch', 'Glance at the day plan'],
  ),
  RoutineTemplate(
    't-evening',
    'evening',
    'مساء هادئ',
    'Calm evening',
    <String>['ترتيب سريع للمكان', 'تجهيز أغراض الغد', 'خفض الإضاءة', 'قراءة قصيرة'],
    <String>['Quick tidy-up', 'Prepare tomorrow\'s things', 'Dim the lights', 'Read a little'],
  ),
  RoutineTemplate(
    't-study',
    'custom',
    'بداية جلسة دراسة',
    'Study session start',
    <String>['تجهيز المكتب', 'إغلاق التنبيهات', 'تحديد هدف صغير للجلسة'],
    <String>['Set up the desk', 'Silence notifications', 'Pick one small goal for the session'],
  ),
];
