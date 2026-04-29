import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/customer_provider.dart';
import 'package:dokkan/providers/exchange_rate_provider.dart';
import 'package:dokkan/data/models/customer_model.dart';
import 'package:intl/intl.dart';

class CustomerStatementScreen extends StatefulWidget {
  final Customer customer;
  const CustomerStatementScreen({super.key, required this.customer});

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  bool _showInSyp = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<CustomerProvider>().loadStatement(widget.customer.id!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: ${widget.customer.name}'),
        actions: [
          IconButton(
            icon: Icon(_showInSyp ? Icons.currency_exchange : Icons.attach_money),
            onPressed: () => setState(() => _showInSyp = !_showInSyp),
            tooltip: 'تبديل العملة للعرض',
          ),
        ],
      ),
      body: Consumer2<CustomerProvider, ExchangeRateProvider>(
        builder: (context, custProvider, exProvider, _) {
          if (custProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final balanceUsd = custProvider.currentBalance['balance_usd'] ?? 0.0;
          final balanceSypCurrent = balanceUsd * exProvider.currentRate;

          return Column(
            children: [
              // ملخص الحساب
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: balanceUsd > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  children: [
                    const Text('الرصيد الإجمالي المستحق', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${balanceUsd.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: balanceUsd > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      'يعادل تقريباً: ${NumberFormat("#,###").format(balanceSypCurrent.toInt())} ل.س',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // الجدول
              Expanded(
                child: custProvider.currentStatement.isEmpty
                    ? const Center(child: Text('لا توجد حركات مسجلة'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('البيان')),
                              DataColumn(label: Text('مدين (عليه)')),
                              DataColumn(label: Text('دائن (له)')),
                              DataColumn(label: Text('الرصيد')),
                            ],
                            rows: _buildRows(custProvider.currentStatement),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context),
        label: const Text('تسديد دفعة'),
        icon: const Icon(Icons.add_card),
      ),
    );
  }

  List<DataRow> _buildRows(List<Map<String, dynamic>> statement) {
    double runningBalance = 0;
    return statement.map((item) {
      final double debit = _showInSyp ? item['debit_syp'] : item['debit_usd'];
      final double credit = _showInSyp ? item['credit_syp'] : item['credit_usd'];
      
      // ملاحظة: الرصيد التراكمي في الجدول يفضل أن يكون بالدولار دائماً لضمان الصحة الرياضية، 
      // أو يتم تحويله لليرة وقت العرض لكل سطر.
      // لتبسيط الأمر، سنعرض الرصيد التراكمي بالدولار دائماً أو نحوله لليرة حسب سعر صرف ذلك السطر.
      final double currentDebitUsd = item['debit_usd'];
      final double currentCreditUsd = item['credit_usd'];
      runningBalance += (currentDebitUsd - currentCreditUsd);
      
      final displayBalance = _showInSyp ? runningBalance * item['exchange_rate'] : runningBalance;

      return DataRow(cells: [
        DataCell(Text(DateFormat('MM/dd HH:mm').format(DateTime.parse(item['date'])))),
        DataCell(Text(item['description'])),
        DataCell(Text(debit > 0 ? debit.toStringAsFixed(_showInSyp ? 0 : 2) : '-')),
        DataCell(Text(credit > 0 ? credit.toStringAsFixed(_showInSyp ? 0 : 2) : '-')),
        DataCell(Text(
          displayBalance.toStringAsFixed(_showInSyp ? 0 : 2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: runningBalance > 0 ? Colors.red : Colors.green,
          ),
        )),
      ]);
    }).toList();
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String currency = 'USD';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسديد دفعة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: currency,
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('دولار (\$')),
                    DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية')),
                  ],
                  onChanged: (v) => setDialogState(() => currency = v!),
                  decoration: const InputDecoration(labelText: 'عملة الدفع'),
                ),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final exRate = context.read<ExchangeRateProvider>().currentRate;
                  await context.read<CustomerProvider>().addPayment(
                    customerId: widget.customer.id!,
                    amount: double.parse(amountController.text),
                    currency: currency,
                    exchangeRate: exRate,
                    notes: notesController.text,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('تأكيد التسديد'),
            ),
          ],
        ),
      ),
    );
  }
}
