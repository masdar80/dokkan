import 'package:flutter/material.dart';
import 'package:dokkan/data/models/customer_model.dart';
import 'package:dokkan/data/models/payment_model.dart';
import 'package:dokkan/data/repositories/customer_repository.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Customer> _customers = [];
  List<Map<String, dynamic>> _currentStatement = [];
  Map<String, double> _currentBalance = {'balance_usd': 0.0};
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  List<Map<String, dynamic>> get currentStatement => _currentStatement;
  Map<String, double> get currentBalance => _currentBalance;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();
    _customers = await _customerRepo.getAllCustomers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCustomer(String name, String? phone) async {
    final customer = Customer(
      name: name,
      phone: phone,
      createdAt: DateTime.now(),
    );
    await _customerRepo.insertCustomer(customer);
    await loadCustomers();
  }

  Future<void> loadStatement(int customerId) async {
    _isLoading = true;
    notifyListeners();
    _currentStatement = await _customerRepo.getCustomerStatement(customerId);
    _currentBalance = await _customerRepo.getCustomerBalance(customerId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPayment({
    required int customerId,
    required double amount,
    required String currency, // 'SYP' or 'USD'
    required double exchangeRate,
    String? notes,
  }) async {
    double amountUsd = (currency == 'USD') ? amount : amount / exchangeRate;
    double amountSyp = (currency == 'SYP') ? amount : amount * exchangeRate;

    final payment = Payment(
      customerId: customerId,
      amountUsd: amountUsd,
      amountSyp: amountSyp,
      exchangeRate: exchangeRate,
      paymentCurrency: currency,
      paymentDate: DateTime.now(),
      notes: notes,
    );

    await _customerRepo.insertPayment(payment);
    await loadStatement(customerId);
  }
}
