import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

class DataSyncService {
  static const _productsKey = 'belvon_catalog_cache_v1';
  static const _syncedAtKey = 'belvon_catalog_synced_at_v1';

  static Future<List<Product>?> loadCachedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_productsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProducts(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(products.map((product) => product.toJson()).toList());
    await prefs.setString(_productsKey, payload);
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime?> lastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_syncedAtKey);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_productsKey);
    await prefs.remove(_syncedAtKey);
  }
}
