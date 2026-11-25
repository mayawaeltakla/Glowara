/// أساس داخلي للصلاحيات (ما هو مفتوح لهذه المستخدمة). لا دفع ولا اشتراكات ولا
/// واجهة بيع في هذه النسخة: كل شيء مفتوح، وهذا الملف يجهّز مكانًا واحدًا واضحًا
/// يُسأل عنه "هل هذه الميزة مفتوحة؟" بدل نثر الشروط في الشاشات لاحقًا.
///
/// قواعد ثابتة (من خطة العلامة، قسم حماية الثقة):
/// - العبادات والقرآن والأذكار والأدعية والنصوص الدينية لا تُحجب أبدًا.
/// - بيانات المستخدمة لا تُحجب ولا تُحذف بسبب حالة الصلاحيات: تبقى قابلة للعرض
///   والتصدير والحذف دائمًا حتى لو أُغلقت ميزة.
library glowara.models.entitlements;

/// ميزات التطبيق. [protected] = لا تُغلق في أي حال.
enum GlowFeature {
  // محميّة دائمًا.
  worship(protected: true),
  quran(protected: true),
  adhkar(protected: true),
  duas(protected: true),
  // أساسيات مجانية.
  tasks(protected: true),
  habits(protected: true),
  calendar(protected: true),
  study(protected: true),
  care(protected: true),
  journalAndMood(protected: true),
  water(protected: true),
  meals(protected: true),
  englishBasics(protected: true),
  // ميزات قد تُوسَّع لاحقًا (مفتوحة كلها الآن).
  weeklyReset(protected: false),
  milestones(protected: false),
  academyFull(protected: false),
  nutritionPlanner(protected: false),
  routines(protected: false),
  library(protected: false),
  dreams(protected: false),
  littleCorner(protected: false),
  moodInsights(protected: false),
  customHome(protected: false),
  dashboard(protected: false);

  const GlowFeature({required this.protected});

  final bool protected;
}

/// ما فُتح لهذه المستخدمة. الافتراضي (إصدار اليوم): كل شيء مفتوح.
class EntitlementSnapshot {
  const EntitlementSnapshot({required this.unlocked});

  /// كل الميزات مفتوحة (الوضع الحالي للتطبيق).
  const EntitlementSnapshot.allUnlocked() : unlocked = const <GlowFeature>{...GlowFeature.values};

  /// لا شيء مفتوح فوق المحميّ (للاختبار ولمرحلة لاحقة بعد موافقتك فقط).
  const EntitlementSnapshot.protectedOnly() : unlocked = const <GlowFeature>{};

  final Set<GlowFeature> unlocked;
}

class EntitlementService {
  const EntitlementService(this.snapshot);

  /// إصدار اليوم: كل شيء مفتوح.
  const EntitlementService.launch() : snapshot = const EntitlementSnapshot.allUnlocked();

  final EntitlementSnapshot snapshot;

  /// هل [feature] مفتوحة للاستعمال الجديد؟ المحميّة مفتوحة دائمًا.
  bool isEnabled(GlowFeature feature) => feature.protected || snapshot.unlocked.contains(feature);

  /// بيانات المستخدمة داخل [feature] تبقى قابلة للعرض والتصدير والحذف دائمًا،
  /// مهما كانت حالة الصلاحيات.
  bool canAccessOwnData(GlowFeature feature) => true;
}
