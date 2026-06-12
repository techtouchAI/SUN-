import '../models/load_model.dart';
import '../models/system_result_model.dart';
import '../models/grid_schedule_model.dart';

class SolarCalculationRepository {
  // Domain Engineering Constants
  static const double systemVoltage = 48.0; // Assume 48V system
  static const double electricalWattsPerTon = 1200.0; // Rough estimate for AC conversion
  static const double gridVoltage = 220.0; // Used for Ampere conversion
  static const double inverterAcEfficiencyFactor = 0.6; // Inverter ACs run at ~60% load over time
  static const double systemLossFactor = 1.3; // 30% losses (wiring, temp, inverter)
  static const double peakSunHours = 4.5; // Average PSH

  double _convertToWatts(LoadModel load) {
    switch (load.unit) {
      case PowerUnit.watt:
        return load.powerValue;
      case PowerUnit.ampere:
        return load.powerValue * gridVoltage; // W = V * I (Assuming PF = 1 for simplicity)
      case PowerUnit.ton:
        return load.powerValue * electricalWattsPerTon;
    }
  }

  Map<String, double> calculateConsumptionDetails(List<LoadModel> loads, {double nightUsageFraction = 0.6}) {
    if (loads.isEmpty) {
      return {'total': 0.0, 'daytime': 0.0, 'nighttime': 0.0};
    }

    double totalWh = 0.0;
    for (var load in loads) {
      double watts = _convertToWatts(load);

      if (load.isInverterDevice) {
        // Inverter ACs reduce consumption over time by ~40% (efficiency multiplier = 0.6)
        totalWh += watts * load.dailyUsageHours * inverterAcEfficiencyFactor;
      } else {
        totalWh += watts * load.dailyUsageHours;
      }
    }

    double nighttime = totalWh * nightUsageFraction;
    double daytime = totalWh - nighttime;

    return {'total': totalWh, 'daytime': daytime, 'nighttime': nighttime};
  }

  Map<String, double> calculateInverterDetails(List<LoadModel> loads) {
    if (loads.isEmpty) return {'peakLoad': 0.0, 'safetyMargin': 0.0, 'totalCapacity': 0.0};

    double peakWatts = 0.0;
    for (var load in loads) {
      double watts = _convertToWatts(load);
      double multiplier = load.startingCurrentMultiplier;

      if (load.isInverterDevice) {
        multiplier = 1.0; // Inverter ACs do not have a sudden high surge power
      } else if (load.unit == PowerUnit.ton) {
        multiplier = 2.0; // Standard ACs have higher surge
      }

      peakWatts += watts * multiplier;
    }

    double safetyMargin = peakWatts * 0.25; // 25% safety margin
    double totalCapacity = peakWatts + safetyMargin;

    return {'peakLoad': peakWatts, 'safetyMargin': safetyMargin, 'totalCapacity': totalCapacity};
  }

  double calculateBatteryCapacity(double nighttimeConsumptionWh, bool isDaytimeOnly, String batteryType) {
    if (isDaytimeOnly || nighttimeConsumptionWh <= 0) return 0.0;

    double batteryDoD = batteryType == 'Lithium' ? 0.8 : 0.5;

    // Ah = (Wh / System Voltage) / DoD
    return (nighttimeConsumptionWh / systemVoltage) / batteryDoD;
  }

