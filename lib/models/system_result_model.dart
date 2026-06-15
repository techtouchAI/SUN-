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
  final double gridContributionPercent;
  final int panelsSavedByGrid;
  final List<double> dailyProductionCurve; // Curve showing power production at different times of day (e.g., Dawn, Morning, Noon, Afternoon, Evening)
  final double requiredGridChargingAmps; // DC Current
  final double requiredGridChargingAcAmps; // AC Current Draw
  final double timeToFullHours; // Time to full in hours
  final String suggestedInverterType;

  // Energy Loss & Brands
  final String energyLossPercentage;
  final String recommendedInverterBrands;
  final String recommendedPanelBrands;

  // Safety Standards
  final double pvDcBreakerAmps;
  final double batteryDcBreakerAmps;
  final double acBreakerAmps;
  final int wireSizeMm2;

  // Pricing
  final double estimatedCostUsd;
  final int totalBreakersCount;
  final String suggestedChargePriority;
  final String gelBatteryWarning;
  final String suggestedIpRating;

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
    required this.gridContributionPercent,
    required this.panelsSavedByGrid,
    required this.dailyProductionCurve,
    this.requiredGridChargingAmps = 0.0,
    this.requiredGridChargingAcAmps = 0.0,
    this.timeToFullHours = 0.0,
    this.suggestedInverterType = '',
    this.energyLossPercentage = '',
    this.recommendedInverterBrands = '',
    this.recommendedPanelBrands = '',
    this.pvDcBreakerAmps = 0.0,
    this.batteryDcBreakerAmps = 0.0,
    this.acBreakerAmps = 0.0,
    this.wireSizeMm2 = 0,
    this.estimatedCostUsd = 0.0,
    this.totalBreakersCount = 0,
    this.suggestedChargePriority = '',
    this.gelBatteryWarning = '',
    this.suggestedIpRating = '',
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
      gridContributionPercent: 0,
      panelsSavedByGrid: 0,
      dailyProductionCurve: [0, 0, 0, 0, 0], // Dawn, Morning, Noon, Afternoon, Evening
      requiredGridChargingAmps: 0.0,
      requiredGridChargingAcAmps: 0.0,
      timeToFullHours: 0.0,
      suggestedInverterType: '',
      energyLossPercentage: '',
      recommendedInverterBrands: '',
      recommendedPanelBrands: '',
      pvDcBreakerAmps: 0.0,
      batteryDcBreakerAmps: 0.0,
      acBreakerAmps: 0.0,
      wireSizeMm2: 0,
      estimatedCostUsd: 0.0,
      totalBreakersCount: 0,
      suggestedChargePriority: '',
      gelBatteryWarning: '',
      suggestedIpRating: '',
    );
  }
}
