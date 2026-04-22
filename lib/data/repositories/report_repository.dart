import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // تقرير المبيعات لفترة محددة
  Future<List<Map<String, dynamic>>> getSalesBetween(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.sale_date, p.name, p.code, si.quantity, si.sell_price_syp, si.profit_usd 
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      JOIN products p ON si.product_id = p.id
      WHERE s.sale_date BETWEEN ? AND ?
      ORDER BY s.sale_date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // تقرير المشتريات لفترة محددة
  Future<List<Map<String, dynamic>>> getPurchasesBetween(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT b.purchase_date, p.name, p.code, b.initial_quantity, b.purchase_price_syp, b.cost_usd, b.exchange_rate
      FROM batches b
      JOIN products p ON b.product_id = p.id
      WHERE b.purchase_date BETWEEN ? AND ?
      ORDER BY b.purchase_date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // جلب ملخصات الأرباح حسب التجميع المطلوب (يومي، شهري، سنوي)
  Future<List<Map<String, dynamic>>> getProfitStats({required String groupBy}) async {
    final db = await _dbHelper.database;
    String dateQuery = '';
    
    if (groupBy == 'daily') {
      dateQuery = "strftime('%Y-%m-%d', s.sale_date)";
    } else if (groupBy == 'monthly') {
      dateQuery = "strftime('%Y-%m', s.sale_date)";
    } else if (groupBy == 'yearly') {
      dateQuery = "strftime('%Y', s.sale_date)";
    }

    return await db.rawQuery('''
      SELECT $dateQuery as period, SUM(s.total_amount_syp) as total_syp, SUM(s.total_amount_usd) as total_usd, SUM(si.profit_usd) as total_profit
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      GROUP BY period
      ORDER BY period DESC
    ''');
  }

  // جلب تفاصيل يوم محدد (كل عملية بيع على حدة)
  Future<List<Map<String, dynamic>>> getDaySalesDetails(String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.sale_date, p.name, si.quantity, si.sell_price_syp, si.profit_usd
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      JOIN products p ON si.product_id = p.id
      WHERE strftime('%Y-%m-%d', s.sale_date) = ?
      ORDER BY s.sale_date ASC
    ''', [date]);
  }

  // تقرير مخصص مع تجميع ديناميكي
  Future<List<Map<String, dynamic>>> getCustomRangeReport({
    required DateTime from, 
    required DateTime to, 
    required String groupBy // 'daily' or 'monthly'
  }) async {
    final db = await _dbHelper.database;
    String dateQuery = groupBy == 'daily' 
        ? "strftime('%Y-%m-%d', s.sale_date)" 
        : "strftime('%Y-%m', s.sale_date)";

    return await db.rawQuery('''
      SELECT $dateQuery as period, SUM(s.total_amount_syp) as total_syp, SUM(si.profit_usd) as total_profit
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      WHERE s.sale_date BETWEEN ? AND ?
      GROUP BY period
      ORDER BY period DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }
}
