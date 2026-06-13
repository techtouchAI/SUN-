import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/system_result_model.dart';
import '../models/load_model.dart';

class PdfExportService {
  Future<void> exportDashboardToPdf(SystemResultModel result, List<LoadModel> loads) async {
    final pdf = pw.Document();

    final amiriFontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final amiriFont = pw.Font.ttf(amiriFontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: amiriFont,
        ),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'تقرير حاسبة الطاقة الشمسية',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'تفاصيل الاستهلاك',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                pw.Text('الاستهلاك الإجمالي: ${result.totalDailyConsumptionWh.toStringAsFixed(0)} واط-ساعة', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('الاستهلاك النهاري: ${result.daytimeConsumptionWh.toStringAsFixed(0)} واط-ساعة', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('الاستهلاك الليلي: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} واط-ساعة', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text(
                  'متطلبات المنظومة',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                pw.Text('الإنفرتر المطلوب: ${(result.requiredInverterCapacityW / 1000).toStringAsFixed(1)} kW', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('بنك البطاريات: ${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('عدد الألواح: ${result.requiredPanels}', style: const pw.TextStyle(fontSize: 16)),
                if (result.panelsSavedByGrid > 0)
                  pw.Text('الألواح الموفرة بسبب الوطنية: ${result.panelsSavedByGrid}', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text(
                  'معايير السلامة (NEC)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                if (result.pvDcBreakerAmps > 0) pw.Text('قاطع الألواح: ${result.pvDcBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
                if (result.batteryDcBreakerAmps > 0) pw.Text('قاطع البطاريات: ${result.batteryDcBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
                if (result.acBreakerAmps > 0) pw.Text('قاطع التيار المتردد: ${result.acBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
                if (result.wireSizeMm2 > 0) pw.Text('حجم أسلاك DC: ${result.wireSizeMm2} mm²', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text(
                  'التكلفة التقديرية',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                pw.Text('الإجمالي: \$${result.estimatedCostUsd.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Solar_Report.pdf',
    );
  }
}