  Map<String, dynamic> calculatePanelsDetails(double daytimeWh, double nighttimeWh, double panelCapacity, bool isDaytimeOnly, GridScheduleModel gridSchedule) {
    if (daytimeWh == 0 && nighttimeWh == 0) {
      return {'daytimePanels': 0, 'batteryPanels': 0, 'totalPanels': 0, 'gridContributionPercent': 0.0, 'panelsSavedByGrid': 0};
    }

    // Total Wh to produce = Consumption * System Losses
    double requiredDaytimeProductionWh = daytimeWh * systemLossFactor;
    double requiredNighttimeProductionWh = isDaytimeOnly ? 0 : nighttimeWh * systemLossFactor;

    // Required total panel wattage = Required Production / Peak Sun Hours
    double requiredDaytimePanelWattage = requiredDaytimeProductionWh / peakSunHours;
    double requiredNighttimePanelWattage = requiredNighttimeProductionWh / peakSunHours;

    int panelsForDaytime = (requiredDaytimePanelWattage / panelCapacity).ceil();
    int originalPanelsForBatteries = (requiredNighttimePanelWattage / panelCapacity).ceil();

    // Grid Integration Logic
    int panelsForBatteries = originalPanelsForBatteries;
    double gridContributionPercent = 0.0;
    int panelsSavedByGrid = 0;

    if (!gridSchedule.isOffGrid && gridSchedule.gridOnHours > 0) {
      // Assuming nighttime is 14 hours. Grid ON hours during night reduces need for solar charging.
      // A simple proportion: if grid is ON for 7 hours, it covers 50% of the charging needs.
      double effectiveGridNightHours = (gridSchedule.gridOnHours / 24.0) * 14.0;
      gridContributionPercent = (effectiveGridNightHours / 14.0).clamp(0.0, 1.0);

      panelsForBatteries = (originalPanelsForBatteries * (1 - gridContributionPercent)).ceil();
      panelsSavedByGrid = originalPanelsForBatteries - panelsForBatteries;
      gridContributionPercent = gridContributionPercent * 100; // to percentage
    }

    return {
      'daytimePanels': panelsForDaytime,
      'batteryPanels': panelsForBatteries,
      'totalPanels': panelsForDaytime + panelsForBatteries,
      'gridContributionPercent': gridContributionPercent,
      'panelsSavedByGrid': panelsSavedByGrid,
    };
  }

  List<double> calculateDailyProductionCurve(int numPanels, double panelCapacity) {
    if (numPanels <= 0) return [0, 0, 0, 0, 0];

    double totalPeakPower = numPanels * panelCapacity;

    // Simulating production curve across Dawn, Morning, Noon (Peak), Afternoon, Evening
    // This is a simplified bell curve-like distribution
    return [
      totalPeakPower * 0.1, // Dawn (10%)
      totalPeakPower * 0.5, // Morning (50%)
      totalPeakPower * 0.9, // Noon (Peak) (90%) - not 100% due to real-world losses even at peak
      totalPeakPower * 0.5, // Afternoon (50%)
      totalPeakPower * 0.1, // Evening (10%)
    ];
  }

  SystemResultModel calculateSystem(List<LoadModel> loads, {double panelCapacity = 540.0, bool isDaytimeOnly = false, GridScheduleModel gridSchedule = const GridScheduleModel()}) {
    try {
      if (loads.isEmpty) {
        return SystemResultModel.empty();
      }

      final consumptionDetails = calculateConsumptionDetails(loads);
      final totalConsumption = consumptionDetails['total']!;
      final daytimeConsumption = consumptionDetails['daytime']!;
      final nighttimeConsumption = consumptionDetails['nighttime']!;

      final inverterDetails = calculateInverterDetails(loads);
      final peakLoad = inverterDetails['peakLoad']!;
      final safetyMargin = inverterDetails['safetyMargin']!;
      final totalInverterCapacity = inverterDetails['totalCapacity']!;

      final batteryCapacity = calculateBatteryCapacity(nighttimeConsumption, isDaytimeOnly, gridSchedule.batteryType);

      final panelsDetails = calculatePanelsDetails(daytimeConsumption, nighttimeConsumption, panelCapacity, isDaytimeOnly, gridSchedule);
      final panelsForDaytime = panelsDetails['daytimePanels'] as int;
      final panelsForBatteries = panelsDetails['batteryPanels'] as int;
      final totalPanelsRequired = panelsDetails['totalPanels'] as int;
      final gridContributionPercent = panelsDetails['gridContributionPercent'] as double;
      final panelsSavedByGrid = panelsDetails['panelsSavedByGrid'] as int;

      final productionCurve = calculateDailyProductionCurve(totalPanelsRequired, panelCapacity);

      return SystemResultModel(
        totalDailyConsumptionWh: totalConsumption,
        daytimeConsumptionWh: daytimeConsumption,
        nighttimeConsumptionWh: nighttimeConsumption,
        peakLoadW: peakLoad,
        safetyMarginW: safetyMargin,
        requiredInverterCapacityW: totalInverterCapacity,
        requiredBatteryCapacityAh: batteryCapacity,
        requiredPanels: totalPanelsRequired,
        panelsForDaytime: panelsForDaytime,
        panelsForBatteries: panelsForBatteries,
        gridContributionPercent: gridContributionPercent,
        panelsSavedByGrid: panelsSavedByGrid,
        dailyProductionCurve: productionCurve,
      );
    } catch (e) {
      // Fallback logic to prevent crashes and "no data" errors
      return SystemResultModel.empty();
    }
  }
}
