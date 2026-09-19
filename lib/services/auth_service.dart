import 'dart:convert';

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
  static const _tokenKey = 'belvon_auth_token';
  static const _userKey = 'belvon_auth_user';

  static String? _token;
  static AuthUser? _user;

  static String? get token => _token;
  static AuthUser? get user => _user;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
  }

  static Future<void> save(String token, AuthUser user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
