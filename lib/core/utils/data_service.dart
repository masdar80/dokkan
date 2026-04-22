import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dokkan/data/datasources/database_helper.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/data/models/category_model.dart';
import 'package:dokkan/data/repositories/product_repository.dart';
import 'package:dokkan/data/repositories/category_repository.dart';
import 'package:dokkan/data/repositories/batch_repository.dart';
import 'package:dokkan/data/models/batch_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide Batch;

class DataService {
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final BatchRepository _batchRepo = BatchRepository();

  // --- 1. النسخ الاحتياطي الكامل (قاعدة البيانات) ---
  
  Future<bool> exportFullBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'dokkan.db');
      final file = File(path);

      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: 'dokkan_backup_${DateTime.now().millisecondsSinceEpoch}.db',
        bytes: bytes,
      );

      return outputFile != null;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  Future<bool> importFullBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'dokkan.db');

        // إغلاق قاعدة البيانات قبل الاستبدال
        await DatabaseHelper.instance.close();
        
        await file.copy(path);
        return true;
      }
      return false;
    } catch (e) {
      print('Restore error: $e');
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
      print('JSON Export error: $e');
      return false;
    }
  }

  Future<bool> importProductsFromJSON() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return false;

      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> data = jsonDecode(content);

      // 1. استيراد التصنيفات
      final List cats = data['categories'];
      Map<int, int> categoryIdMap = {}; // خرائط لربط المعرفات القديمة بالجديدة

      for (var catMap in cats) {
        int oldId = catMap['id'];
        // التحقق إذا كان التصنيف موجوداً بنفس الاسم
        final existingCats = await _categoryRepo.getAllCategories();
        final existing = existingCats.where((c) => c.name == catMap['name']);
        
        if (existing.isNotEmpty) {
          categoryIdMap[oldId] = existing.first.id!;
        } else {
          int newId = await _categoryRepo.insertCategory(Category(name: catMap['name']));
          categoryIdMap[oldId] = newId;
        }
      }

      // 2. استيراد المواد
      final List prods = data['products'];
      for (var prodMap in prods) {
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
      print('JSON Import error: $e');
      return false;
    }
  }
}
