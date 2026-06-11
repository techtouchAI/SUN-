class SystemResultModel {
  final double totalDailyConsumptionWh; // Total Wh consumed per day
  final double daytimeConsumptionWh;
  final double nighttimeConsumptionWh;
  final double peakLoadW;
  final double safetyMarginW;
  final double requiredInverterCapacityW; // Peak load with safety margin
  final double requiredBatteryCapacityAh; // Required Ah based on night usage, voltage, and DoD
  final int requiredPanels; // Number of panels needed based on total consumption and PSH
  final int panelsForDaytime;
  final int panelsForBatteries;
  final List<double> dailyProductionCurve; // Curve showing power production at different times of day (e.g., Dawn, Morning, Noon, Afternoon, Evening)

  SystemResultModel({
    required this.totalDailyConsumptionWh,
    required this.daytimeConsumptionWh,
    required this.nighttimeConsumptionWh,
    required this.peakLoadW,
    required this.safetyMarginW,
    required this.requiredInverterCapacityW,
    required this.requiredBatteryCapacityAh,
    required this.requiredPanels,
    required this.panelsForDaytime,
    required this.panelsForBatteries,
    required this.dailyProductionCurve,
  });

  factory SystemResultModel.empty() {
    return SystemResultModel(
      totalDailyConsumptionWh: 0,
      daytimeConsumptionWh: 0,
      nighttimeConsumptionWh: 0,
      peakLoadW: 0,
      safetyMarginW: 0,
      requiredInverterCapacityW: 0,
      requiredBatteryCapacityAh: 0,
      requiredPanels: 0,
      panelsForDaytime: 0,
      panelsForBatteries: 0,
      dailyProductionCurve: [0, 0, 0, 0, 0], // Dawn, Morning, Noon, Afternoon, Evening
    );
  }
}
