import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class VerificationService {
  static const _trustedKey = 'belvon_trusted_device';
  static String? _pendingCode;
  static DateTime? _expiresAt;

  static Future<bool> isTrustedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trustedKey) ?? false;
  }

  static Future<String> createCode() async {
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    _pendingCode = code;
    _expiresAt = DateTime.now().add(const Duration(minutes: 5));
    return code;
  }

  static bool verify(String code) {
    if (_pendingCode == null || _expiresAt == null) return false;
    if (DateTime.now().isAfter(_expiresAt!)) {
      _pendingCode = null;
      _expiresAt = null;
      return false;
    }
    final ok = code.trim() == _pendingCode;
    if (ok) {
      _pendingCode = null;
      _expiresAt = null;
    }
    return ok;
  }

  static Future<void> trustDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trustedKey, true);
  }
}
