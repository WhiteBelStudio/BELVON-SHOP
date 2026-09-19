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

    headers['X-Device-ID'] = AuthService.deviceId;
    headers['X-Device-Name'] = 'BELVON SHOP';

    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    final encoded = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: encoded);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
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

  static Future<AuthUser> ownerLogin(
    String email,
    String password,
    String secondPassword,
  ) async {
    return _login('/auth/owner-login', {
      'email': email,
      'password': password,
      'second_password': secondPassword,
    });
  }

  static Future<Map<String, dynamic>> secureLogin(
    String email,
    String password,
  ) async {
    return await request(
      'POST',
      '/auth/login-secure',
      body: {
        'email': email,
        'password': password,
        'device_id': AuthService.deviceId,
        'device_name': 'BELVON SHOP',
      },
      auth: false,
    ) as Map<String, dynamic>;
  }

  static Future<AuthUser> register(String email, String password) async {
    final data = await request(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;

    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await AuthService.save(data['access_token'] as String, user);
    return user;
  }

  static Future<Map<String, dynamic>> deviceStatus(String requestId) async {
    return await request(
      'GET',
      '/auth/device-status/$requestId',
      auth: false,
    ) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> deviceRequests() async {
    return await request('GET', '/auth/device-requests') as List<dynamic>;
  }

  static Future<void> decideDeviceRequest(
    String requestId,
    bool approved,
  ) async {
    await request(
      'POST',
      '/auth/device-requests/$requestId/decision',
      body: {'approved': approved},
    );
  }

  static Future<AuthUser> login(String email, String password) async {
    return _login('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  static Future<AuthUser> _login(
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await request(
      'POST',
      path,
      body: body,
      auth: false,
    ) as Map<String, dynamic>;

    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await AuthService.save(data['access_token'] as String, user);
    return user;
  }
}
