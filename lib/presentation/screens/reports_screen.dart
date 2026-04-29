import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/data/repositories/report_repository.dart';
import 'package:dokkan/providers/sales_provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';
import 'package:intl/intl.dart';
import 'package:dokkan/core/utils/pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportRepository _reportRepo = ReportRepository();
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _toDate = DateTime.now();
  String _customGroupBy = 'daily'; // 'daily' or 'monthly'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _handlePdfExport,
            tooltip: 'تصدير PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'المالية', icon: Icon(Icons.account_balance)),
            Tab(text: 'المبيعات', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'المشتريات', icon: Icon(Icons.local_shipping)),
            Tab(text: 'تقرير مخصص', icon: Icon(Icons.date_range)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFinancialTab(),
            _buildMovementTab(isSales: true),
            _buildMovementTab(isSales: false),
            _buildCustomReportTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePdfExport() async {
    final index = _tabController.index;
    if (index == 0) {
      // تصدير التقارير المالية (سنضيفها لاحقاً لو طلبت)
      return;
    }

    if (index == 1 || index == 2) {
      final isSales = index == 1;
      final data = isSales 
          ? await _reportRepo.getSalesBetween(_fromDate, _toDate)
          : await _reportRepo.getPurchasesBetween(_fromDate, _toDate);
      
      await PdfService.generateMovementReport(
        title: isSales ? 'تقرير المبيعات' : 'تقرير المشتريات',
        data: data,
        from: _fromDate,
        to: _toDate,
        isSales: isSales,
      );
    }

    if (index == 3) {
      final data = await _reportRepo.getCustomRangeReport(
        from: _fromDate,
        to: _toDate,
        groupBy: _customGroupBy,
      );
      
      await PdfService.generateMovementReport(
        title: 'تقرير مخصص (${_customGroupBy == 'daily' ? 'يومي' : 'شهري'})',
        data: data.map((item) => {
          'name': item['period'],
          'sale_date': item['period'], // نستخدمه كحقل تاريخ
          'sell_price_syp': item['total_syp'],
          'profit_usd': item['total_profit'],
        }).toList(),
        from: _fromDate,
        to: _toDate,
        isSales: true, // نستخدم قالب المبيعات لأنه يحتوي على الربح
      );
    }
  }

  // --- 1. التقارير المالية (يومي، شهري، سنوي) ---
  Widget _buildFinancialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFinancialSummaryCard('يومي', 'daily'),
        const SizedBox(height: 16),
        _buildFinancialSummaryCard('شهري', 'monthly'),
        const SizedBox(height: 16),
        _buildFinancialSummaryCard('سنوي', 'yearly'),
      ],
    );
  }

  Widget _buildFinancialSummaryCard(String title, String type) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportRepo.getProfitStats(groupBy: type),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.isEmpty) return const SizedBox.shrink();

        final latest = data.first;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('أرباح الـ $title (${latest['period']})', 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Icon(Icons.trending_up, color: Colors.green),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text('إجمالي المبيعات: ${latest['total_syp']} ل.س'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الربح الصافي: ${latest['total_profit'].toStringAsFixed(2)} \$',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: latest['total_profit'] >= 0 ? Colors.green : Colors.red
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showDrillDownDetails(latest['period'], type),
                      child: const Text('التفاصيل'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. تقارير الحركة (مبيعات / مشتريات) ---
  Widget _buildMovementTab({required bool isSales}) {
    return Column(
      children: [
        _buildDateRangePicker(),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: isSales 
                ? _reportRepo.getSalesBetween(_fromDate, _toDate)
                : _reportRepo.getPurchasesBetween(_fromDate, _toDate),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final invoice = data[index];
                  final id = isSales ? invoice['sale_id'] : invoice['purchase_id'];
                  final date = DateTime.parse(isSales ? invoice['sale_date'] : invoice['purchase_date']);
                  final totalSyp = invoice['total_amount_syp'] ?? 0;
                  final totalUsd = invoice['total_amount_usd'] ?? 0;
                  final itemsCount = invoice['items_count'] ?? 0;
                  final secondaryName = isSales 
                      ? (invoice['customer_name'] ?? 'زبون عام')
                      : (invoice['supplier_name'] ?? 'مورد عام');
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      onTap: () => _showInvoiceDetails(id, isSales, invoice),
                      title: Text(
                        '${isSales ? "فاتورة مبيع" : "فاتورة شراء"} #$id', 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$secondaryName | $itemsCount مواد'),
                          Text(DateFormat('yyyy-MM-dd HH:mm').format(date), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${NumberFormat("#,###").format(totalSyp)} ل.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${totalUsd.toStringAsFixed(2)} \$', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _showDeleteTransactionDialog(context, invoice, isSales),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showInvoiceDetails(int id, bool isSales, Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'تفاصيل الفاتورة #$id', 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: isSales 
                  ? _reportRepo.getSaleInvoiceItems(id)
                  : _reportRepo.getPurchaseInvoiceItems(id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data!;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final qty = item['quantity'] ?? item['initial_quantity'] ?? 0;
                      final price = isSales ? item['sell_price_syp'] : item['purchase_price_syp'];
                      return ListTile(
                        title: Text(item['product_name'] ?? 'مادة غير معروفة'),
                        subtitle: Text('الكمية: $qty × $price ل.س'),
                        trailing: Text('${(qty * price).toStringAsFixed(0)} ل.س'),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            if (isSales && (invoice['discount_amount_syp'] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الخصم:', style: TextStyle(color: Colors.red)),
                    Text('-${invoice['discount_amount_syp']} ل.س', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي النهائي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${NumberFormat("#,###").format(invoice['total_amount_syp'])} ل.س', 
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. تقرير مخصص ديناميكي ---
  Widget _buildCustomReportTab() {
    return Column(
      children: [
        _buildDateRangePicker(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('تجميع حسب:'),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('يومي'),
                selected: _customGroupBy == 'daily',
                onSelected: (val) => setState(() => _customGroupBy = 'daily'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('شهري'),
                selected: _customGroupBy == 'monthly',
                onSelected: (val) => setState(() => _customGroupBy = 'monthly'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _reportRepo.getCustomRangeReport(from: _fromDate, to: _toDate, groupBy: _customGroupBy),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  return ListTile(
                    title: Text(item['period']),
                    subtitle: Text('المبيعات: ${item['total_syp']} ل.س'),
                    trailing: Text(
                      '${item['total_profit'].toStringAsFixed(2)} \$',
                      style: TextStyle(color: item['total_profit'] >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- واجهات التفاصيل المتسلسلة (Drill-Down) ---
  void _showDeleteTransactionDialog(BuildContext context, Map<String, dynamic> item, bool isSales) {
    final id = isSales ? item['sale_id'] : item['purchase_id'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSales ? 'إلغاء فاتورة مبيع' : 'إلغاء فاتورة شراء'),
        content: Text(isSales 
            ? 'هل أنت متأكد من إلغاء الفاتورة رقم #$id؟ سيتم إرجاع كافة الكميات للمخزون.'
            : 'هل أنت متأكد من إلغاء الفاتورة رقم #$id؟ سيتم خصم الكميات من المخزون.\nملاحظة: لا يمكن الحذف إذا تم بيع جزء من أي مادة في الفاتورة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              bool success = true;
              if (isSales) {
                await context.read<SalesProvider>().deleteSale(id);
              } else {
                success = await context.read<InventoryProvider>().deletePurchaseInvoice(id);
              }
              
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر الحذف: تم بيع جزء من مواد هذه الفاتورة بالفعل')),
                  );
                }
                setState(() {}); // تحديث الواجهة
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _showDrillDownDetails(String period, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('ملخص فواتير $period', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getDetailsFuture(period, type),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final list = snapshot.data!;
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      if (type == 'daily') {
                        return ListTile(
                          title: Text('فاتورة مبيع #${item['sale_id']}'),
                          subtitle: Text('الوقت: ${DateFormat('HH:mm').format(DateTime.parse(item['sale_date']))}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${item['total_amount_syp']} ل.س'),
                              Text('${item['total_profit'].toStringAsFixed(2)} \$', style: const TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          ),
                          onTap: () => _showInvoiceDetails(item['sale_id'], true, item),
                        );
                      } else {
                        return ListTile(
                          title: Text(item['sub_period'] ?? item['period']),
                          subtitle: Text('المبيعات: ${item['total_syp']} ل.س'),
                          trailing: Text('${item['total_profit'].toStringAsFixed(2)} \$', 
                            style: TextStyle(color: item['total_profit'] >= 0 ? Colors.green : Colors.red)),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getDetailsFuture(String period, String type) {
    if (type == 'daily') return _reportRepo.getDaySalesDetails(period);
    if (type == 'monthly') return _reportRepo.getCustomRangeReport(
      from: DateTime.parse('$period-01'), 
      to: DateTime.parse('$period-31'), 
      groupBy: 'daily'
    );
    return _reportRepo.getCustomRangeReport(
      from: DateTime.parse('$period-01-01'), 
      to: DateTime.parse('$period-12-31'), 
      groupBy: 'monthly'
    );
  }

  Widget _buildDateRangePicker() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('من: ${DateFormat('yyyy-MM-dd').format(_fromDate)}'),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _fromDate = date);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('إلى: ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _toDate = date);
              },
            ),
          ),
        ],
      ),
    );
  }
}
