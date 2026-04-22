import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/presentation/screens/add_product_screen.dart';
import 'package:dokkan/presentation/screens/category_management_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<InventoryProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
              );
            },
            tooltip: 'إدارة التصنيفات',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => context.read<InventoryProvider>().search(value),
              decoration: InputDecoration(
                hintText: 'البحث بالاسم أو الرمز...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.products.isEmpty) {
            return const Center(child: Text('لا توجد مواد في المخزون'));
          }

          return ListView.builder(
            itemCount: provider.products.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الرمز: ${product.code}'),
                      Text('الكمية: ${product.currentQuantity}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${product.defaultSellPriceSyp} ل.س',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditProductDialog(context, product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _showDeleteProductDialog(context, product),
                      ),
                    ],
                  ),
                  onTap: () {},
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, dynamic product) {
    final nameController = TextEditingController(text: product.name);
    final codeController = TextEditingController(text: product.code);
    final priceController = TextEditingController(text: product.defaultSellPriceSyp.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل مادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المادة')),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'رمز المادة')),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'سعر البيع الافتراضي'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final updated = product.copyWith(
                name: nameController.text,
                code: codeController.text,
                defaultSellPriceSyp: double.parse(priceController.text),
              );
              context.read<InventoryProvider>().updateProduct(updated);
              Navigator.pop(context);
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(BuildContext context, dynamic product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مادة'),
        content: Text('هل أنت متأكد من حذف "${product.name}"؟\nملاحظة: لا يمكن حذف مادة مرتبطة بمبيعات أو مشتريات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final success = await context.read<InventoryProvider>().deleteProduct(product.id!);
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر الحذف: المادة مرتبطة بحركات مالية')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
