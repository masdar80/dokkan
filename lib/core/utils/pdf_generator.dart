import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> generateSalesReport({
    required Map<String, double> stats,
    required List<Map<String, dynamic>> sales,
  }) async {
    final pdf = pw.Document();

    // نستخدم خط يدعم العربية للتقرير
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('تقرير مبيعات وأرباح دكان', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          
          // الملخص
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('إجمالي المبيعات (ل.س): ${stats['total_sales_syp']?.toStringAsFixed(0)}'),
                pw.Text('إجمالي المبيعات (USD): ${stats['total_sales_usd']?.toStringAsFixed(2)} \$'),
                pw.Text('صافي الربح الكلي: ${stats['total_profit_usd']?.toStringAsFixed(2)} \$', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          pw.Text('تفاصيل العمليات:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          
          // الجدول
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'المادة', 'الكمية', 'السعر (ل.س)', 'الربح (\$)'],
            data: sales.map((s) => [
              DateFormat('yyyy-MM-dd').format(DateTime.parse(s['sale_date'])),
              s['name'],
              s['quantity'].toString(),
              s['sell_price_syp'].toString(),
              s['profit_usd'].toStringAsFixed(2),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
