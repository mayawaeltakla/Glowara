/// نماذج «ركني الصغير»: رسائل وذكريات وأمنيات تكتبها المستخدمة لنفسها، ويمكن
/// «ختم» الرسالة لتُفتح في تاريخ لاحق. الختم لطيف لا تشفير: النص محفوظ كبقية
/// بياناتها على الجهاز. لا مشاركة تلقائية ولا تنبيهات.
library glowara.models.corner;

const List<String> kCornerKinds = <String>['letter', 'memory', 'wish'];

const int kCornerTitleMax = 60;
const int kCornerTextMax = 2000;
const int kCornerMaxEntries = 100;

final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class CornerEntry {
  const CornerEntry({
    required this.id,
    required this.userId,
    required this.kind,
    this.title = '',
    required this.text,
    this.openOn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// letter | memory | wish
  final String kind;
  final String title;
  final String text;

  /// `YYYY-MM-DD`: لا تُعرض الرسالة قبل هذا التاريخ إلا بطلبها.
  final String? openOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// مختومة في [todayKey] (`YYYY-MM-DD`) إن كان تاريخ الفتح لاحقًا له.
  bool isSealed(String todayKey) => openOn != null && openOn!.compareTo(todayKey) > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'kind': kind,
        'title': title,
        'text': text,
        'openOn': openOn,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory CornerEntry.fromJson(Map<String, dynamic> j) {
    DateTime? opt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final kind = j['kind'];
    final open = j['openOn'];
    return CornerEntry(
      id: j['id'] as String,
      userId: j['userId'] as String,
      kind: kind is String && kCornerKinds.contains(kind) ? kind : 'letter',
      title: (j['title'] as String?) ?? '',
      text: (j['text'] as String?) ?? '',
      openOn: open is String && _dateKeyPattern.hasMatch(open) ? open : null,
      createdAt: opt(j['createdAt']) ?? DateTime.now(),
      updatedAt: opt(j['updatedAt']) ?? DateTime.now(),
    );
  }
}

bool isValidCornerDate(String? s) => s != null && _dateKeyPattern.hasMatch(s);
