import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/data/models/category_model.dart';
import 'package:dokkan/data/repositories/product_repository.dart';
import 'package:dokkan/data/repositories/category_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Batch;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io' as io;

class DataService {
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  // --- 1. النسخ الاحتياطي الكامل (قاعدة البيانات) ---
  
  Future<bool> exportFullBackup() async {
    try {
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await databaseFactoryFfiWeb.readDatabaseBytes('dokkan.db');
      } else {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'dokkan.db');
        final file = io.File(path);
        if (!await file.exists()) return false;
        bytes = await file.readAsBytes();
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: 'dokkan_backup_${DateTime.now().millisecondsSinceEpoch}.db',
        bytes: bytes,
      );

      return outputFile != null;
    } catch (e) {
      debugPrint('Backup error: $e');
      return false;
    }
  }

  Future<bool> importFullBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final bytes = kIsWeb 
            ? result.files.single.bytes 
            : await io.File(result.files.single.path!).readAsBytes();
        
        if (bytes == null) return false;

        // إغلاق قاعدة البيانات قبل الاستبدال
        await DatabaseHelper.instance.close();

        if (kIsWeb) {
          await databaseFactoryFfiWeb.writeDatabaseBytes('dokkan.db', bytes);
        } else {
          final dbPath = await getDatabasesPath();
          final path = join(dbPath, 'dokkan.db');
          await io.File(path).writeAsBytes(bytes);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  // --- 2. تصدير واستيراد جزئي (JSON) ---

  Future<bool> exportProductsToJSON() async {
    try {
      final categories = await _categoryRepo.getAllCategories();
      final products = await _productRepo.getAllProducts();

      final data = {
        'categories': categories.map((c) => c.toMap()).toList(),
        'products': products.map((p) => p.toMap()).toList(),
      };

      String jsonString = jsonEncode(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير المواد',
        fileName: 'dokkan_items.json',
        bytes: bytes,
      );

      return outputFile != null;
    } catch (e) {
      debugPrint('JSON Export error: $e');
      return false;
    }
  }

  Future<bool> importProductsFromJSON() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // مهم جداً للويب والجوال معاً
      );

      if (result == null) return false;

      final bytes = result.files.single.bytes;
      if (bytes == null) return false;
      
      String content = utf8.decode(bytes);
      Map<String, dynamic> data = jsonDecode(content);

      // 1. استيراد التصنيفات
      final List cats = (data['categories'] as List?) ?? [];
      Map<int, int> categoryIdMap = {}; 

      for (var item in cats) {
        final catMap = item as Map<String, dynamic>;
        int oldId = catMap['id'] as int;
        String catName = catMap['name'] as String;

        final existingCats = await _categoryRepo.getAllCategories();
        final existing = existingCats.where((c) => c.name == catName);
        
        if (existing.isNotEmpty) {
          categoryIdMap[oldId] = existing.first.id!;
        } else {
          int newId = await _categoryRepo.insertCategory(Category(name: catName));
          categoryIdMap[oldId] = newId;
        }
      }

      // 2. استيراد المواد
      final List prods = (data['products'] as List?) ?? [];
      for (var item in prods) {
        final prodMap = item as Map<String, dynamic>;
        final product = Product.fromMap(prodMap);
        int? newCatId = product.categoryId != null ? categoryIdMap[product.categoryId] : null;

        // التحقق إذا كانت المادة موجودة بالرمز
        final existing = await _productRepo.getProductByCode(product.code);
        
        if (existing != null) {
          // تحديث البيانات الأساسية فقط
          final updated = existing.copyWith(
            name: product.name,
            categoryId: newCatId,
            defaultSellPriceSyp: product.defaultSellPriceSyp,
          );
          await _productRepo.updateProduct(updated);
        } else {
          // إضافة مادة جديدة
          final newProd = product.copyWith(categoryId: newCatId, currentQuantity: 0);
          await _productRepo.insertProduct(newProd);
        }
      }
      return true;
    } catch (e) {
      debugPrint('JSON Import error: $e');
      return false;
    }
  }
}
