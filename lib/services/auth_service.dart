import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.blocked,
  });

  final int id;
  final String email;
  final String role;
  final bool blocked;

  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isOwner => role == 'owner';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    email: json['email'] as String,
    role: json['role'] as String? ?? 'customer',
    blocked: json['blocked'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'blocked': blocked,
  };
}

class AuthService {
  static const _legacyTokenKey = 'belvon_auth_token';
  static const _userKey = 'belvon_auth_user';
  static const _deviceKey = 'belvon_device_id';
  static const _secureTokenKey = 'belvon_secure_auth_token';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(),
  );

  static String? _token;
  static AuthUser? _user;
  static String? _deviceId;

  static String? get token => _token;
  static AuthUser? get user => _user;
  static String get deviceId => _deviceId!;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _deviceId = prefs.getString(_deviceKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      final random = Random.secure();
      _deviceId = List.generate(
        24,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      await prefs.setString(_deviceKey, _deviceId!);
    }

    var token = await _secureStorage.read(key: _secureTokenKey);

    // One-time migration from the legacy plaintext token location.
    if (token == null || token.isEmpty) {
      final legacyToken = prefs.getString(_legacyTokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        token = legacyToken;
        await _secureStorage.write(key: _secureTokenKey, value: token);
        await prefs.remove(_legacyTokenKey);
      }
    }

    if (token == null || token.isEmpty || _isExpired(token)) {
      await _clearSessionStorage(prefs);
      return;
    }

    _token = token;

    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _user = AuthUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        _user = null;
      }
    }

    if (_user == null) {
      await _clearSessionStorage(prefs);
    }
  }

  static Future<void> save(String token, AuthUser user) async {
    if (token.trim().isEmpty || _isExpired(token)) {
      throw const FormatException('Недействительный токен авторизации.');
    }

    _token = token;
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _secureTokenKey, value: token);
    await prefs.remove(_legacyTokenKey);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> logout() async {
    _token = null;
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    await _clearSessionStorage(prefs);
  }

  static Future<void> _clearSessionStorage(SharedPreferences prefs) async {
    _token = null;
    _user = null;
    await _secureStorage.delete(key: _secureTokenKey);
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_userKey);
  }

  static bool _isExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      );
      if (payload is! Map) return false;

      final exp = payload['exp'];
      if (exp is! num) return false;

      return DateTime.now().millisecondsSinceEpoch >=
          exp.toInt() * 1000;
    } catch (_) {
      return false;
    }
  }
}
