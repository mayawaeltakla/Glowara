/// ملاحظة تاريخية: كان هذا الملف يحتوي تنفيذ تخزين قديمًا عبر
/// `shared_preferences`. تم استبداله بالكامل بطبقة `LocalDatabase` (sembast)
/// والمستودعات المنفصلة في `lib/core/repositories/`.
///
/// أُبقي الملف فارغًا عمدًا حتى لا تُحلّل واجهة قديمة غير مستخدمة، ولا يوجد
/// أي استيراد له من التطبيق. البيانات القديمة تُرحَّل عبر
/// `lib/core/db/legacy_migration.dart`.
library glowara.storage.legacy;
