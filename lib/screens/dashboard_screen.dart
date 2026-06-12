import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(systemResultProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.systemDashboard),
        actions: [
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
      body: result.totalDailyConsumptionWh == 0 && result.requiredInverterCapacityW == 0
          ? const Center(
              child: Text(
                AppStrings.noLoadDataAvailable,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(
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
                      if (!isDaytimeOnly) '${AppStrings.nighttimeConsumption}: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} W',
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
                      '${AppStrings.peakLoad}: ${result.peakLoadW.toStringAsFixed(0)} W',
                      '${AppStrings.safetyMargin}: ${result.safetyMarginW.toStringAsFixed(0)} W',
                    ]),
                  ),
                  if (!isDaytimeOnly)
                    _buildResultCard(
                      title: AppStrings.batteryBank,
                      value: '${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah',
                      icon: Icons.battery_charging_full,
                      color: Colors.green,
                      onTap: () => _showExplanationModal(context, AppStrings.batteryExplanationTitle, [
                        AppStrings.batteryExplanationBody,
                        'السعة المطلوبة: ${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah',
                        if (result.requiredGridChargingAmps > 0) 'أمبير الشحن المطلوب من الوطنية: ${result.requiredGridChargingAmps.toStringAsFixed(1)} A',
                      ]),
                    ),
                  if (ref.watch(gridScheduleProvider).isUpsMode == false)
                    _buildResultCard(
                      title: AppStrings.solarPanels,
                      value: '${result.requiredPanels} ${AppStrings.panelsUnit}',
                      icon: Icons.solar_power,
                      color: Colors.amber,
                      onTap: () => _showExplanationModal(context, AppStrings.panelsExplanationTitle, [
                        AppStrings.recommendedPanelBrands,
                        '${AppStrings.panelsDaytime}: ${result.panelsForDaytime} لوح',
                        if (!isDaytimeOnly) '${AppStrings.panelsBattery}: ${result.panelsForBatteries} لوح',
                        if (result.gridContributionPercent > 0) 'بما أن الوطنية متوفرة، سيتم شحن البطاريات منها بنسبة ${result.gridContributionPercent.toStringAsFixed(0)}% مما يقلل الحاجة لألواح شحن إضافية.',
                        if (result.panelsSavedByGrid > 0) 'عدد الألواح التي تم توفيرها بسبب وجود الوطنية: ${result.panelsSavedByGrid} لوح',
                        'المجموع الكلي: ${result.requiredPanels} لوح',
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
                      '${(result.estimatedCostUsd * 1500).toStringAsFixed(0)} ${AppStrings.costInIqd}',
                      '\n${AppStrings.pricingDisclaimer}',
                    ]),
                  ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showExplanationModal(BuildContext context, String title, List<String> details) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...details.map((detail) => Padding(
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
                  )),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              )
            ],
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
              ),
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
