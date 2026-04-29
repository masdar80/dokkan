import 'package:flutter/material.dart';
import 'package:dokkan/data/repositories/sale_repository.dart';

class SalesProvider with ChangeNotifier {
  final SaleRepository _saleRepo = SaleRepository();
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  Future<void> recordSale({
    required List<Map<String, dynamic>> items,
    required double discountSyp,
    required double currentExchangeRate,
    int? customerId,
    String saleType = 'cash',
    String saleCurrency = 'SYP',
  }) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      await _saleRepo.processSale(
        items: items,
        discountSyp: discountSyp,
        currentExchangeRate: currentExchangeRate,
        customerId: customerId,
        saleType: saleType,
        saleCurrency: saleCurrency,
      );
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> deleteSale(int saleId) async {
    _isProcessing = true;
    notifyListeners();
    try {
      await _saleRepo.deleteSale(saleId);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
