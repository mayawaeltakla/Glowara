/// تسجيل الأخطاء المتوقعة التي لا يجب أن توقف التطبيق، بدل ابتلاعها بصمت.
library glowara.utils.app_log;

import 'dart:developer' as developer;

/// يسجّل [error] القادم من [source] في سجل المطوّر (DevTools / logcat / console).
void logError(String source, Object error, [StackTrace? stackTrace]) {
  developer.log(
    '$source: $error',
    name: 'glowara',
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}
