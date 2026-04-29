import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // تقرير فواتير المبيعات لفترة محددة
  Future<List<Map<String, dynamic>>> getSalesBetween(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id as sale_id, s.sale_date, s.total_amount_syp, s.total_amount_usd, 
             s.exchange_rate, s.sale_currency, s.discount_amount_syp, c.name as customer_name,
             (SELECT COUNT(*) FROM sale_items WHERE sale_id = s.id) as items_count
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE s.sale_date BETWEEN ? AND ?
      ORDER BY s.sale_date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // تقرير فواتير المشتريات لفترة محددة
  Future<List<Map<String, dynamic>>> getPurchasesBetween(DateTime from, DateTime to) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT p.id as purchase_id, p.purchase_date, p.total_amount_syp, p.total_amount_usd, 
             p.exchange_rate, p.purchase_currency, p.supplier_name,
             (SELECT COUNT(*) FROM batches WHERE purchase_id = p.id) as items_count
      FROM purchases p
      WHERE p.purchase_date BETWEEN ? AND ?
      ORDER BY p.purchase_date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // جلب مواد فاتورة مبيع محددة
  Future<List<Map<String, dynamic>>> getSaleInvoiceItems(int saleId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT si.*, p.name as product_name
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);
  }

  // جلب مواد فاتورة شراء محددة
  Future<List<Map<String, dynamic>>> getPurchaseInvoiceItems(int purchaseId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT b.*, p.name as product_name
      FROM batches b
      JOIN products p ON b.product_id = p.id
      WHERE b.purchase_id = ?
    ''', [purchaseId]);
  }

  // جلب ملخصات الأرباح حسب التجميع المطلوب (يومي، شهري، سنوي)
  Future<List<Map<String, dynamic>>> getProfitStats({required String groupBy}) async {
    final db = await _dbHelper.database;
    String dateQuery = '';
    if (groupBy == 'daily') dateQuery = "strftime('%Y-%m-%d', s.sale_date)";
    else if (groupBy == 'monthly') dateQuery = "strftime('%Y-%m', s.sale_date)";
    else if (groupBy == 'yearly') dateQuery = "strftime('%Y', s.sale_date)";

    return await db.rawQuery('''
      SELECT period, SUM(total_syp) as total_syp, SUM(invoice_profit) as total_profit
      FROM (
        SELECT $dateQuery as period, 
               MAX(s.total_amount_syp) as total_syp, 
               (SUM(si.profit_usd) - MAX(s.discount_amount_usd)) as invoice_profit
        FROM sales s
        JOIN sale_items si ON s.id = si.sale_id
        GROUP BY s.id
      )
      GROUP BY period
      ORDER BY period DESC
    ''');
  }

  // جلب تفاصيل يوم محدد (كل فاتورة بيع على حدة)
  Future<List<Map<String, dynamic>>> getDaySalesDetails(String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT s.id as sale_id, s.sale_date, s.total_amount_syp, s.total_amount_usd,
             (SUM(si.profit_usd) - s.discount_amount_usd) as total_profit
      FROM sales s
      JOIN sale_items si ON s.id = si.sale_id
      WHERE strftime('%Y-%m-%d', s.sale_date) = ?
      GROUP BY s.id
      ORDER BY s.sale_date ASC
    ''', [date]);
  }

  // تقرير مخصص مع تجميع ديناميكي
  Future<List<Map<String, dynamic>>> getCustomRangeReport({
    required DateTime from, 
    required DateTime to, 
    required String groupBy 
  }) async {
    final db = await _dbHelper.database;
    String dateQuery = groupBy == 'daily' 
        ? "strftime('%Y-%m-%d', s.sale_date)" 
        : "strftime('%Y-%m', s.sale_date)";

    return await db.rawQuery('''
      SELECT period, SUM(total_syp) as total_syp, SUM(invoice_profit) as total_profit
      FROM (
        SELECT $dateQuery as period, 
               MAX(s.total_amount_syp) as total_syp, 
               (SUM(si.profit_usd) - MAX(s.discount_amount_usd)) as invoice_profit
        FROM sales s
        JOIN sale_items si ON s.id = si.sale_id
        WHERE s.sale_date BETWEEN ? AND ?
        GROUP BY s.id
      )
      GROUP BY period
      ORDER BY period DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }
}
