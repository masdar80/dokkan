class Product {
  final int? id;
  final String code;
  final String name;
  final int? categoryId;
  final double currentQuantity;
  final double defaultSellPriceSyp;
  final DateTime createdAt;

  Product({
    this.id,
    required this.code,
    required this.name,
    this.categoryId,
    this.currentQuantity = 0,
    this.defaultSellPriceSyp = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category_id': categoryId,
      'current_quantity': currentQuantity,
      'default_sell_price_syp': defaultSellPriceSyp,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      code: map['code'] ?? '',
      name: map['name'],
      categoryId: map['category_id'],
      currentQuantity: map['current_quantity'],
      defaultSellPriceSyp: map['default_sell_price_syp'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Product copyWith({
    int? id,
    String? code,
    String? name,
    int? categoryId,
    double? currentQuantity,
    double? defaultSellPriceSyp,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      defaultSellPriceSyp: defaultSellPriceSyp ?? this.defaultSellPriceSyp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
