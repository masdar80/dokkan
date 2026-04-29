import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class BatchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertBatch(Batch batch) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      int id = await txn.insert('batches', batch.toMap());
      await txn.execute('''
        UPDATE products 
        SET current_quantity = current_quantity + ? 
        WHERE id = ?
      ''', [batch.initialQuantity, batch.productId]);
      return id;
    });
  }

  Future<void> processPurchaseInvoice({
    required List<Map<String, dynamic>> items, // Each map: {'productId': int, 'quantity': double, 'priceSyp': double}
    required double exchangeRate,
    String? supplierName,
    String purchaseCurrency = 'SYP',
  }) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      double totalAmountSyp = 0;
      double totalAmountUsd = 0;
      
      for (var item in items) {
        totalAmountSyp += (item['quantity'] as double) * (item['priceSyp'] as double);
      }
      totalAmountUsd = totalAmountSyp / exchangeRate;

      // 1. تسجيل رأس فاتورة الشراء
      int purchaseId = await txn.insert('purchases', {
        'supplier_name': supplierName ?? 'مورد عام',
        'purchase_date': DateTime.now().toIso8601String(),
        'total_amount_syp': totalAmountSyp,
        'total_amount_usd': totalAmountUsd,
        'exchange_rate': exchangeRate,
        'purchase_currency': purchaseCurrency,
      });

      // 2. تسجيل المواد (الدفعات)
      for (var item in items) {
        final qty = item['quantity'] as double;
        final priceSyp = item['priceSyp'] as double;
        final productId = item['productId'] as int;

        await txn.insert('batches', {
          'product_id': productId,
          'purchase_id': purchaseId,
          'initial_quantity': qty,
          'remaining_quantity': qty,
          'purchase_price_syp': priceSyp,
          'exchange_rate': exchangeRate,
          'cost_usd': priceSyp / exchangeRate,
          'purchase_date': DateTime.now().toIso8601String(),
        });

        // 3. تحديث الكمية في جدول المواد
        await txn.execute('''
          UPDATE products 
          SET current_quantity = current_quantity + ? 
          WHERE id = ?
        ''', [qty, productId]);
      }
    });
  }

  Future<List<Batch>> getBatchesForProduct(int productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'product_id = ? AND remaining_quantity > 0',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC',
    );
    return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
  }

  Future<List<Batch>> getActiveBatchesForProduct(int productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'product_id = ? AND remaining_quantity > 0',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC', // لضمان تطبيق FIFO
    );
    return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
  }

  // تحديث بيانات دفعة (سعر أو تاريخ)
  Future<int> updateBatch(Batch batch) async {
    final db = await _dbHelper.database;
    return await db.update(
      'batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  // حذف فاتورة شراء بالكامل
  Future<bool> deletePurchaseInvoice(int purchaseId) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 1. جلب الدفعات المرتبطة بهذه الفاتورة
      final batches = await txn.query('batches', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      if (batches.isEmpty) return false;
      
      // 2. صمام الأمان: منع الحذف إذا تم بيع أي جزء من أي دفعة في هذه الفاتورة
      for (var map in batches) {
        if ((map['remaining_quantity'] as double) < (map['initial_quantity'] as double)) {
          return false; 
        }
      }

      // 3. تحديث إجمالي الكميات في جدول المواد وتجفيف الدفعات
      for (var map in batches) {
        double qty = map['initial_quantity'] as double;
        int productId = map['product_id'] as int;

        await txn.execute('''
          UPDATE products 
          SET current_quantity = current_quantity - ? 
          WHERE id = ?
        ''', [qty, productId]);
      }

      // 4. حذف الفاتورة (سيؤدي لحذف الدفعات تلقائياً بسبب CASCADE)
      await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);
      return true;
    });
  }
}
