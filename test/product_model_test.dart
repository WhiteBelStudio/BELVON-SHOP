import 'package:flutter_test/flutter_test.dart';

import 'package:belvon_shop/models/product.dart';

void main() {
  test('product JSON round-trip preserves catalog fields', () {
    const source = Product(
      id: 7,
      name: 'Тестовый товар',
      description: 'Описание',
      category: 'Тест',
      price: 1990,
    );

    final restored = Product.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.description, source.description);
    expect(restored.category, source.category);
    expect(restored.price, source.price);
  });

  test('product JSON applies safe defaults for optional fields', () {
    final product = Product.fromJson({
      'id': 9,
      'name': 'Минимальный товар',
      'price': 10,
    });

    expect(product.id, 9);
    expect(product.name, 'Минимальный товар');
    expect(product.description, isEmpty);
    expect(product.category, 'Без категории');
    expect(product.price, 10);
  });
}
