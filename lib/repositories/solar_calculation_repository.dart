import 'dart:math' as math;

import '../core/errors/app_exceptions.dart';
import '../core/validation/input_validator.dart';
import '../models/calculation_breakdown_model.dart';
import '../models/grid_schedule_model.dart';
import '../models/load_model.dart';
import '../models/safety_design_model.dart';
import '../models/system_mode.dart';
import '../models/system_result_model.dart';
import '../services/safety_audit_service.dart';

/// Domain calculation engine for preliminary solar sizing.
///
/// All energy values are Wh/day, power values are W, current values are A,
/// and voltage values are V. Electrical protection outputs are explicitly
/// preliminary because string topology, cable route, temperature and local
/// code data are not part of the current input model.
class SolarCalculationRepository {
  static const Map<int, double> panelIscDictionary = {
    330: 9.5,
    400: 10.5,
    450: 11.5,
    540: 13.8,
    600: 18.5,
  };

  static const double electricalWattsPerTon = 1200.0;
  static const double inverterEfficiency = 0.90;
  static const double gelBatteryDod = 0.50;
  static const double lithiumBatteryDod = 0.80;
  static const double gelBatteryEfficiency = 0.85;
  static const double lithiumBatteryEfficiency = 0.95;
  static const double gelMaximumChargeRate = 0.20;
  static const double daytimeStartHour = 6.0;
  static const double daytimeEndHour = 18.0;
  static const double directModePowerMargin = 1.30;
  static const double inverterSafetyMarginFactor = 0.25;
  static const double estimatedInverterUsdPerKw = 100.0;

  static double getInterpolatedIsc(double wattage) {
    if (!wattage.isFinite || wattage <= 0) return 0.0;
    final keys = panelIscDictionary.keys.toList()..sort();
    if (wattage <= keys.first) return panelIscDictionary[keys.first]!;
    if (wattage >= keys.last) return panelIscDictionary[keys.last]!;
    for (var i = 0; i < keys.length - 1; i++) {
      final lowerWatt = keys[i];
      final upperWatt = keys[i + 1];
      if (wattage >= lowerWatt && wattage <= upperWatt) {
        final ratio = (wattage - lowerWatt) / (upperWatt - lowerWatt);
        final lowerIsc = panelIscDictionary[lowerWatt]!;
        final upperIsc = panelIscDictionary[upperWatt]!;
        return lowerIsc + ratio * (upperIsc - lowerIsc);
      }
    }
    return 0.0;
  }

  double _convertToWatts(LoadModel load, double gridVoltage) {
    final unitWatts = switch (load.unit) {
      PowerUnit.watt => load.powerValue,
      PowerUnit.ampere => load.powerValue * gridVoltage,
      PowerUnit.ton => load.powerValue * electricalWattsPerTon,
    };
    return unitWatts * load.quantity;
  }

  Map<String, double> calculateConsumptionDetails(
    List<LoadModel> loads,
    double gridVoltage,
  ) {
    if (loads.isEmpty) {
      return {
        'total': 0,
        'daytime': 0,
        'nighttime': 0,
        'continuousDaytimeWatts': 0,
      };
    }
    if (!gridVoltage.isFinite || gridVoltage <= 0) {
      throw InvalidEngineeringInput(
        'جهد الشبكة يجب أن يكون منتهياً وأكبر من صفر.',
      );
    }
    InputValidator.validateLoads(loads);

    final energyProfile = _hourlyLoadProfile(loads, gridVoltage);
    final powerProfile = _hourlyActivePowerProfile(loads, gridVoltage);
    final totalWh = energyProfile.fold(0.0, (sum, value) => sum + value);
    final daytimeWh = energyProfile
        .sublist(6, 18)
        .fold(0.0, (sum, value) => sum + value);
    final nighttimeWh = totalWh - daytimeWh;
    final daytimePeak = powerProfile.sublist(6, 18).fold(0.0, math.max);

    return {
      'total': totalWh,
      'daytime': daytimeWh,
      'nighttime': nighttimeWh,
      'continuousDaytimeWatts': daytimePeak,
    };
  }

