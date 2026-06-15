import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import '../models/system_mode.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';
import '../services/pdf_export_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(systemErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
    final result = ref.watch(systemResultProvider);
    final systemMode = ref.watch(systemModeProvider);
    final loads = ref.watch(loadListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.systemDashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () async {
              try {
                final pdfService = PdfExportService();
                await pdfService.exportDashboardToPdf(
                  result,
                  loads,
                  systemMode,
                  ref.read(iqdExchangeRateProvider),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء تصدير PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChartScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: loads.isEmpty
          ? const Center(
              child: Text(
                "الرجاء إضافة أحمال أولاً",
                style: TextStyle(fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: ref.read(panelCapacityProvider).toString(),
                          decoration: const InputDecoration(
                            labelText: AppStrings.panelCapacityWatts,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsedValue = double.tryParse(value);
                            if (parsedValue != null && parsedValue > 0) {
                              ref.read(panelCapacityProvider.notifier).state = parsedValue;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: ref.read(panelIscProvider).toString(),
                          decoration: const InputDecoration(
                            labelText: AppStrings.panelIsc,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsedValue = double.tryParse(value);
                            if (parsedValue != null && parsedValue >= 0) {
                              ref.read(panelIscProvider.notifier).state = parsedValue;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    AppStrings.interactiveHint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      children: [
                  _buildResultCard(
                    title: AppStrings.totalConsumption,
                    value: '${(result.totalDailyConsumptionWh / 1000).toStringAsFixed(2)} kWh',
                    icon: Icons.electrical_services,
                    color: Colors.blue,
                    onTap: () => _showExplanationModal(context, AppStrings.consumptionExplanationTitle, [
                      '${AppStrings.totalConsumption}: ${result.totalDailyConsumptionWh.toStringAsFixed(0)} W',
                      '${AppStrings.daytimeConsumption}: ${result.daytimeConsumptionWh.toStringAsFixed(0)} W',
                      if (systemMode != SystemMode.directOnGrid) '${AppStrings.nighttimeConsumption}: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} W',
                    ]),
                  ),
                  _buildResultCard(
                    title: AppStrings.requiredInverter,
                    value: '${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
                    icon: Icons.power,
                    color: Colors.orange,
                    onTap: () => _showExplanationModal(context, AppStrings.inverterExplanationTitle, [
                      'النوع المقترح: ${result.suggestedInverterType}',
                      AppStrings.recommendedInverterBrands,
                      'حجم الإنفرتر تم اختياره بناءً على أقصى حمل لحظي يمكن أن يعمل في نفس الوقت، مع إضافة هامش أمان لحماية الجهاز.',
                      'يوضح هذا أيضاً تأثير الأجهزة الإنفرتر في تقليل الحمل المبدئي (Surge).',
                      if (result.suggestedIpRating.isNotEmpty) 'تقييم الحماية المقترح (IP): ${result.suggestedIpRating}',
                      '${AppStrings.peakLoad}: ${result.peakLoadW.toStringAsFixed(0)} W',
                      '${AppStrings.safetyMargin}: ${result.safetyMarginW.toStringAsFixed(0)} W',
                    ]),
                  ),
                  if (systemMode != SystemMode.directOnGrid)
                    _buildResultCard(
                      title: AppStrings.batteryBank,
                      value: '${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah',
                      icon: Icons.battery_charging_full,
                      color: Colors.green,
                      onTap: () => _showExplanationModal(context, AppStrings.batteryExplanationTitle, [
                        AppStrings.batteryExplanationBody,
                        'السعة المطلوبة: ${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah',
                        if (result.requiredGridChargingAmps > 0) '⚡ تيار شحن البطاريات الداخلي (DC): ${result.requiredGridChargingAmps.toStringAsFixed(1)} A',
                        if (result.requiredGridChargingAcAmps > 0) '🔌 السحب الفعلي من الشبكة (AC): ${result.requiredGridChargingAcAmps.toStringAsFixed(1)} A',
                        if (result.timeToFullHours > 0) '⏳ الوقت المقدر لشحن البطاريات بالكامل: ${result.timeToFullHours.toStringAsFixed(1)} ساعات',
                        if (result.suggestedChargePriority.isNotEmpty) 'أولوية الشحن المقترحة: ${result.suggestedChargePriority}',
                        if (result.gelBatteryWarning.isNotEmpty) result.gelBatteryWarning,
                      ]),
                    ),
                  if (systemMode != SystemMode.ups)
                    _buildResultCard(
                      title: AppStrings.solarPanels,
                      value: '${result.requiredPanels} ${AppStrings.panelsUnit}',
                      icon: Icons.solar_power,
                      color: Colors.amber,
                      onTap: () => _showExplanationModal(context, AppStrings.panelsExplanationTitle, [
                        AppStrings.recommendedPanelBrands,
                        '${AppStrings.panelsDaytime}: ${result.panelsForDaytime} لوح',
                        if (systemMode != SystemMode.directOnGrid) '${AppStrings.panelsBattery}: ${result.panelsForBatteries} لوح',
                        if (result.gridContributionPercent > 0) 'بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.',
                        if (result.panelsSavedByGrid > 0) 'عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح',
                        'المجموع الكلي: ${result.requiredPanels} لوح',
                        '\n💡 ملاحظة هندسية حول تقليل الألواح:\nيمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.',
                      ]),
                    ),
                  _buildResultCard(
                    title: AppStrings.energyLossTitle,
                    value: result.energyLossPercentage,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.deepOrange,
                    onTap: () => _showExplanationModal(context, AppStrings.energyLossExplanationTitle, [
                      AppStrings.energyLossTemp,
                      AppStrings.energyLossInverter,
                      AppStrings.energyLossWiring,
                      AppStrings.energyLossSoiling,
                    ]),
                  ),
                  _buildResultCard(
                    title: AppStrings.safetyStandardsTitle,
                    value: 'NEC Standards',
                    icon: Icons.health_and_safety,
                    color: Colors.redAccent,
                    onTap: () => _showExplanationModal(context, AppStrings.safetyStandardsTitle, [
                      if (result.pvDcBreakerAmps > 0) '${AppStrings.pvBreaker}: ${result.pvDcBreakerAmps.toStringAsFixed(1)} A',
                      if (result.batteryDcBreakerAmps > 0) '${AppStrings.batteryBreaker}: ${result.batteryDcBreakerAmps.toStringAsFixed(1)} A',
                      if (result.acBreakerAmps > 0) '${AppStrings.acBreaker}: ${result.acBreakerAmps.toStringAsFixed(1)} A',
                      if (result.wireSizeMm2 > 0) '${AppStrings.dcWireSize}: ${result.wireSizeMm2} ${AppStrings.wireMm2}',
                    ]),
                  ),
                  _buildResultCard(
                    title: AppStrings.estimatedSystemCost,
                    value: '\$${result.estimatedCostUsd.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.green.shade700,
                    onTap: () => _showExplanationModal(context, AppStrings.estimatedSystemCost, [
                      '${result.estimatedCostUsd.toStringAsFixed(2)} ${AppStrings.costInUsd}',
                      '${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ${AppStrings.costInWarqa}',
                      '${(result.estimatedCostUsd * ref.watch(iqdExchangeRateProvider)).toStringAsFixed(0)} ${AppStrings.costInIqd}',
                      '\n${AppStrings.pricingDisclaimer}',
                    ]),
                  ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "شكل توضيحي للربط",
                        style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/photoi.png',
                            fit: BoxFit.contain,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
    );
  }

  void _showExplanationModal(BuildContext context, String title, List<String> details) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24.0,
            left: 24.0,
            right: 24.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details.map((detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 18)),
                            Expanded(
                              child: Text(
                                detail,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ]
          ],
        ),
        ),
      ),
    );
  }
}
