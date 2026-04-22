import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateMovementReport({
    required String title,
    required List<Map<String, dynamic>> data,
    required DateTime from,
    required DateTime to,
    required bool isSales,
  }) async {
    final pdf = pw.Document();
    
    // استخدام خط يدعم العربية من Google Fonts تلقائياً
    final ttf = await PdfGoogleFonts.amiriRegular();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttf),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('تموينات شحادة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(title, style: pw.TextStyle(fontSize: 20)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('الفترة من: ${DateFormat('yyyy-MM-dd').format(from)} إلى: ${DateFormat('yyyy-MM-dd').format(to)}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['المادة', 'التاريخ', 'السعر (ل.س)', isSales ? 'الربح (\$)' : 'الكمية'],
            data: data.map((item) => [
              item['name'],
              DateFormat('yyyy-MM-dd').format(DateTime.parse(item[isSales ? 'sale_date' : 'purchase_date'])),
              item[isSales ? 'sell_price_syp' : 'purchase_price_syp'].toString(),
              isSales ? item['profit_usd'].toString() : item['quantity'].toString(),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 20),
          pw.Footer(
            trailing: pw.Text('تاريخ التوليد: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
