import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class BatchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertBatch(Batch batch) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. إضافة الدفعة
      int id = await txn.insert('batches', batch.toMap());
      
      // 2. تحديث الكمية الإجمالية في جدول المواد
      await txn.execute('''
        UPDATE products 
        SET current_quantity = current_quantity + ? 
        WHERE id = ?
      ''', [batch.initialQuantity, batch.productId]);
      
      return id;
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

  // حذف دفعة شراء
  Future<bool> deleteBatch(int id) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 1. جلب بيانات الدفعة للتأكد من الحالة
      final maps = await txn.query('batches', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return false;
      
      final batch = Batch.fromMap(maps.first);
      
      // 2. صمام الأمان: منع الحذف إذا تم بيع أي جزء من الدفعة
      if (batch.remainingQuantity < batch.initialQuantity) {
        return false; 
      }

      // 3. تحديث إجمالي كمية المادة (خصم الكمية التي كانت ستضاف)
      await txn.execute('''
        UPDATE products 
        SET current_quantity = current_quantity - ? 
        WHERE id = ?
      ''', [batch.initialQuantity, batch.productId]);

      // 4. حذف الدفعة
      await txn.delete('batches', where: 'id = ?', whereArgs: [id]);
      return true;
    });
  }
}
