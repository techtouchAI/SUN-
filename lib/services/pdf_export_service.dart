import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/system_result_model.dart';
import '../models/safety_audit_model.dart';
import '../models/load_model.dart';
import '../models/system_mode.dart';
import '../logic/app_strings.dart';

class PdfExportService {
  static List<String> batterySummaryLines(SystemResultModel result) {
    if (result.requiredBatteryCapacityAh <= 0) {
      return const ['غير مطلوب — لا يوجد استهلاك ليلي.'];
    }
    return [
      'السعة المطلوبة: ${result.requiredBatteryCapacityAh.toStringAsFixed(0)}Ah (${((result.requiredBatteryCapacityAh * result.systemVoltage) / 1000).toStringAsFixed(1)} kWh) بناءً على نظام ${result.systemVoltage.toStringAsFixed(0)}V',
      AppStrings.batteryExplanationBody,
      result.breakdown.batteryExplanationAr,
      if (result.requiredGridChargingAmps > 0)
        '⚡ تيار شحن البطاريات الداخلي (DC): ${result.requiredGridChargingAmps.toStringAsFixed(1)} A',
      if (result.requiredGridChargingAcAmps > 0)
        '🔌 السحب الفعلي من الشبكة (AC): ${result.requiredGridChargingAcAmps.toStringAsFixed(1)} A',
      if (result.timeToFullHours > 0)
        '⏳ الوقت المقدر لشحن البطاريات بالكامل: ${result.timeToFullHours.toStringAsFixed(1)} ساعات',
      if (result.suggestedChargePriority.isNotEmpty)
        'أولوية الشحن المقترحة: ${result.suggestedChargePriority}',
      if (result.gelBatteryWarning.isNotEmpty) result.gelBatteryWarning,
    ];
  }

  static List<String> protectionSummaryLines(SystemResultModel result) => [
    for (final protection in result.safetyAudit.presentationResults)
      '${protection.kind.labelAr}: ${protection.conciseStatusAr}'
          '${protection.isCalculated ? '' : ' — ${protection.conciseReasonAr}'}',
  ];

