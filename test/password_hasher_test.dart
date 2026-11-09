import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/security/password_hasher.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PasswordHasher.pbkdf2', () {
    // متجهات اختبار PBKDF2-HMAC-SHA256 المعروفة (كلمة المرور "password"، الملح "salt").
    final salt = utf8.encode('salt');

    test('matches the known vector for 1 iteration', () {
      expect(
        _hex(PasswordHasher.pbkdf2('password', salt, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the known vector for 2 iterations', () {
      expect(
        _hex(PasswordHasher.pbkdf2('password', salt, 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('matches the known vector for 4096 iterations', () {
      expect(
        _hex(PasswordHasher.pbkdf2('password', salt, 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('rejects an iteration count below 1', () {
      expect(() => PasswordHasher.pbkdf2('x', salt, 0), throwsArgumentError);
    });
  });

  group('PasswordHasher helpers', () {
    test('randomBytes returns the requested length and differs per call', () {
      final a = PasswordHasher.randomBytes(16);
      final b = PasswordHasher.randomBytes(16);
      expect(a.length, 16);
      expect(a, isNot(equals(b)));
    });

    test('constantTimeEquals compares content and length', () {
      expect(PasswordHasher.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(PasswordHasher.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(PasswordHasher.constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
      expect(PasswordHasher.constantTimeEqualsString('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEqualsString('abc', 'abd'), isFalse);
    });
  });
}
