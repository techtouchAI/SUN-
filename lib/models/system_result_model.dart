import 'calculation_breakdown_model.dart';
import 'safety_audit_model.dart';

class SystemResultModel {
  final double totalDailyConsumptionWh;
  final double daytimeConsumptionWh;
  final double nighttimeConsumptionWh;
  final double peakLoadW;
  final double safetyMarginW;
  final double requiredInverterCapacityW;
  final double requiredBatteryCapacityAh;
  final double requiredBatteryEnergyWh;
  final double usableBatteryEnergyWh;
  final double systemVoltage;
  final int requiredPanels;
  final int panelsForDaytime;
  final int panelsForBatteries;
  final double gridContributionPercent;
  final int panelsSavedByGrid;
  final List<double> dailyProductionCurve;
  final List<double> hourlyPvPowerW;
  final List<double> hourlyLoadPowerW;
  final List<double> hourlyGridPowerW;
  final List<double> hourlyBatterySocPercent;
  final double totalPvEnergyWh;
  final double requiredGridChargingAmps;
  final double requiredGridChargingAcAmps;
  final double timeToFullHours;
  final String suggestedInverterType;
  final String energyLossPercentage;
  final String recommendedInverterBrands;
  final String recommendedPanelBrands;
  final double pvDcBreakerAmps;
  final double batteryDcBreakerAmps;
  final double acBreakerAmps;
  final int wireSizeMm2;
  final double estimatedCostUsd;
  final int totalBreakersCount;
  final String suggestedChargePriority;
  final String gelBatteryWarning;
  final String suggestedIpRating;
  final String electricalEstimateLabel;
  final String? calculationError;
  final CalculationBreakdownModel breakdown;
  final SafetyAuditReport safetyAudit;

  const SystemResultModel({
    required this.totalDailyConsumptionWh,
    required this.daytimeConsumptionWh,
    required this.nighttimeConsumptionWh,
    required this.peakLoadW,
    required this.safetyMarginW,
    required this.requiredInverterCapacityW,
    required this.requiredBatteryCapacityAh,
    this.requiredBatteryEnergyWh = 0,
    this.usableBatteryEnergyWh = 0,
    this.systemVoltage = 48,
    required this.requiredPanels,
    required this.panelsForDaytime,
    required this.panelsForBatteries,
    required this.gridContributionPercent,
    required this.panelsSavedByGrid,
    required this.dailyProductionCurve,
    this.hourlyPvPowerW = const [],
    this.hourlyLoadPowerW = const [],
    this.hourlyGridPowerW = const [],
    this.hourlyBatterySocPercent = const [],
    this.totalPvEnergyWh = 0,
    this.requiredGridChargingAmps = 0,
    this.requiredGridChargingAcAmps = 0,
    this.timeToFullHours = 0,
    this.suggestedInverterType = '',
    this.energyLossPercentage = '',
    this.recommendedInverterBrands = '',
    this.recommendedPanelBrands = '',
    this.pvDcBreakerAmps = 0,
    this.batteryDcBreakerAmps = 0,
    this.acBreakerAmps = 0,
    this.wireSizeMm2 = 0,
    this.estimatedCostUsd = 0,
    this.totalBreakersCount = 0,
    this.suggestedChargePriority = '',
    this.gelBatteryWarning = '',
    this.suggestedIpRating = '',
    this.electricalEstimateLabel = 'تقدير كهربائي أولي غير تنفيذي',
    this.calculationError,
    this.breakdown = const CalculationBreakdownModel(
      daytimePanelsExplanationAr: '',
      daytimePanelsExplanationEn: '',
      batteryPanelsExplanationAr: '',
      batteryPanelsExplanationEn: '',
      inverterExplanationAr: '',
      inverterExplanationEn: '',
      batteryExplanationAr: '',
      batteryExplanationEn: '',
    ),
    this.safetyAudit = const SafetyAuditReport.empty(),
  });

  static SystemResultModel failure(String message) {
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
      dailyProductionCurve: const [0, 0, 0, 0, 0],
      calculationError: message,
    );
  }
}