  Map<String, double> calculateInverterDetails(
    List<LoadModel> loads,
    double gridVoltage,
  ) {
    if (loads.isEmpty) {
      return {'peakLoad': 0, 'safetyMargin': 0, 'totalCapacity': 0};
    }
    final hourlyPeak = _hourlyPeakSurgeWatts(loads, gridVoltage);
    final safetyMargin = hourlyPeak * inverterSafetyMarginFactor;
    return {
      'peakLoad': hourlyPeak,
      'safetyMargin': safetyMargin,
      'totalCapacity': hourlyPeak + safetyMargin,
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
    final dod = _batteryDod(batteryType);
    final batteryEfficiency = _batteryEfficiency(batteryType);
    final usableEnergy =
        nighttimeConsumptionWh * daysOfAutonomy / inverterEfficiency;
    return usableEnergy / (dod * batteryEfficiency * systemVoltage);
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
    _requireFinitePositive(panelCapacity, 'قدرة اللوح');
    _requireFinitePositive(peakSunHours, 'ساعات الذروة');
    if (!energyLossPercentage.isFinite ||
        energyLossPercentage < 0 ||
        energyLossPercentage >= 100) {
      throw InvalidEngineeringInput(
        'نسبة الفقد يجب أن تكون بين 0% و100% حصراً.',
      );
    }
    if (systemMode == SystemMode.ups || (daytimeWh <= 0 && nighttimeWh <= 0)) {
      return _emptyPanelsResult();
    }

    final pvPerformanceFactor = 1.0 - energyLossPercentage / 100.0;
    final panelDailyEnergyWh =
        panelCapacity * peakSunHours * pvPerformanceFactor;
    _requireFinitePositive(panelDailyEnergyWh, 'الطاقة اليومية للوح');

    final daytimeDcEnergyWh = daytimeWh / inverterEfficiency;
    final dod = _batteryDod(gridSchedule.batteryType);
    final batteryEfficiency = _batteryEfficiency(gridSchedule.batteryType);
    final requiredBatteryChargeWh = nighttimeWh <= 0
        ? 0.0
        : (nighttimeWh / inverterEfficiency) /
              (dod * batteryEfficiency) /
              chargeEfficiency;

    final gridFraction =
        systemMode == SystemMode.hybrid && gridSchedule.gridOnHours > 0
        ? (gridSchedule.gridChargeDependencyPercent / 100.0).clamp(0.0, 1.0)
        : 0.0;
    final remainingBatteryPvWh = requiredBatteryChargeWh * (1.0 - gridFraction);

    final daytimePowerPathW =
        (continuousDaytimeWatts / inverterEfficiency) * directModePowerMargin;
    final daytimePanels = systemMode == SystemMode.directOnGrid
        ? _ceilPanelCount(
            daytimePowerPathW,
            panelCapacity * pvPerformanceFactor,
          )
        : _ceilPanelCount(daytimeDcEnergyWh, panelDailyEnergyWh);
    final batteryPanels = systemMode == SystemMode.directOnGrid
        ? 0
        : _ceilPanelCount(remainingBatteryPvWh, panelDailyEnergyWh);

    // Count from combined energy before rounding to avoid double rounding.
    final combinedEnergyPanels = systemMode == SystemMode.directOnGrid
        ? daytimePanels
        : daytimePanels + batteryPanels;

    return {
      'daytimePanels': daytimePanels,
      'batteryPanels': batteryPanels,
      'totalPanels': combinedEnergyPanels,
      'gridContributionPercent': gridFraction * 100.0,
      'panelsSavedByGrid': math.max(
        0,
        _ceilPanelCount(requiredBatteryChargeWh, panelDailyEnergyWh) -
            batteryPanels,
      ),
      'daytimePanelsExplanationAr': systemMode == SystemMode.directOnGrid
          ? 'التشغيل المباشر يعتمد على القدرة اللحظية: ${continuousDaytimeWatts.toStringAsFixed(0)}W، مع كفاءة العاكس وهامش قدرة 30%.'
          : 'تم حساب ألواح النهار من الطاقة النهارية الفعلية ${daytimeWh.toStringAsFixed(0)}Wh، وسعة اللوح اليومية ${panelDailyEnergyWh.toStringAsFixed(0)}Wh.',
      'daytimePanelsExplanationEn': systemMode == SystemMode.directOnGrid
          ? 'Direct mode uses instantaneous daytime power with inverter efficiency and a 30% power margin.'
          : 'Daytime panels are based on the explicit daytime energy profile and effective daily panel energy.',
      'batteryPanelsExplanationAr': systemMode == SystemMode.directOnGrid
          ? ''
          : 'طاقة شحن البطارية المطلوبة قبل الشبكة ${requiredBatteryChargeWh.toStringAsFixed(0)}Wh، والمتبقي من الطاقة الشمسية ${remainingBatteryPvWh.toStringAsFixed(0)}Wh. تم تطبيق اعتماد الشبكة قبل التقريب.',
      'batteryPanelsExplanationEn': systemMode == SystemMode.directOnGrid
          ? ''
          : 'Battery charging energy is reduced by the grid fraction before panel count rounding.',
      'floatPreservationRecommendationAr': '',
      'panelDailyEnergyWh': panelDailyEnergyWh,
      'requiredBatteryChargeWh': requiredBatteryChargeWh,
      'remainingBatteryPvWh': remainingBatteryPvWh,
    };
  }

  List<double> calculateDailyProductionCurve(
    int numPanels,
    double panelCapacity, {
    double peakSunHours = 4.5,
    double energyLossPercentage = 30,
  }) {
    if (numPanels <= 0 || !panelCapacity.isFinite || panelCapacity <= 0) {
      return const [];
    }
    final factor = 1.0 - energyLossPercentage / 100.0;
    if (!factor.isFinite ||
        factor <= 0 ||
        !peakSunHours.isFinite ||
        peakSunHours <= 0) {
      return const [];
    }
    final weights = List<double>.filled(24, 0);
    var sum = 0.0;
    for (var hour = 6; hour < 18; hour++) {
      final value = math.sin(math.pi * (hour - 6 + 0.5) / 12.0).clamp(0.0, 1.0);
      weights[hour] = value;
      sum += value;
    }
    final scale = peakSunHours / sum;
    final peakPower = numPanels * panelCapacity * factor;
    return [for (final weight in weights) peakPower * weight * scale];
  }

  SystemResultModel calculateSystem(
    List<LoadModel> loads, {
    required double gridVoltage,
    String inverterLocation = 'indoor',
    double panelCapacity = 540.0,
    double panelIsc = 0.0,
    SafetyDesignModel safetyDesign = const SafetyDesignModel(),
    SystemMode systemMode = SystemMode.hybrid,
    GridScheduleModel gridSchedule = const GridScheduleModel(),
    double solarWattPrice = 0.16,
    double batteryAmperePrice = 0.85,
    double breakerPrice = 0.0,
    double wiringCost = 0.0,
    double systemVoltage = 48.0,
    double peakSunHours = 4.5,
    double energyLossPercentage = 30.0,
    double daysOfAutonomy = 1.0,
  }) {
    if (loads.isEmpty) {
      throw const InvalidLoadInput('لا توجد أحمال لإجراء الحساب.');
    }

    InputValidator.validateLoads(loads);
    InputValidator.validateSystemParameters(
      panelCapacity: panelCapacity,
      panelIsc: panelIsc,
      peakSunHours: peakSunHours,
      systemVoltage: systemVoltage,
      gridVoltage: gridVoltage,
      energyLossPercentage: energyLossPercentage,
      daysOfAutonomy: daysOfAutonomy,
      solarWattPrice: solarWattPrice,
      batteryAmperePrice: batteryAmperePrice,
      breakerPrice: breakerPrice,
      wiringCost: wiringCost,
    );
    InputValidator.validateGridSchedule(
      gridStartHour: gridSchedule.gridStartHour,
      gridOnHours: gridSchedule.gridOnHours,
      gridOffHours: gridSchedule.gridOffHours,
      gridChargeDependencyPercent: gridSchedule.gridChargeDependencyPercent,
    );

    final profile = _hourlyLoadProfile(loads, gridVoltage);
    final powerProfile = _hourlyActivePowerProfile(loads, gridVoltage);
    final totalConsumption = profile.fold(0.0, (sum, value) => sum + value);
    // The profile has 24 slots indexed by hour; slots 0..5 and 18..23 are night.
    final daytimeWh = profile
        .sublist(6, 18)
        .fold(0.0, (sum, value) => sum + value);
    final nighttimeWh = totalConsumption - daytimeWh;
    final daytimePeak = powerProfile.sublist(6, 18).fold(0.0, math.max);

    final inverterDetails = calculateInverterDetails(loads, gridVoltage);
    final peakLoad = inverterDetails['peakLoad']!;
    final safetyMargin = inverterDetails['safetyMargin']!;
    final inverterCapacity = inverterDetails['totalCapacity']!;

    final batteryDod = _batteryDod(gridSchedule.batteryType);
    final batteryEfficiency = _batteryEfficiency(gridSchedule.batteryType);
    final batteryOutputEnergyWh =
        nighttimeWh / inverterEfficiency * daysOfAutonomy;
    final requiredBatteryEnergyWh =
        systemMode == SystemMode.directOnGrid || nighttimeWh <= 0
        ? 0.0
        : batteryOutputEnergyWh / (batteryDod * batteryEfficiency);
    final batteryCapacityAh = requiredBatteryEnergyWh / systemVoltage;
    final usableBatteryEnergyWh = systemMode == SystemMode.directOnGrid
        ? 0.0
        : batteryOutputEnergyWh;

    final chargeEfficiency = gridSchedule.batteryType == 'Lithium'
        ? lithiumBatteryEfficiency
        : gelBatteryEfficiency;
    final panelDetails = calculatePanelsDetails(
      daytimeWh: daytimeWh,
      nighttimeWh: nighttimeWh,
      continuousDaytimeWatts: daytimePeak,
      panelCapacity: panelCapacity,
      systemMode: systemMode,
      gridSchedule: gridSchedule,
      peakSunHours: peakSunHours,
      energyLossPercentage: energyLossPercentage,
      chargeEfficiency: chargeEfficiency,
    );
    final panelsForDaytime = panelDetails['daytimePanels'] as int;
    final panelsForBatteries = panelDetails['batteryPanels'] as int;
    final totalPanels = panelDetails['totalPanels'] as int;
    final gridContributionPercent =
        panelDetails['gridContributionPercent'] as double;
    final panelsSavedByGrid = panelDetails['panelsSavedByGrid'] as int;

    final pvCurve = calculateDailyProductionCurve(
      totalPanels,
      panelCapacity,
      peakSunHours: peakSunHours,
      energyLossPercentage: energyLossPercentage,
    );
    final totalPvEnergyWh = pvCurve.fold(0.0, (sum, value) => sum + value);

    final gridChargeEnergyWh = systemMode == SystemMode.ups
        ? requiredBatteryEnergyWh / chargeEfficiency
        : (panelDetails['requiredBatteryChargeWh'] as double) *
              gridContributionPercent /
              100.0;
    final gridChargingAmps =
        gridSchedule.gridOnHours > 0 && gridChargeEnergyWh > 0
        ? gridChargeEnergyWh / gridSchedule.gridOnHours / systemVoltage
        : 0.0;
    final gridChargingAcAmps = gridChargingAmps > 0
        ? (gridChargingAmps * systemVoltage / inverterEfficiency) / gridVoltage
        : 0.0;
    final theoreticalChargeTime = gridChargingAmps > 0
        ? requiredBatteryEnergyWh / (gridChargingAmps * systemVoltage)
        : 0.0;

    final warnings = <String>[
      'هذه النتائج تقديرية أولية وليست مخططاً تنفيذياً أو اعتماداً لمعيار NEC.',
      if (panelIsc <= 0)
        'بيانات Isc غير متوفرة؛ لم يتم إخراج مقاس حماية PV نهائي.',
      if (systemMode == SystemMode.ups)
        'وضع UPS لا يستخدم الألواح الشمسية في هذا النموذج.',
      if (systemMode == SystemMode.offGrid && gridContributionPercent > 0)
        'تم تجاهل مساهمة الشبكة لأن النظام Off-grid.',
      if (gridSchedule.gridOnHours == 0 && systemMode == SystemMode.ups)
        'لا توجد ساعات شبكة متاحة لحساب شحن UPS من الشبكة.',
    ];

    var gelWarning = '';
    if (gridSchedule.batteryType == 'Lead-Acid/Gel' && batteryCapacityAh > 0) {
      final maxChargeAmps = batteryCapacityAh * gelMaximumChargeRate;
      if (gridChargingAmps > maxChargeAmps) {
        gelWarning =
            'تحذير: تيار الشحن النظري من الشبكة يتجاوز 0.2C لبطارية الجل. يجب اختيار شاحن يحد التيار.';
        warnings.add(gelWarning);
      }
    }

    final chargePriority = switch (systemMode) {
      SystemMode.offGrid ||
      SystemMode.directOnGrid => 'غير منطبق — لا توجد أولوية شبكة في هذا الوضع',
      SystemMode.ups => 'Utility First / SNU',
      SystemMode.hybrid =>
        gridContributionPercent > 50
            ? 'Utility First / SNU'
            : 'Solar First / CSO',
    };

    final electricalLabel =
        'تدقيق بيانات الحماية — لا توجد قواعد اختصاصية مفعّلة لإصدار توصية';
    final safetyAudit = const SafetyAuditService().evaluate(
      safetyDesign,
      systemMode,
    );
    final inverterCost = inverterCapacity / 1000.0 * estimatedInverterUsdPerKw;
    final panelsCost = totalPanels * panelCapacity * solarWattPrice;
    final batteriesCost = batteryCapacityAh * batteryAmperePrice;
    final estimatedCost =
        panelsCost + batteriesCost + inverterCost + wiringCost;

    final breakdown = CalculationBreakdownModel(
      daytimePanelsExplanationAr:
          panelDetails['daytimePanelsExplanationAr'] as String,
      daytimePanelsExplanationEn:
          panelDetails['daytimePanelsExplanationEn'] as String,
      batteryPanelsExplanationAr:
          panelDetails['batteryPanelsExplanationAr'] as String,
      batteryPanelsExplanationEn:
          panelDetails['batteryPanelsExplanationEn'] as String,
      inverterExplanationAr:
          'الحمل الأقصى المتزامن من ملف التشغيل ${peakLoad.toStringAsFixed(0)}W، مع هامش 25% = ${inverterCapacity.toStringAsFixed(0)}W.',
      inverterExplanationEn:
          'Peak simultaneous load is derived from the load profile with a 25% margin.',
      batteryExplanationAr: systemMode == SystemMode.directOnGrid
          ? 'لا توجد بطارية في وضع التشغيل المباشر.'
          : 'الطاقة القابلة للاستخدام ${usableBatteryEnergyWh.toStringAsFixed(0)}Wh، والطاقة الاسمية المطلوبة ${requiredBatteryEnergyWh.toStringAsFixed(0)}Wh بعد DoD وكفاءة البطارية.',
      batteryExplanationEn:
          'Battery sizing separates usable output energy from nominal stored energy.',
      assumptionsAr: [
        'الفترات النهارية الافتراضية 06:00–18:00 عند استخدام day/night hours.',
        'تحويل الأمبير إلى واط يفترض معامل قدرة 1.0 لأن معامل القدرة غير مدخل.',
        'PSH قيمة يومية متوسطة وليست ضماناً لإنتاج كل يوم.',
        'السعر تقديري ويستخدم سعر الواط وسعر أمبير البطارية كما أدخلهما المستخدم.',
      ],
      warningsAr: warnings,
      electricalEstimateOnly: true,
      mpptRecommendationAr:
          'لا يمكن تحديد MPPT نهائي دون Voc/Vmp وتكوين السلاسل والتيار الأقصى للعاكس.',
    );

    final hourlyGrid = List<double>.filled(24, 0);
    if (gridChargeEnergyWh > 0 && gridSchedule.gridOnHours > 0) {
      final gridPower = gridChargeEnergyWh / gridSchedule.gridOnHours;
      _addHours(
        hourlyGrid,
        gridPower,
        gridSchedule.gridStartHour,
        gridSchedule.gridOnHours,
      );
    }

    return SystemResultModel(
      totalDailyConsumptionWh: totalConsumption,
      daytimeConsumptionWh: daytimeWh,
      nighttimeConsumptionWh: nighttimeWh,
      peakLoadW: peakLoad,
      safetyMarginW: safetyMargin,
      requiredInverterCapacityW: inverterCapacity,
      requiredBatteryCapacityAh: batteryCapacityAh,
      requiredBatteryEnergyWh: requiredBatteryEnergyWh,
      usableBatteryEnergyWh: usableBatteryEnergyWh,
      systemVoltage: systemVoltage,
      requiredPanels: totalPanels,
      panelsForDaytime: panelsForDaytime,
      panelsForBatteries: panelsForBatteries,
      gridContributionPercent: gridContributionPercent,
      panelsSavedByGrid: panelsSavedByGrid,
      dailyProductionCurve: pvCurve,
      hourlyPvPowerW: pvCurve,
      hourlyLoadPowerW: powerProfile,
      hourlyGridPowerW: hourlyGrid,
      totalPvEnergyWh: totalPvEnergyWh,
      requiredGridChargingAmps: gridChargingAmps,
      requiredGridChargingAcAmps: gridChargingAcAmps,
      timeToFullHours: theoreticalChargeTime,
      suggestedInverterType: _inverterType(systemMode),
      energyLossPercentage: '${energyLossPercentage.toStringAsFixed(0)}%',
      recommendedInverterBrands: 'Deye, Growatt, Huawei, Victron Energy',
      recommendedPanelBrands: 'Longi, Jinko Solar, JA Solar, Trina Solar',
      pvDcBreakerAmps: 0,
      batteryDcBreakerAmps: 0,
      acBreakerAmps: 0,
      wireSizeMm2: 0,
      estimatedCostUsd: estimatedCost,
      totalBreakersCount: 0,
      suggestedChargePriority: chargePriority,
      gelBatteryWarning: gelWarning,
      suggestedIpRating: inverterLocation == 'outdoor'
          ? 'IP65 (تقديري)'
          : 'IP20 (تقديري)',
      electricalEstimateLabel: electricalLabel,
      safetyAudit: safetyAudit,
      breakdown: breakdown,
    );
  }

  Map<String, dynamic> _emptyPanelsResult() => {
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
    'panelDailyEnergyWh': 0.0,
    'requiredBatteryChargeWh': 0.0,
    'remainingBatteryPvWh': 0.0,
  };

  List<double> _hourlyLoadProfile(List<LoadModel> loads, double gridVoltage) {
    final result = List<double>.filled(24, 0);
    for (final load in loads) {
      final watts = _convertToWatts(load, gridVoltage);
      if (load.operatingPeriods.isNotEmpty) {
        for (var hour = 0; hour < 24; hour++) {
          final hourStart = hour.toDouble();
          final hourEnd = hourStart + 1;
          final active = load.operatingPeriods.fold<double>(0, (sum, period) {
            final overlap = math.max(
              0,
              math.min(hourEnd, period.endHour) -
                  math.max(hourStart, period.startHour),
            );
            return sum + overlap;
          });
          result[hour] += watts * active;
        }
      } else {
        _addHours(result, watts, daytimeStartHour, load.daytimeHours);
        _addHours(result, watts, daytimeEndHour, load.nighttimeHours);
      }
    }
    return result;
  }

  List<double> _hourlyActivePowerProfile(
    List<LoadModel> loads,
    double gridVoltage,
  ) {
    final result = List<double>.filled(24, 0);
    for (final load in loads) {
      final watts = _convertToWatts(load, gridVoltage);
      if (load.operatingPeriods.isNotEmpty) {
        for (var hour = 0; hour < 24; hour++) {
          final hourStart = hour.toDouble();
          final hourEnd = hourStart + 1;
          final active = load.operatingPeriods.any(
            (period) =>
                math.min(hourEnd, period.endHour) >
                math.max(hourStart, period.startHour),
          );
          if (active) result[hour] += watts;
        }
      } else {
        _addActiveHours(result, watts, daytimeStartHour, load.daytimeHours);
        _addActiveHours(result, watts, daytimeEndHour, load.nighttimeHours);
      }
    }
    return result;
  }

  double _hourlyPeakSurgeWatts(List<LoadModel> loads, double gridVoltage) {
    final peaks = List<double>.filled(24, 0);
    for (final load in loads) {
      final watts = _convertToWatts(load, gridVoltage);
      final multiplier = load.isInverterDevice
          ? 1.0
          : load.startingCurrentMultiplier;
      if (load.operatingPeriods.isNotEmpty) {
        for (var hour = 0; hour < 24; hour++) {
          final active = load.operatingPeriods.any(
            (p) => p.startHour < hour + 1 && p.endHour > hour,
          );
          if (active) peaks[hour] += watts * multiplier;
        }
      } else {
        _addHours(
          peaks,
          watts * multiplier,
          daytimeStartHour,
          load.daytimeHours,
        );
        _addHours(
          peaks,
          watts * multiplier,
          daytimeEndHour,
          load.nighttimeHours,
        );
      }
    }
    return peaks.fold(0.0, math.max);
  }

  void _addActiveHours(
    List<double> target,
    double watts,
    double start,
    double hours,
  ) {
    var remaining = hours;
    var cursor = start % 24;
    while (remaining > 0) {
      final index = cursor.floor() % 24;
      final fraction = math.min(remaining, 1.0 - (cursor - cursor.floor()));
      target[index] += watts;
      remaining -= fraction;
      cursor = (cursor + fraction) % 24;
    }
  }

  void _addHours(
    List<double> target,
    double watts,
    double start,
    double hours,
  ) {
    var remaining = hours;
    var cursor = start % 24;
    while (remaining > 0) {
      final index = cursor.floor() % 24;
      final fraction = math.min(remaining, 1.0 - (cursor - cursor.floor()));
      target[index] += watts * fraction;
      remaining -= fraction;
      cursor = (cursor + fraction) % 24;
    }
  }

  double _batteryDod(String batteryType) =>
      batteryType == 'Lithium' ? lithiumBatteryDod : gelBatteryDod;

  double _batteryEfficiency(String batteryType) => batteryType == 'Lithium'
      ? lithiumBatteryEfficiency
      : gelBatteryEfficiency;

  int _ceilPanelCount(double requiredEnergy, double perPanelEnergy) {
    if (requiredEnergy <= 0) return 0;
    final value = requiredEnergy / perPanelEnergy;
    if (!value.isFinite) {
      throw CalculationFailure(
        'تعذر حساب عدد الألواح لأن الطاقة المطلوبة غير منتهية.',
      );
    }
    return value.ceil();
  }

  void _requireFinitePositive(double value, String label) {
    if (!value.isFinite || value <= 0) {
      throw InvalidEngineeringInput(
        '$label يجب أن تكون قيمة منتهية وأكبر من صفر.',
      );
    }
  }

  String _inverterType(SystemMode mode) => switch (mode) {
    SystemMode.ups => 'إنفرتر شاحن / UPS',
    SystemMode.directOnGrid => 'إنفرتر أون-جريد (On-grid)',
    SystemMode.hybrid => 'إنفرتر هايبرد (Hybrid)',
    SystemMode.offGrid => 'إنفرتر أوف-جريد (Off-grid)',
  };
}
