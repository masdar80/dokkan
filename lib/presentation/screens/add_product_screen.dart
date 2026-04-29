import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/data/models/category_model.dart';

import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  Category? _selectedCategory;

  Future<void> _scanBarcode() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666', 
        'إلغاء', 
        true, 
        ScanMode.BARCODE,
      );
      if (barcodeScanRes != '-1') {
        setState(() {
          _barcodeController.text = barcodeScanRes;
        });
      }
    } catch (e) {
      debugPrint('Barcode scan error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة مادة جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // اسم المادة
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المادة',
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال اسم المادة';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // الباركود
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'الباركود (اختياري)',
                        prefixIcon: Icon(Icons.qr_code_scanner),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          // التحقق من التفرد سيتم برمجياً قبل الحفظ أو هنا
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.camera_alt),
                    tooltip: 'مسح باركود',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // رمز المادة
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'رمز المادة (اختياري)',
                  hintText: 'سيتم توليد رمز تلقائي إذا ترك فارغاً',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),

              // التصنيف
              Consumer<InventoryProvider>(
                builder: (context, provider, _) {
                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'تصنيف المادة',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: provider.categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.name));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                    validator: (value) {
                      if (value == null) return 'يرجى اختيار تصنيف';
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // سعر البيع
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'سعر البيع الافتراضي',
                  prefixIcon: Icon(Icons.sell),
                  suffixText: 'ل.س',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
                  if (double.tryParse(value) == null) return 'يرجى إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final provider = context.read<InventoryProvider>();
                    
                    // التحقق من تكرار الباركود
                    if (_barcodeController.text.isNotEmpty) {
                      bool exists = await provider.isBarcodeExists(_barcodeController.text);
                      if (exists) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('هذا الباركود مستخدم مسبقاً لمادة أخرى!'), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }
                    }

                    await provider.addProduct(
                      name: _nameController.text,
                      code: _codeController.text,
                      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
                      categoryId: _selectedCategory?.id,
                      defaultPrice: double.parse(_priceController.text),
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('حفظ المادة', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
