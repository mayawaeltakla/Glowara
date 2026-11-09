/// أدوات اشتقاق وفحص كلمات المرور والرموز (PBKDF2-HMAC-SHA256).
///
/// تُستخدم من [AuthRepository] و[PrivacyService] حتى يكون للتجزئة تنفيذ واحد
/// مُختبَر بدل نسختين متباعدتين.
library glowara.security.password_hasher;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  /// عدد الدورات للتجزئات الجديدة. يُخزَّن مع كل تجزئة، فيمكن رفعه لاحقًا
  /// وترقية التجزئات القديمة عند أول تسجيل دخول ناجح.
  static const int currentIterations = 100000;

  static const int saltLength = 16;
  static const int hashLength = 32;

  /// بايتات عشوائية آمنة تشفيريًا.
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018).
  static Uint8List pbkdf2(
    String password,
    List<int> salt,
    int iterations, {
    int length = hashLength,
  }) {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'must be >= 1');
    }
    final hmac = Hmac(sha256, utf8.encode(password));
    const blockLength = 32;
    final blocks = (length / blockLength).ceil();
    final output = <int>[];

    for (var block = 1; block <= blocks; block++) {
      final blockIndex = <int>[
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert(<int>[...salt, ...blockIndex]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
    }
    return Uint8List.fromList(output.sublist(0, length));
  }

  /// مقارنة بزمن ثابت: لا يتوقف الفحص عند أول اختلاف.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// نسخة نصية من [constantTimeEquals] (للتجزئات المخزّنة بصيغة base64).
  static bool constantTimeEqualsString(String a, String b) =>
      constantTimeEquals(utf8.encode(a), utf8.encode(b));
}
