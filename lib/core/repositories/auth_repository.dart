/// المصادقة المحلية: حساب محلي بكلمة مرور مُجزَّأة (PBKDF2-HMAC-SHA256).
///
/// ملاحظة مهمة: هذه مصادقة على الجهاز فقط ولا تُزامن بين الأجهزة.
/// المزامنة السحابية تحتاج خدمة خلفية (Firebase/Supabase) ولم تُنفّذ بعد.
library glowara.repositories.auth;

import 'dart:convert';

import 'package:glowara/core/db/local_database.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/security/password_hasher.dart';
import 'package:glowara/core/utils/app_log.dart';

class AuthResult {
  const AuthResult({required this.ok, this.user, this.error});
  final bool ok;
  final AppUser? user;
  final String? error;
}

class AuthRepository {
  AuthRepository(
    this._db, {
    int iterations = PasswordHasher.currentIterations,
  }) : _iterations = iterations;

  final LocalDatabase _db;
  final int _iterations;

  static const String _users = 'users';
  static const String _currentUserKey = 'current_user';
  static const int _minPasswordLength = 6;

  Future<AppUser?> currentUser() async {
    final raw = await _db.getSetting(_currentUserKey);
    if (raw is! Map) return null;
    try {
      return AppUser.fromJson(Map<String, dynamic>.from(raw));
    } catch (e, st) {
      logError('AuthRepository.currentUser', e, st);
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
    if (password.length < _minPasswordLength) {
      return const AuthResult(ok: false, error: 'weak_password');
    }
    final existing = await _findByEmail(normalized);
    if (existing != null) {
      return const AuthResult(ok: false, error: 'email_exists');
    }

    final salt = PasswordHasher.randomBytes(PasswordHasher.saltLength);
    final hash = PasswordHasher.pbkdf2(password, salt, _iterations);
    final now = DateTime.now();
    final id = uniqueId();
    const language = 'ar';
    final user = AppUser(
      id: id,
      email: normalized,
      displayName: name.trim().isEmpty ? null : name.trim(),
      createdAt: now,
      language: language,
      syncStatus: SyncStatus.local,
      lastModified: now,
    );

    await _db.put(_users, id, <String, dynamic>{
      'id': id,
      'email': normalized,
      'name': name.trim(),
      'language': language,
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
      final actual = base64Encode(PasswordHasher.pbkdf2(password, salt, iterations));
      if (!PasswordHasher.constantTimeEqualsString(actual, expected)) {
        return const AuthResult(ok: false, error: 'wrong_password');
      }

      // ترقية التجزئة القديمة إلى العدد الحالي من الدورات بعد نجاح الدخول.
      if (iterations < _iterations) {
        await _upgradeHash(record, password);
      }

      final user = AppUser(
        id: record['id'] as String,
        email: record['email'] as String,
        displayName: (record['name'] as String?)?.isEmpty ?? true
            ? null
            : record['name'] as String,
        createdAt: DateTime.tryParse(record['createdAt'] as String? ?? '') ?? DateTime.now(),
        language: (record['language'] as String?) ?? 'ar',
        lastModified: DateTime.now(),
        // لا مزامنة سحابية في هذه النسخة، فالحساب محلي دائمًا.
        syncStatus: SyncStatus.local,
      );
      await _db.setSetting(_currentUserKey, user.toJson());
      return AuthResult(ok: true, user: user);
    } catch (e, st) {
      logError('AuthRepository.login', e, st);
      return const AuthResult(ok: false, error: 'login_failed');
    }
  }

  Future<void> logout() => _db.setSetting(_currentUserKey, null);

  /// يحذف حساب [userId] وبياناته فقط، ويُنهي الجلسة الحالية.
  /// لا يمسّ حسابات أخرى على الجهاز ولا التفضيلات المشتركة.
  Future<void> deleteAccount(String userId) async {
    await _db.deleteUserData(userId);
    await logout();
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

  Future<void> _upgradeHash(Map<String, dynamic> record, String password) async {
    final salt = PasswordHasher.randomBytes(PasswordHasher.saltLength);
    final hash = PasswordHasher.pbkdf2(password, salt, _iterations);
    await _db.put(_users, record['id'] as String, <String, dynamic>{
      ...record,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': _iterations,
    });
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
}
