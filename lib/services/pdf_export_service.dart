import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/system_result_model.dart';
import '../models/load_model.dart';
import '../models/system_mode.dart';
import '../logic/app_strings.dart';

class PdfExportService {
  Future<void> exportDashboardToPdf(
      SystemResultModel result,
      List<LoadModel> loads,
      SystemMode systemMode,
      double iqdExchangeRate) async {
    final pdf = pw.Document();

    final amiriFontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final amiriFont = pw.Font.ttf(amiriFontData);

    final imgData = await rootBundle.load('assets/photoi.png');
    final imageBytes = imgData.buffer.asUint8List();
    final connectionImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: amiriFont,
          bold: amiriFont,
        ),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'تقرير حاسبة الطاقة الشمسية',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            // 1. Total Consumption
            pw.Text('تفاصيل الاستهلاك', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('الاستهلاك الإجمالي: ${result.totalDailyConsumptionWh.toStringAsFixed(0)} W', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('الاستهلاك النهاري: ${result.daytimeConsumptionWh.toStringAsFixed(0)} W', style: const pw.TextStyle(fontSize: 16)),
            if (systemMode != SystemMode.directOnGrid)
              pw.Text('الاستهلاك الليلي: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} W', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),

            // 2. Required Inverter
            pw.Text('الإنفرتر المطلوب', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('الإنفرتر: ${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('النوع المقترح: ${result.suggestedInverterType}', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('الماركات العالمية الموصى بها للعواكس: Deye, Growatt, Huawei, Victron Energy', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('حجم الإنفرتر تم اختياره بناءً على أقصى حمل لحظي يمكن أن يعمل في نفس الوقت، مع إضافة هامش أمان لحماية الجهاز.', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('يوضح هذا أيضاً تأثير الأجهزة الإنفرتر في تقليل الحمل المبدئي (Surge).', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('الحمل الأقصى اللحظي: ${result.peakLoadW.toStringAsFixed(0)} W', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('هامش الأمان: ${result.safetyMarginW.toStringAsFixed(0)} W', style: const pw.TextStyle(fontSize: 14)),
            if (result.suggestedIpRating.isNotEmpty) pw.Text('تقييم الحماية المقترح (IP): ${result.suggestedIpRating}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),

            // 3. Solar Panels
            if (systemMode != SystemMode.ups) ...[
              pw.Text('الألواح الشمسية', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('عدد الألواح: ${result.requiredPanels} ألواح', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('المصنعين من فئة (Tier 1) المعتمدة للألواح: Longi, Jinko Solar, JA Solar, Trina Solar', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('ألواح للتشغيل المباشر: ${result.panelsForDaytime} لوح', style: const pw.TextStyle(fontSize: 14)),
              if (systemMode != SystemMode.directOnGrid)
                pw.Text('ألواح لشحن البطاريات: ${result.panelsForBatteries} لوح', style: const pw.TextStyle(fontSize: 14)),
              if (result.gridContributionPercent > 0)
                pw.Text('بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.', style: const pw.TextStyle(fontSize: 14)),
              if (result.panelsSavedByGrid > 0)
                pw.Text('عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح', style: const pw.TextStyle(fontSize: 14)),
              if (systemMode != SystemMode.directOnGrid)
                pw.Text('\n💡 ملاحظة هندسية حول تقليل الألواح:\nيمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
            ],

            // 4. Battery Bank
            if (systemMode != SystemMode.directOnGrid) ...[
              pw.Text('بنك البطاريات', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('السعة المطلوبة: ${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah', style: const pw.TextStyle(fontSize: 16)),
              pw.Text(AppStrings.batteryExplanationBody, style: const pw.TextStyle(fontSize: 14)),
              pw.Text(result.breakdown.batteryExplanationAr, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              if (result.requiredGridChargingAmps > 0)
                pw.Text('⚡ تيار شحن البطاريات الداخلي (DC): ${result.requiredGridChargingAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 14)),
              if (result.requiredGridChargingAcAmps > 0)
                pw.Text('🔌 السحب الفعلي من الشبكة (AC): ${result.requiredGridChargingAcAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 14)),
              if (result.timeToFullHours > 0)
                pw.Text('⏳ الوقت المقدر لشحن البطاريات بالكامل: ${result.timeToFullHours.toStringAsFixed(1)} ساعات', style: const pw.TextStyle(fontSize: 14)),
              if (result.suggestedChargePriority.isNotEmpty)
                pw.Text('أولوية الشحن المقترحة: ${result.suggestedChargePriority}', style: const pw.TextStyle(fontSize: 14)),
              if (result.gelBatteryWarning.isNotEmpty)
                pw.Text(result.gelBatteryWarning, style: const pw.TextStyle(fontSize: 14, color: PdfColors.red)),
              pw.SizedBox(height: 20),
            ],

            // 5. NEC Standards
            pw.Text('معايير السلامة العالمية (NEC)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            if (result.pvDcBreakerAmps > 0) pw.Text('جوزات الألواح (DC Breakers): ${result.pvDcBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
            if (result.batteryDcBreakerAmps > 0) pw.Text('جوزات البطاريات (DC Breakers): ${result.batteryDcBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
            if (result.acBreakerAmps > 0) pw.Text('جوزات التيار المتردد (AC Breakers): ${result.acBreakerAmps.toStringAsFixed(1)} A', style: const pw.TextStyle(fontSize: 16)),
            if (result.wireSizeMm2 > 0) pw.Text('أحجام الأسلاك (DC Wire Sizing): ${result.wireSizeMm2} mm²', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),

            // 6. Expected Energy Loss
            pw.Text('نسبة ضياع الطاقة المتوقعة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('عامل الحرارة (Temperature Coefficient): انخفاض كفاءة الخلايا الشمسية عند ارتفاع درجات حرارة الألواح فوق 25 درجة مئوية (وهو عامل حاسم في الصيف).', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('كفاءة التحويل (Inverter Efficiency): الفقد الطبيعي أثناء تحويل التيار المستمر (DC) من الألواح إلى تيار متردد (AC) للمنزل (بنسبة تفقد حوالي 3% إلى 5%).', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('مقاومة الأسلاك (Wiring/DC Losses): الضياع الناتجة عن المقاومة الكهربائية في الكابلات المسؤولة عن نقل الطاقة من الألواح إلى العاكس ومن العاكس إلى البطاريات.', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('الغبار والأوساخ (Soiling Losses): انخفاض امتصاص الضوء بسبب تراكم الأتربة على سطح الألواح.', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),

            // 7. Estimated Cost
            pw.Text('التكلفة التقديرية للمنظومة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('${result.estimatedCostUsd.toStringAsFixed(2)} دولار', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ورقة', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('${(result.estimatedCostUsd * iqdExchangeRate).toStringAsFixed(0)} دينار عراقي', style: const pw.TextStyle(fontSize: 16)),
            pw.Text('\nملاحظة: هذا السعر تقريبي مبني على إعداداتك. لم يتم حساب أسعار الجوزات وأسلاك الربط إلا إذا قمت بإضافتها يدوياً من شاشة الإعدادات، لكونها متغيرة حسب النوع والطول.', style: const pw.TextStyle(fontSize: 14)),

            // Append Image
            pw.SizedBox(height: 20),
            pw.Text('شكل توضيحي للربط', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Center(
              child: pw.Image(connectionImage, height: 200),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Solar_Report.pdf',
    );
  }
}
