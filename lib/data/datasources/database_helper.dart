import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:dokkan/core/constants/app_strings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const String dbName = 'dokkan.db';
  static const int dbVersion = 2;
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppStrings.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppStrings.dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // جدول التصنيفات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');

    // جدول الزبائن
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول المواد
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        barcode TEXT UNIQUE,
        name TEXT UNIQUE NOT NULL,
        category_id INTEGER,
        current_quantity REAL DEFAULT 0,
        default_sell_price_syp REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // جدول المبيعات
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        sale_date TEXT NOT NULL,
        total_amount_syp REAL NOT NULL,
        total_amount_usd REAL NOT NULL,
        exchange_rate REAL NOT NULL,
        sale_type TEXT DEFAULT 'cash',
        sale_currency TEXT DEFAULT 'SYP',
        discount_amount_syp REAL DEFAULT 0,
        discount_amount_usd REAL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // جدول فواتير المشتريات
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_name TEXT,
        purchase_date TEXT NOT NULL,
        total_amount_syp REAL NOT NULL,
        total_amount_usd REAL NOT NULL,
        exchange_rate REAL NOT NULL,
        purchase_currency TEXT DEFAULT 'SYP'
      )
    ''');

    // جدول الدفعات (مواد المشتريات)
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        purchase_id INTEGER,
        initial_quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        purchase_price_syp REAL NOT NULL,
        exchange_rate REAL NOT NULL,
        cost_usd REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');

    // جدول تفاصيل المبيعات
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        sell_price_syp REAL NOT NULL,
        cost_usd_at_sale REAL NOT NULL,
        profit_usd REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // جدول دفعات الزبائن
    await db.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount_usd REAL NOT NULL,
        amount_syp REAL NOT NULL,
        exchange_rate REAL NOT NULL,
        payment_currency TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // جدول الشركاء
    await db.execute('''
      CREATE TABLE partners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        percentage REAL NOT NULL,
        capital_usd REAL DEFAULT 0
      )
    ''');

    // جدول الربط بين المبيع والدفعات
    await db.execute('''
      CREATE TABLE sale_batch_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_item_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        quantity_taken REAL NOT NULL,
        FOREIGN KEY (sale_item_id) REFERENCES sale_items (id) ON DELETE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES batches (id)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS sale_batch_links');
      await db.execute('DROP TABLE IF EXISTS sale_items');
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS batches');
      await db.execute('DROP TABLE IF EXISTS products');
      await db.execute('DROP TABLE IF EXISTS categories');
      await db.execute('DROP TABLE IF EXISTS partners');
      await _createDB(db, newVersion);
    } else if (oldVersion == 4) {
      // الترقية للإصدار 5 مع الحفاظ على البيانات
      // 1. إضافة جدول الزبائن
      await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          phone TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // 2. إضافة جدول دفعات الزبائن
      await db.execute('''
        CREATE TABLE customer_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          amount_usd REAL NOT NULL,
          amount_syp REAL NOT NULL,
          exchange_rate REAL NOT NULL,
          payment_currency TEXT NOT NULL,
          payment_date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');

      // 3. إضافة أعمدة لجدول المواد
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT UNIQUE');

      // 4. إضافة أعمدة لجدول المبيعات
      await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL');
      await db.execute('ALTER TABLE sales ADD COLUMN sale_type TEXT DEFAULT "cash"');
      await db.execute('ALTER TABLE sales ADD COLUMN sale_currency TEXT DEFAULT "SYP"');
    }

    if (oldVersion < 6) {
      // 1. إضافة جدول المشتريات
      await db.execute('''
        CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_name TEXT,
          purchase_date TEXT NOT NULL,
          total_amount_syp REAL NOT NULL,
          total_amount_usd REAL NOT NULL,
          exchange_rate REAL NOT NULL,
          purchase_currency TEXT DEFAULT 'SYP'
        )
      ''');

      // 2. إضافة أعمدة لجدول المبيعات
      await db.execute('ALTER TABLE sales ADD COLUMN discount_amount_syp REAL DEFAULT 0');
      await db.execute('ALTER TABLE sales ADD COLUMN discount_amount_usd REAL DEFAULT 0');

      // 3. إضافة عمود لجدول الدفعات
      await db.execute('ALTER TABLE batches ADD COLUMN purchase_id INTEGER REFERENCES purchases(id) ON DELETE CASCADE');

      // 4. ترحيل البيانات القديمة للمشتريات (إن وجد)
      final batches = await db.query('batches');
      for (var batch in batches) {
        if (batch['purchase_id'] == null) {
          // إنشاء فاتورة شراء لكل دفعة قديمة للحفاظ على البيانات
          int purchaseId = await db.insert('purchases', {
            'supplier_name': 'مورد قديم',
            'purchase_date': batch['purchase_date'],
            'total_amount_syp': (batch['initial_quantity'] as double) * (batch['purchase_price_syp'] as double),
            'total_amount_usd': (batch['initial_quantity'] as double) * (batch['cost_usd'] as double),
            'exchange_rate': batch['exchange_rate'],
            'purchase_currency': 'SYP'
          });
          
          await db.update('batches', {'purchase_id': purchaseId}, where: 'id = ?', whereArgs: [batch['id']]);
        }
      }
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
