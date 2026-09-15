import 'dart:math' as math;

import '../core/errors/app_exceptions.dart';
import '../core/validation/input_validator.dart';
import '../models/calculation_breakdown_model.dart';
import '../models/grid_schedule_model.dart';
import '../models/load_model.dart';
import '../models/safety_audit_model.dart';
import '../models/system_mode.dart';
import '../models/system_result_model.dart';
import '../services/electrical_protection_service.dart';

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
    // Daytime energy is derived from the hours the user declared for each
    // load (daytimeHours / operating periods), not from a fixed 06:00–18:00
    // slice of the chart profile. A fixed slice would silently move energy
    // past 18:00 (e.g. a 14-hour day load) into the night bucket and inflate
    // the battery and panel requirements.
    final daytimeWh = _daytimeEnergyWh(loads, gridVoltage);
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
    List<double>? hourlyLoadProfile,
    double? chargerPowerLimitW,
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
    final batteryEfficiency = _batteryEfficiency(gridSchedule.batteryType);
    final requiredBatteryChargeWh = _requiredBatteryChargeWh(
      nighttimeWh,
      batteryEfficiency,
      chargeEfficiency,
    );
    // UPS has no PV array, but the grid still recharges the daily discharge,
    // so its grid charge energy must be reported even though no panel is
    // sized. Everything else with no energy to serve needs no panels at all.
    final upsGridChargeEnergyWh = systemMode == SystemMode.ups
        ? math.min(
            requiredBatteryChargeWh,
            _deliverableGridChargeWh(
              requestedEnergyWh: requiredBatteryChargeWh,
              gridSchedule: gridSchedule,
              chargerPowerLimitW: chargerPowerLimitW,
              chargeEfficiency: chargeEfficiency,
            ),
          )
        : 0.0;
    if (systemMode == SystemMode.ups || (daytimeWh <= 0 && nighttimeWh <= 0)) {
      return _emptyPanelsResult(systemMode, upsGridChargeEnergyWh);
    }

    final pvPerformanceFactor = 1.0 - energyLossPercentage / 100.0;
    final panelDailyEnergyWh =
        panelCapacity * peakSunHours * pvPerformanceFactor;
    _requireFinitePositive(panelDailyEnergyWh, 'الطاقة اليومية للوح');

    final daytimeDcEnergyWh = daytimeWh / inverterEfficiency;

    // The fraction of the daily battery recharge that the national grid is
    // asked to cover. UPS is always 100% grid-charged, off-grid and
    // direct-on-grid never charge from the grid.
    final gridChargeFraction = _effectiveGridChargeFraction(
      systemMode,
      gridSchedule,
    );
    final requestedGridChargeWh = requiredBatteryChargeWh * gridChargeFraction;
    // Size PV from the user's planned split, not from charger limitations.
    // Keep deliverable energy separate for charging estimates and warnings:
    // insufficient grid charging must not silently override the selected split.
    final deliverableGridChargeWh = _deliverableGridChargeWh(
      requestedEnergyWh: requestedGridChargeWh,
      gridSchedule: gridSchedule,
      chargerPowerLimitW: chargerPowerLimitW,
      chargeEfficiency: chargeEfficiency,
    );
    final gridChargeEnergyWh = math.min(
      requestedGridChargeWh,
      deliverableGridChargeWh,
    );
    final remainingBatteryPvWh = math.max(
      0.0,
      requiredBatteryChargeWh - requestedGridChargeWh,
    );

    // Daytime loads that run while the national grid is available are served
    // by the grid, so they must not be sized as solar panels.
    final daytimeGridServedWh =
        (systemMode == SystemMode.hybrid &&
            gridSchedule.gridOnHours > 0 &&
            hourlyLoadProfile != null)
        ? _daytimeEnergyServedByGrid(hourlyLoadProfile, gridSchedule)
        : 0.0;
    final daytimePvEnergyWh = math.max(0.0, daytimeWh - daytimeGridServedWh);
    final daytimePvDcEnergyWh = daytimePvEnergyWh / inverterEfficiency;

    final daytimePowerPathW =
        (continuousDaytimeWatts / inverterEfficiency) * directModePowerMargin;
    final daytimePanels = systemMode == SystemMode.directOnGrid
        ? _ceilPanelCount(
            daytimePowerPathW,
            panelCapacity * pvPerformanceFactor,
          )
        : _ceilPanelCount(daytimePvDcEnergyWh, panelDailyEnergyWh);
    // Combine all PV energy before rounding so separate allocations cannot add
    // an unnecessary extra panel at a rounding boundary.
    final combinedEnergyPanels = systemMode == SystemMode.directOnGrid
        ? daytimePanels
        : _ceilPanelCount(
            daytimePvDcEnergyWh + remainingBatteryPvWh,
            panelDailyEnergyWh,
          );
    final batteryPanels = systemMode == SystemMode.directOnGrid
        ? 0
        : math.max(0, combinedEnergyPanels - daytimePanels);
    // Array size with no grid credit at all. It bounds the PV string current
    // the installation could reach, so electrical protection is derived from
    // it rather than from the grid-reduced recommendation.
    final fullSolarPanels = systemMode == SystemMode.directOnGrid
        ? daytimePanels
        : _ceilPanelCount(
            daytimeDcEnergyWh + requiredBatteryChargeWh,
            panelDailyEnergyWh,
          );

    return {
      'daytimePanels': daytimePanels,
      'batteryPanels': batteryPanels,
      'totalPanels': combinedEnergyPanels,
      'gridContributionPercent': requiredBatteryChargeWh > 0
          ? gridChargeFraction * 100.0
          : 0.0,
      'panelsSavedByGrid': math.max(0, fullSolarPanels - combinedEnergyPanels),
      'maximumArrayPanels': math.max(fullSolarPanels, combinedEnergyPanels),
      'daytimePanelsExplanationAr': systemMode == SystemMode.directOnGrid
          ? 'التشغيل المباشر يعتمد على القدرة اللحظية: ${continuousDaytimeWatts.toStringAsFixed(0)}W، مع كفاءة العاكس وهامش قدرة 30%.'
          : daytimeGridServedWh > 0
          ? 'طاقة أحمال النهار ${daytimeWh.toStringAsFixed(0)}Wh، غطّت الوطنية منها ${daytimeGridServedWh.toStringAsFixed(0)}Wh أثناء ساعات توفرها، فتبقى على الشمس ${daytimePvEnergyWh.toStringAsFixed(0)}Wh بواقع $daytimePanels لوح.'
          : 'تم حساب ألواح النهار من الطاقة النهارية الفعلية ${daytimeWh.toStringAsFixed(0)}Wh، وسعة اللوح اليومية ${panelDailyEnergyWh.toStringAsFixed(0)}Wh.',
      'daytimePanelsExplanationEn': systemMode == SystemMode.directOnGrid
          ? 'Direct mode uses instantaneous daytime power with inverter efficiency and a 30% power margin.'
          : daytimeGridServedWh > 0
          ? 'Daytime loads overlapping the grid window are served by the grid; only the remaining daytime energy is sized as solar panels.'
          : 'Daytime panels are based on the explicit daytime energy profile and effective daily panel energy.',
      'batteryPanelsExplanationAr': systemMode == SystemMode.directOnGrid
          ? ''
          : 'طاقة شحن البطارية المطلوبة قبل الشبكة: ${requiredBatteryChargeWh.toStringAsFixed(0)}Wh. نسبة الاعتماد على الوطنية لشحن البطاريات: ${(gridChargeFraction * 100).toStringAsFixed(0)}%. طاقة الشحن المخصصة للوطنية: ${requestedGridChargeWh.toStringAsFixed(0)}Wh. طاقة الشحن الممكنة من الوطنية حسب قدرة الشاحن وساعات التوفر: ${gridChargeEnergyWh.toStringAsFixed(0)}Wh. المتبقي من الطاقة الشمسية: ${remainingBatteryPvWh.toStringAsFixed(0)}Wh. ألواح لشحن البطاريات: $batteryPanels لوح. تم جمع طاقة النهار والشحن ثم تقريب العدد مرة واحدة.',
      'batteryPanelsExplanationEn': systemMode == SystemMode.directOnGrid
          ? ''
          : 'Battery PV energy is reduced by the selected grid charging percentage, then daytime and charging energy are combined before one panel-count rounding step. Deliverable grid charging energy is estimated separately; any shortfall is warned about, not added back to PV.',
      'floatPreservationRecommendationAr': '',
      'panelDailyEnergyWh': panelDailyEnergyWh,
      'requiredBatteryChargeWh': requiredBatteryChargeWh,
      'requestedGridChargeWh': requestedGridChargeWh,
      'gridChargeEnergyWh': gridChargeEnergyWh,
      'remainingBatteryPvWh': remainingBatteryPvWh,
      'daytimeGridServedWh': daytimeGridServedWh,
      'daytimePvEnergyWh': daytimePvEnergyWh,
    };
  }

  /// Fraction of the daily battery recharge the grid is asked to cover.
  ///
  /// UPS locks this to 100% because it has no PV array to charge from,
  /// off-grid and direct-on-grid never charge the battery from the grid, and
  /// hybrid always uses the user-selected percentage so 100% zeroes battery
  /// PV panels. Deliverable energy is estimated separately from grid hours
  /// and charger power; any shortfall is warned about, not added back to PV.
  double _effectiveGridChargeFraction(
    SystemMode systemMode,
    GridScheduleModel gridSchedule,
  ) {
    switch (systemMode) {
      case SystemMode.ups:
        return 1.0;
      case SystemMode.offGrid:
      case SystemMode.directOnGrid:
        return 0.0;
      case SystemMode.hybrid:
        final percent = gridSchedule.gridChargeDependencyPercent;
        return (percent / 100.0).clamp(0.0, 1.0);
    }
  }

  /// Energy the charger can actually put into the battery while the grid is
  /// available: `charger power × grid hours × charge efficiency`, converted to
  /// the AC side of the charger. Without grid hours nothing is deliverable;
  /// without a known charger limit the full requested energy is assumed once
  /// hours are available.
  double _deliverableGridChargeWh({
    required double requestedEnergyWh,
    required GridScheduleModel gridSchedule,
    required double? chargerPowerLimitW,
    required double chargeEfficiency,
  }) {
    if (requestedEnergyWh <= 0) return 0.0;
    final onHours = gridSchedule.gridOnHours;
    if (!onHours.isFinite || onHours <= 0) return 0.0;
    final limit = chargerPowerLimitW;
    if (limit == null || !limit.isFinite || limit <= 0) {
      return requestedEnergyWh;
    }
    final acPowerW = limit * inverterEfficiency;
    return acPowerW * onHours * chargeEfficiency;
  }

  /// Load energy inside 06:00–18:00 that falls within the grid availability
  /// window, hour by hour, so partial hours at the window edges are honored.
  double _daytimeEnergyServedByGrid(
    List<double> hourlyLoadProfile,
    GridScheduleModel gridSchedule,
  ) {
    final onHours = math.min(gridSchedule.gridOnHours, 24.0);
    if (onHours <= 0) return 0.0;
    final start = gridSchedule.gridStartHour;
    final end = start + onHours;
    var served = 0.0;
    for (
      var hour = daytimeStartHour.toInt();
      hour < daytimeEndHour.toInt();
      hour++
    ) {
      if (hour < 0 || hour >= hourlyLoadProfile.length) continue;
      final hourStart = hour.toDouble();
      final hourEnd = hourStart + 1;
      var overlap = math.min(hourEnd, end) - math.max(hourStart, start);
      if (end > 24.0) {
        overlap +=
            math.min(hourEnd, end - 24.0) - math.max(hourStart, start - 24.0);
      }
      if (overlap <= 0) continue;
      served += hourlyLoadProfile[hour] * math.min(overlap, 1.0);
    }
    return math.max(0.0, served);
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
    SystemMode systemMode = SystemMode.hybrid,
    GridScheduleModel gridSchedule = const GridScheduleModel(),
    double solarWattPrice = 0.16,
    double batteryAmperePrice = 0.85,
    double wiringCost = 0.0,
    double systemVoltage = 48.0,
    double peakSunHours = 4.5,
    double energyLossPercentage = 30.0,
    double daysOfAutonomy = 1.0,
    int? pvModulesPerString,
    int? pvParallelStrings,
    double? dcCableOneWayLengthMeters,
    String? dcCableMaterial,
    String? dcCableInsulation,
    String? dcCableInstallationMethod,
    double? dcCableAmbientTemperatureCelsius,
    int? dcCableLoadedConductors,
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
    // Daytime energy comes from the hours the user declared for each load,
    // not from a fixed 06:00–18:00 slice of the chart profile. The fixed
    // slice previously misclassified declared daytime hours that extend past
    // 18:00 as night energy, which inflated batteries and panel counts.
    final daytimeWh = _daytimeEnergyWh(loads, gridVoltage);
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
      hourlyLoadProfile: profile,
      chargerPowerLimitW: inverterCapacity,
    );
    final panelsForDaytime = panelDetails['daytimePanels'] as int;
    final panelsForBatteries = panelDetails['batteryPanels'] as int;
    final totalPanels = panelDetails['totalPanels'] as int;
    final gridContributionPercent =
        panelDetails['gridContributionPercent'] as double;
    final panelsSavedByGrid = panelDetails['panelsSavedByGrid'] as int;
    final maximumArrayPanels = panelDetails['maximumArrayPanels'] as int;
    final requestedGridChargeWh =
        panelDetails['requestedGridChargeWh'] as double;
    final daytimeGridServedWh = panelDetails['daytimeGridServedWh'] as double;

    final pvCurve = calculateDailyProductionCurve(
      totalPanels,
      panelCapacity,
      peakSunHours: peakSunHours,
      energyLossPercentage: energyLossPercentage,
    );
    final totalPvEnergyWh = pvCurve.fold(0.0, (sum, value) => sum + value);

    // Grid charge energy is the amount the charger can actually deliver
    // during the available grid hours, already capped by the requested
    // dependency fraction in the panel details step. UPS recharges its full
    // daily discharge from the grid; hybrid recharges only the configured
    // fraction; off-grid and direct-on-grid recharge nothing from the grid.
    final gridChargeEnergyWh = panelDetails['gridChargeEnergyWh'] as double;
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
    final gridChargeLimitedByHardware =
        requestedGridChargeWh - gridChargeEnergyWh > 1.0;

    final warnings = <String>[
      'هذه النتائج تقديرية أولية وليست مخططاً تنفيذياً أو اعتماداً لمعيار NEC.',
      if (panelIsc <= 0)
        'بيانات Isc غير متوفرة؛ لم يتم إخراج مقاس حماية PV نهائي.',
      if (systemMode == SystemMode.ups)
        'وضع UPS لا يستخدم الألواح الشمسية في هذا النموذج.',
      if (systemMode == SystemMode.offGrid && gridSchedule.gridOnHours > 0)
        'تم تجاهل ساعات الوطنية المحفوظة (${gridSchedule.gridOnHours.toStringAsFixed(0)} ساعة) لأن النظام معرَّف بدون تيار وطني؛ ألغِ تفعيل «نظام بدون تيار وطني» إذا كانت الوطنية متوفرة فعلاً.',
      if (gridSchedule.gridOnHours == 0 && systemMode == SystemMode.ups)
        'لا توجد ساعات شبكة متاحة لحساب شحن UPS من الشبكة.',
      if (daytimeGridServedWh > 0 && panelsForDaytime == 0)
        'الوطنية تغطي كامل أحمال النهار خلال ساعات توفرها؛ لم تُحسب ألواح نهارية. إذا انقطعت الوطنية نهاراً فستحتاج ألواحاً لتغطية تلك الأحمال.',
      if (gridChargeLimitedByHardware && gridSchedule.gridOnHours <= 0)
        'نسبة الاعتماد على الوطنية لشحن البطاريات ${(gridContributionPercent).toStringAsFixed(0)}% خُصمت من ألواح الشحن، لكن ساعات توفر الوطنية = 0 فلا يمكن تنفيذ الشحن فعلياً. أدخل ساعات التوفر أو اخفض النسبة قبل تنفيذ المنظومة.',
      if (gridChargeLimitedByHardware && gridSchedule.gridOnHours > 0)
        'قدرة الشحن خلال ساعات توفر الوطنية (${gridSchedule.gridOnHours.toStringAsFixed(0)} ساعة) لا تكفي لتغطية نسبة الاعتماد المطلوبة؛ تم احتساب ${gridChargeEnergyWh.toStringAsFixed(0)}Wh فعلياً من أصل ${requestedGridChargeWh.toStringAsFixed(0)}Wh، يوجد عجز شحن قدره ${(requestedGridChargeWh - gridChargeEnergyWh).toStringAsFixed(0)}Wh لم يُضف إلى الألواح التزاماً بالنسبة المختارة. زِد ساعات الوطنية أو قدرة الشاحن، أو اخفض نسبة الاعتماد على الوطنية قبل تنفيذ المنظومة.',
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
        'حسابات الحماية من بيانات SUN الحالية — ليست اعتماداً معيارياً أو اختياراً لجهاز تجاري';
    final safetyAudit = const ElectricalProtectionService().evaluate(
      ProtectionCalculationInputs(
        systemMode: systemMode,
        panelIscAmps: panelIsc,
        // Protection must bound the largest array the site could install, so
        // it is derived before the grid credit that reduces the recommended
        // panel count.
        requiredPanels: maximumArrayPanels,
        systemVoltageVolts: systemVoltage,
        gridVoltageVolts: gridVoltage,
        requiredInverterCapacityWatts: inverterCapacity,
        requiredBatteryCapacityAh: batteryCapacityAh,
        nighttimeConsumptionWh: nighttimeWh,
        pvModulesPerString: pvModulesPerString,
        pvParallelStrings: pvParallelStrings,
        dcCableOneWayLengthMeters: dcCableOneWayLengthMeters,
        dcCableMaterial: dcCableMaterial,
        dcCableInsulation: dcCableInsulation,
        dcCableInstallationMethod: dcCableInstallationMethod,
        dcCableAmbientTemperatureCelsius: dcCableAmbientTemperatureCelsius,
        dcCableLoadedConductors: dcCableLoadedConductors,
      ),
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
        'الأحمال النهارية التي تعمل أثناء ساعات توفر الوطنية تُغطى منها ولا تُحسب على الألواح في وضع Hybrid.',
        'عدد ألواح شحن البطاريات يعتمد على النسبة المختارة للوطنية، وليس ضماناً لإمكان توفير طاقة الشحن المطلوبة.',
        'شحن البطاريات من الوطنية محدود بقدرة شاحن الإنفرتر (${inverterCapacity.toStringAsFixed(0)}W) مضروبة في ساعات التوفر وكفاءة الشحن.',
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

  /// Zero-panel result used by UPS and by loads with no declared energy.
  ///
  /// UPS still reports a 100% grid contribution because its battery is charged
  /// entirely from the national grid, matching what the input screen shows as a
  /// locked value; without this the stored slider value would silently decide
  /// the reported contribution.
  Map<String, dynamic> _emptyPanelsResult(
    SystemMode systemMode,
    double gridChargeEnergyWh,
  ) => {
    'daytimePanels': 0,
    'batteryPanels': 0,
    'totalPanels': 0,
    'gridContributionPercent': systemMode == SystemMode.ups ? 100.0 : 0.0,
    'panelsSavedByGrid': 0,
    'maximumArrayPanels': 0,
    'daytimePanelsExplanationAr': '',
    'daytimePanelsExplanationEn': '',
    'batteryPanelsExplanationAr': '',
    'batteryPanelsExplanationEn': '',
    'floatPreservationRecommendationAr': '',
    'panelDailyEnergyWh': 0.0,
    'requiredBatteryChargeWh': 0.0,
    'requestedGridChargeWh': gridChargeEnergyWh,
    'gridChargeEnergyWh': gridChargeEnergyWh,
    'remainingBatteryPvWh': 0.0,
    'daytimeGridServedWh': 0.0,
    'daytimePvEnergyWh': 0.0,
  };

  /// Daytime energy (Wh) derived from the hours the user declared for each
  /// load: `quantity × power × daytimeHours`, and for custom operating
  /// periods the overlap with the 06:00–18:00 daytime window.
  double _daytimeEnergyWh(List<LoadModel> loads, double gridVoltage) {
    var daytimeWh = 0.0;
    for (final load in loads) {
      final watts = _convertToWatts(load, gridVoltage);
      if (load.operatingPeriods.isNotEmpty) {
        for (final period in load.operatingPeriods) {
          final daytimeOverlap = math.max(
            0.0,
            math.min(period.endHour, daytimeEndHour) -
                math.max(period.startHour, daytimeStartHour),
          );
          daytimeWh += watts * daytimeOverlap;
        }
      } else {
        daytimeWh += watts * load.daytimeHours;
      }
    }
    return daytimeWh;
  }

  /// Daily DC energy (Wh) required to recharge one night's discharge.
  /// The inverter loss is on the discharge side (battery → AC); the battery
  /// and charge efficiencies apply once each. Depth-of-discharge and autonomy
  /// size the battery bank, not the daily recharge energy, so they do not
  /// appear here.
  double _requiredBatteryChargeWh(
    double nighttimeWh,
    double batteryEfficiency,
    double chargeEfficiency,
  ) {
    if (nighttimeWh <= 0) return 0.0;
    return (nighttimeWh / inverterEfficiency) /
        batteryEfficiency /
        chargeEfficiency;
  }

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
