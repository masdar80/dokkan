import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getAllCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> updateCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    // نقل المنتجات التابعة لهذا التصنيف إلى "بدون تصنيف"
    await db.update(
      'products',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
