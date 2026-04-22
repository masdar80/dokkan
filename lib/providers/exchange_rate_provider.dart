import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dokkan/data/datasources/exchange_rate_service.dart';

class ExchangeRateProvider with ChangeNotifier {
  double _currentRate = 0.0;
  bool _isLoading = false;
  final ExchangeRateService _service = ExchangeRateService();

  double get currentRate => _currentRate;
  bool get isLoading => _isLoading;

  ExchangeRateProvider() {
    _loadSavedRate();
  }

  Future<void> _loadSavedRate() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRate = prefs.getDouble('exchange_rate') ?? 0.0;
    notifyListeners();
  }

  Future<double?> fetchFromWeb() async {
    _isLoading = true;
    notifyListeners();
    
    final rate = await _service.fetchExchangeRate();
    
    _isLoading = false;
    notifyListeners();
    return rate;
  }

  Future<void> updateRate(double newRate) async {
    _currentRate = newRate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('exchange_rate', newRate);
    notifyListeners();
  }
}
