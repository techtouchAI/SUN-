import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/calculation_state.dart';
import '../models/system_result_model.dart';
import '../services/pdf_export_service.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculation = ref.watch(calculationStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('نتائج الحساب'),
        actions: [
          if (calculation is CalculationReady)
            IconButton(
              tooltip: 'تصدير PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportPdf(context, ref),
            ),
          IconButton(
            tooltip: 'المنحنى الزمني',
            icon: const Icon(Icons.show_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChartScreen()),
            ),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: switch (calculation) {
        CalculationNoLoads() => const _StatusView(
          icon: Icons.info_outline,
          message: 'أضف حملاً واحداً على الأقل قبل عرض النتائج.',
        ),
        CalculationInvalidInput(error: final error) => _StatusView(
          icon: Icons.error_outline,
          message: error.message,
          color: Colors.red,
        ),
        CalculationFailed(error: final error) => _StatusView(
          icon: Icons.error_outline,
          message: 'فشل الحساب دون إخفاء السبب: $error',
          color: Colors.red,
        ),
        CalculationReady(result: final result) => _results(
          context,
          ref,
          result,
        ),
      },
    );
  }

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    SystemResultModel result,
  ) {
    final settings = ref.watch(systemSettingsProvider);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تقدير أولي غير تنفيذي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                Text(result.electricalEstimateLabel),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metricCard(
                      'الاستهلاك اليومي',
                      '${result.totalDailyConsumptionWh.toStringAsFixed(0)} Wh',
                      Icons.bolt,
                    ),
                    _metricCard(
                      'ذروة الحمل',
                      '${result.peakLoadW.toStringAsFixed(0)} W',
                      Icons.flash_on,
                    ),
                    _metricCard(
                      'الإنفرتر',
                      '${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
                      Icons.power,
                    ),
                    _metricCard(
                      'الألواح',
                      '${result.requiredPanels}',
                      Icons.wb_sunny,
                    ),
                    _metricCard(
                      'البطارية',
                      '${result.requiredBatteryCapacityAh.toStringAsFixed(1)} Ah @ ${settings.systemVoltage.toStringAsFixed(0)}V',
                      Icons.battery_full,
                    ),
                    _metricCard(
                      'الشحن من الشبكة',
                      '${result.gridContributionPercent.toStringAsFixed(0)}%',
                      Icons.electrical_services,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _details(result),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'التكلفة التقديرية: ${result.estimatedCostUsd.toStringAsFixed(2)} USD',
                        ),
                        Text(
                          'بالدينار: ${(result.estimatedCostUsd * settings.iqdExchangeRate).toStringAsFixed(0)} IQD',
                        ),
                        Text('نوع الإنفرتر: ${result.suggestedInverterType}'),
                        Text(
                          'المعيار الكهربائي: ${result.electricalEstimateLabel}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'الافتراضات والتحذيرات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...result.breakdown.assumptionsAr.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(item),
                      ),
                    ),
                    ...result.breakdown.warningsAr.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _details(SystemResultModel result) {
    final children = <Widget>[
      const Text(
        'تفصيل الحساب',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      if (result.breakdown.daytimePanelsExplanationAr.isNotEmpty)
        Text(result.breakdown.daytimePanelsExplanationAr),
      if (result.breakdown.batteryPanelsExplanationAr.isNotEmpty)
        Text(result.breakdown.batteryPanelsExplanationAr),
      Text(result.breakdown.inverterExplanationAr),
      Text(result.breakdown.batteryExplanationAr),
      if (result.suggestedChargePriority.isNotEmpty)
        Text('أولوية الشحن: ${result.suggestedChargePriority}'),
      if (result.gelBatteryWarning.isNotEmpty)
        Text(
          result.gelBatteryWarning,
          style: const TextStyle(color: Colors.orange),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final dto = ref.read(finalCalculationDtoProvider);
    if (dto == null) return;
    try {
      await PdfExportService.exportCalculationReport(dto);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تصدير التقرير: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _StatusView({required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
