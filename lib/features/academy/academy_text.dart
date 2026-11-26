/// أدوات عرض نصوص الأكاديمية (اتجاه النص حسب محتواه).
library glowara.feature.academy.text;

import 'package:flutter/widgets.dart';

final RegExp _arabicLetters = RegExp(r'[؀-ۿ]');

/// النص الذي فيه حروف عربية يُعرض من اليمين، وغيره (الإنجليزي) من اليسار، فلا تنزاح
/// علامات الترقيم في نهاية الجمل الإنجليزية داخل صفحة عربية.
TextDirection directionOf(String text) =>
    _arabicLetters.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
