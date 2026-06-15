class GridScheduleModel {
  final double gridOnHours;
  final double gridOffHours;
  final String batteryType;
  final double gridChargeDependencyPercent;

  const GridScheduleModel({
    this.gridOnHours = 0.0,
    this.gridOffHours = 24.0,
    this.batteryType = 'Lead-Acid/Gel',
    this.gridChargeDependencyPercent = 100.0,
  });

  GridScheduleModel copyWith({
    double? gridOnHours,
    double? gridOffHours,
    String? batteryType,
    double? gridChargeDependencyPercent,
  }) {
    return GridScheduleModel(
      gridOnHours: gridOnHours ?? this.gridOnHours,
      gridOffHours: gridOffHours ?? this.gridOffHours,
      batteryType: batteryType ?? this.batteryType,
      gridChargeDependencyPercent:
          gridChargeDependencyPercent ?? this.gridChargeDependencyPercent,
    );
  }
}
