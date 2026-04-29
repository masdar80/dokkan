class Batch {
  final int? id;
  final int productId;
  final int? purchaseId;
  final double initialQuantity;
  final double remainingQuantity;
  final double purchasePriceSyp;
  final double exchangeRate;
  final double costUsd;
  final DateTime purchaseDate;

  Batch({
    this.id,
    required this.productId,
    this.purchaseId,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.purchasePriceSyp,
    required this.exchangeRate,
    required this.costUsd,
    required this.purchaseDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'purchase_id': purchaseId,
      'initial_quantity': initialQuantity,
      'remaining_quantity': remainingQuantity,
      'purchase_price_syp': purchasePriceSyp,
      'exchange_rate': exchangeRate,
      'cost_usd': costUsd,
      'purchase_date': purchaseDate.toIso8601String(),
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'],
      productId: map['product_id'],
      purchaseId: map['purchase_id'],
      initialQuantity: map['initial_quantity'],
      remainingQuantity: map['remaining_quantity'],
      purchasePriceSyp: map['purchase_price_syp'],
      exchangeRate: map['exchange_rate'],
      costUsd: map['cost_usd'],
      purchaseDate: DateTime.parse(map['purchase_date']),
    );
  }
}
