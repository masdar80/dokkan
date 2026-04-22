import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/data/models/category_model.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة التصنيفات')),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            itemCount: provider.categories.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final cat = provider.categories[index];
              return Card(
                child: ListTile(
                  title: Text(cat.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(context, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDialog(context, cat),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تصنيف جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<InventoryProvider>().addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Category category) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم التصنيف'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final updated = Category(id: category.id, name: controller.text);
                context.read<InventoryProvider>().updateCategory(updated);
                Navigator.pop(context);
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تصنيف'),
        content: Text('هل أنت متأكد من حذف التصنيف "${category.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              context.read<InventoryProvider>().deleteCategory(category.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
