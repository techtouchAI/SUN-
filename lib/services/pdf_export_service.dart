import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/system_result_model.dart';
import '../logic/app_strings.dart';

class PdfExportService {
  Future<void> exportResultToPdf(SystemResultModel result) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.amiriRegular();
    final fontBold = await PdfGoogleFonts.amiriBold();

    const textDirection = pw.TextDirection.rtl;

    // Helper functions for typography
    pw.Widget titleText(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.blue900), textDirection: textDirection),
    );

    pw.Widget subtitleText(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blueGrey800), textDirection: textDirection),
    );

    pw.Widget detailText(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(text, style: pw.TextStyle(font: fontRegular, fontSize: 16, color: PdfColors.black), textDirection: textDirection),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: textDirection,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Center(
                child: titleText('تقرير حسابات الطاقة الشمسية'),
              ),
            ),

            // Solar Panels Section
            subtitleText(AppStrings.solarPanels),
            detailText('إجمالي عدد الألواح: ${result.requiredPanels}'),

            // Batteries Section
            subtitleText(AppStrings.batteryBank),
            detailText('السعة المطلوبة للبطاريات: ${result.requiredBatteryCapacityAh.toStringAsFixed(1)} Ah'),

            // Inverter Section
            subtitleText(AppStrings.requiredInverter),
            detailText('سعة العاكس (إنفرتر): ${(result.requiredInverterCapacityW / 1000).toStringAsFixed(1)} kW'),
            if (result.suggestedInverterType.isNotEmpty)
              detailText('نوع العاكس الموصى به: ${result.suggestedInverterType}'),

            // Protection Section
            subtitleText(AppStrings.safetyStandardsTitle),
            if (result.pvDcBreakerAmps > 0)
               detailText('${AppStrings.pvBreaker}: ${result.pvDcBreakerAmps.toStringAsFixed(1)} A'),
            if (result.batteryDcBreakerAmps > 0)
               detailText('${AppStrings.batteryBreaker}: ${result.batteryDcBreakerAmps.toStringAsFixed(1)} A'),
            if (result.acBreakerAmps > 0)
               detailText('${AppStrings.acBreaker}: ${result.acBreakerAmps.toStringAsFixed(1)} A'),
            if (result.wireSizeMm2 > 0)
               detailText('${AppStrings.dcWireSize}: ${result.wireSizeMm2.toStringAsFixed(1)} mm²'),

          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Solar_Calculation_Report.pdf',
    );
  }
}
