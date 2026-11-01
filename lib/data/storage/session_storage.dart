// lib/data/storage/session_storage.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT token → SecureStorage (encrypted keychain/keystore)
/// Role, userId, fullName, rememberMe → SharedPreferences
class SessionStorage {
  SessionStorage._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Keys ──────────────────────────────────────────────────────
  static const _kToken      = 'access_token';
  static const _kRole       = 'role';
  static const _kFullName   = 'full_name';
  static const _kUserId     = 'user_id';
  static const _kIsLock     = 'is_lock';
  static const _kRememberMe = 'remember_me';

  // ── Save ──────────────────────────────────────────────────────
  static Future<void> saveSession({
    required String accessToken,
    required String role,
    required String fullName,
    required int    userId,
    required bool   isLock,
    required bool   rememberMe,
  }) async {
    // Token vào SecureStorage
    await _secureStorage.write(key: _kToken, value: accessToken);

    final prefs = await _p;
    await prefs.setString(_kRole,     role);
    await prefs.setString(_kFullName, fullName);
    await prefs.setInt(_kUserId,      userId);
    await prefs.setBool(_kIsLock,     isLock);
    await prefs.setBool(_kRememberMe, rememberMe);
  }

  // ── Read ──────────────────────────────────────────────────────
  static Future<String?> getAccessToken() =>
      _secureStorage.read(key: _kToken);

  static Future<String?> getRole() async =>
      (await _p).getString(_kRole);

  static Future<String?> getFullName() async =>
      (await _p).getString(_kFullName);

  static Future<int?> getUserId() async =>
      (await _p).getInt(_kUserId);

  static Future<bool> getIsLock() async =>
      (await _p).getBool(_kIsLock) ?? false;

  static Future<bool> getRememberMe() async =>
      (await _p).getBool(_kRememberMe) ?? false;

  // ── Check login ───────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final rememberMe = await getRememberMe();
    if (!rememberMe) return false;
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Clear ─────────────────────────────────────────────────────
  static Future<void> clearSession() async {
    await _secureStorage.delete(key: _kToken);
    final prefs = await _p;
    await prefs.remove(_kRole);
    await prefs.remove(_kFullName);
    await prefs.remove(_kUserId);
    await prefs.remove(_kIsLock);
    // Giữ lại rememberMe preference của user
  }

  /// Xóa hoàn toàn (khi user tắt remember me)
  static Future<void> clearAll() async {
    await clearSession();
    final prefs = await _p;
    await prefs.remove(_kRememberMe);
  }
}
