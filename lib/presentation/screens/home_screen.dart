import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/core/constants/app_strings.dart';
import 'package:dokkan/presentation/screens/inventory_list_screen.dart';
import 'package:dokkan/presentation/screens/add_batch_screen.dart';
import 'package:dokkan/presentation/screens/pos_screen.dart';
import 'package:dokkan/presentation/screens/reports_screen.dart';
import 'package:dokkan/data/repositories/sale_repository.dart';
import 'package:dokkan/presentation/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SaleRepository _saleRepo = SaleRepository();
  Map<String, double>? _stats;

  @override
  void initState() {
    super.initState();
    // محاولة جلب سعر الصرف عند الفتح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExchangeRate();
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final stats = await _saleRepo.getSummaryStats();
    setState(() => _stats = stats);
  }

  Future<void> _checkExchangeRate() async {
    final provider = Provider.of<ExchangeRateProvider>(context, listen: false);
    final webRate = await provider.fetchFromWeb();
    
    if (webRate != null) {
      _showApprovalDialog(webRate);
    } else if (provider.currentRate == 0) {
      // إذا فشل الجلب والسعر الحالي 0، نطلب إدخال يدوي
      _showManualEntryDialog();
    }
  }

  void _showApprovalDialog(double rate) {
    final TextEditingController controller = TextEditingController(text: rate.toString());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('تحديث سعر الصرف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تم جلب سعر الصرف التالي من الموقع. يمكنك الموافقة عليه أو تعديله:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'SYP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null) {
                context.read<ExchangeRateProvider>().updateRate(newRate);
                Navigator.pop(context);
              }
            },
            child: const Text(AppStrings.approve),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('إدخال سعر الصرف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('فشل جلب السعر تلقائياً. يرجى إدخال سعر الصرف الحالي للبدء:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'SYP'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null) {
                context.read<ExchangeRateProvider>().updateRate(newRate);
                Navigator.pop(context);
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // شريط سعر الصرف الدائم
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_exchange, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'سعر الصرف الحالي:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Consumer<ExchangeRateProvider>(
                      builder: (context, provider, _) {
                        return Text(
                          '${provider.currentRate} SYP',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _checkExchangeRate,
                      tooltip: 'تحديث السعر',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // بطاقة ملخص سريعة
          if (_stats != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat(
                      'أرباح اليوم', 
                      '${_stats!['total_profit_usd']?.toStringAsFixed(1)} \$',
                      color: (_stats!['total_profit_usd'] ?? 0) >= 0 ? Colors.white : Colors.redAccent,
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildQuickStat('المبيعات', '${(_stats!['total_sales_syp']! / 1000).toStringAsFixed(0)}K'),
                  ],
                ),
              ),
            ),
          
          // محتوى الصفحة الرئيسي
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(context, Icons.inventory, AppStrings.inventory, Colors.orange, const InventoryListScreen()),
                _buildMenuCard(context, Icons.shopping_cart, AppStrings.sales, Colors.green, const POSScreen()),
                _buildMenuCard(context, Icons.local_shipping, AppStrings.purchases, Colors.blue, const AddBatchScreen()),
                _buildMenuCard(context, Icons.bar_chart, AppStrings.reports, Colors.purple, const ReportsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, IconData icon, String title, Color color, [Widget? destination]) {
    return Card(
      child: InkWell(
        onTap: () {
          if (destination != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
