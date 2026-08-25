import '../errors/app_exceptions.dart';
import '../../models/load_model.dart';

class InputValidator {
  static const double _timeTolerance = 0.0001;
  static const double maxPeakSunHours = 24.0;
  static const double maxAutonomyDays = 30.0;
  static const double maxStartingCurrentMultiplier = 10.0;
  static const double maxQuantity = 100000.0;

  static void validateFinitePositive(
    double value,
    String field,
    String label, {
    double? max,
  }) {
    if (!value.isFinite || value <= 0 || (max != null && value > max)) {
      throw InvalidEngineeringInput(
        '$label يجب أن يكون أكبر من صفر${max == null ? '' : ' وألا يتجاوز $max'}.'
        ' القيمة الحالية غير صالحة.',
        field: field,
      );
    }
  }

  static void validateSystemParameters({
    required double panelCapacity,
    required double peakSunHours,
    required double systemVoltage,
    required double gridVoltage,
    required double energyLossPercentage,
    required double daysOfAutonomy,
    required double panelIsc,
    required double solarWattPrice,
    required double batteryAmperePrice,
    required double wiringCost,
  }) {
    validateFinitePositive(panelCapacity, 'panelCapacity', 'قدرة اللوح');
    validateFinitePositive(
      peakSunHours,
      'peakSunHours',
      'ساعات الذروة',
      max: maxPeakSunHours,
    );
    validateFinitePositive(systemVoltage, 'systemVoltage', 'جهد النظام');
    validateFinitePositive(gridVoltage, 'gridVoltage', 'جهد الشبكة');
    validateFinitePositive(
      daysOfAutonomy,
      'daysOfAutonomy',
      'أيام الاستقلالية',
      max: maxAutonomyDays,
    );
    if (!energyLossPercentage.isFinite ||
        energyLossPercentage < 0 ||
        energyLossPercentage >= 100) {
      throw InvalidEngineeringInput(
        'نسبة الفقد يجب أن تكون بين 0% و99.99%.',
        field: 'energyLossPercentage',
      );
    }
    _validateNonNegativeFinite(panelIsc, 'panelIsc', 'تيار القصر');
    _validateNonNegativeFinite(
      solarWattPrice,
      'solarWattPrice',
      'سعر الواط الشمسي',
    );
    _validateNonNegativeFinite(
      batteryAmperePrice,
      'batteryAmperePrice',
      'سعر أمبير البطارية',
    );
    _validateNonNegativeFinite(wiringCost, 'wiringCost', 'تكلفة الأسلاك');
  }

  static void validateGridSchedule({
    required double gridStartHour,
    required double gridOnHours,
    required double gridOffHours,
    required double gridChargeDependencyPercent,
  }) {
    if (!gridStartHour.isFinite || gridStartHour < 0 || gridStartHour >= 24) {
      throw InvalidEngineeringInput(
        'ساعة بدء توفر الشبكة يجب أن تكون بين 0 و24 دون احتساب 24.',
        field: 'gridStartHour',
      );
    }
    _validateHours(gridOnHours, 'gridOnHours', 'ساعات توفر الشبكة');
    _validateHours(gridOffHours, 'gridOffHours', 'ساعات انقطاع الشبكة');
    if ((gridOnHours + gridOffHours - 24.0).abs() > 0.0001) {
      throw InvalidEngineeringInput(
        'يجب أن يساوي مجموع ساعات توفر وانقطاع الشبكة 24 ساعة.',
        field: 'gridSchedule',
      );
    }
    if (gridStartHour + gridOnHours > 24.0001) {
      throw InvalidEngineeringInput(
        'نافذة توفر الشبكة يجب ألا تتجاوز نهاية اليوم؛ لا يدعم الجدول حالياً نافذة تعبر منتصف الليل.',
        field: 'gridSchedule',
      );
    }
    if (!gridChargeDependencyPercent.isFinite ||
        gridChargeDependencyPercent < 0 ||
        gridChargeDependencyPercent > 100) {
      throw InvalidEngineeringInput(
        'نسبة اعتماد شحن البطارية على الشبكة يجب أن تكون بين 0% و100%.',
        field: 'gridChargeDependencyPercent',
      );
    }
  }

