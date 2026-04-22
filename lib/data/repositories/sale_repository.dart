import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class SaleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> processSale({
    required int productId,
    required double quantity,
    required double sellPriceSyp,
    required double currentExchangeRate,
  }) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. جلب الدفعات المتاحة لهذه المادة (مرتبة حسب التاريخ - FIFO)
      final List<Map<String, dynamic>> batchMaps = await txn.query(
        'batches',
        where: 'product_id = ? AND remaining_quantity > 0',
        whereArgs: [productId],
        orderBy: 'purchase_date ASC',
      );
      
      double remainingToSell = quantity;
      double totalCostUsdAtSale = 0;
      
      for (var map in batchMaps) {
        if (remainingToSell <= 0) break;
        
        var batch = Batch.fromMap(map);
        double takeFromThisBatch = (batch.remainingQuantity >= remainingToSell) 
            ? remainingToSell 
            : batch.remainingQuantity;
            
        // حساب التكلفة لهذه الجزئية بالدولار
        totalCostUsdAtSale += takeFromThisBatch * batch.costUsd;
        
        // تحديث الدفعة في قاعدة البيانات
        await txn.update(
          'batches',
          {'remaining_quantity': batch.remainingQuantity - takeFromThisBatch},
          where: 'id = ?',
          whereArgs: [batch.id],
        );
        
        remainingToSell -= takeFromThisBatch;
      }
      
      if (remainingToSell > 0) {
        throw Exception('الكمية المطلوبة أكبر من المتوفر في المخزون');
      }

      // 2. تسجيل العملية في جدول المبيعات
      double totalAmountSyp = quantity * sellPriceSyp;
      double totalAmountUsd = totalAmountSyp / currentExchangeRate;
      double profitUsd = totalAmountUsd - totalCostUsdAtSale;

      int saleId = await txn.insert('sales', {
        'sale_date': DateTime.now().toIso8601String(),
        'total_amount_syp': totalAmountSyp,
        'total_amount_usd': totalAmountUsd,
        'exchange_rate': currentExchangeRate,
      });

      // 3. تسجيل تفاصيل المادة المبيعة
      int saleItemId = await txn.insert('sale_items', {
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'sell_price_syp': sellPriceSyp,
        'cost_usd_at_sale': totalCostUsdAtSale,
        'profit_usd': profitUsd,
      });

      // جديد: تسجيل روابط الدفعات للقدرة على الإرجاع
      double tempRemaining = quantity;
      for (var map in batchMaps) {
        if (tempRemaining <= 0) break;
        double take = (map['remaining_quantity'] >= tempRemaining) ? tempRemaining : map['remaining_quantity'];
        
        await txn.insert('sale_batch_links', {
          'sale_item_id': saleItemId,
          'batch_id': map['id'],
          'quantity_taken': take,
        });
        
        tempRemaining -= take;
      }

      // 4. تحديث الكمية الإجمالية في جدول المواد
      await txn.execute('''
        UPDATE products 
        SET current_quantity = current_quantity - ? 
        WHERE id = ?
      ''', [quantity, productId]);
    });
  }

  Future<Map<String, double>> getSummaryStats() async {
    final db = await _dbHelper.database;
    
    final salesResult = await db.rawQuery('SELECT SUM(total_amount_syp) as total_syp, SUM(total_amount_usd) as total_usd FROM sales');
    final profitResult = await db.rawQuery('SELECT SUM(profit_usd) as total_profit FROM sale_items');
    
    return {
      'total_sales_syp': salesResult.first['total_syp'] as double? ?? 0.0,
      'total_sales_usd': salesResult.first['total_usd'] as double? ?? 0.0,
      'total_profit_usd': profitResult.first['total_profit'] as double? ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getDailySalesReport() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.sale_date, p.name, si.quantity, si.sell_price_syp, si.profit_usd 
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      JOIN products p ON si.product_id = p.id
      ORDER BY s.sale_date DESC
    ''');
  }

  // حذف عملية بيع وإرجاع الكميات للمخزون
  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. جلب كافة المواد في هذا المبيع وروابط الدفعات الخاصة بها
      final List<Map<String, dynamic>> items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (var item in items) {
        int itemId = item['id'];
        int productId = item['product_id'];
        double totalQty = item['quantity'];

        // جلب روابط الدفعات لهذا العنصر
        final List<Map<String, dynamic>> links = await txn.query(
          'sale_batch_links',
          where: 'sale_item_id = ?',
          whereArgs: [itemId],
        );

        for (var link in links) {
          int batchId = link['batch_id'];
          double qtyToReturn = link['quantity_taken'];

          // إرجاع الكمية للدفعة الأصلية
          await txn.execute('''
            UPDATE batches 
            SET remaining_quantity = remaining_quantity + ? 
            WHERE id = ?
          ''', [qtyToReturn, batchId]);
        }

        // تحديث إجمالي كمية المادة
        await txn.execute('''
          UPDATE products 
          SET current_quantity = current_quantity + ? 
          WHERE id = ?
        ''', [totalQty, productId]);
      }

      // 2. حذف المبيع (سيؤدي لحذف العناصر والروابط تلقائياً بسبب CASCADE)
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }
}
