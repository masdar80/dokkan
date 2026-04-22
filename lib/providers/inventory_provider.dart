import 'package:flutter/material.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/data/models/category_model.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:dokkan/data/repositories/product_repository.dart';
import 'package:dokkan/data/repositories/category_repository.dart';
import 'package:dokkan/data/repositories/batch_repository.dart';
import 'package:dokkan/core/utils/utils.dart';

class InventoryProvider with ChangeNotifier {
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final BatchRepository _batchRepo = BatchRepository();

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  InventoryProvider() {
    loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([
      loadProducts(),
      loadCategories(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _products = await _productRepo.getAllProducts();
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _categoryRepo.getAllCategories();
    notifyListeners();
  }

  // إدارة المواد
  Future<void> addProduct({
    required String name,
    String? code,
    int? categoryId,
    required double defaultPrice,
  }) async {
    final finalCode = (code == null || code.isEmpty) ? Utils.generateProductCode() : code;
    
    final product = Product(
      code: finalCode,
      name: name,
      categoryId: categoryId,
      defaultSellPriceSyp: defaultPrice,
      createdAt: DateTime.now(),
    );
    await _productRepo.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _productRepo.updateProduct(product);
    await loadProducts();
  }

  Future<int> deleteProduct(int id) async {
    final result = await _productRepo.deleteProduct(id);
    if (result > 0) {
      await loadProducts();
    }
    return result;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await loadProducts();
    } else {
      _products = await _productRepo.searchProducts(query);
      notifyListeners();
    }
  }

  // إدارة التصنيفات
  Future<void> addCategory(String name) async {
    await _categoryRepo.insertCategory(Category(name: name));
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await _categoryRepo.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _categoryRepo.deleteCategory(id);
    await loadCategories();
  }

  // إدارة المشتريات
  Future<void> addPurchase({
    required int productId,
    required double quantity,
    required double priceSyp,
    required double currentExchangeRate,
  }) async {
    final batch = Batch(
      productId: productId,
      initialQuantity: quantity,
      remainingQuantity: quantity,
      purchasePriceSyp: priceSyp,
      exchangeRate: currentExchangeRate,
      costUsd: priceSyp / currentExchangeRate,
      purchaseDate: DateTime.now(),
    );
    
    await _batchRepo.insertBatch(batch);
    await loadProducts();
  }

  // جلب تكلفة القطعة (لأقدم دفعة متوفرة)
  Future<double> getProductCost(int productId) async {
    final batches = await _batchRepo.getActiveBatchesForProduct(productId);
    if (batches.isNotEmpty) {
      return batches.first.costUsd;
    }
    return 0;
  }
  

  Future<bool> deleteBatch(int id) async {
    final success = await _batchRepo.deleteBatch(id);
    if (success) {
      await loadProducts();
    }
    return success;
  }
}
