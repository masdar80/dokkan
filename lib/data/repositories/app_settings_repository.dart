import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class AppSettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isPinDefault() async {
    final value = await getSetting('pin_is_default');
    return value == null || value == 'true';
  }

  Future<String?> getPinHash() async {
    return await getSetting('admin_pin_hash');
  }

  Future<void> savePinHash(String hash) async {
    await setSetting('admin_pin_hash', hash);
    await setSetting('pin_is_default', 'false');
  }
}
