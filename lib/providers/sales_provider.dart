import 'package:flutter/material.dart';
import 'package:dokkan/data/repositories/sale_repository.dart';

class SalesProvider with ChangeNotifier {
  final SaleRepository _saleRepo = SaleRepository();
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  Future<void> recordSale({
    required int productId,
    required double quantity,
    required double sellPriceSyp,
    required double currentExchangeRate,
  }) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      await _saleRepo.processSale(
        productId: productId,
        quantity: quantity,
        sellPriceSyp: sellPriceSyp,
        currentExchangeRate: currentExchangeRate,
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
