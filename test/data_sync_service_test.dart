import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belvon_shop/models/product.dart';
import 'package:belvon_shop/services/data_sync_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalog cache round-trips product data', () async {
    const source = <Product>[
      Product(
        id: 42,
        name: 'Тестовый товар',
        description: 'Описание',
        category: 'Тест',
        price: 1234.5,
      ),
    ];

    await DataSyncService.saveProducts(source);

    final restored = await DataSyncService.loadCachedProducts();

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
    expect(restored!.single.id, 42);
    expect(restored.single.name, 'Тестовый товар');
    expect(restored.single.price, 1234.5);
    expect(await DataSyncService.lastSync(), isNotNull);
  });

  test('clearCache removes catalog snapshot and timestamp', () async {
    await DataSyncService.saveProducts(const <Product>[
      Product(
        id: 1,
        name: 'Cache',
        description: '',
        category: 'Test',
        price: 1,
      ),
    ]);

    await DataSyncService.clearCache();

    expect(await DataSyncService.loadCachedProducts(), isNull);
    expect(await DataSyncService.lastSync(), isNull);
  });
}
