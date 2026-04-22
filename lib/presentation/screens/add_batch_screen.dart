import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/presentation/widgets/product_search_field.dart';

class AddBatchScreen extends StatefulWidget {
  final Product? initialProduct;
  const AddBatchScreen({super.key, this.initialProduct});

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _priceControllerSyp = TextEditingController();
  final _priceControllerUsd = TextEditingController();
  bool _isUsdMode = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  void _calculateOtherCurrency(String value, bool isFromUsd) {
    final rate = context.read<ExchangeRateProvider>().currentRate;
    if (rate == 0) return;
    
    final input = double.tryParse(value) ?? 0;
    if (isFromUsd) {
      _priceControllerSyp.text = (input * rate).toStringAsFixed(0);
    } else {
      _priceControllerUsd.text = (input / rate).toStringAsFixed(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل مشتريات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // البحث عن المادة
              ProductSearchField(
                selectedProduct: _selectedProduct,
                onSelected: (p) => setState(() => _selectedProduct = p),
              ),
              const SizedBox(height: 16),
              
              // الكمية
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'الكمية المشتراة',
                  prefixIcon: Icon(Icons.add_shopping_cart),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // اختيار عملة الشراء
              Row(
                children: [
                  const Text('عملة الشراء:'),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('ليرة سورية'),
                    selected: !_isUsdMode,
                    onSelected: (val) => setState(() => _isUsdMode = !val),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('دولار أمريكي'),
                    selected: _isUsdMode,
                    onSelected: (val) => setState(() => _isUsdMode = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // حقول السعر
              TextFormField(
                controller: _isUsdMode ? _priceControllerUsd : _priceControllerSyp,
                decoration: InputDecoration(
                  labelText: _isUsdMode ? 'سعر شراء القطعة (بالدولار)' : 'سعر شراء القطعة (بالليرة)',
                  prefixIcon: Icon(_isUsdMode ? Icons.attach_money : Icons.payments),
                  suffixText: _isUsdMode ? '\$' : 'SYP',
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _calculateOtherCurrency(val, _isUsdMode),
                validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              
              // عرض السعر المقابل
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _isUsdMode 
                      ? 'يعادل تقريباً: ${_priceControllerSyp.text} ل.س'
                      : 'يعادل تقريباً: ${_priceControllerUsd.text} \$',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() && _selectedProduct != null) {
                    final rate = context.read<ExchangeRateProvider>().currentRate;
                    await context.read<InventoryProvider>().addPurchase(
                      productId: _selectedProduct!.id!,
                      quantity: double.parse(_quantityController.text),
                      priceSyp: double.parse(_priceControllerSyp.text),
                      currentExchangeRate: rate,
                    );
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('إضافة للمخزون', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
