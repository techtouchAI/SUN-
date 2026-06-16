import 'package:flutter/foundation.dart';
import '../models/load_model.dart';
import '../models/system_result_model.dart';
import '../models/grid_schedule_model.dart';
import '../models/system_mode.dart';
import '../models/calculation_breakdown_model.dart';

class SolarCalculationRepository {
  // Domain Engineering Constants
  static const Map<int, double> panelIscDictionary = {
    330: 9.5,
    400: 10.5,
    450: 11.5,
    540: 13.8,
    600: 18.5,
  };

  static double getInterpolatedIsc(double wattage) {
    if (wattage <= 0) return 0.0;

    final keys = panelIscDictionary.keys.toList()..sort();

    if (wattage <= keys.first) return panelIscDictionary[keys.first]!;
    if (wattage >= keys.last) return panelIscDictionary[keys.last]!;

    for (int i = 0; i < keys.length - 1; i++) {
      int lowerWatt = keys[i];
      int upperWatt = keys[i + 1];

      if (wattage >= lowerWatt && wattage <= upperWatt) {
        double lowerIsc = panelIscDictionary[lowerWatt]!;
        double upperIsc = panelIscDictionary[upperWatt]!;

        // Linear interpolation
        double ratio = (wattage - lowerWatt) / (upperWatt - lowerWatt);
        return lowerIsc + (ratio * (upperIsc - lowerIsc));
      }
    }
    return 0.0;
  }

  static const double electricalWattsPerTon =
      1200.0; // Rough estimate for AC conversion
  // Used for Ampere conversion
  static const double inverterAcEfficiencyFactor =
      0.6; // Inverter ACs run at ~60% load over time
  static const double inverterEfficiency =
      0.90; // 10% loss when converting DC from battery/panels to AC

  double _convertToWatts(LoadModel load, double gridVoltage) {
    switch (load.unit) {
      case PowerUnit.watt:
        return load.powerValue;
      case PowerUnit.ampere:
        return load.powerValue *
            gridVoltage; // W = V * I (Assuming PF = 1 for simplicity)
      case PowerUnit.ton:
        return load.powerValue * electricalWattsPerTon;
    }
  }

  Map<String, double> calculateConsumptionDetails(
    List<LoadModel> loads,
    double gridVoltage, {
    double nightUsageFraction = 0.6,
  }) {
    if (loads.isEmpty) {
      return {
        'total': 0.0,
        'daytime': 0.0,
        'nighttime': 0.0,
        'continuousDaytimeWatts': 0.0,
      };
    }

    double totalWh = 0.0;
    double continuousDaytimeWatts = 0.0;

    for (var load in loads) {
      double watts = _convertToWatts(load, gridVoltage);

      if (load.isInverterDevice) {
        // Inverter ACs reduce consumption over time by ~40% (efficiency multiplier = 0.6)
        totalWh += watts * load.dailyUsageHours * inverterAcEfficiencyFactor;
      } else {
        totalWh += watts * load.dailyUsageHours;
      }

      // Calculate continuous daytime watts (assuming daytime loads run continuously for daytime calculations)
      // Here we sum the watts of all loads that might run during the day.
      // If a load has 0 daily hours, we ignore it. Otherwise, we add its wattage to the continuous daytime watts.
      if (load.dailyUsageHours > 0) {
        continuousDaytimeWatts += watts;
      }
    }

    double nighttime = totalWh * nightUsageFraction;
    double daytime = totalWh - nighttime;

    return {
      'total': totalWh,
      'daytime': daytime,
      'nighttime': nighttime,
      'continuousDaytimeWatts': continuousDaytimeWatts,
    };
  }

