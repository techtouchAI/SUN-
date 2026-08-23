import '../core/errors/app_exceptions.dart';

class GridScheduleModel {
  final double gridStartHour;
  final double gridOnHours;
  final double gridOffHours;
  final String batteryType;
  final double gridChargeDependencyPercent;

  const GridScheduleModel({
    this.gridStartHour = 0.0,
    this.gridOnHours = 0.0,
    this.gridOffHours = 24.0,
    this.batteryType = 'Lead-Acid/Gel',
    this.gridChargeDependencyPercent = 100.0,
  });

  bool get isAvailable => gridOnHours > 0;
  double get gridEndHour => gridStartHour + gridOnHours;

  GridScheduleModel copyWith({
    double? gridStartHour,
    double? gridOnHours,
    double? gridOffHours,
    String? batteryType,
    double? gridChargeDependencyPercent,
  }) {
    return GridScheduleModel(
      gridStartHour: gridStartHour ?? this.gridStartHour,
      gridOnHours: gridOnHours ?? this.gridOnHours,
      gridOffHours: gridOffHours ?? this.gridOffHours,
      batteryType: batteryType ?? this.batteryType,
      gridChargeDependencyPercent:
          gridChargeDependencyPercent ?? this.gridChargeDependencyPercent,
    );
  }

  Map<String, dynamic> toJson() => {
    'gridStartHour': gridStartHour,
    'gridOnHours': gridOnHours,
    'gridOffHours': gridOffHours,
    'batteryType': batteryType,
    'gridChargeDependencyPercent': gridChargeDependencyPercent,
  };

  factory GridScheduleModel.fromJson(Map<String, dynamic> json) {
    double readDouble(dynamic value, String field, double fallback) {
      if (value == null) return fallback;
      if (value is num && value.isFinite) return value.toDouble();
      throw PersistenceFailure('قيمة $field المحفوظة غير صالحة.');
    }

    return GridScheduleModel(
      gridStartHour: readDouble(json['gridStartHour'], 'gridStartHour', 0),
      gridOnHours: readDouble(json['gridOnHours'], 'gridOnHours', 0),
      gridOffHours: readDouble(json['gridOffHours'], 'gridOffHours', 24),
      batteryType: json['batteryType'] is String
          ? json['batteryType'] as String
          : 'Lead-Acid/Gel',
      gridChargeDependencyPercent: readDouble(
        json['gridChargeDependencyPercent'],
        'gridChargeDependencyPercent',
        100,
      ),
    );
  }
}
