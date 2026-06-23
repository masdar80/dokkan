import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/auth_provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/providers/sales_provider.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:dokkan/presentation/widgets/product_search_field.dart';
import 'package:dokkan/providers/customer_provider.dart';
import 'package:dokkan/data/models/customer_model.dart';
import 'package:dokkan/presentation/screens/barcode_scanner_screen.dart';
import 'package:dokkan/presentation/screens/role_selection_screen.dart';
import 'package:intl/intl.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Cart state
  final List<Map<String, dynamic>> _cartItems = [];
  
  // Selection state
  Product? _selectedProduct;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  
  // Invoice settings
  Customer? _selectedCustomer;
  bool _isCredit = false;
  String _saleCurrency = 'SYP';
  final _discountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<CustomerProvider>().loadCustomers());
  }

  void _updatePriceController() {
    if (_selectedProduct == null) return;
    final rate = context.read<ExchangeRateProvider>().currentRate;
    if (_saleCurrency == 'SYP') {
      _priceController.text = _selectedProduct!.defaultSellPriceSyp.toString();
    } else {
      _priceController.text = (_selectedProduct!.defaultSellPriceSyp / rate).toStringAsFixed(2);
    }
  }

  void _addToCart() {
    if (_selectedProduct == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    if (qty <= 0) return;
    
    // التحقق من الكمية المتوفرة
    double existingQtyInCart = 0;
    for (var item in _cartItems) {
      if (item['productId'] == _selectedProduct!.id) {
        existingQtyInCart += item['quantity'];
      }
    }

    if (qty + existingQtyInCart > _selectedProduct!.currentQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الكمية المطلوبة أكبر من المتوفر!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      final rate = context.read<ExchangeRateProvider>().currentRate;
      final priceSyp = _saleCurrency == 'USD' ? (price * rate) : price;
      
      _cartItems.add({
        'productId': _selectedProduct!.id,
        'name': _selectedProduct!.name,
        'quantity': qty,
        'sellPriceSyp': priceSyp,
      });
      _selectedProduct = null;
      _qtyController.text = '1';
      _priceController.clear();
    });
  }

  double get _totalBeforeDiscountSyp {
    return _cartItems.fold(0, (sum, item) => sum + (item['quantity'] * item['sellPriceSyp']));
  }

  Future<void> _scanBarcode() async {
    final String? res = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (res != null) {
      final product = await context.read<InventoryProvider>().getProductByBarcode(res);
      if (product != null) {
        setState(() {
          _selectedProduct = product;
          _updatePriceController();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<ExchangeRateProvider>().currentRate;
    final totalSyp = _totalBeforeDiscountSyp - (double.tryParse(_discountController.text) ?? 0);
    final totalUsd = totalSyp / (rate > 0 ? rate : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع (فاتورة)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تغيير الوضع / تسجيل الخروج',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. اختيار المادة
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ProductSearchField(
                              selectedProduct: _selectedProduct,
                              onSelected: (p) => setState(() {
                                _selectedProduct = p;
                                _updatePriceController();
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(onPressed: _scanBarcode, icon: const Icon(Icons.camera_alt)),
                        ],
                      ),
                      if (_selectedProduct != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyController,
                                decoration: const InputDecoration(labelText: 'الكمية', prefixIcon: Icon(Icons.numbers)),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: InputDecoration(
                                  labelText: 'السعر (${_saleCurrency == 'SYP' ? 'ل.س' : '\$'})',
                                  prefixIcon: const Icon(Icons.sell),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addToCart,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              child: const Text('إضافة'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
  
            // 2. قائمة السلة
            Expanded(
              child: _cartItems.isEmpty 
                ? const Center(child: Text('السلة فارغة', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('الكمية: ${item['quantity']} × ${item['sellPriceSyp']} ل.س'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${(item['quantity'] * item['sellPriceSyp']).toStringAsFixed(0)} ل.س', 
                                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => setState(() => _cartItems.removeAt(index)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
  
            // 3. ملخص الفاتورة والتشيك أوت
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('نقدي'), icon: Icon(Icons.money)),
                            ButtonSegment(value: true, label: Text('بالدين'), icon: Icon(Icons.credit_card)),
                          ],
                          selected: {_isCredit},
                          onSelectionChanged: (val) => setState(() {
                            _isCredit = val.first;
                            _saleCurrency = _isCredit ? 'USD' : 'SYP';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isCredit)
                        Expanded(
                          child: Consumer<CustomerProvider>(
                            builder: (context, cp, _) => DropdownButtonFormField<Customer>(
                              value: _selectedCustomer,
                              decoration: const InputDecoration(labelText: 'الزبون', isDense: true),
                              items: cp.customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                              onChanged: (v) => setState(() => _selectedCustomer = v),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          decoration: const InputDecoration(labelText: 'الخصم (ل.س)', prefixIcon: Icon(Icons.discount)),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('الإجمالي: ${totalSyp.toStringAsFixed(0)} ل.س', 
                               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('تقريباً: ${totalUsd.toStringAsFixed(2)} \$', 
                               style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Consumer<SalesProvider>(
                      builder: (context, sp, _) => ElevatedButton(
                        onPressed: (_cartItems.isEmpty || sp.isProcessing) ? null : () async {
                          if (_isCredit && _selectedCustomer == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار زبون')));
                            return;
                          }
                          
                          try {
                            await sp.recordSale(
                              items: _cartItems,
                              discountSyp: double.tryParse(_discountController.text) ?? 0,
                              currentExchangeRate: rate,
                              customerId: _isCredit ? _selectedCustomer?.id : null,
                              saleType: _isCredit ? 'credit' : 'cash',
                              saleCurrency: _saleCurrency,
                            );
                            if (mounted) {
                              context.read<InventoryProvider>().loadProducts();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح')));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: sp.isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontSize: 18)),
                      ),
                    ),
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
