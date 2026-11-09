import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/security/privacy_service.dart';

import 'support/test_db.dart';

void main() {
  late LocalDatabase db;
  var now = DateTime(2026, 11, 9, 10);
  late PrivacyService privacy;

  setUp(() async {
    db = await openTestDatabase();
    now = DateTime(2026, 11, 9, 10);
    privacy = PrivacyService(db, iterations: 10, clock: () => now);
  });

  test('a new PIN verifies and a wrong one does not', () async {
    expect(await privacy.isPinSet(), isFalse);
    await privacy.setPin('2468');
    expect(await privacy.isPinSet(), isTrue);
    expect(await privacy.verifyPin('2468'), isTrue);
    expect(await privacy.verifyPin('1111'), isFalse);
  });

  test('a PIN shorter than the minimum is rejected', () async {
    await expectLater(privacy.setPin('123'), throwsArgumentError);
  });

  test('the stored hash is not the PIN and is salted', () async {
    await privacy.setPin('2468');
    final hash = await db.getSetting('pin_hash');
    final salt = await db.getSetting('pin_salt');
    expect(hash, isA<String>());
    expect(hash, isNot('2468'));
    expect(salt, isA<String>());
  });

  test('five wrong attempts lock verification until the lock expires', () async {
    await privacy.setPin('2468');
    for (var i = 0; i < PrivacyService.maxAttempts; i++) {
      expect(await privacy.verifyPin('0000'), isFalse);
    }
    expect(await privacy.lockRemaining(), greaterThan(Duration.zero));
    // حتى الرمز الصحيح مرفوض أثناء القفل.
    expect(await privacy.verifyPin('2468'), isFalse);

    now = now.add(PrivacyService.lockDuration + const Duration(seconds: 1));
    expect(await privacy.lockRemaining(), Duration.zero);
    expect(await privacy.verifyPin('2468'), isTrue);
  });

  test('a correct entry resets the failed-attempt counter', () async {
    await privacy.setPin('2468');
    for (var i = 0; i < PrivacyService.maxAttempts - 1; i++) {
      expect(await privacy.verifyPin('0000'), isFalse);
    }
    expect(await privacy.verifyPin('2468'), isTrue);
    // بعد التصفير لا يكفي خطأ واحد للقفل.
    expect(await privacy.verifyPin('0000'), isFalse);
    expect(await privacy.lockRemaining(), Duration.zero);
  });

  test('a legacy SHA-256 PIN is accepted and upgraded to PBKDF2', () async {
    const pin = '1357';
    const salt = 'bGVnYWN5LXNhbHQ=';
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    await db.setSetting('pin_salt', salt);
    await db.setSetting('pin_hash', base64Encode(bytes));

    expect(await privacy.verifyPin('0000'), isFalse);
    expect(await privacy.verifyPin(pin), isTrue);
    expect(await db.getSetting('pin_version'), 2);
    // يعمل بعد الترقية بالصيغة الجديدة.
    expect(await privacy.verifyPin(pin), isTrue);
    expect(await privacy.verifyPin('0000'), isFalse);
  });

  test('removePin clears the PIN and its state', () async {
    await privacy.setPin('2468');
    await privacy.removePin();
    expect(await privacy.isPinSet(), isFalse);
    expect(await privacy.verifyPin('2468'), isFalse);
  });
}
