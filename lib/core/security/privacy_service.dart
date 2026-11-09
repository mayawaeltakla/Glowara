/// قفل خصوصية محلي (PIN) للمذكرات.
///
/// تنبيه: هذا قفل وصول محلي فقط، وليس تشفيرًا للبيانات.
/// تشفير المذكرات فعليًا يحتاج طبقة تشفير مُدقّقة (مثل AES-GCM) وإدارة مفاتيح
/// آمنة، وهي غير منفّذة في هذه النسخة. القفل يمنع الفتح العابر داخل التطبيق
/// ولا يحمي من الوصول إلى ملفات التطبيق على جهاز مفتوح.
///
/// الرمز يُشتق بـ PBKDF2-HMAC-SHA256 مع ملح عشوائي، وبعد [maxAttempts] محاولات
/// خاطئة متتالية يُقفل التحقق لمدة [lockDuration]. الرموز المحفوظة بالصيغة
/// القديمة (SHA-256 متكرر) تُقبل وتُرقّى تلقائيًا عند أول إدخال صحيح.
library glowara.security.privacy;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/security/password_hasher.dart';

class PrivacyService {
  PrivacyService(
    this._db, {
    int iterations = PasswordHasher.currentIterations,
    DateTime Function()? clock,
  })  : _iterations = iterations,
        _now = clock ?? DateTime.now;

  final LocalDatabase _db;
  final int _iterations;
  final DateTime Function() _now;

  static const int minLength = 4;
  static const int maxAttempts = 5;
  static const Duration lockDuration = Duration(minutes: 5);

  static const String _hashKey = 'pin_hash';
  static const String _saltKey = 'pin_salt';
  static const String _versionKey = 'pin_version';
  static const String _iterationsKey = 'pin_iterations';
  static const String _failedKey = 'pin_failed';
  static const String _lockedUntilKey = 'pin_locked_until';

  /// الإصدار 2 = PBKDF2. غيابه يعني الصيغة القديمة.
  static const int _currentVersion = 2;
  static const int _legacyIterations = 10000;

  Future<bool> isPinSet() async {
    final hash = await _db.getSetting(_hashKey);
    return hash is String && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (pin.length < minLength) {
      throw ArgumentError('PIN must be at least $minLength characters');
    }
    final salt = PasswordHasher.randomBytes(PasswordHasher.saltLength);
    final hash = PasswordHasher.pbkdf2(pin, salt, _iterations);
    await _db.setSetting(_saltKey, base64Encode(salt));
    await _db.setSetting(_hashKey, base64Encode(hash));
    await _db.setSetting(_iterationsKey, _iterations);
    await _db.setSetting(_versionKey, _currentVersion);
    await _clearAttempts();
  }

  /// المدة المتبقية على انتهاء القفل المؤقت (صفر إن لم يكن مقفلًا).
  Future<Duration> lockRemaining() async {
    final raw = await _db.getSetting(_lockedUntilKey);
    if (raw is! String) return Duration.zero;
    final until = DateTime.tryParse(raw);
    if (until == null) return Duration.zero;
    final remaining = until.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// يتحقق من الرمز. يعيد false أثناء القفل المؤقت دون فحص الرمز.
  Future<bool> verifyPin(String pin) async {
    if (await lockRemaining() > Duration.zero) return false;

    final hash = await _db.getSetting(_hashKey);
    final salt = await _db.getSetting(_saltKey);
    if (hash is! String || salt is! String) return false;

    final version = _asInt(await _db.getSetting(_versionKey));
    final bool matches;
    if (version == _currentVersion) {
      final stored = _asInt(await _db.getSetting(_iterationsKey)) ?? _iterations;
      final derived = base64Encode(
        PasswordHasher.pbkdf2(pin, base64Decode(salt), stored),
      );
      matches = PasswordHasher.constantTimeEqualsString(derived, hash);
    } else {
      matches = PasswordHasher.constantTimeEqualsString(
        _legacyDerive(pin, salt),
        hash,
      );
    }

    if (!matches) {
      await _registerFailure();
      return false;
    }

    if (version != _currentVersion) {
      await setPin(pin); // ترقية الصيغة القديمة (وتصفير العدّاد).
    } else {
      await _clearAttempts();
    }
    return true;
  }

  Future<void> removePin() async {
    for (final key in <String>[
      _hashKey,
      _saltKey,
      _versionKey,
      _iterationsKey,
    ]) {
      await _db.setSetting(key, null);
    }
    await _clearAttempts();
  }

  Future<void> _registerFailure() async {
    final failed = (_asInt(await _db.getSetting(_failedKey)) ?? 0) + 1;
    if (failed >= maxAttempts) {
      final until = _now().add(lockDuration);
      await _db.setSetting(_lockedUntilKey, until.toUtc().toIso8601String());
      await _db.setSetting(_failedKey, 0);
    } else {
      await _db.setSetting(_failedKey, failed);
    }
  }

  Future<void> _clearAttempts() async {
    await _db.setSetting(_failedKey, null);
    await _db.setSetting(_lockedUntilKey, null);
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;

  /// الاشتقاق القديم (قبل PBKDF2). يبقى فقط لقراءة الرموز المحفوظة سابقًا.
  static String _legacyDerive(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _legacyIterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }
}
