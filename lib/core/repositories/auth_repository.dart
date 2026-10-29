/// المصادقة المحلية: حساب محلي بكلمة مرور مُجزَّأة (PBKDF2-HMAC-SHA256).
///
/// ملاحظة مهمة: هذه مصادقة على الجهاز فقط ولا تُزامن بين الأجهزة.
/// المزامنة السحابية تحتاج خدمة خلفية (Firebase/Supabase) ولم تُنفّذ بعد.
library glowara.repositories.auth;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';

class AuthResult {
  const AuthResult({required this.ok, this.user, this.error});
  final bool ok;
  final AppUser? user;
  final String? error;
}

class AuthRepository {
  AuthRepository(this._db);

  final LocalDatabase _db;

  static const String _users = 'users';
  static const String _currentUserKey = 'current_user';
  static const int _iterations = 12000;

  Future<AppUser?> currentUser() async {
    final raw = await _db.getSetting(_currentUserKey);
    if (raw is! Map) return null;
    try {
      return AppUser.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAccounts() async => (await _db.count(_users)) > 0;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_isEmail(normalized)) {
      return const AuthResult(ok: false, error: 'invalid_email');
    }
    if (password.length < 6) {
      return const AuthResult(ok: false, error: 'weak_password');
    }
    final existing = await _findByEmail(normalized);
    if (existing != null) {
      return const AuthResult(ok: false, error: 'email_exists');
    }

    final salt = _randomBytes(16);
    final hash = _pbkdf2(password, salt, _iterations, 32);
    final now = DateTime.now();
    final id = uniqueId();
    final user = AppUser(
      id: id,
      email: normalized,
      displayName: name.trim().isEmpty ? null : name.trim(),
      createdAt: now,
      language: 'ar',
      syncStatus: SyncStatus.local,
      lastModified: now,
    );

    await _db.put(_users, id, <String, dynamic>{
      'id': id,
      'email': normalized,
      'name': name.trim(),
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': _iterations,
      'createdAt': now.toIso8601String(),
    });
    await _db.setSetting(_currentUserKey, user.toJson());
    return AuthResult(ok: true, user: user);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final normalized = email.trim().toLowerCase();
    final record = await _findByEmail(normalized);
    if (record == null) {
      return const AuthResult(ok: false, error: 'account_not_found');
    }
    try {
      final salt = base64Decode(record['salt'] as String);
      final expected = record['hash'] as String;
      final iterations = (record['iterations'] as num?)?.toInt() ?? _iterations;
      final actual = base64Encode(_pbkdf2(password, salt, iterations, 32));
      if (actual != expected) {
        return const AuthResult(ok: false, error: 'wrong_password');
      }
      final user = AppUser(
        id: record['id'] as String,
        email: record['email'] as String,
        displayName: (record['name'] as String?)?.isEmpty ?? true
            ? null
            : record['name'] as String,
        createdAt: DateTime.tryParse(record['createdAt'] as String? ?? '') ?? DateTime.now(),
        language: 'ar',
        lastModified: DateTime.now(),
        syncStatus: SyncStatus.synced,
      );
      await _db.setSetting(_currentUserKey, user.toJson());
      return AuthResult(ok: true, user: user);
    } catch (_) {
      return const AuthResult(ok: false, error: 'login_failed');
    }
  }

  Future<void> logout() => _db.setSetting(_currentUserKey, null);

  /// حذف الحساب والبيانات المحلية كاملة (لا يمكن التراجع).
  Future<void> deleteAccount() async {
    await _db.clearAll();
  }

  Future<void> updateProfile(AppUser user) async {
    await _db.setSetting(_currentUserKey, user.toJson());
    // حدّث سجل المستخدم أيضًا، وإلا عاد الاسم القديم بعد الخروج والدخول.
    final record = await _db.byId<Map<String, Object?>>(_users, user.id, (m) => m);
    if (record != null) {
      record['name'] = user.displayName ?? '';
      await _db.put(_users, user.id, Map<String, dynamic>.from(record));
    }
  }

  Future<Map<String, dynamic>?> _findByEmail(String email) async {
    final users = await _db.list(_users, (m) => m);
    for (final user in users) {
      if ((user['email'] as String?)?.toLowerCase() == email) return user;
    }
    return null;
  }

  static bool _isEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256 (تنفيذ مباشر لتفادي اعتماد إضافي).
  static Uint8List _pbkdf2(String password, Uint8List salt, int iterations, int length) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hashLength = 32;
    final blocks = (length / hashLength).ceil();
    final output = <int>[];

    for (var block = 1; block <= blocks; block++) {
      final blockBytes = <int>[
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert(<int>[...salt, ...blockBytes]).bytes;
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
}
