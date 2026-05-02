import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import 'onboarding_service.dart';

/// Combined biometric + PIN authentication for the lock screen.
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Biometric ──────────────────────────────────────────────────────
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'Unlock your document vault',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ─── PIN ────────────────────────────────────────────────────────────
  String _hash(String pin) =>
      sha256.convert(utf8.encode('docshelf::$pin')).toString();

  Future<void> setPin(String fourDigit) async {
    await OnboardingService.instance.setPinHash(_hash(fourDigit));
    await OnboardingService.instance.setHasSetPin(true);
  }

  Future<bool> verifyPin(String fourDigit) async {
    final saved = await OnboardingService.instance.getPinHash();
    if (saved == null) return false;
    final ok = _hash(fourDigit) == saved;
    if (ok) {
      _failed = 0;
      _lockoutUntil = null;
    } else {
      _failed++;
      if (_failed >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        _failed = 0;
      }
    }
    return ok;
  }

  Future<bool> hasPin() async =>
      await OnboardingService.instance.getPinHash() != null;

  Future<void> clearPin() async {
    await OnboardingService.instance.clearPinHash();
    await OnboardingService.instance.setHasSetPin(false);
  }

  Future<bool> isLockEnabled() =>
      OnboardingService.instance.isBiometricEnabled();

  Future<void> setLockEnabled(bool value) =>
      OnboardingService.instance.setBiometricEnabled(value);

  // ─── PIN attempt throttling (in-memory only) ────────────────────────
  int _failed = 0;
  DateTime? _lockoutUntil;

  bool isLockedOut() {
    final until = _lockoutUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _lockoutUntil = null;
      return false;
    }
    return true;
  }

  int secondsUntilUnlock() {
    final until = _lockoutUntil;
    if (until == null) return 0;
    final s = until.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  int get failedAttempts => _failed;
}
