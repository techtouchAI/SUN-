import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/final_calculation_dto.dart';
import '../models/load_model.dart';
import '../models/system_mode.dart';
import '../models/system_result_model.dart';

class PdfExportService {
  static Future<void> exportCalculationReport(FinalCalculationDto dto) async {
    final pdf = pw.Document();
    final amiriFontData = await rootBundle.load(
      'assets/fonts/Amiri-Regular.ttf',
    );
    final amiriFont = pw.Font.ttf(amiriFontData);
    pw.MemoryImage? connectionImage;
    try {
      final imageData = await rootBundle.load('assets/photoi.png');
      connectionImage = pw.MemoryImage(imageData.buffer.asUint8List());
    } on FlutterError {
      connectionImage = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: amiriFont, bold: amiriFont),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'تقرير حاسبة الطاقة الشمسية',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('اسم المشروع: ${dto.projectName}'),
          pw.Text('التاريخ: ${dto.generatedAt.toIso8601String()}'),
          pw.Text('إصدار التطبيق: ${dto.appVersion}'),
          pw.Text('إصدار نموذج الحساب: ${dto.calculationVersion}'),
          pw.SizedBox(height: 18),
          _heading('المدخلات'),
          _inputTable(dto),
          pw.SizedBox(height: 18),
          _heading('الأحمال وملف التشغيل'),
          _loadsTable(dto.loads),
          pw.SizedBox(height: 18),
          _heading('النتائج'),
          _resultsTable(dto.result),
          pw.SizedBox(height: 18),
          _heading('الافتراضات والتحذيرات'),
          ...dto.result.breakdown.assumptionsAr.map(
            (item) => pw.Text('• $item'),
          ),
          ...dto.result.breakdown.warningsAr.map(
            (item) => pw.Text(
              '• $item',
              style: const pw.TextStyle(color: PdfColors.orange),
            ),
          ),
          pw.SizedBox(height: 18),
          _heading('المعيار الكهربائي'),
          pw.Text(dto.result.electricalEstimateLabel),
          pw.Text(
            'لا تمثل هذه المخرجات تصميماً تنفيذياً أو اعتماداً لمعيار NEC عند نقص بيانات اللوح والسلاسل والكابلات.',
          ),
          if (connectionImage != null) ...[
            pw.SizedBox(height: 18),
            _heading('شكل توضيحي للربط'),
            pw.Center(child: pw.Image(connectionImage, height: 180)),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'SUN-solar-report.pdf',
    );
  }

  static pw.Widget _heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _inputTable(FinalCalculationDto dto) {
    final settings = dto.settings;
    return pw.TableHelper.fromTextArray(
      headers: const ['الحقل', 'القيمة'],
      data: [
        ['النظام', _modeLabel(settings.systemMode)],
        ['قدرة اللوح', '${settings.panelCapacity} W'],
        ['تيار Isc', '${settings.panelIsc} A'],
        ['PSH', '${settings.peakSunHours} h'],
        ['جهد النظام', '${settings.systemVoltage} V'],
        ['جهد الشبكة', '${settings.gridVoltage} V'],
        [
          'الفقد الكلي المستخدم في النموذج',
          '${settings.energyLossPercentage}%',
        ],
        ['الاستقلالية', '${settings.daysOfAutonomy} يوم'],
        [
          'جدول الشبكة',
          '${settings.gridSchedule.gridOnHours}h تشغيل / ${settings.gridSchedule.gridOffHours}h انقطاع',
        ],
        [
          'بداية توفر الشبكة',
          '${settings.gridSchedule.gridStartHour.toStringAsFixed(2)}h',
        ],
        [
          'اعتماد الشحن على الشبكة',
          '${settings.gridSchedule.gridChargeDependencyPercent}%',
        ],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      border: pw.TableBorder.all(color: PdfColors.grey400),
    );
  }

  static pw.Widget _loadsTable(List<LoadModel> loads) {
    return pw.TableHelper.fromTextArray(
      headers: const [
        'الاسم',
        'القدرة',
        'الكمية',
        'نهار h',
        'ليل h',
        'الفترات المخصصة',
        'المعامل',
      ],
      data: loads
          .map(
            (load) => [
              load.name,
              '${load.powerValue} ${load.unit.name}',
              '${load.quantity}',
              load.daytimeHours.toStringAsFixed(2),
              load.nighttimeHours.toStringAsFixed(2),
              load.operatingPeriods.isEmpty
                  ? 'نهار/ليل'
                  : load.operatingPeriods
                        .map(
                          (period) =>
                              '${period.startHour.toStringAsFixed(1)}–${period.endHour.toStringAsFixed(1)}',
                        )
                        .join('، '),
              load.startingCurrentMultiplier.toStringAsFixed(2),
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      border: pw.TableBorder.all(color: PdfColors.grey400),
    );
  }

  static pw.Widget _resultsTable(SystemResultModel result) {
    return pw.TableHelper.fromTextArray(
      headers: const ['النتيجة', 'القيمة'],
      data: [
        [
          'الاستهلاك اليومي',
          '${result.totalDailyConsumptionWh.toStringAsFixed(0)} Wh',
        ],
        [
          'الطاقة النهارية',
          '${result.daytimeConsumptionWh.toStringAsFixed(0)} Wh',
        ],
        [
          'الطاقة الليلية',
          '${result.nighttimeConsumptionWh.toStringAsFixed(0)} Wh',
        ],
        ['ذروة الحمل', '${result.peakLoadW.toStringAsFixed(0)} W'],
        [
          'سعة الإنفرتر',
          '${result.requiredInverterCapacityW.toStringAsFixed(0)} W',
        ],
        ['عدد الألواح', '${result.requiredPanels}'],
        ['ألواح النهار', '${result.panelsForDaytime}'],
        ['ألواح البطارية', '${result.panelsForBatteries}'],
        [
          'سعة البطارية الاسمية',
          '${result.requiredBatteryCapacityAh.toStringAsFixed(1)} Ah',
        ],
        [
          'طاقة البطارية القابلة للاستخدام',
          '${result.usableBatteryEnergyWh.toStringAsFixed(0)} Wh',
        ],
        [
          'اعتماد الشبكة',
          '${result.gridContributionPercent.toStringAsFixed(0)}%',
        ],
        ['أولوية الشحن', result.suggestedChargePriority],
        [
          'التكلفة التقديرية',
          '${result.estimatedCostUsd.toStringAsFixed(2)} USD',
        ],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 10),
      border: pw.TableBorder.all(color: PdfColors.grey400),
    );
  }

  static String _modeLabel(SystemMode mode) => switch (mode) {
    SystemMode.hybrid => 'هايبرد',
    SystemMode.offGrid => 'مستقل',
    SystemMode.ups => 'UPS',
    SystemMode.directOnGrid => 'تشغيل نهاري مباشر',
  };
}
