class Payment {
  final int? id;
  final int customerId;
  final double amountUsd;
  final double amountSyp;
  final double exchangeRate;
  final String paymentCurrency; // 'SYP' or 'USD'
  final DateTime paymentDate;
  final String? notes;

  Payment({
    this.id,
    required this.customerId,
    required this.amountUsd,
    required this.amountSyp,
    required this.exchangeRate,
    required this.paymentCurrency,
    required this.paymentDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount_usd': amountUsd,
      'amount_syp': amountSyp,
      'exchange_rate': exchangeRate,
      'payment_currency': paymentCurrency,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      customerId: map['customer_id'],
      amountUsd: map['amount_usd'],
      amountSyp: map['amount_syp'],
      exchangeRate: map['exchange_rate'],
      paymentCurrency: map['payment_currency'],
      paymentDate: DateTime.parse(map['payment_date']),
      notes: map['notes'],
    );
  }
}
