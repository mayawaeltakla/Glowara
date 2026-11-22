/// تحميل منهج الأكاديمية المضمّن (ملف أصول، يعمل دون إنترنت).
library glowara.services.academy_content;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:glowara/core/models/academy_models.dart';

class AcademyContent {
  AcademyContent._();

  static const String a1Asset = 'assets/academy/a1.json';

  static AcademyCurriculum? _a1;

  /// منهج A1. يُحمَّل مرة ويُحفظ في الذاكرة.
  static Future<AcademyCurriculum> loadA1({AssetBundle? bundle}) async {
    final cached = _a1;
    if (cached != null && bundle == null) return cached;
    final text = await (bundle ?? rootBundle).loadString(a1Asset);
    final curriculum = parse(text);
    if (bundle == null) _a1 = curriculum;
    return curriculum;
  }

  /// للاختبارات: يضع منهجًا محمّلًا مسبقًا (أو يمسحه بـ null) فلا يمرّ التحميل بقناة الأصول.
  @visibleForTesting
  static void overrideA1(AcademyCurriculum? curriculum) => _a1 = curriculum;

  static AcademyCurriculum parse(String jsonText) =>
      AcademyCurriculum.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);
}
