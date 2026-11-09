import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'id_usuario';

  // =========================================================
  // SESSÃO
  // =========================================================

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  static Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<void> deleteUserId() async {
    await _storage.delete(key: _userIdKey);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);

    await _storage.delete(key: _userIdKey);
  }

  // =========================================================
  // BLOQUEIO DO APP
  // Cada usuário possui suas próprias configurações.
  // =========================================================

  static String _lockEnabledKey(String userId) {
    return 'app_lock_enabled_$userId';
  }

  static String _biometricEnabledKey(String userId) {
    return 'app_biometric_enabled_$userId';
  }

  static String _pinHashKey(String userId) {
    return 'app_pin_hash_$userId';
  }

  static String _pinSaltKey(String userId) {
    return 'app_pin_salt_$userId';
  }

  static Future<void> setAppLockEnabled(String userId, bool enabled) async {
    await _storage.write(
      key: _lockEnabledKey(userId),
      value: enabled.toString(),
    );
  }

  static Future<bool> isAppLockEnabled(String userId) async {
    final value = await _storage.read(key: _lockEnabledKey(userId));

    return value == 'true';
  }

  static Future<void> setBiometricEnabled(String userId, bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey(userId),
      value: enabled.toString(),
    );
  }

  static Future<bool> isBiometricEnabled(String userId) async {
    final value = await _storage.read(key: _biometricEnabledKey(userId));

    return value == 'true';
  }

  static Future<void> savePinHash(String userId, String hash) async {
    await _storage.write(key: _pinHashKey(userId), value: hash);
  }

  static Future<String?> getPinHash(String userId) async {
    return _storage.read(key: _pinHashKey(userId));
  }

  static Future<void> savePinSalt(String userId, String salt) async {
    await _storage.write(key: _pinSaltKey(userId), value: salt);
  }

  static Future<String?> getPinSalt(String userId) async {
    return _storage.read(key: _pinSaltKey(userId));
  }

  static Future<void> clearAppLockForUser(String userId) async {
    await _storage.delete(key: _lockEnabledKey(userId));

    await _storage.delete(key: _biometricEnabledKey(userId));

    await _storage.delete(key: _pinHashKey(userId));

    await _storage.delete(key: _pinSaltKey(userId));
  }
}
