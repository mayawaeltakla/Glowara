/// قفل خصوصية محلي (PIN) للمذكرات.
///
/// تنبيه: هذا قفل وصول محلي فقط، وليس تشفيرًا للبيانات.
/// تشفير المذكرات فعليًا يحتاج طبقة تشفير مُدقّقة (مثل AES-GCM) وإدارة مفاتيح
/// آمنة، وهي غير منفّذة في هذه النسخة. القفل يمنع الفتح العابر داخل التطبيق
/// ولا يحمي من الوصول إلى ملفات التطبيق على جهاز مفتوح.
library glowara.security.privacy;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:glowara/core/db/local_database.dart';

class PrivacyService {
  PrivacyService(this._db);

  final LocalDatabase _db;

  static const String _hashKey = 'pin_hash';
  static const String _saltKey = 'pin_salt';
  static const int _iterations = 10000;

  Future<bool> isPinSet() async {
    final hash = await _db.getSetting(_hashKey);
    return hash is String && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 characters');
    }
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64Encode(saltBytes);
    final hash = _derive(pin, salt);
    await _db.setSetting(_saltKey, salt);
    await _db.setSetting(_hashKey, hash);
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _db.getSetting(_hashKey);
    final salt = await _db.getSetting(_saltKey);
    if (hash is! String || salt is! String) return false;
    return _derive(pin, salt) == hash;
  }

  Future<void> removePin() async {
    await _db.setSetting(_hashKey, null);
    await _db.setSetting(_saltKey, null);
  }

  static String _derive(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }
}
