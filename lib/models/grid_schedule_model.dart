class GridScheduleModel {
  final double gridOnHours;
  final double gridOffHours;
  final bool isOffGrid;
  final String batteryType;

  const GridScheduleModel({
    this.gridOnHours = 0.0,
    this.gridOffHours = 24.0,
    this.isOffGrid = true,
    this.batteryType = 'Lead-Acid/Gel',
  });

  GridScheduleModel copyWith({
    double? gridOnHours,
    double? gridOffHours,
    bool? isOffGrid,
    String? batteryType,
  }) {
    return GridScheduleModel(
      gridOnHours: gridOnHours ?? this.gridOnHours,
      gridOffHours: gridOffHours ?? this.gridOffHours,
      isOffGrid: isOffGrid ?? this.isOffGrid,
      batteryType: batteryType ?? this.batteryType,
    );
  }
}
