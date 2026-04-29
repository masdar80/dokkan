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
  // Cart for purchase
  final List<Map<String, dynamic>> _purchaseItems = [];
  
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _priceControllerSyp = TextEditingController();
  final _priceControllerUsd = TextEditingController();
  final _supplierController = TextEditingController();
  
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

  void _addItemToList() {
    if (_selectedProduct == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final priceSyp = double.tryParse(_priceControllerSyp.text) ?? 0;
    
    if (qty <= 0 || priceSyp <= 0) return;

    setState(() {
      _purchaseItems.add({
        'productId': _selectedProduct!.id,
        'name': _selectedProduct!.name,
        'quantity': qty,
        'priceSyp': priceSyp,
      });
      _selectedProduct = null;
      _qtyController.text = '1';
      _priceControllerSyp.clear();
      _priceControllerUsd.clear();
    });
  }

  double get _totalSyp => _purchaseItems.fold(0, (sum, item) => sum + (item['quantity'] * item['priceSyp']));

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<ExchangeRateProvider>().currentRate;
    
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل فاتورة مشتريات')),
      body: SafeArea(
        child: Column(
          children: [
            // 1. اختيار المادة وإدخال السعر والكمية
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      ProductSearchField(
                        selectedProduct: _selectedProduct,
                        onSelected: (p) => setState(() => _selectedProduct = p),
                      ),
                      if (_selectedProduct != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyController,
                                decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _isUsdMode ? _priceControllerUsd : _priceControllerSyp,
                                decoration: InputDecoration(
                                  labelText: 'سعر الشراء (${_isUsdMode ? '\$' : 'ل.س'})',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => _calculateOtherCurrency(v, _isUsdMode),
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isUsdMode ? Icons.attach_money : Icons.payments, color: Colors.blue),
                              onPressed: () => setState(() => _isUsdMode = !_isUsdMode),
                            ),
                            ElevatedButton(
                              onPressed: _addItemToList,
                              child: const Text('إضافة'),
                            ),
                          ],
                        ),
                        if (_priceControllerSyp.text.isNotEmpty || _priceControllerUsd.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _isUsdMode ? '≈ ${_priceControllerSyp.text} ل.س' : '≈ ${_priceControllerUsd.text} \$',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
  
            // 2. قائمة المواد المضافة للفاتورة
            Expanded(
              child: _purchaseItems.isEmpty 
                ? const Center(child: Text('قائمة المواد فارغة'))
                : ListView.builder(
                    itemCount: _purchaseItems.length,
                    itemBuilder: (context, index) {
                      final item = _purchaseItems[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('الكمية: ${item['quantity']} × ${item['priceSyp']} ل.س'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(item['quantity'] * item['priceSyp']).toStringAsFixed(0)} ل.س'),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => setState(() => _purchaseItems.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
  
            // 3. ملخص الفاتورة والحفظ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5)],
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(labelText: 'اسم المورد (اختياري)', prefixIcon: Icon(Icons.business)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإجمالي: ${_totalSyp.toStringAsFixed(0)} ل.س', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('بالدولار: ${(_totalSyp / (rate > 0 ? rate : 1)).toStringAsFixed(2)} \$', style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _purchaseItems.isEmpty ? null : () async {
                          await context.read<InventoryProvider>().addPurchaseInvoice(
                            items: _purchaseItems,
                            currentExchangeRate: rate,
                            supplierName: _supplierController.text.isEmpty ? null : _supplierController.text,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ الفاتورة'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
