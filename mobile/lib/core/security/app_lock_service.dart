import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_storage.dart';

class AppLockService {
  final LocalAuthentication _localAuth;

  AppLockService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<String> _getCurrentUserId() async {
    final userId = await SecureStorage.getUserId();

    if (userId == null || userId.trim().isEmpty) {
      throw Exception('Nenhum usuário autenticado.');
    }

    return userId;
  }

  String _generateSalt() {
    final random = Random.secure();

    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    return base64UrlEncode(bytes);
  }

  String _hashPin({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt:$pin');

    return sha256.convert(bytes).toString();
  }

  Future<bool> isLockEnabled() async {
    final userId = await _getCurrentUserId();

    return SecureStorage.isAppLockEnabled(userId);
  }

  Future<bool> isBiometricEnabled() async {
    final userId = await _getCurrentUserId();

    return SecureStorage.isBiometricEnabled(userId);
  }

  Future<bool> hasPin() async {
    final userId = await _getCurrentUserId();

    final hash = await SecureStorage.getPinHash(userId);

    final salt = await SecureStorage.getPinSalt(userId);

    return hash != null && hash.isNotEmpty && salt != null && salt.isNotEmpty;
  }

  Future<void> configurePin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw Exception('O PIN deve possuir entre 4 e 6 números.');
    }

    final userId = await _getCurrentUserId();

    final salt = _generateSalt();

    final hash = _hashPin(pin: pin, salt: salt);

    await SecureStorage.savePinSalt(userId, salt);

    await SecureStorage.savePinHash(userId, hash);

    await SecureStorage.setAppLockEnabled(userId, true);
  }

  Future<bool> verifyPin(String pin) async {
    final userId = await _getCurrentUserId();

    final savedHash = await SecureStorage.getPinHash(userId);

    final salt = await SecureStorage.getPinSalt(userId);

    if (savedHash == null || salt == null) {
      return false;
    }

    final enteredHash = _hashPin(pin: pin, salt: salt);

    return enteredHash == savedHash;
  }

  Future<void> disableLock() async {
    final userId = await _getCurrentUserId();

    await SecureStorage.clearAppLockForUser(userId);
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();

      if (!supported) {
        return false;
      }

      final biometrics = await _localAuth.getAvailableBiometrics();

      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final available = await canUseBiometrics();

      if (!available) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Use sua biometria para desbloquear o Route Cash.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enableBiometrics() async {
    if (!await isLockEnabled()) {
      throw Exception('Configure um PIN antes de ativar a biometria.');
    }

    if (!await canUseBiometrics()) {
      throw Exception('Nenhuma biometria está configurada neste aparelho.');
    }

    final authenticated = await authenticateWithBiometrics();

    if (!authenticated) {
      return false;
    }

    final userId = await _getCurrentUserId();

    await SecureStorage.setBiometricEnabled(userId, true);

    return true;
  }

  Future<void> disableBiometrics() async {
    final userId = await _getCurrentUserId();

    await SecureStorage.setBiometricEnabled(userId, false);
  }
}
