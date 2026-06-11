import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import 'chart_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(systemResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChartScreen()),
              );
            },
          )
        ],
      ),
      body: result.totalDailyConsumptionWh == 0
          ? const Center(
              child: Text(
                'No load data available. Please add loads.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                children: [
                  _buildResultCard(
                    title: 'Total Consumption',
                    value: '${(result.totalDailyConsumptionWh / 1000).toStringAsFixed(2)} kWh',
                    icon: Icons.electrical_services,
                    color: Colors.blue,
                  ),
                  _buildResultCard(
                    title: 'Required Inverter',
                    value: '${(result.requiredInverterCapacityW / 1000).toStringAsFixed(2)} kW',
                    icon: Icons.power,
                    color: Colors.orange,
                  ),
                  _buildResultCard(
                    title: 'Battery Bank',
                    value: '${result.requiredBatteryCapacityAh.toStringAsFixed(0)} Ah',
                    icon: Icons.battery_charging_full,
                    color: Colors.green,
                  ),
                  _buildResultCard(
                    title: 'Solar Panels',
                    value: '${result.requiredPanels} Panels',
                    subtitle: '(Assuming 550W each)',
                    icon: Icons.solar_power,
                    color: Colors.amber,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
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
    );
  }
}
