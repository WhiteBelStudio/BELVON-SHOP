import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'belvon_favorites';

  static Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const <String>[];
    return values
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  static Future<void> save(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final values = favorites.map((id) => id.toString()).toList();
    await prefs.setStringList(_key, values);
  }
}
