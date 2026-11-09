/// خدمة جلب نص القرآن الكريم من الشبكة.
///
/// المصدر: https://api.alquran.cloud (نص عثماني مع التشكيل، ويجب مراجعة النص
/// قبل أي إصدار عام). لا تجلب هذه الخدمة أذكارًا أو أدعية: مصدرها غير مربوط بعد.
///
/// تُحقن الخدمة من `AppState` (يمكن استبدالها بنسخة وهمية في الاختبارات أو
/// بنسخة مدمجة دون إنترنت لاحقًا). في وضع عدم الاتصال تعتمد الواجهة على
/// النسخة المخزّنة محليًا ولا تُجري أي اتصال.
library glowara.services.quran;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// سبب فشل جلب النص.
enum QuranErrorType {
  /// طلب غير صالح (رقم سورة خارج 1..114).
  invalidRequest,

  /// تعذّر الاتصال بالشبكة.
  network,

  /// انتهت مهلة الطلب.
  timeout,

  /// ردّ الخادم بحالة خطأ.
  server,

  /// الاستجابة وصلت لكنها ليست بالشكل المتوقع.
  invalidResponse,
}

/// نتيجة جلب نص (للقراءة فقط).
class QuranResult {
  const QuranResult.success(Map<String, dynamic> value)
      : ok = true,
        data = value,
        error = null,
        errorType = null;

  const QuranResult.failure(QuranErrorType type, [this.error])
      : ok = false,
        data = null,
        errorType = type;

  final bool ok;
  final Map<String, dynamic>? data;

  /// وصف تقني قصير للمطوّرين (لا يُعرض للمستخدمة كما هو).
  final String? error;
  final QuranErrorType? errorType;
}

/// واجهة خدمة القرآن.
abstract class QuranService {
  Future<QuranResult> getSurah(int number);

  /// يحرّر الموارد (اتصالات الشبكة المفتوحة).
  void close();
}

/// تنفيذ بعيد يجلب من api.alquran.cloud مع مهلة وإعادة محاولة عند الأعطال
/// المؤقتة (انقطاع الشبكة، المهلة، أخطاء 5xx وحد المعدّل 429).
class RemoteQuranService implements QuranService {
  RemoteQuranService({
    http.Client? client,
    this.baseUrl = 'https://api.alquran.cloud/v1',
    this.timeout = const Duration(seconds: 15),
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 400),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final int maxAttempts;
  final Duration retryDelay;

  @override
  Future<QuranResult> getSurah(int number) async {
    if (number < 1 || number > 114) {
      return const QuranResult.failure(
        QuranErrorType.invalidRequest,
        'surah must be between 1 and 114',
      );
    }
    return _fetch(Uri.parse('$baseUrl/surah/$number/quran-uthmani'));
  }

  @override
  void close() => _client.close();

  Future<QuranResult> _fetch(Uri uri) async {
    var last = const QuranResult.failure(QuranErrorType.network);
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client.get(uri).timeout(timeout);
        if (response.statusCode == 200) {
          return _parse(response.bodyBytes);
        }
        last = QuranResult.failure(
          QuranErrorType.server,
          'HTTP ${response.statusCode}',
        );
        final retryable = response.statusCode >= 500 || response.statusCode == 429;
        if (!retryable) return last;
      } on TimeoutException {
        last = const QuranResult.failure(QuranErrorType.timeout);
      } on Exception catch (e) {
        last = QuranResult.failure(QuranErrorType.network, e.toString());
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
    return last;
  }

  QuranResult _parse(List<int> bodyBytes) {
    try {
      // JSON هو UTF-8 دائمًا؛ لا نعتمد على ترويسة charset التي قد تغيب فيفسد النص العربي.
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! Map) {
        return const QuranResult.failure(
          QuranErrorType.invalidResponse,
          'root is not an object',
        );
      }
      if (decoded['code'] != 200) {
        return QuranResult.failure(
          QuranErrorType.server,
          decoded['status']?.toString() ?? 'error',
        );
      }
      final data = decoded['data'];
      if (data is! Map) {
        return const QuranResult.failure(
          QuranErrorType.invalidResponse,
          'missing data object',
        );
      }
      return QuranResult.success(Map<String, dynamic>.from(data));
    } on FormatException catch (e) {
      return QuranResult.failure(QuranErrorType.invalidResponse, e.message);
    }
  }
}

/// نموذج آية مُستخرجة من استجابة API.
class Ayah {
  const Ayah({required this.number, required this.text, required this.numberInSurah});

  /// الرقم العام للآية في المصحف (1..6236).
  final int number;
  final String text;

  /// رقم الآية داخل سورتها.
  final int numberInSurah;
}

/// نموذج سورة مُستخرجة من استجابة API.
class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.numberOfAyahs,
    required this.ayahs,
  });

  final int number;
  final String name;
  final String englishName;
  final int numberOfAyahs;
  final List<Ayah> ayahs;

  factory Surah.fromApi(Map<String, dynamic> data) {
    final ayahs = (data['ayahs'] as List<dynamic>)
        .map((e) => Ayah(
              number: (e['number'] as num?)?.toInt() ?? 0,
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
