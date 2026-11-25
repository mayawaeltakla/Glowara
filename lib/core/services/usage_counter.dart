/// عدّ استخدام مجهول (اختياري وبموافقة): يخبر جامع صاحبة المشروع مرة في اليوم أن
/// "جهازًا ما" فتح التطبيق، لتعرف كم مستخدمة نشطة. لا شيء من بياناتها يخرج.
///
/// ما يُرسل فقط: معرّف عشوائي للتثبيت (لا يدل على حساب ولا شخص)، ونسخة التطبيق،
/// والمنصة (android/web/…)، واللغة (ar/en)، وتاريخ اليوم.
/// لا يُرسل أبدًا: اسم أو بريد أو مهام أو عادات أو مذكرات أو مزاج أو عبادة أو ملفات
/// أو موقع.
///
/// معطّل تمامًا ما لم يُبنَ التطبيق بعنوان جامع (`--dart-define=GLOWARA_PING_URL=...`)،
/// ولا يرسل شيئًا قبل أن توافق المستخدمة صراحةً، ويمكنها الإيقاف متى شاءت.
library glowara.services.usage_counter;

import 'dart:convert';
import 'dart:math';

import 'package:glowara/core/repositories/settings_repository.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:http/http.dart' as http;

/// عنوان الجامع (يُحقن عند البناء). فارغ = العدّ معطّل ولا تظهر بطاقة موافقة.
const String kUsagePingUrl = String.fromEnvironment('GLOWARA_PING_URL');

/// نسخة التطبيق المرسلة (تُحقن عند البناء).
const String kUsageAppVersion = String.fromEnvironment('GLOWARA_VERSION', defaultValue: '1.0.0');

const String kUsageConsentKey = 'usage_ping_consent';
const String kUsageInstallIdKey = 'usage_install_id';
const String kUsageLastPingKey = 'usage_last_ping';

enum UsageConsent { unset, granted, declined }

class UsageCounter {
  UsageCounter({
    required SettingsRepository settings,
    String? endpoint,
    http.Client? client,
    DateTime Function()? now,
    Random? random,
  })  : _settings = settings,
        endpoint = endpoint ?? debugEndpoint ?? kUsagePingUrl,
        _client = client,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  /// للاختبارات فقط: عنوان يُستعمل بدل المحقون عند البناء.
  static String? debugEndpoint;

  final SettingsRepository _settings;
  final String endpoint;
  final http.Client? _client;
  final DateTime Function() _now;
  final Random _random;

  /// مفعَّل في هذا البناء: عنوان https صالح فقط.
  bool get configured {
    final uri = Uri.tryParse(endpoint);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Future<UsageConsent> consent() async {
    final v = await _settings.get<String>(kUsageConsentKey);
    if (v == '1') return UsageConsent.granted;
    if (v == '0') return UsageConsent.declined;
    return UsageConsent.unset;
  }

  Future<void> setConsent(bool granted) => _settings.set(kUsageConsentKey, granted ? '1' : '0');

  /// معرّف عشوائي (128 بت) يُنشأ أول مرة على هذا الجهاز ويبقى. لا يُصدَّر مع النسخ
  /// الاحتياطية ولا يرتبط بحساب.
  Future<String> installId() async {
    final existing = await _settings.get<String>(kUsageInstallIdKey);
    if (existing != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(existing)) return existing;
    final id = List<String>.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _settings.set(kUsageInstallIdKey, id);
    return id;
  }

  /// الحمولة التي تُرسل بالضبط (للاختبار وللشفافية).
  Future<Map<String, String>> payload({required String platform, required String locale}) async => <String, String>{
        'id': await installId(),
        'v': kUsageAppVersion,
        'p': platform,
        'l': locale == 'ar' ? 'ar' : 'en',
        'd': dateKey(_now()),
      };

  /// يرسل إشارة اليوم إن كان مفعَّلًا وموافَقًا عليه ولم تُرسل اليوم. يبتلع كل
  /// الأخطاء (لا يزعج المستخدمة ولا يوقف التطبيق). يعيد true إن أُرسلت بنجاح.
  Future<bool> maybePing({required String platform, required String locale}) async {
    try {
      if (!configured) return false;
      if (await consent() != UsageConsent.granted) return false;
      final today = dateKey(_now());
      if (await _settings.get<String>(kUsageLastPingKey) == today) return false;
      final body = jsonEncode(await payload(platform: platform, locale: locale));
      final client = _client ?? http.Client();
      try {
        final res = await client
            .post(Uri.parse(endpoint), headers: <String, String>{'Content-Type': 'text/plain;charset=UTF-8'}, body: body)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode < 200 || res.statusCode >= 300) return false;
      } finally {
        if (_client == null) client.close();
      }
      await _settings.set(kUsageLastPingKey, today);
      return true;
    } catch (_) {
      return false;
    }
  }
}
