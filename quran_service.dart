/// خدمة جلب النصوص الدينية من مصادر موثوقة على الإنترنت.
///
/// المصادر المستخدمة:
/// - القرآن الكريم: https://api.alquran.cloud (نص عثماني مع التشكيل، مراجعة دقيقة مطلوبة قبل الإصدار).
/// - الأذكار: https://www.hisnmuslim.com (حصن المسلم).
///
/// ملاحظة: في وضع عدم الاتصال تُستخدم النسخ المخزنة محلياً فقط، ولا يُتصل بالإنترنت.
library glowara.feature.worship.quran_service;

import 'dart:convert';
import 'package:http/http.dart' as http;

/// نتيجة جلب نص read-only.
class QuranResult {
  const QuranResult._({required this.ok, required this.data, this.error});
  final bool ok;
  final Map<String, dynamic>? data;
  final String? error;
}

/// واجهة خدمة القرآن (يمكن استبدالها بنسخة محلية مدمجة لاحقًا).
abstract class QuranService {
  Future<QuranResult> getSurah(int number);
  Future<QuranResult> getMeta();
}

/// تنفيذ بعيد عن network (يجلب من api.alquran.cloud).
class RemoteQuranService implements QuranService {
  RemoteQuranService({this.client, this.baseUrl = 'https://api.alquran.cloud/v1'});
  final http.Client? client;
  final String baseUrl;

  Future<http.Response> _get(Uri uri) {
    final injected = client;
    if (injected != null) return injected.get(uri);
    // http.get ينشئ عميلًا ويغلقه تلقائيًا، بخلاف http.Client() الذي قد يبقى مفتوحًا.
    return http.get(uri);
  }

  @override
  Future<QuranResult> getSurah(int number) async {
    try {
      final res = await _get(Uri.parse('$baseUrl/surah/$number/quran-uthmani')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return QuranResult._(ok: false, error: 'HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded['code'] != 200) {
        return QuranResult._(ok: false, error: decoded['status']?.toString() ?? 'error');
      }
      return QuranResult._(ok: true, data: decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      return QuranResult._(ok: false, error: e.toString());
    }
  }

  @override
  Future<QuranResult> getMeta() async {
    try {
      final res = await _get(Uri.parse('$baseUrl/meta')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return QuranResult._(ok: false, error: 'HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return QuranResult._(ok: true, data: decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      return QuranResult._(ok: false, error: e.toString());
    }
  }
}

/// نموذج آية مُستخرجة من استجابة API.
class Ayah {
  const Ayah({required this.number, required this.text, required this.numberInSurah});
  final int number;
  final String text;
  final int numberInSurah;
}

/// نموذج سورة مُستخرجة من استجابة API.
class Surah {
  const Surah({required this.number, required this.name, required this.englishName, required this.numberOfAyahs, required this.ayahs});
  final int number;
  final String name;
  final String englishName;
  final int numberOfAyahs;
  final List<Ayah> ayahs;

  factory Surah.fromApi(Map<String, dynamic> data) {
    final ayahs = (data['ayahs'] as List<dynamic>)
        .map((e) => Ayah(
              number: (e['numberInSurah'] as num?)?.toInt() ?? 0,
              text: e['text'] as String? ?? '',
              numberInSurah: (e['numberInSurah'] as num?)?.toInt() ?? 0,
            ))
        .toList();
    return Surah(
      number: (data['number'] as num?)?.toInt() ?? 0,
      name: data['name'] as String? ?? '',
      englishName: data['englishName'] as String? ?? '',
      numberOfAyahs: (data['numberOfAyahs'] as num?)?.toInt() ?? 0,
      ayahs: ayahs,
    );
  }
}
