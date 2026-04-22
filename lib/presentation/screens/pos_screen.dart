import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/providers/sales_provider.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/presentation/widgets/product_search_field.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل عملية بيع'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // اختيار المادة بالبحث
              ProductSearchField(
                selectedProduct: _selectedProduct,
                onSelected: (product) {
                  setState(() {
                    _selectedProduct = product;
                    _priceController.text = product.defaultSellPriceSyp.toString();
                  });
                },
              ),
              const SizedBox(height: 16),
              
              if (_selectedProduct != null) ...[
                Consumer<ExchangeRateProvider>(
                  builder: (context, exProvider, _) {
                    final sellPriceUsd = (double.tryParse(_priceController.text) ?? 0) / exProvider.currentRate;
                    // ملاحظة: التكلفة هنا تقديرية لأحدث سعر شراء، أو يمكن جلبها من المستودع بدقة أكبر
                    // سنفترض مؤقتاً عرض تحذير بسيط إذا كان السعر منخفضاً جداً
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المتوفر حالياً: ${_selectedProduct!.currentQuantity}',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                        if (sellPriceUsd > 0) 
                          Text(
                            'سعر البيع بالدولار: ${sellPriceUsd.toStringAsFixed(2)} \$',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              // الكمية
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'الكمية المباعة',
                  prefixIcon: Icon(Icons.shopping_basket),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
                  final qty = double.tryParse(value);
                  if (qty == null) return 'يرجى إدخال رقم صحيح';
                  if (_selectedProduct != null && qty > _selectedProduct!.currentQuantity) {
                    return 'الكمية أكبر من المتوفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // سعر البيع
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'سعر مبيع القطعة (بالليرة)',
                  prefixIcon: Icon(Icons.sell),
                  suffixText: 'ل.س',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
                  return null;
                },
              ),
              
              const Spacer(),
              
              Consumer<SalesProvider>(
                builder: (context, salesProvider, _) {
                  return ElevatedButton(
                    onPressed: salesProvider.isProcessing ? null : () async {
                      if (_formKey.currentState!.validate() && _selectedProduct != null) {
                        final exProvider = context.read<ExchangeRateProvider>();
                        final invProvider = context.read<InventoryProvider>();
                        
                        final rate = exProvider.currentRate;
                        final sellPriceUsd = (double.tryParse(_priceController.text) ?? 0) / rate;
                        final costUsd = await invProvider.getProductCost(_selectedProduct!.id!);

                        if (sellPriceUsd < costUsd) {
                          // تظهر نافذة التنبيه عند البيع بخسارة
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('تنبيه: بيع بخسارة'),
                                ],
                              ),
                              content: Text(
                                'سعر البيع (${sellPriceUsd.toStringAsFixed(2)}\$) أقل من سعر التكلفة (${costUsd.toStringAsFixed(2)}\$).\n\nهل أنت متأكد من إتمام عملية البيع؟',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text('إتمام رغم الخسارة'),
                                ),
                              ],
                            ),
                          );
                          
                          if (proceed != true) return;
                        }

                        try {
                          await salesProvider.recordSale(
                            productId: _selectedProduct!.id!,
                            quantity: double.parse(_quantityController.text),
                            sellPriceSyp: double.parse(_priceController.text),
                            currentExchangeRate: rate,
                          );
                          
                          if (mounted) {
                            context.read<InventoryProvider>().loadProducts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تمت العملية بنجاح')),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: salesProvider.isProcessing 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تأكيد البيع', style: TextStyle(fontSize: 18)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
