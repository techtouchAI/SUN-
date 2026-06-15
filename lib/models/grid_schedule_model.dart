class GridScheduleModel {
  final double gridOnHours;
  final double gridOffHours;
  final bool isOffGrid;
  final String batteryType;
  final bool isUpsMode;
  final double gridChargeDependencyPercent;

  const GridScheduleModel({
    this.gridOnHours = 0.0,
    this.gridOffHours = 24.0,
    this.isOffGrid = true,
    this.batteryType = 'Lead-Acid/Gel',
    this.isUpsMode = false,
    this.gridChargeDependencyPercent = 100.0,
  });

  GridScheduleModel copyWith({
    double? gridOnHours,
    double? gridOffHours,
    bool? isOffGrid,
    String? batteryType,
    bool? isUpsMode,
    double? gridChargeDependencyPercent,
  }) {
    return GridScheduleModel(
      gridOnHours: gridOnHours ?? this.gridOnHours,
      gridOffHours: gridOffHours ?? this.gridOffHours,
      isOffGrid: isOffGrid ?? this.isOffGrid,
      batteryType: batteryType ?? this.batteryType,
      isUpsMode: isUpsMode ?? this.isUpsMode,
      gridChargeDependencyPercent: gridChargeDependencyPercent ?? this.gridChargeDependencyPercent,
    );
  }
}
