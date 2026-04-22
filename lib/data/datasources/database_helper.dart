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

    // جدول المواد
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT UNIQUE NOT NULL,
        category_id INTEGER,
        current_quantity REAL DEFAULT 0,
        default_sell_price_syp REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // جدول الدفعات
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        initial_quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        purchase_price_syp REAL NOT NULL,
        exchange_rate REAL NOT NULL,
        cost_usd REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // جدول المبيعات
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_date TEXT NOT NULL,
        total_amount_syp REAL NOT NULL,
        total_amount_usd REAL NOT NULL,
        exchange_rate REAL NOT NULL
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
      // تحديث بسيط للتطوير: حذف الجداول وإعادة إنشائها (لضمان سلامة الهيكل الجديد)
      // في التطبيقات الإنتاجية نستخدم ALTER TABLE
      await db.execute('DROP TABLE IF EXISTS sale_batch_links');
      await db.execute('DROP TABLE IF EXISTS sale_items');
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS batches');
      await db.execute('DROP TABLE IF EXISTS products');
      await db.execute('DROP TABLE IF EXISTS categories');
      await db.execute('DROP TABLE IF EXISTS partners');
      await _createDB(db, newVersion);
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