  Future<void> exportDashboardToPdf(
    SystemResultModel result,
    List<LoadModel> loads,
    SystemMode systemMode,
    double iqdExchangeRate,
    double panelCapacity,
  ) async {
    final pdf = pw.Document();

    final amiriFontData = await rootBundle.load(
      'assets/fonts/Amiri-Regular.ttf',
    );
    final amiriFont = pw.Font.ttf(amiriFontData);

    final imgData = await rootBundle.load('assets/photoi.png');
    final imageBytes = imgData.buffer.asUint8List();
    final connectionImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: amiriFont, bold: amiriFont),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'تقرير حاسبة الطاقة الشمسية',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            // 1. Total Consumption
            pw.Text(
              'تفاصيل الاستهلاك',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text(
              'الاستهلاك الإجمالي: ${result.totalDailyConsumptionWh.toStringAsFixed(0)} Wh',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              'الاستهلاك النهاري: ${result.daytimeConsumptionWh.toStringAsFixed(0)} Wh',
              style: const pw.TextStyle(fontSize: 16),
            ),
            if (systemMode != SystemMode.directOnGrid)
              pw.Text(
                'الاستهلاك الليلي: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} Wh',
                style: const pw.TextStyle(fontSize: 16),
              ),
            pw.SizedBox(height: 20),

            // 2. Required Inverter
            pw.Text(
              'الإنفرتر المطلوب',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text(
              'الإنفرتر: ${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              'النوع المقترح: ${result.suggestedInverterType}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'حجم الإنفرتر تم اختياره بناءً على أقصى حمل لحظي يمكن أن يعمل في نفس الوقت، مع إضافة هامش أمان لحماية الجهاز.',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'يوضح هذا أيضاً تأثير الأجهزة الإنفرتر في تقليل الحمل المبدئي (Surge).',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'الحمل الأقصى اللحظي: ${result.peakLoadW.toStringAsFixed(0)} W',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'هامش الأمان: ${result.safetyMarginW.toStringAsFixed(0)} W',
              style: const pw.TextStyle(fontSize: 14),
            ),
            if (result.suggestedIpRating.isNotEmpty)
              pw.Text(
                'تقييم الحماية المقترح (IP): ${result.suggestedIpRating}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            pw.SizedBox(height: 20),

            // 3. Solar Panels
            if (systemMode != SystemMode.ups) ...[
              pw.Text(
                'الألواح الشمسية',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Text(
                'عدد الألواح: ${result.requiredPanels} ألواح (تمت الحسابات بناءً على ألواح بقدرة ${panelCapacity.toStringAsFixed(0)}W)',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'ألواح أحمال النهار: ${result.panelsForDaytime} لوح',
                style: const pw.TextStyle(fontSize: 14),
              ),
              if (systemMode != SystemMode.directOnGrid)
                pw.Text(
                  'ألواح لشحن البطاريات: ${result.panelsForBatteries} لوح',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              if (result.gridContributionPercent > 0)
                pw.Text(
                  'بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              if (result.panelsSavedByGrid > 0)
                pw.Text(
                  'عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              if (result.breakdown.mpptRecommendationAr.isNotEmpty)
                pw.Text(
                  '\n${result.breakdown.mpptRecommendationAr}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              if (systemMode != SystemMode.directOnGrid)
                pw.Text(
                  '\n💡 ملاحظة هندسية حول تقليل الألواح:\nيمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              if (result.breakdown.floatPreservationRecommendationAr.isNotEmpty)
                pw.Text(
                  '\n${result.breakdown.floatPreservationRecommendationAr}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              pw.SizedBox(height: 20),
            ],

            // 4. Battery Bank
            if (systemMode != SystemMode.directOnGrid) ...[
              pw.Text(
                'بنك البطاريات',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              for (final line in batterySummaryLines(result))
                pw.Text(line, style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
            ],

            // 5. Electrical protection derived only from existing SUN state.
            pw.Text(
              'الحماية الكهربائية',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (final line in protectionSummaryLines(result)) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            pw.SizedBox(height: 20),

            // 6. Expected Energy Loss
            pw.Text(
              'نسبة ضياع الطاقة المتوقعة',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text(
              'عامل الحرارة (Temperature Coefficient): انخفاض كفاءة الخلايا الشمسية عند ارتفاع درجات حرارة الألواح فوق 25 درجة مئوية (وهو عامل حاسم في الصيف).',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'كفاءة التحويل (Inverter Efficiency): الفقد الطبيعي أثناء تحويل التيار المستمر (DC) من الألواح إلى تيار متردد (AC) للمنزل (بنسبة تفقد حوالي 3% إلى 5%).',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'مقاومة الأسلاك (Wiring/DC Losses): الضياع الناتجة عن المقاومة الكهربائية في الكابلات المسؤولة عن نقل الطاقة من الألواح إلى العاكس ومن العاكس إلى البطاريات.',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'الغبار والأوساخ (Soiling Losses): انخفاض امتصاص الضوء بسبب تراكم الأتربة على سطح الألواح.',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 20),

            // 7. Estimated Cost
            pw.Text(
              'التكلفة التقديرية للمنظومة',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text(
              '${result.estimatedCostUsd.toStringAsFixed(2)} دولار',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              '${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ورقة',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              '${(result.estimatedCostUsd * iqdExchangeRate).toStringAsFixed(0)} دينار عراقي',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              '\n${AppStrings.pricingDisclaimer}',
              style: const pw.TextStyle(fontSize: 14),
            ),

            // Append Image
            pw.SizedBox(height: 20),
            pw.Text(
              'شكل توضيحي للربط',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Center(child: pw.Image(connectionImage, height: 200)),
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
