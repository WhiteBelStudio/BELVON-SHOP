import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});
  final String version;
  final String url;
}

class UpdateService {
  static const currentVersion = '1.3.0';
  static const releaseApi =
      'https://api.github.com/repos/WhiteBelStudio/BELVON-SHOP/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    final response = await http
        .get(Uri.parse(releaseApi), headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'BELVON-SHOP',
        })
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Не удалось проверить обновления');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
    final url = data['html_url'] as String? ??
        'https://github.com/WhiteBelStudio/BELVON-SHOP/releases';
    if (tag.isEmpty || !_isNewer(tag, currentVersion)) return null;
    return UpdateInfo(version: tag, url: url);
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String value) => value.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parse(remote);
    final b = parse(local);
    for (var i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  static Future<void> openRelease(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw Exception('Не удалось открыть страницу обновления');
    }
  }
}
