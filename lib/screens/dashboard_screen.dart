import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import '../models/calculation_state.dart';
import '../models/dc_cable_installation_model.dart';
import '../models/pv_array_topology_model.dart';
import '../models/safety_audit_model.dart';
import '../models/system_mode.dart';
import '../models/system_result_model.dart';
import '../repositories/solar_calculation_repository.dart';
import 'chart_screen.dart';
import 'settings_screen.dart';
import '../services/pdf_export_service.dart';
import '../widgets/reactive_text_field.dart';
import '../widgets/safety_audit_details.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculationState = ref.watch(calculationStateProvider);
    final systemMode = ref.watch(systemModeProvider);
    final loads = ref.watch(loadListProvider);

    if (loads.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.systemDashboard)),
        body: const Center(
          child: Text(
            'الرجاء إضافة أحمال أولاً',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (calculationState is! CalculationReady) {
      final message = switch (calculationState) {
        CalculationInvalidInput(:final error) => error.message,
        CalculationFailed(:final error) => error.toString(),
        _ => 'لا توجد نتيجة حساب جاهزة حالياً.',
      };
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.systemDashboard)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'تعذر إكمال الحساب.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final result = calculationState.result;

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
                  ref.read(panelCapacityProvider),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ReactiveTextField(
                      initialValue: ref.watch(panelCapacityProvider),
                      labelText: AppStrings.panelCapacityWatts,
                      onChanged: (value) {
                        final parsedValue = double.tryParse(value);
                        if (parsedValue != null && parsedValue > 0) {
                          ref.read(panelCapacityProvider.notifier).state =
                              parsedValue;
                          ref.read(panelIscProvider.notifier).state =
                              SolarCalculationRepository.getInterpolatedIsc(
                                parsedValue,
                              );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ReactiveTextField(
                      initialValue: ref.watch(panelIscProvider),
                      labelText: AppStrings.panelIsc,
                      onChanged: (value) {
                        final parsedValue = double.tryParse(value);
                        if (parsedValue != null && parsedValue >= 0) {
                          ref.read(panelIscProvider.notifier).state =
                              parsedValue;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.65,
                children: [
                  _buildResultCard(
                    title: AppStrings.totalConsumption,
                    value:
                        '${(result.totalDailyConsumptionWh / 1000).toStringAsFixed(2)} kWh',
                    icon: Icons.electrical_services,
                    color: Colors.blue,
                    onTap: () => _showExplanationModal(
                      context,
                      AppStrings.consumptionExplanationTitle,
                      [
                        '${AppStrings.totalConsumption}: ${result.totalDailyConsumptionWh.toStringAsFixed(0)} Wh',
                        '${AppStrings.daytimeConsumption}: ${result.daytimeConsumptionWh.toStringAsFixed(0)} Wh',
                        if (systemMode != SystemMode.directOnGrid)
                          '${AppStrings.nighttimeConsumption}: ${result.nighttimeConsumptionWh.toStringAsFixed(0)} Wh',
                      ],
                      headerValue:
                          '${(result.totalDailyConsumptionWh / 1000).toStringAsFixed(2)} kWh',
                    ),
                  ),
                  _buildResultCard(
                    title: AppStrings.requiredInverter,
                    value:
                        '${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
                    icon: Icons.power,
                    color: Colors.orange,
                    onTap: () => _showExplanationModal(
                      context,
                      AppStrings.inverterExplanationTitle,
                      [
                        'النوع المقترح: ${result.suggestedInverterType}',
                        result.breakdown.inverterExplanationAr,
                        if (result.suggestedIpRating.isNotEmpty)
                          'تقييم الحماية المقترح (IP): ${result.suggestedIpRating}',
                      ],
                      headerValue:
                          '${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
                    ),
                  ),
                  if (systemMode != SystemMode.directOnGrid)
                    _buildResultCard(
                      title: AppStrings.batteryBank,
                      value: result.requiredBatteryCapacityAh > 0
                          ? '${result.requiredBatteryCapacityAh.toStringAsFixed(0)}Ah (${((result.requiredBatteryCapacityAh * result.systemVoltage) / 1000).toStringAsFixed(1)} kWh) بناءً على نظام ${result.systemVoltage.toStringAsFixed(0)}V'
                          : 'غير مطلوب — لا يوجد استهلاك ليلي',
                      icon: Icons.battery_charging_full,
                      color: Colors.green,
                      onTap: () => _showExplanationModal(
                        context,
                        AppStrings.batteryExplanationTitle,
                        result.requiredBatteryCapacityAh > 0
                            ? [
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
                                if (result.gelBatteryWarning.isNotEmpty)
                                  result.gelBatteryWarning,
                              ]
                            : [
                                'لم تُدخل ساعات تشغيل ليلية للأحمال؛ لذلك لا توجد طاقة ليلية تتطلب بطاريات في هذه النتيجة.',
                              ],
                        headerValue: result.requiredBatteryCapacityAh > 0
                            ? '${result.requiredBatteryCapacityAh.toStringAsFixed(0)}Ah (${((result.requiredBatteryCapacityAh * result.systemVoltage) / 1000).toStringAsFixed(1)} kWh)'
                            : 'غير مطلوب',
                        headerSubtitle: result.requiredBatteryCapacityAh > 0
                            ? 'بناءً على نظام ${result.systemVoltage.toStringAsFixed(0)}V'
                            : null,
                      ),
                    ),
                  if (systemMode != SystemMode.ups)
                    _buildResultCard(
                      title: AppStrings.solarPanels,
                      value:
                          '${result.requiredPanels} ${AppStrings.panelsUnit} (تمت الحسابات بناءً على ألواح بقدرة ${ref.watch(panelCapacityProvider).toStringAsFixed(0)}W)',
                      icon: Icons.solar_power,
                      color: Colors.amber,
                      onTap: () => _showExplanationModal(
                        context,
                        AppStrings.panelsExplanationTitle,
                        [
                          '${AppStrings.panelsDaytime}: ${result.panelsForDaytime} لوح',
                          result.breakdown.daytimePanelsExplanationAr,
                          if (systemMode != SystemMode.directOnGrid) ...[
                            '\n${AppStrings.panelsBattery}: ${result.panelsForBatteries} لوح',
                            result.breakdown.batteryPanelsExplanationAr,
                            if (result
                                .breakdown
                                .mpptRecommendationAr
                                .isNotEmpty)
                              '\n${result.breakdown.mpptRecommendationAr}',
                          ],
                          '\nالمجموع الكلي: ${result.requiredPanels} لوح',
                          if (systemMode != SystemMode.directOnGrid)
                            '\n💡 ملاحظة هندسية حول تقليل الألواح:\nيمكنك تقليل عدد الألواح المقترحة، ولكن تذكر أن الألواح هي المصدر الأساسي لتوفير الأمبير نهاراً. في حال كان إنتاج الألواح أقل من استهلاك الحمل، ستقوم المنظومة بتعويض العجز عن طريق سحب التيار من البطاريات نهاراً. هذا السحب المستمر سيمنع البطاريات من الوصول للامتلاء، ويزيد من دورات التفريغ (Cycle Life)، مما يقلل من عمرها الافتراضي.',
                          if (result
                              .breakdown
                              .floatPreservationRecommendationAr
                              .isNotEmpty)
                            '\n${result.breakdown.floatPreservationRecommendationAr}',
                        ],
                        headerValue:
                            '${result.requiredPanels} ${AppStrings.panelsUnit}',
                        headerSubtitle:
                            'تمت الحسابات بناءً على ألواح بقدرة ${ref.watch(panelCapacityProvider).toStringAsFixed(0)}W',
                      ),
                    ),
                  _buildResultCard(
                    title: AppStrings.energyLossTitle,
                    value: result.energyLossPercentage,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.deepOrange,
                    onTap: () => _showExplanationModal(
                      context,
                      AppStrings.energyLossExplanationTitle,
                      [
                        AppStrings.energyLossTemp,
                        AppStrings.energyLossInverter,
                        AppStrings.energyLossWiring,
                        AppStrings.energyLossSoiling,
                      ],
                      headerValue: result.energyLossPercentage,
                    ),
                  ),
                  _buildResultCard(
                    title: AppStrings.safetyStandardsTitle,
                    value: result.safetyAudit.hasCalculatedValue
                        ? 'حساب تلقائي'
                        : 'غير متاح',
                    icon: Icons.health_and_safety,
                    color: Colors.redAccent,
                    onTap: () => _showSafetyAuditModal(context, ref, result),
                  ),
                  _buildResultCard(
                    title: AppStrings.estimatedSystemCost,
                    value: '\$${result.estimatedCostUsd.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.green.shade700,
                    onTap: () => _showExplanationModal(
                      context,
                      AppStrings.estimatedSystemCost,
                      [
                        '${result.estimatedCostUsd.toStringAsFixed(2)} ${AppStrings.costInUsd}',
                        '${(result.estimatedCostUsd / 100).toStringAsFixed(2)} ${AppStrings.costInWarqa}',
                        '${(result.estimatedCostUsd * ref.watch(iqdExchangeRateProvider)).toStringAsFixed(0)} ${AppStrings.costInIqd}',
                        '\n${AppStrings.pricingDisclaimer}',
                      ],
                      headerValue:
                          '\$${result.estimatedCostUsd.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "شكل توضيحي للربط",
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                            const Icon(
                              Icons.image_not_supported,
                              size: 100,
                              color: Colors.grey,
                            ),
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

  void _showSafetyAuditModal(
    BuildContext context,
    WidgetRef ref,
    SystemResultModel result,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.88,
        child: SafetyAuditDetails(
          report: result.safetyAudit,
          requiredPanels: result.requiredPanels,
          panelIscAmps: ref.read(panelIscProvider),
          savedTopology: PvArrayTopologyModel(
            modulesPerString: ref.read(pvModulesPerStringProvider),
            parallelStrings: ref.read(pvParallelStringsProvider),
          ),
          savedDcCable: DcCableInstallationModel(
            oneWayLengthMeters: ref.read(dcCableLengthMetersProvider),
            conductorMaterial: ref.read(dcCableMaterialProvider),
            insulationRating: ref.read(dcCableInsulationProvider),
            installationMethod: ref.read(dcCableInstallationMethodProvider),
            ambientTemperatureCelsius: ref.read(
              dcCableAmbientTemperatureProvider,
            ),
            loadedConductors: ref.read(dcCableLoadedConductorsProvider),
          ),
          onTopologySelected: (topology) {
            ref.read(pvModulesPerStringProvider.notifier).state =
                topology.modulesPerString;
            ref.read(pvParallelStringsProvider.notifier).state =
                topology.parallelStrings;
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ ترتيب الألواح وإعادة حساب الحماية.'),
              ),
            );
          },
          onInputRequested: (kind) {
            final section = switch (kind) {
              ProtectionResultKind.pvArrayCurrent => SettingsSection.pvTopology,
              ProtectionResultKind.dcConductorSize => SettingsSection.dcCable,
              _ => null,
            };
            if (section == null) return;
            Navigator.pop(sheetContext);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SettingsScreen(initialSection: section),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showExplanationModal(
    BuildContext context,
    String title,
    List<String> details, {
    required String headerValue,
    String? headerSubtitle,
  }) {
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  headerValue,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                if (headerSubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    headerSubtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
                const Divider(height: 24, thickness: 1.5),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details.map((detail) {
                        final parts = detail.split(':');
                        final hasTitle =
                            parts.length > 1 && parts[0].length < 60;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 18)),
                              Expanded(
                                child: hasTitle
                                    ? RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '${parts[0]}:\n',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: parts
                                                  .sublist(1)
                                                  .join(':')
                                                  .trim(),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Text(
                                        detail,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
        onTap: () {
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