  Map<String, double> calculateInverterDetails(
    List<LoadModel> loads,
    double gridVoltage,
  ) {
    if (loads.isEmpty) {
      return {'peakLoad': 0.0, 'safetyMargin': 0.0, 'totalCapacity': 0.0};
    }

    double peakWatts = 0.0;
    for (var load in loads) {
      double watts = _convertToWatts(load, gridVoltage);
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

    return {
      'peakLoad': peakWatts,
      'safetyMargin': safetyMargin,
      'totalCapacity': totalCapacity,
    };
  }

  double calculateBatteryCapacity(
    double nighttimeConsumptionWh,
    SystemMode systemMode,
    String batteryType,
    double systemVoltage,
    double daysOfAutonomy,
  ) {
    if (systemMode == SystemMode.directOnGrid || nighttimeConsumptionWh <= 0) {
      return 0.0;
    }

    double batteryDoD = batteryType == 'Lithium' ? 0.8 : 0.5;

    // Ah = (Wh / System Voltage) / DoD * daysOfAutonomy
    return ((nighttimeConsumptionWh / systemVoltage) / batteryDoD) *
        daysOfAutonomy;
  }

  Map<String, dynamic> calculatePanelsDetails({
    required double daytimeWh,
    required double nighttimeWh,
    required double continuousDaytimeWatts,
    required double panelCapacity,
    required SystemMode systemMode,
    required GridScheduleModel gridSchedule,
    required double peakSunHours,
    required double energyLossPercentage,
    required double chargeEfficiency,
  }) {
    if ((daytimeWh == 0 && nighttimeWh == 0) || systemMode == SystemMode.ups) {
      return {
        'daytimePanels': 0,
        'batteryPanels': 0,
        'totalPanels': 0,
        'gridContributionPercent': 0.0,
        'panelsSavedByGrid': 0,
        'daytimePanelsExplanationAr': '',
        'daytimePanelsExplanationEn': '',
        'batteryPanelsExplanationAr': '',
        'batteryPanelsExplanationEn': '',
        'floatPreservationRecommendationAr': '',
      };
    }

    // Effective Panel Capacity due to System Losses/Heat
    double effectivePanelCapacity =
        panelCapacity * (1.0 - (energyLossPercentage / 100.0));

    // For night time consumption, we must account for charge efficiency
    double energyToRechargeWh = nighttimeWh > 0
        ? nighttimeWh / chargeEfficiency
        : 0.0;

    // Total Wh to produce
    double requiredDaytimeProductionWh = daytimeWh;
    double requiredNighttimeProductionWh = systemMode == SystemMode.directOnGrid
        ? 0
        : energyToRechargeWh;

    // --- Daytime Panels Calculation: Energy Path vs Power Path ---
    double energyPathWattage = requiredDaytimeProductionWh / peakSunHours;
    double powerPathWattage =
        (continuousDaytimeWatts / inverterEfficiency) * 1.30; // 30% margin

    double requiredDaytimePanelWattage = 0.0;
    String daytimePanelsExplanationAr = '';
    String daytimePanelsExplanationEn = '';

    int panelsForEnergyPath =
        (energyPathWattage / effectivePanelCapacity).ceil();
    int panelsForPowerPath =
        (powerPathWattage / effectivePanelCapacity).ceil();

    String floatPreservationRecommendationAr = '';

    if (systemMode == SystemMode.directOnGrid) {
      // Strict Power Path (No batteries to buffer)
      requiredDaytimePanelWattage = powerPathWattage;

      daytimePanelsExplanationAr =
          'نظام التشغيل المباشر (Direct On-Grid) يعتمد على مسار القدرة اللحظية. الحمل المستمر = ${continuousDaytimeWatts.toStringAsFixed(0)}W. تم القسمة على كفاءة الانفرتر (0.90) وإضافة معامل استقرار 30% ليكون إجمالي القدرة المطلوبة للنهار = ${requiredDaytimePanelWattage.toStringAsFixed(0)}W.';
      daytimePanelsExplanationEn =
          'Direct On-Grid mode relies on the Instantaneous Power Path. Continuous Load = ${continuousDaytimeWatts.toStringAsFixed(0)}W. Divided by inverter efficiency (0.90) and a 30% stability margin added. Total required daytime power = ${requiredDaytimePanelWattage.toStringAsFixed(0)}W.';
    } else {
      // Energy Path (Batteries act as buffer)
      requiredDaytimePanelWattage = energyPathWattage;

      daytimePanelsExplanationAr =
          'نظام (الهجين / المستقل) يعتمد على مسار الطاقة حيث تعمل البطارية كممتص للصدمات (Buffer). الطاقة المطلوبة نهاراً = ${requiredDaytimeProductionWh.toStringAsFixed(0)}Wh. بالقسمة على ساعات الذروة الشمسية ($peakSunHours)، القدرة المطلوبة = ${requiredDaytimePanelWattage.toStringAsFixed(0)}W.';
      daytimePanelsExplanationEn =
          'Hybrid/Off-Grid mode relies on the Energy Path (Batteries act as buffer). Daytime energy required = ${requiredDaytimeProductionWh.toStringAsFixed(0)}Wh. Divided by Peak Sun Hours ($peakSunHours), required power = ${requiredDaytimePanelWattage.toStringAsFixed(0)}W.';

      if (panelsForPowerPath > panelsForEnergyPath) {
        int diff = panelsForPowerPath - panelsForEnergyPath;
        floatPreservationRecommendationAr = '💡 نصيحة هندسية للاستقرار: للحفاظ على عمر البطاريات وضمان دخولها فترة الليل مشحونة 100% دون استنزاف نهاري، يُفضل إضافة $diff لوح شمسي إضافي لتغطية الفواقد الطبيعية.';
      }
    }

    int panelsForDaytime =
        (requiredDaytimePanelWattage / effectivePanelCapacity).ceil();

    // --- Nighttime (Battery) Panels Calculation ---
    double requiredNighttimePanelWattage =
        requiredNighttimeProductionWh / peakSunHours;
    int originalPanelsForBatteries =
        (requiredNighttimePanelWattage / effectivePanelCapacity).ceil();

    int panelsForBatteries = originalPanelsForBatteries;
    double gridContributionPercent = 0.0;
    int panelsSavedByGrid = 0;
    String batteryPanelsExplanationAr = '';
    String batteryPanelsExplanationEn = '';

    if (systemMode != SystemMode.offGrid &&
        systemMode != SystemMode.directOnGrid &&
        gridSchedule.gridOnHours > 0) {
      // Grid Integration Logic - ONLY for Battery Charging
      double nighttimeGridContribution =
          (gridSchedule.gridChargeDependencyPercent / 100.0).clamp(0.0, 1.0);

      panelsForBatteries =
          (originalPanelsForBatteries * (1 - nighttimeGridContribution)).ceil();
      panelsSavedByGrid = originalPanelsForBatteries - panelsForBatteries;
      gridContributionPercent =
          nighttimeGridContribution * 100; // to percentage

      batteryPanelsExplanationAr =
          'القدرة المطلوبة لشحن البطاريات = ${requiredNighttimePanelWattage.toStringAsFixed(0)}W. عدد الألواح الأساسي = $originalPanelsForBatteries. تم تخفيض الألواح بنسبة ${gridContributionPercent.toStringAsFixed(0)}% بناءً على اعتمادية الشحن من الشبكة الوطنية. تم توفير $panelsSavedByGrid ألواح.';
      batteryPanelsExplanationEn =
          'Power required for battery charging = ${requiredNighttimePanelWattage.toStringAsFixed(0)}W. Original panels = $originalPanelsForBatteries. Panels reduced by ${gridContributionPercent.toStringAsFixed(0)}% based on grid charging dependency. Saved $panelsSavedByGrid panels.';
    } else if (systemMode != SystemMode.directOnGrid) {
      batteryPanelsExplanationAr =
          'القدرة المطلوبة لشحن البطاريات = ${requiredNighttimePanelWattage.toStringAsFixed(0)}W، مقسومة على القدرة الفعلية للوح. لا يوجد اعتماد على الشبكة الوطنية للشحن.';
      batteryPanelsExplanationEn =
          'Power required for battery charging = ${requiredNighttimePanelWattage.toStringAsFixed(0)}W, divided by effective panel capacity. No grid dependency for charging.';
    }

    return {
      'daytimePanels': panelsForDaytime,
      'batteryPanels': panelsForBatteries,
      'totalPanels': panelsForDaytime + panelsForBatteries,
      'gridContributionPercent': gridContributionPercent,
      'panelsSavedByGrid': panelsSavedByGrid,
      'daytimePanelsExplanationAr': daytimePanelsExplanationAr,
      'daytimePanelsExplanationEn': daytimePanelsExplanationEn,
      'batteryPanelsExplanationAr': batteryPanelsExplanationAr,
      'batteryPanelsExplanationEn': batteryPanelsExplanationEn,
      'floatPreservationRecommendationAr': floatPreservationRecommendationAr,
    };
  }

  List<double> calculateDailyProductionCurve(
    int numPanels,
    double panelCapacity,
  ) {
    if (numPanels <= 0) return [0, 0, 0, 0, 0];

    double totalPeakPower = numPanels * panelCapacity;

    // Simulating production curve across Dawn, Morning, Noon (Peak), Afternoon, Evening
    // This is a simplified bell curve-like distribution
    return [
      totalPeakPower * 0.1, // Dawn (10%)
      totalPeakPower * 0.5, // Morning (50%)
      totalPeakPower *
          0.9, // Noon (Peak) (90%) - not 100% due to real-world losses even at peak
      totalPeakPower * 0.5, // Afternoon (50%)
      totalPeakPower * 0.1, // Evening (10%)
    ];
  }

  int _calculateWireSize(double maxAmps) {
    if (maxAmps <= 20) return 4;
    if (maxAmps <= 30) return 6;
    if (maxAmps <= 50) return 10;
    return 25; // per prompt up to 100A
  }

  SystemResultModel calculateSystem(
    List<LoadModel> loads, {
    required double gridVoltage,
    String inverterLocation = 'indoor',
    double panelCapacity = 540.0,
    double panelIsc = 0.0,
    SystemMode systemMode = SystemMode.hybrid,
    GridScheduleModel gridSchedule = const GridScheduleModel(),
    double solarWattPrice = 0.16,
    double batteryAmperePrice = 0.85,
    double breakerPrice = 0.0,
    double wiringCost = 0.0,
    double systemVoltage = 48.0,
    double peakSunHours = 4.5,
    double energyLossPercentage = 18.0,
    double daysOfAutonomy = 1.0,
  }) {
    try {
      if (loads.isEmpty) {
        return SystemResultModel.empty();
      }

      final consumptionDetails = calculateConsumptionDetails(
        loads,
        gridVoltage,
      );
      final totalConsumption = consumptionDetails['total']!;
      final daytimeConsumption = consumptionDetails['daytime']!;
      final nighttimeConsumption = consumptionDetails['nighttime']!;
      final continuousDaytimeWatts =
          consumptionDetails['continuousDaytimeWatts']!;

      // Apply Inverter Efficiency to get Actual DC Wh needed from panels/battery
      final actualDaytimeDcWh = daytimeConsumption / inverterEfficiency;
      final actualNighttimeDcWh = nighttimeConsumption / inverterEfficiency;

      double chargeEfficiency = gridSchedule.batteryType == 'Lithium'
          ? 0.95
          : 0.85;

      final inverterDetails = calculateInverterDetails(loads, gridVoltage);
      final peakLoad = inverterDetails['peakLoad']!;
      final safetyMargin = inverterDetails['safetyMargin']!;
      final totalInverterCapacity = inverterDetails['totalCapacity']!;

      final batteryCapacity = calculateBatteryCapacity(
        actualNighttimeDcWh,
        systemMode,
        gridSchedule.batteryType,
        systemVoltage,
        daysOfAutonomy,
      );

      final panelsDetails = calculatePanelsDetails(
        daytimeWh: actualDaytimeDcWh,
        nighttimeWh: actualNighttimeDcWh,
        continuousDaytimeWatts: continuousDaytimeWatts,
        panelCapacity: panelCapacity,
        systemMode: systemMode,
        gridSchedule: gridSchedule,
        peakSunHours: peakSunHours,
        energyLossPercentage: energyLossPercentage,
        chargeEfficiency: chargeEfficiency,
      );
      final panelsForDaytime = panelsDetails['daytimePanels'] as int;
      final panelsForBatteries = panelsDetails['batteryPanels'] as int;
      final totalPanelsRequired = panelsDetails['totalPanels'] as int;
      final gridContributionPercent =
          panelsDetails['gridContributionPercent'] as double;
      final panelsSavedByGrid = panelsDetails['panelsSavedByGrid'] as int;

      final productionCurve = calculateDailyProductionCurve(
        totalPanelsRequired,
        panelCapacity,
      );

      double requiredGridChargingAmps = 0.0; // DC Amps
      double requiredGridChargingAcAmps = 0.0; // AC Amps draw
      double timeToFullHours = 0.0;
      String gelBatteryWarning = '';

      double effectivePanelCapacity =
          panelCapacity * (1.0 - (energyLossPercentage / 100.0));
      double maxAmps = gridSchedule.batteryType == 'Lead-Acid/Gel'
          ? batteryCapacity * 0.20
          : double.infinity;

      if (gridSchedule.gridOnHours > 0 &&
          systemMode != SystemMode.offGrid &&
          systemMode != SystemMode.directOnGrid) {
        // Calculate grid portion based on dependency percent and proportional night hours
        double energyToRechargeWh = actualNighttimeDcWh > 0
            ? actualNighttimeDcWh / chargeEfficiency
            : 0.0;
        double dailyWhToRecharge = energyToRechargeWh;
        double nighttimeGridHours = gridSchedule.gridOnHours * (14.0 / 24.0);

        double gridWattsNeeded = 0.0;
        if (nighttimeGridHours > 0) {
          double dependency = systemMode == SystemMode.ups
              ? 100.0
              : gridSchedule.gridChargeDependencyPercent;
          gridWattsNeeded =
              (dailyWhToRecharge * (dependency / 100.0)) / nighttimeGridHours;
        }

        requiredGridChargingAmps = gridWattsNeeded / systemVoltage;
      }

      // Solar Battery Charging Amps
      double maxSolarChargingAmps =
          (panelsForBatteries * effectivePanelCapacity) / systemVoltage;

      // Ensure total charging amps from panels/grid don't exceed maxAmps (0.2C) for Gel batteries
      if (gridSchedule.batteryType == 'Lead-Acid/Gel') {
        if (requiredGridChargingAmps > maxAmps ||
            maxSolarChargingAmps > maxAmps) {
          if (requiredGridChargingAmps > maxAmps) {
            requiredGridChargingAmps = maxAmps;
          }
          gelBatteryWarning =
              'تحذير: تيار الشحن الإجمالي (من الألواح أو الوطنية) عالي جداً وقد يتلف بطاريات الجل. تم تقييد حسابات تيار الشحن لـ ${maxAmps.toStringAsFixed(1)}A (0.2C)';
        }
      }

      if (requiredGridChargingAmps > 0 &&
          systemMode != SystemMode.offGrid &&
          systemMode != SystemMode.directOnGrid) {
        double dcPower = requiredGridChargingAmps * systemVoltage;
        double requiredAcPower = dcPower / 0.95; // 95% inverter efficiency
        requiredGridChargingAcAmps = requiredAcPower / gridVoltage;
        timeToFullHours = batteryCapacity / requiredGridChargingAmps;
      }

      String suggestedInverterType = '';
      if (systemMode == SystemMode.ups) {
        suggestedInverterType = 'إنفرتر شاحن / UPS';
      } else if (systemMode == SystemMode.directOnGrid) {
        suggestedInverterType = 'إنفرتر أون-جريد (On-Grid Inverter)';
      } else if (systemMode == SystemMode.hybrid) {
        suggestedInverterType = 'إنفرتر هايبرد (Hybrid Inverter)';
      } else {
        suggestedInverterType = 'إنفرتر أوف-جريد (Off-Grid Inverter)';
      }

      // Safety Standards Calculations
      double mpptAmps = 0.0;
      String mpptRecommendationAr = '';
      if (panelsForBatteries > 0 && panelIsc > 0) {
        mpptAmps = panelsForBatteries * panelIsc * 1.25;
        mpptRecommendationAr = 'حجم منظم الشحن (MPPT) المقترح: ${mpptAmps.toStringAsFixed(1)} أمبير';
      }

      double pvDcBreakerAmps = panelIsc > 0 ? (panelIsc * 1.56) : 0;
      double maxContinuousBatteryCurrent =
          (totalInverterCapacity / inverterEfficiency) / systemVoltage;
      double batteryDcBreakerAmps = maxContinuousBatteryCurrent * 1.25;
      double maxAcOutputCurrent = totalInverterCapacity / gridVoltage;
      double acBreakerAmps = maxAcOutputCurrent * 1.25;

      // Determine max amps for wire sizing
      double maxAmpsForWire = [
        maxContinuousBatteryCurrent,
        requiredGridChargingAmps,
        maxAcOutputCurrent,
        if (panelIsc > 0) panelIsc * 1.56,
      ].reduce((a, b) => a > b ? a : b);

      int wireSizeMm2 = _calculateWireSize(maxAmpsForWire);

      String suggestedChargePriority =
          gridSchedule.gridChargeDependencyPercent > 50
          ? 'SNU / Utility First'
          : 'CSO / Solar First';
      String suggestedIpRating = inverterLocation == 'outdoor'
          ? 'IP65'
          : 'IP20';

      // Pricing Calculations
      int totalBreakersCount = 0;
      if (pvDcBreakerAmps > 0) totalBreakersCount++;
      if (batteryDcBreakerAmps > 0) totalBreakersCount++;
      if (acBreakerAmps > 0) totalBreakersCount++;

      double inverterCost =
          (totalInverterCapacity / 1000.0) * 100.0; // $100 per kW
      double solarPanelsCost =
          totalPanelsRequired * panelCapacity * solarWattPrice;
      double batteriesCost = batteryCapacity * batteryAmperePrice;
      double breakersCost = totalBreakersCount * breakerPrice;

      double totalEstimatedCostUsd =
          solarPanelsCost +
          batteriesCost +
          inverterCost +
          breakersCost +
          wiringCost;

      String inverterExplanationAr =
          'الحمل المستمر وقت الذروة = ${peakLoad.toStringAsFixed(0)}W. يضاف هامش أمان 25% (${safetyMargin.toStringAsFixed(0)}W) لتكون القدرة المطلوبة ${totalInverterCapacity.toStringAsFixed(0)}W.';
      String inverterExplanationEn =
          'Peak Continuous Load = ${peakLoad.toStringAsFixed(0)}W. Added a 25% safety margin (${safetyMargin.toStringAsFixed(0)}W) for a total required capacity of ${totalInverterCapacity.toStringAsFixed(0)}W.';

      String batteryExplanationAr = '';
      String batteryExplanationEn = '';
      if (systemMode != SystemMode.directOnGrid && batteryCapacity > 0) {
        double batteryDoD = gridSchedule.batteryType == 'Lithium' ? 0.8 : 0.5;
        String dodString = (batteryDoD * 100).toStringAsFixed(0);
        batteryExplanationAr =
            'استهلاك الليل المباشر = ${nighttimeConsumption.toStringAsFixed(0)}Wh. قسمة على كفاءة الانفرتر (0.90) = ${actualNighttimeDcWh.toStringAsFixed(0)}Wh. بمعامل تفريغ ($dodString% DoD) ونظام فولطية (${systemVoltage}V) السعة المطلوبة هي ${batteryCapacity.toStringAsFixed(0)}Ah.';
        batteryExplanationEn =
            'Nighttime direct consumption = ${nighttimeConsumption.toStringAsFixed(0)}Wh. Divided by inverter efficiency (0.90) = ${actualNighttimeDcWh.toStringAsFixed(0)}Wh. Considering DoD ($dodString%) and system voltage (${systemVoltage}V), required capacity is ${batteryCapacity.toStringAsFixed(0)}Ah.';
      }

      CalculationBreakdownModel breakdown = CalculationBreakdownModel(
        daytimePanelsExplanationAr: panelsDetails['daytimePanelsExplanationAr'],
        daytimePanelsExplanationEn: panelsDetails['daytimePanelsExplanationEn'],
        batteryPanelsExplanationAr: panelsDetails['batteryPanelsExplanationAr'],
        batteryPanelsExplanationEn: panelsDetails['batteryPanelsExplanationEn'],
        inverterExplanationAr: inverterExplanationAr,
        inverterExplanationEn: inverterExplanationEn,
        batteryExplanationAr: batteryExplanationAr,
        batteryExplanationEn: batteryExplanationEn,
        floatPreservationRecommendationAr: panelsDetails['floatPreservationRecommendationAr'] ?? '',
        mpptRecommendationAr: mpptRecommendationAr,
      );

      return SystemResultModel(
        totalDailyConsumptionWh: totalConsumption,
        daytimeConsumptionWh: daytimeConsumption,
        nighttimeConsumptionWh: nighttimeConsumption,
        peakLoadW: peakLoad,
        safetyMarginW: safetyMargin,
        requiredInverterCapacityW: totalInverterCapacity,
        requiredBatteryCapacityAh: batteryCapacity,
        systemVoltage: systemVoltage,
        requiredPanels: totalPanelsRequired,
        panelsForDaytime: panelsForDaytime,
        panelsForBatteries: panelsForBatteries,
        gridContributionPercent: gridContributionPercent,
        panelsSavedByGrid: panelsSavedByGrid,
        dailyProductionCurve: productionCurve,
        requiredGridChargingAmps: requiredGridChargingAmps,
        requiredGridChargingAcAmps: requiredGridChargingAcAmps,
        timeToFullHours: timeToFullHours,
        suggestedInverterType: suggestedInverterType,
        energyLossPercentage: '${energyLossPercentage.toStringAsFixed(0)}%',
        recommendedInverterBrands: 'Deye, Growatt, Huawei, Victron Energy',
        recommendedPanelBrands: 'Longi, Jinko Solar, JA Solar, Trina Solar',
        pvDcBreakerAmps: pvDcBreakerAmps,
        batteryDcBreakerAmps: batteryDcBreakerAmps,
        acBreakerAmps: acBreakerAmps,
        wireSizeMm2: wireSizeMm2,
        estimatedCostUsd: totalEstimatedCostUsd,
        totalBreakersCount: totalBreakersCount,
        suggestedChargePriority: suggestedChargePriority,
        gelBatteryWarning: gelBatteryWarning,
        suggestedIpRating: suggestedIpRating,
        breakdown: breakdown,
      );
    } catch (e, st) {
      // Re-throw or log to avoid swallowing the error
      debugPrint('Error calculating system: $e\n$st');
      rethrow;
    }
  }
}
