import 'package:flutter/material.dart';
import 'package:dokkan/core/utils/data_service.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/auth_provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:dokkan/presentation/screens/customers_screen.dart';
import 'package:dokkan/presentation/screens/role_selection_screen.dart';
import 'package:dokkan/presentation/screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'تموينات شحادة',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('الزبائن والذمم المالية'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('الإعدادات العامة'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('نسخة احتياطية كاملة'),
            onTap: () async {
              bool success = await dataService.exportFullBackup();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'تم الحفظ بنجاح' : 'تم إلغاء العملية')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة كاملة'),
            onTap: () async {
              bool success = await dataService.importFullBackup();
              if (success && context.mounted) {
                context.read<InventoryProvider>().loadAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت الاستعادة بنجاح، يرجى إعادة تشغيل التطبيق لضمان استقرار البيانات')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('تصدير المواد (JSON)'),
            onTap: () async {
              bool success = await dataService.exportProductsToJSON();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'تم التصدير بنجاح' : 'فشل التصدير')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('استيراد مواد (JSON)'),
            onTap: () async {
              bool success = await dataService.importProductsFromJSON();
              if (success && context.mounted) {
                context.read<InventoryProvider>().loadAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم الاستيراد بنجاح')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج / تغيير الوضع', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('الإصدار 1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
