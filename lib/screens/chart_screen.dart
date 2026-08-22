import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/providers.dart';
import '../models/calculation_state.dart';

class ChartScreen extends ConsumerWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculationStateProvider);
    if (state is! CalculationReady) {
      return const Scaffold(
        body: Center(child: Text('لا توجد سلسلة زمنية صالحة لعرضها.')),
      );
    }
    final result = state.result;
    final series = [
      result.hourlyPvPowerW,
      result.hourlyLoadPowerW,
      result.hourlyGridPowerW,
    ];
    final maxValue = series
        .expand((values) => values)
        .fold<double>(0, math.max);
    final maxY = maxValue > 0 && maxValue.isFinite ? maxValue * 1.15 : 1.0;

    return Scaffold(
      appBar: AppBar(title: const Text('المنحنى الزمني التوضيحي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Wrap(
              spacing: 18,
              children: [
                _Legend(label: 'PV Power (W)', color: Colors.amber),
                _Legend(label: 'Load Power (W)', color: Colors.blue),
                _Legend(label: 'Grid Power (W)', color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('الساعة'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 3,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}:00',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('القدرة W'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _line(result.hourlyPvPowerW, Colors.amber),
                    _line(result.hourlyLoadPowerW, Colors.blue),
                    _line(result.hourlyGridPowerW, Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'إجمالي طاقة PV اليومية المحسوبة: ${result.totalPvEnergyWh.toStringAsFixed(0)} Wh',
            ),
            const Text(
              'هذا عرض زمني للتقدير؛ لا يمثل قياسات irradiance فعلية ولا اعتماداً تنفيذياً.',
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    final spots = <FlSpot>[];
    for (var index = 0; index < values.length && index < 24; index++) {
      final value = values[index];
      if (value.isFinite && value >= 0) {
        spots.add(FlSpot(index.toDouble(), value));
      }
    }
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
