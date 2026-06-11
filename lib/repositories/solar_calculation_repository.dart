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

  double calculateTotalConsumption(List<LoadModel> loads) {
    if (loads.isEmpty) return 0.0;

    double totalWh = 0.0;
    for (var load in loads) {
      double watts = _convertToWatts(load);

      if (load.isInverterDevice && load.unit == PowerUnit.ton) {
        // Apply efficiency factor for inverter ACs over time
        totalWh += watts * load.dailyUsageHours * inverterAcEfficiencyFactor;
      } else {
        totalWh += watts * load.dailyUsageHours;
      }
    }
    return totalWh;
  }

  double calculateInverterCapacity(List<LoadModel> loads) {
    if (loads.isEmpty) return 0.0;

    double peakWatts = 0.0;
    for (var load in loads) {
      double watts = _convertToWatts(load);
      peakWatts += watts * load.startingCurrentMultiplier;
    }

    // Add 25% safety margin
    return peakWatts * 1.25;
  }

  double calculateBatteryCapacity(List<LoadModel> loads, {double nightUsageFraction = 0.6}) {
    if (loads.isEmpty) return 0.0;

    double totalWh = calculateTotalConsumption(loads);
    // Assume a fraction of total consumption happens at night (e.g., 60%)
    double nightConsumptionWh = totalWh * nightUsageFraction;

    // Ah = (Wh / System Voltage) / DoD
    double requiredAh = (nightConsumptionWh / systemVoltage) / batteryDoD;

    return requiredAh;
  }

  int calculatePanelsRequired(List<LoadModel> loads, double panelCapacity) {
    if (loads.isEmpty) return 0;

    double totalWh = calculateTotalConsumption(loads);

    // Total Wh to produce = Consumption * System Losses
    double requiredDailyProductionWh = totalWh * systemLossFactor;

    // Required total panel wattage = Required Production / Peak Sun Hours
    double requiredTotalPanelWattage = requiredDailyProductionWh / peakSunHours;

    // Number of panels
    return (requiredTotalPanelWattage / panelCapacity).ceil();
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

  SystemResultModel calculateSystem(List<LoadModel> loads, {double panelCapacity = 540.0}) {
    try {
      if (loads.isEmpty) {
        return SystemResultModel.empty();
      }

      double totalConsumption = calculateTotalConsumption(loads);
      double inverterCapacity = calculateInverterCapacity(loads);
      double batteryCapacity = calculateBatteryCapacity(loads);
      int panelsRequired = calculatePanelsRequired(loads, panelCapacity);
      List<double> productionCurve = calculateDailyProductionCurve(panelsRequired, panelCapacity);

      return SystemResultModel(
        totalDailyConsumptionWh: totalConsumption,
        requiredInverterCapacityW: inverterCapacity,
        requiredBatteryCapacityAh: batteryCapacity,
        requiredPanels: panelsRequired,
        dailyProductionCurve: productionCurve,
      );
    } catch (e) {
      // Fallback logic to prevent crashes and "no data" errors
      return SystemResultModel.empty();
    }
  }
}
