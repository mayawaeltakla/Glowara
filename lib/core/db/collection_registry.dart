/// السجل المركزي لمجموعات بيانات Glowara.
///
/// كل مجموعة (store) في قاعدة البيانات يجب أن تُسجَّل هنا مع طريقة ملكيتها.
/// منه تُشتق قائمة المجموعات التي يمرّ عليها التصدير والاستيراد والحذف، وعليه
/// تقوم اختبارات الحماية في `test/collection_registry_test.dart` و
/// `test/collection_discovery_test.dart`:
///
///  * مجموعة مستعملة في الكود وغير مسجَّلة هنا تُفشل الاختبارات.
///  * كل مجموعة مسجَّلة تُختبر سلوكيًا: تصدير حساب لا يحمل بيانات غيره،
///    والاستيراد يعيد بياناته، وحذفه لا يمسّ حسابًا آخر.
///
/// لإضافة مجموعة جديدة انظري `docs/ADDING_A_COLLECTION.md`.
library glowara.db.collection_registry;

/// كيف يُعرَف مالك السجل؟
enum CollectionOwnership {
  /// السجل يحمل حقل `userId` مباشرة.
  userId,

  /// السجل لا يحمل `userId`؛ مالكه هو مالك سجل أب (مثل سجل العادة).
  parent,

  /// سجل الحساب نفسه (مفتاحه هو معرّف الحساب). لا يُصدَّر ولا يُستورد.
  account,

  /// لا مالك له (محتوى مشترك أو قديم غير مستعمل). لا يدخل تصدير حساب ولا
  /// يُحذف مع حساب، ويظهر فقط في تصدير الجهاز كله.
  none,
}

/// شكل مفتاح السجل (الذي يُعاد بناؤه عند استيراد البيانات إلى حساب آخر).
enum CollectionKeyShape {
  /// مفتاح عادي (معرّف فريد).
  plain,

  /// `<userId>_<YYYY-MM-DD>` (الماء والمزاج).
  userDate,

  /// `profile_<userId>`.
  profile,

  /// `<userId>_<suffix>` حيث اللاحقة بلا شرطة سفلية (مثل `<userId>_first-task`).
  userSuffix,
}

class CollectionSpec {
  const CollectionSpec(
    this.name,
    this.ownership, {
    this.parent,
    this.parentField,
    this.keyShape = CollectionKeyShape.plain,
    this.legacyOwnerless = false,
    this.note,
  }) : assert(
          ownership != CollectionOwnership.parent || (parent != null && parentField != null),
          'a parent-owned collection needs parent and parentField',
        );

  final String name;
  final CollectionOwnership ownership;

  /// اسم مجموعة الأب (عند `ownership == parent`).
  final String? parent;

  /// الحقل في السجل الذي يشير إلى مفتاح سجل الأب.
  final String? parentField;

  final CollectionKeyShape keyShape;

  /// قد توجد سجلات قديمة في هذه المجموعة بلا `userId` (قيمته فارغة). هذه
  /// السجلات لا تُصدَّر مع حساب ولا تُحذف معه ولا تُنقل ملكيتها تلقائيًا.
  final bool legacyOwnerless;

  /// ملاحظة توثيقية.
  final String? note;
}

class CollectionRegistry {
  CollectionRegistry._();

  static const List<CollectionSpec> specs = <CollectionSpec>[
    CollectionSpec('tasks', CollectionOwnership.userId),
    CollectionSpec('habits', CollectionOwnership.userId),
    CollectionSpec(
      'habitLogs',
      CollectionOwnership.parent,
      parent: 'habits',
      parentField: 'habitId',
      note: 'HabitLog has no userId; ownership comes from the habit.',
    ),
    CollectionSpec(
      'worship',
      CollectionOwnership.none,
      note: 'Legacy store, no repository writes to it; worship items live in code.',
    ),
    CollectionSpec(
      'readingLogs',
      CollectionOwnership.userId,
      legacyOwnerless: true,
      note: 'Old records may have an empty userId.',
    ),
    CollectionSpec('moods', CollectionOwnership.userId, keyShape: CollectionKeyShape.userDate),
    CollectionSpec('journals', CollectionOwnership.userId),
    CollectionSpec('subjects', CollectionOwnership.userId),
    CollectionSpec(
      'units',
      CollectionOwnership.parent,
      parent: 'subjects',
      parentField: 'subjectId',
    ),
    CollectionSpec(
      'sessions',
      CollectionOwnership.userId,
      legacyOwnerless: true,
      note: 'Old records may have an empty userId.',
    ),
    CollectionSpec('careSteps', CollectionOwnership.userId),
    CollectionSpec('careLogs', CollectionOwnership.userId),
    CollectionSpec('water', CollectionOwnership.userId, keyShape: CollectionKeyShape.userDate),
    CollectionSpec('meals', CollectionOwnership.userId),
    CollectionSpec('decks', CollectionOwnership.userId),
    CollectionSpec(
      'cards',
      CollectionOwnership.parent,
      parent: 'decks',
      parentField: 'deckId',
      note: 'WordCard has no userId; ownership comes from the deck.',
    ),
    CollectionSpec('lessons', CollectionOwnership.userId),
    CollectionSpec('quizAttempts', CollectionOwnership.userId),
    CollectionSpec('goals', CollectionOwnership.userId),
    CollectionSpec(
      'weeklyResets',
      CollectionOwnership.userId,
      keyShape: CollectionKeyShape.userDate,
      note: 'Key is <userId>_<weekStart YYYY-MM-DD>; weekStart/weekEnd are stored explicitly.',
    ),
    CollectionSpec(
      'milestones',
      CollectionOwnership.userId,
      keyShape: CollectionKeyShape.userSuffix,
      note: 'Key is <userId>_<milestoneId>; milestone ids never contain an underscore.',
    ),
    CollectionSpec(
      'academyProgress',
      CollectionOwnership.userId,
      keyShape: CollectionKeyShape.userSuffix,
      note: 'Key is <userId>_<unitId>; unit ids never contain an underscore. Content itself is bundled, not stored.',
    ),
    CollectionSpec('profiles', CollectionOwnership.userId, keyShape: CollectionKeyShape.profile),
    CollectionSpec('sync', CollectionOwnership.userId),
    CollectionSpec(
      'users',
      CollectionOwnership.account,
      note: 'Accounts and password hashes; never exported or imported.',
    ),
  ];

  /// أسماء المجموعات بترتيب التسجيل.
  static final List<String> names =
      List<String>.unmodifiable(specs.map((CollectionSpec s) => s.name));

  static final Set<String> _nameSet = names.toSet();

  static bool isRegistered(String name) => _nameSet.contains(name);

  static CollectionSpec byName(String name) =>
      specs.firstWhere((CollectionSpec s) => s.name == name);
}
