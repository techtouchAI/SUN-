import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import '../models/calculation_state.dart';

String? productionHourLabel(double value, int pointCount) {
  final hour = value.toInt();
  if (hour < 0 || hour >= pointCount || hour % 3 != 0) return null;
  return '${hour.toString().padLeft(2, '0')}:00';
}

class ChartScreen extends ConsumerWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculationState = ref.watch(calculationStateProvider);
    if (calculationState is! CalculationReady) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.dailyProductionCurve)),
        body: const Center(
          child: Text('لا يمكن عرض المخطط قبل اكتمال حساب صحيح.'),
        ),
      );
    }
    final result = calculationState.result;
    final curve = result.dailyProductionCurve;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.dailyProductionCurve)),
      body: result.requiredPanels == 0
          ? const Center(child: Text(AppStrings.noSolarProductionData))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    AppStrings.estimatedSolarProductionVsTime,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            curve.reduce(
                              (curr, next) => curr > next ? curr : next,
                            ) *
                            1.2, // dynamic max height
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 3,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final label = productionHourLabel(
                                  value,
                                  curve.length,
                                );
                                if (label == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0) return const Text('0');
                                return Text(
                                  '${(value / 1000).toStringAsFixed(1)}k',
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (int i = 0; i < curve.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: curve[i],
                                  color: Colors.amber,
                                  width: 20,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    AppStrings.yAxisPowerWatts,
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
    );
  }
}
