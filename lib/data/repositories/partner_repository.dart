import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class Partner {
  final int? id;
  final String name;
  final double percentage;
  final double capitalUsd;

  Partner({this.id, required this.name, required this.percentage, required this.capitalUsd});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'percentage': percentage,
    'capital_usd': capitalUsd,
  };

  factory Partner.fromMap(Map<String, dynamic> map) => Partner(
    id: map['id'],
    name: map['name'],
    percentage: map['percentage'],
    capitalUsd: map['capital_usd'],
  );
}

class PartnerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertPartner(Partner partner) async {
    final db = await _dbHelper.database;
    return await db.insert('partners', partner.toMap());
  }

  Future<List<Partner>> getAllPartners() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('partners');
    return List.generate(maps.length, (i) => Partner.fromMap(maps[i]));
  }
}
