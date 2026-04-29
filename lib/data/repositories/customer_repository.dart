import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/customer_model.dart';
import 'package:dokkan/data/models/payment_model.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<int> insertPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.insert('customer_payments', payment.toMap());
  }

  // جلب كشف الحساب المدمج (فواتير آجل + دفعات)
  Future<List<Map<String, dynamic>>> getCustomerStatement(int customerId) async {
    final db = await _dbHelper.database;
    
    // جلب المبيعات الآجلة
    final List<Map<String, dynamic>> sales = await db.rawQuery('''
      SELECT 
        'sale' as type,
        id,
        sale_date as date,
        total_amount_usd as debit_usd,
        total_amount_syp as debit_syp,
        0.0 as credit_usd,
        0.0 as credit_syp,
        exchange_rate,
        'فاتورة مبيع رقم ' || id as description
      FROM sales
      WHERE customer_id = ? AND sale_type = 'credit'
    ''', [customerId]);

    // جلب الدفعات
    final List<Map<String, dynamic>> payments = await db.rawQuery('''
      SELECT 
        'payment' as type,
        id,
        payment_date as date,
        0.0 as debit_usd,
        0.0 as debit_syp,
        amount_usd as credit_usd,
        amount_syp as credit_syp,
        exchange_rate,
        CASE 
          WHEN notes IS NOT NULL AND notes != '' THEN 'دفعة: ' || notes 
          ELSE 'تسديد دفعة' 
        END as description
      FROM customer_payments
      WHERE customer_id = ?
    ''', [customerId]);

    // دمج وترتيب حسب التاريخ
    List<Map<String, dynamic>> statement = [...sales, ...payments];
    statement.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    return statement;
  }

  Future<Map<String, double>> getCustomerBalance(int customerId) async {
    final db = await _dbHelper.database;
    
    final salesRes = await db.rawQuery(
      'SELECT SUM(total_amount_usd) as total FROM sales WHERE customer_id = ? AND sale_type = "credit"',
      [customerId]
    );
    final paymentsRes = await db.rawQuery(
      'SELECT SUM(amount_usd) as total FROM customer_payments WHERE customer_id = ?',
      [customerId]
    );

    double debit = (salesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    double credit = (paymentsRes.first['total'] as num?)?.toDouble() ?? 0.0;
    
    return {
      'balance_usd': debit - credit,
    };
  }
}
