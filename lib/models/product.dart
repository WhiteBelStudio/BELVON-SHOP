class Product {
  final int id;
  final String name;
  final String description;
  final String category;
  final double price;

  const Product({required this.id, required this.name, required this.description, required this.category, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    name: json['name']?.toString() ?? 'Без названия',
    description: json['description']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Без категории',
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'price': price,
  };
}
