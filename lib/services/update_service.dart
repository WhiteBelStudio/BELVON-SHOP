import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});
  final String version;
  final String url;
}

class UpdateService {
  static const currentVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.3.4');
  static const releaseApi =
      'https://api.github.com/repos/WhiteBelStudio/BELVON-SHOP/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    final response = await http.get(
      Uri.parse(releaseApi),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'BELVON-SHOP',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Не удалось проверить обновления');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '')
        .replaceFirst(RegExp(r'^v'), '');
    final url = data['html_url'] as String? ??
        'https://github.com/WhiteBelStudio/BELVON-SHOP/releases';

    if (tag.isEmpty || !_isNewer(tag, currentVersion)) return null;
    return UpdateInfo(version: tag, url: url);
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String value) {
      final core = value.split('+').first.split('-').first;
      final parts = core.split('.');
      return List.generate(
        3,
        (index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
      );
    }

    final remoteParts = parse(remote);
    final localParts = parse(local);

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] != localParts[i]) {
        return remoteParts[i] > localParts[i];
      }
    }
    return false;
  }

  static Future<void> openRelease(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Не удалось открыть страницу обновления');
    }
  }
}
