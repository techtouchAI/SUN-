class SystemResultModel {
  final double totalDailyConsumptionWh; // Total Wh consumed per day
  final double requiredInverterCapacityW; // Peak load with safety margin
  final double requiredBatteryCapacityAh; // Required Ah based on night usage, voltage, and DoD
  final int requiredPanels; // Number of panels needed based on total consumption and PSH
  final List<double> dailyProductionCurve; // Curve showing power production at different times of day (e.g., Dawn, Morning, Noon, Afternoon, Evening)

  SystemResultModel({
    required this.totalDailyConsumptionWh,
    required this.requiredInverterCapacityW,
    required this.requiredBatteryCapacityAh,
    required this.requiredPanels,
    required this.dailyProductionCurve,
  });

  factory SystemResultModel.empty() {
    return SystemResultModel(
      totalDailyConsumptionWh: 0,
      requiredInverterCapacityW: 0,
      requiredBatteryCapacityAh: 0,
      requiredPanels: 0,
      dailyProductionCurve: [0, 0, 0, 0, 0], // Dawn, Morning, Noon, Afternoon, Evening
    );
  }
}
