import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && AuthService.token != null) {
      headers['Authorization'] = 'Bearer ${AuthService.token}';
    }

    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    final encoded = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: encoded);
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        throw Exception('Unsupported method');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['detail']?.toString() ?? 'Ошибка API')
          : 'Ошибка API (${response.statusCode})';
      throw Exception(message);
    }

    return decoded;
  }

  static Future<AuthUser> login(String email, String password) async {
    final data = await request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;

    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await AuthService.save(data['access_token'] as String, user);
    return user;
  }
}
