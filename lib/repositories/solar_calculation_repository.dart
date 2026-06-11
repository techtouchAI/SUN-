import '../models/load_model.dart';
import '../models/system_result_model.dart';

class SolarCalculationRepository {
  // Constants for calculations
  static const double systemVoltage = 24.0; // Assume 24V system for batteries (can be parameterized)
  static const double gridVoltage = 220.0; // 220V AC
  static const double tonToWatts = 3516.85; // 1 Ton of refrigeration = 3516.85W (Thermal), but for AC input power it's usually less. Let's use standard electrical equivalent or a practical value.
  // For air conditioners, 1 Ton roughly consumes 1000W-1200W electrical. Let's use a practical average: 1200W per Ton.
  static const double electricalWattsPerTon = 1200.0;
  static const double inverterAcEfficiencyFactor = 0.6; // Inverter ACs consume about 60% of max power on average over time.
  static const double systemLossFactor = 1.3; // 30% losses (temperature, wiring, inverter efficiency)
  static const double batteryDoD = 0.5; // 50% Depth of Discharge for Gel/Lead-Acid. (80% for Lithium, let's stick to 50% as default for safety or parameterize it)
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

  double calculateBatteryCapacity(double nighttimeConsumptionWh, bool isDaytimeOnly) {
    if (isDaytimeOnly || nighttimeConsumptionWh <= 0) return 0.0;

    // Ah = (Wh / System Voltage) / DoD
    return (nighttimeConsumptionWh / systemVoltage) / batteryDoD;
  }

  Map<String, int> calculatePanelsDetails(double daytimeWh, double nighttimeWh, double panelCapacity, bool isDaytimeOnly) {
    if (daytimeWh == 0 && nighttimeWh == 0) return {'daytimePanels': 0, 'batteryPanels': 0, 'totalPanels': 0};

    // Total Wh to produce = Consumption * System Losses
    double requiredDaytimeProductionWh = daytimeWh * systemLossFactor;
    double requiredNighttimeProductionWh = isDaytimeOnly ? 0 : nighttimeWh * systemLossFactor;

    // Required total panel wattage = Required Production / Peak Sun Hours
    double requiredDaytimePanelWattage = requiredDaytimeProductionWh / peakSunHours;
    double requiredNighttimePanelWattage = requiredNighttimeProductionWh / peakSunHours;

    int panelsForDaytime = (requiredDaytimePanelWattage / panelCapacity).ceil();
    int panelsForBatteries = (requiredNighttimePanelWattage / panelCapacity).ceil();

    return {
      'daytimePanels': panelsForDaytime,
      'batteryPanels': panelsForBatteries,
      'totalPanels': panelsForDaytime + panelsForBatteries
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

  SystemResultModel calculateSystem(List<LoadModel> loads, {double panelCapacity = 540.0, bool isDaytimeOnly = false}) {
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

      final batteryCapacity = calculateBatteryCapacity(nighttimeConsumption, isDaytimeOnly);

      final panelsDetails = calculatePanelsDetails(daytimeConsumption, nighttimeConsumption, panelCapacity, isDaytimeOnly);
      final panelsForDaytime = panelsDetails['daytimePanels']!;
      final panelsForBatteries = panelsDetails['batteryPanels']!;
      final totalPanelsRequired = panelsDetails['totalPanels']!;

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
        dailyProductionCurve: productionCurve,
      );
    } catch (e) {
      // Fallback logic to prevent crashes and "no data" errors
      return SystemResultModel.empty();
    }
  }
}
