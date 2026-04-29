import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class SaleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> processSale({
    required List<Map<String, dynamic>> items, // Each map: {'productId': int, 'quantity': double, 'sellPriceSyp': double}
    required double discountSyp,
    required double currentExchangeRate,
    int? customerId,
    String saleType = 'cash',
    String saleCurrency = 'SYP',
  }) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      double totalInvoiceAmountSyp = 0;
      
      // 1. حساب إجمالي الفاتورة قبل الخصم
      for (var item in items) {
        totalInvoiceAmountSyp += (item['quantity'] as double) * (item['sellPriceSyp'] as double);
      }

      final finalAmountSyp = totalInvoiceAmountSyp - discountSyp;
      final finalAmountUsd = finalAmountSyp / currentExchangeRate;
      final discountUsd = discountSyp / currentExchangeRate;

      // 2. تسجيل رأس الفاتورة في جدول المبيعات
      int saleId = await txn.insert('sales', {
        'customer_id': customerId,
        'sale_date': DateTime.now().toIso8601String(),
        'total_amount_syp': finalAmountSyp,
        'total_amount_usd': finalAmountUsd,
        'exchange_rate': currentExchangeRate,
        'sale_type': saleType,
        'sale_currency': saleCurrency,
        'discount_amount_syp': discountSyp,
        'discount_amount_usd': discountUsd,
      });

      // 3. معالجة كل مادة في الفاتورة
      for (var item in items) {
        final productId = item['productId'] as int;
        final quantity = item['quantity'] as double;
        final sellPriceSyp = item['sellPriceSyp'] as double;

        // جلب الدفعات المتاحة لهذه المادة (FIFO)
        final List<Map<String, dynamic>> batchMaps = await txn.query(
          'batches',
          where: 'product_id = ? AND remaining_quantity > 0',
          whereArgs: [productId],
          orderBy: 'purchase_date ASC',
        );
        
        double remainingToSell = quantity;
        double totalCostUsdAtSale = 0;
        
        List<Map<String, dynamic>> linksToInsert = [];

        for (var map in batchMaps) {
          if (remainingToSell <= 0) break;
          
          var batch = Batch.fromMap(map);
          double takeFromThisBatch = (batch.remainingQuantity >= remainingToSell) 
              ? remainingToSell 
              : batch.remainingQuantity;
              
          totalCostUsdAtSale += takeFromThisBatch * batch.costUsd;
          
          await txn.update(
            'batches',
            {'remaining_quantity': batch.remainingQuantity - takeFromThisBatch},
            where: 'id = ?',
            whereArgs: [batch.id],
          );
          
          linksToInsert.add({
            'batch_id': batch.id,
            'quantity_taken': takeFromThisBatch,
          });

          remainingToSell -= takeFromThisBatch;
        }
        
        if (remainingToSell > 0) {
          throw Exception('الكمية المطلوبة لمادة معينة أكبر من المتوفر في المخزون');
        }

        double itemProfitUsd = (quantity * (sellPriceSyp / currentExchangeRate)) - totalCostUsdAtSale;

        // تسجيل تفاصيل المادة المبيعة
        int saleItemId = await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'sell_price_syp': sellPriceSyp,
          'cost_usd_at_sale': totalCostUsdAtSale,
          'profit_usd': itemProfitUsd,
        });

        // تسجيل روابط الدفعات
        for (var link in linksToInsert) {
          await txn.insert('sale_batch_links', {
            'sale_item_id': saleItemId,
            'batch_id': link['batch_id'],
            'quantity_taken': link['quantity_taken'],
          });
        }

        // تحديث الكمية الإجمالية في جدول المواد
        await txn.execute('''
          UPDATE products 
          SET current_quantity = current_quantity - ? 
          WHERE id = ?
        ''', [quantity, productId]);
      }
    });
  }

  Future<Map<String, double>> getSummaryStats() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    final salesResult = await db.rawQuery('''
      SELECT SUM(total_amount_syp) as total_syp 
      FROM sales 
      WHERE strftime('%Y-%m-%d', sale_date) = ?
    ''', [today]);
    
    final profitResult = await db.rawQuery('''
      SELECT SUM(si.profit_usd) as total_profit, SUM(s.discount_amount_usd) as total_discount
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE strftime('%Y-%m-%d', s.sale_date) = ?
    ''', [today]);
    
    final rawProfit = profitResult.first['total_profit'] as double? ?? 0.0;
    final totalDiscount = profitResult.first['total_discount'] as double? ?? 0.0;

    return {
      'today_sales_syp': salesResult.first['total_syp'] as double? ?? 0.0,
      'today_profit_usd': rawProfit - totalDiscount,
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
