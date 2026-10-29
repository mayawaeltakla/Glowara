/// نظام التعريب الذاتي للتطبيق (بدون ملفات مولّدة)، يدعم العربية والإنجليزية
/// مع اتجاه RTL/LTR حسب اللغة المختارة.
library glowara.localization;

import 'package:flutter/material.dart';
import 'extra_strings.dart';

/// وفد localisation يوفّر مثيل AppLocalizations للسياق.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final strings = await AppLocalizations._loadStrings(locale.languageCode);
    return AppLocalizations(locale, strings);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// جميع النصوص المترجمة. يمكن توسيعه بإضافة ملفات ARB مستقبلاً.
class AppLocalizations {
  AppLocalizations(this.locale, this._strings);

  final Locale locale;
  final Map<String, String> _strings;

  /// اللغات المدعومة.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar', 'AE'),
    Locale('en', 'US'),
  ];

  /// الاتجاه النصي للغة الحالية.
  bool get isRtl => locale.languageCode == 'ar';

  /// النص حسب المفتاح، أو المفتاح نفسه إن لم يوجد (ل troubleshooting).
  String operator [](String key) => _strings[key] ?? key;

  // ---------- العناوين ----------
  String get appTitle => this['appTitle'];
  String get appTagline => this['appTagline'];

  // ---------- الترحيب ----------
  String get welcome => this['welcome'];
  String get welcomeSub => this['welcomeSub'];
  String get getStarted => this['getStarted'];

  // ---------- الحساب ----------
  String get login => this['login'];
  String get signup => this['signup'];
  String get email => this['email'];
  String get password => this['password'];
  String get confirmPassword => this['confirmPassword'];
  String get name => this['name'];
  String get logout => this['logout'];
  String get deleteAccount => this['deleteAccount'];

  // ---------- الإعدادات ----------
  String get language => this['language'];
  String get arabic => this['arabic'];
  String get english => this['english'];
  String get theme => this['theme'];
  String get light => this['light'];
  String get dark => this['dark'];
  String get system => this['system'];

  // ---------- التنقل ----------
  String get home => this['home'];
  String get today => this['today'];
  String get worship => this['worship'];
  String get calendar => this['calendar'];
  String get study => this['study'];
  String get selfCare => this['selfCare'];
  String get more => this['more'];
  String get journal => this['journal'];
  String get languageLearning => this['languageLearning'];
  String get progress => this['progress'];
  String get settings => this['settings'];

  // ---------- الإجراءات ----------
  String get save => this['save'];
  String get cancel => this['cancel'];
  String get delete => this['delete'];
  String get edit => this['edit'];
  String get add => this['add'];
  String get done => this['done'];
  String get close => this['close'];
  String get back => this['back'];
  String get next => this['next'];
  String get skip => this['skip'];
  String get sync => this['sync'];

  // ---------- المزامنة والحالة ----------
  String get syncStatus => this['syncStatus'];
  String get synced => this['synced'];
  String get syncing => this['syncing'];
  String get offline => this['offline'];
  String get online => this['online'];
  String get savedLocally => this['savedLocally'];
  String get noInternet => this['noInternet'];
  String get tryAgain => this['tryAgain'];

  // ---------- الرسائل ----------
  String get error => this['error'];
  String get success => this['success'];
  String get loading => this['loading'];
  String get empty => this['empty'];
  String get emptySub => this['emptySub'];
  String get confirmDelete => this['confirmDelete'];
  String get confirmDeleteSub => this['confirmDeleteSub'];
  String get confirm => this['confirm'];
  String get date => this['date'];
  String get none => this['none'];
  String get reset => this['reset'];

  // ---------- الأقسام ----------
  String get prayerTimes => this['prayerTimes'];
  String get nextPrayer => this['nextPrayer'];
  String get quran => this['quran'];
  String get adhkar => this['adhkar'];
  String get tasbih => this['tasbih'];
  String get istighfar => this['istighfar'];
  String get dua => this['dua'];
  String get morning => this['morning'];
  String get evening => this['evening'];
  String get tasks => this['tasks'];
  String get habits => this['habits'];
  String get subjects => this['subjects'];
  String get sessions => this['sessions'];
  String get mood => this['mood'];
  String get water => this['water'];
  String get meals => this['meals'];
  String get achievements => this['achievements'];
  String get statistics => this['statistics'];
  String get privacy => this['privacy'];
  String get private => this['private'];
  String get notMedicalAdvice => this['notMedicalAdvice'];
  String get version => this['version'];
  String get about => this['about'];

  /// النصوص مضمّنة في الكود (fallback + extraStrings) كي تعمل دون أصول إضافية.
  static Future<Map<String, String>> _loadStrings(String lang) async {
    final fallback = Map<String, String>.from(_fallback[lang] ?? _fallback['en']!);
    final extra = extraStrings[lang] ?? extraStrings['en']!;
    return <String, String>{...fallback, ...extra};
  }

  static const Map<String, Map<String, String>> _fallback = {
    'en': <String, String>{
      'appTitle': 'Glowara',
      'appTagline': 'A calm space for worship, planning, study and self-care',
      'welcome': 'Welcome to Glowara',
      'welcomeSub': 'Your gentle companion for worship, planning, study and self-care.',
      'getStarted': 'Get started',
      'login': 'Log in',
      'signup': 'Create account',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'name': 'Name',
      'logout': 'Log out',
      'deleteAccount': 'Delete account',
      'language': 'Language',
      'arabic': 'Arabic',
      'english': 'English',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'home': 'Home',
      'today': 'Today',
      'worship': 'Worship',
      'calendar': 'Calendar',
      'study': 'Study',
      'selfCare': 'Self-care',
      'more': 'More',
      'journal': 'Journal',
      'languageLearning': 'Language learning',
      'progress': 'Progress & achievements',
      'settings': 'Settings',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'done': 'Done',
      'close': 'Close',
      'back': 'Back',
      'next': 'Next',
      'skip': 'Skip',
      'sync': 'Sync',
      'syncStatus': 'Sync status',
      'synced': 'Synced',
      'syncing': 'Syncing...',
      'offline': 'Offline',
      'online': 'Online',
      'savedLocally': 'Saved on this device',
      'noInternet': 'No internet connection',
      'tryAgain': 'Try again',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'empty': 'No items yet',
      'emptySub': 'There is nothing here yet. Add your first item.',
      'confirmDelete': 'Delete this item?',
      'confirmDeleteSub': 'This cannot be undone.',
      'prayerTimes': 'Prayer times',
      'nextPrayer': 'Next prayer',
      'quran': 'Quran',
      'adhkar': 'Adhkar',
      'tasbih': 'Tasbih',
      'istighfar': 'Istighfar',
      'dua': 'Dua',
      'morning': 'Morning',
      'evening': 'Evening',
      'tasks': 'Tasks',
      'habits': 'Habits',
      'subjects': 'Subjects',
      'sessions': 'Sessions',
      'mood': 'Mood',
      'water': 'Water',
      'meals': 'Meals',
      'achievements': 'Achievements',
      'statistics': 'Statistics',
      'privacy': 'Privacy',
      'private': 'Private',
      'notMedicalAdvice': 'This app is not a substitute for medical advice.',
      'version': 'Version',
      'about': 'About',
    },
    'ar': <String, String>{
      'appTitle': 'غلوارا',
      'appTagline': 'مساحة هادئة للعبادة والتخطيط والدراسة والعناية بالنفس',
      'welcome': 'أهلاً بك في غلوارا',
      'welcomeSub': 'رفيقتك اللطيفة للعبادة والتخطيط والدراسة والعناية بالنفس.',
      'getStarted': 'البدء',
      'login': 'تسجيل الدخول',
      'signup': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirmPassword': 'تأكيد كلمة المرور',
      'name': 'الاسم',
      'logout': 'تسجيل الخروج',
      'deleteAccount': 'حذف الحساب',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'الإنجليزية',
      'theme': 'الثيم',
      'light': 'نهاري',
      'dark': 'ليلي',
      'system': 'نظام الجهاز',
      'home': 'الرئيسية',
      'today': 'اليوم',
      'worship': 'العبادات',
      'calendar': 'التقويم',
      'study': 'الدراسة',
      'selfCare': 'العناية بالنفس',
      'more': 'المزيد',
      'journal': 'المذكرات',
      'languageLearning': 'تعلّم اللغة',
      'progress': 'التقدم والإنجازات',
      'settings': 'الإعدادات',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'add': 'إضافة',
      'done': 'تم',
      'close': 'إغلاق',
      'back': 'رجوع',
      'next': 'التالي',
      'skip': 'تخطي',
      'sync': 'مزامنة',
      'syncStatus': 'حالة المزامنة',
      'synced': 'تمت المزامنة',
      'syncing': 'جارٍ المزامنة...',
      'offline': 'غير متصل',
      'online': 'متصل',
      'savedLocally': 'محفوظ على هذا الجهاز',
      'noInternet': 'لا يوجد اتصال بالإنترنت',
      'tryAgain': 'محاولة مرة أخرى',
      'error': 'خطأ',
      'success': 'نجاح',
      'loading': 'جارٍ التحميل...',
      'empty': 'لا توجد عناصر بعد',
      'emptySub': 'لا يوجد شيء هنا بعد. أضِفي عنصرك الأول.',
      'confirmDelete': 'حذف هذا العنصر؟',
      'confirmDeleteSub': 'لا يمكن التراجع عن هذا الإجراء.',
      'prayerTimes': 'مواقيت الصلاة',
      'nextPrayer': 'الصلاة التالية',
      'quran': 'القرآن الكريم',
      'adhkar': 'الأذكار',
      'tasbih': 'التسبيح',
      'istighfar': 'الاستغفار',
      'dua': 'الدعاء',
      'morning': 'صباحاً',
      'evening': 'مساءً',
      'tasks': 'المهام',
      'habits': 'العادات',
      'subjects': 'المواد',
      'sessions': 'جلسات الدراسة',
      'mood': 'المزاج',
      'water': 'الماء',
      'meals': 'الوجبات',
      'achievements': 'الإنجازات',
      'statistics': 'الإحصائيات',
      'privacy': 'الخصوصية',
      'private': 'خاص',
      'notMedicalAdvice': 'هذا التطبيق ليس بديلاً عن الاستشارة الطبية.',
      'version': 'الإصدار',
      'about': 'حول التطبيق',
    },
  };
}

/// مساعدة لقراءة النصوص من سياق البناء.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations)!;

  /// قراءة نص إضافي بالمفتاح.
  String tr(String key) => l10n[key];
}