  static void validateLoads(List<LoadModel> loads) {
    for (final load in loads) {
      if (load.name.trim().isEmpty) {
        throw InvalidLoadInput(
          'اسم الحمل لا يمكن أن يكون فارغاً.',
          field: 'name',
        );
      }
      if (!load.powerValue.isFinite || load.powerValue <= 0) {
        throw InvalidLoadInput(
          'قدرة الحمل يجب أن تكون أكبر من صفر.',
          field: 'powerValue',
        );
      }
      if (load.quantity <= 0 || load.quantity > maxQuantity) {
        throw InvalidLoadInput(
          'كمية الحمل يجب أن تكون بين 1 و$maxQuantity.',
          field: 'quantity',
        );
      }
      _validateHours(
        load.dailyUsageHours,
        'dailyUsageHours',
        'ساعات الاستخدام اليومية',
      );
      _validateHours(
        load.daytimeHours,
        'daytimeHours',
        'ساعات التشغيل النهارية',
      );
      _validateHours(
        load.nighttimeHours,
        'nighttimeHours',
        'ساعات التشغيل الليلية',
      );
      if (load.daytimeHours + load.nighttimeHours > 24.0001) {
        throw InvalidLoadInput(
          'مجموع ساعات النهار والليل لا يمكن أن يتجاوز 24 ساعة.',
          field: 'hours',
        );
      }
      if (load.operatingPeriods.isEmpty &&
          (load.dailyUsageHours - load.daytimeHours - load.nighttimeHours)
                  .abs() >
              _timeTolerance) {
        throw InvalidLoadInput(
          'ساعات الاستخدام اليومية يجب أن تساوي مجموع ساعات النهار والليل.',
          field: 'hours',
        );
      }
      if (!load.startingCurrentMultiplier.isFinite ||
          load.startingCurrentMultiplier < 1 ||
          load.startingCurrentMultiplier > maxStartingCurrentMultiplier) {
        throw InvalidLoadInput(
          'معامل تيار البدء يجب أن يكون بين 1 و$maxStartingCurrentMultiplier.',
          field: 'startingCurrentMultiplier',
        );
      }
      final periods = [...load.operatingPeriods]
        ..sort((first, second) => first.startHour.compareTo(second.startHour));
      var totalPeriodHours = 0.0;
      double? previousEndHour;
      for (final period in periods) {
        if (!period.startHour.isFinite ||
            !period.endHour.isFinite ||
            period.startHour < 0 ||
            period.endHour > 24 ||
            period.endHour <= period.startHour) {
          throw InvalidLoadInput(
            'فترة تشغيل الحمل خارج المجال 0..24 أو مدتها غير موجبة.',
            field: 'operatingPeriods',
          );
        }
        if (previousEndHour != null &&
            period.startHour < previousEndHour - _timeTolerance) {
          throw InvalidLoadInput(
            'فترات تشغيل الحمل لا يمكن أن تتداخل؛ التداخل يكرر استهلاك الحمل.',
            field: 'operatingPeriods',
          );
        }
        totalPeriodHours += period.durationHours;
        previousEndHour = period.endHour;
      }
      if (periods.isNotEmpty &&
          (load.dailyUsageHours - totalPeriodHours).abs() > _timeTolerance) {
        throw InvalidLoadInput(
          'ساعات الاستخدام اليومية يجب أن تساوي مجموع فترات التشغيل المحفوظة.',
          field: 'operatingPeriods',
        );
      }
    }
  }

  static void _validateHours(double value, String field, String label) {
    if (!value.isFinite || value < 0 || value > 24) {
      throw InvalidLoadInput(
        '$label يجب أن تكون بين 0 و24 ساعة.',
        field: field,
      );
    }
  }

  static void _validateNonNegativeFinite(
    double value,
    String field,
    String label,
  ) {
    if (!value.isFinite || value < 0) {
      throw InvalidEngineeringInput(
        '$label يجب أن تكون قيمة منتهية وغير سالبة.',
        field: field,
      );
    }
  }
}
