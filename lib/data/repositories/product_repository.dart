import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:sqflite/sqflite.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    
    // 1. فحص حركات المبيع
    final sales = await db.query('sale_items', where: 'product_id = ?', whereArgs: [id]);
    if (sales.isNotEmpty) {
      return -1; // رمز: يوجد مبيعات
    }

    // 2. فحص حركات الشراء (الدفعات)
    final batches = await db.query('batches', where: 'product_id = ?', whereArgs: [id]);
    if (batches.isNotEmpty) {
      return -2; // رمز: يوجد مشتريات
    }

    // 3. إذا كان السجل نظيفاً تماماً، اسمح بالحذف
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'name LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProductByCode(String code) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }
}
