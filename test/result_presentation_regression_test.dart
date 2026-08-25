import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/system_result_model.dart';
import 'package:solar_calculator/screens/chart_screen.dart';
import 'package:solar_calculator/services/pdf_export_service.dart';

void main() {
  test('production chart labels are safe for the 24-hour curve', () {
    expect(productionHourLabel(0, 24), '00:00');
    expect(productionHourLabel(3, 24), '03:00');
    expect(productionHourLabel(21, 24), '21:00');
    expect(productionHourLabel(23, 24), isNull);
    expect(productionHourLabel(24, 24), isNull);
  });

  test('PDF summary keeps no-night battery and protection states concise', () {
    final result = SystemResultModel.failure('not used by the summary');

    expect(PdfExportService.batterySummaryLines(result), const [
      'غير مطلوب — لا يوجد استهلاك ليلي.',
    ]);
    expect(PdfExportService.protectionSummaryLines(result), hasLength(4));
    expect(
      PdfExportService.protectionSummaryLines(result).join(' '),
      isNot(contains('Source Input')),
    );
  });
}
