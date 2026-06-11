class GridScheduleModel {
  final double gridOnHours;
  final double gridOffHours;
  final bool isOffGrid;

  const GridScheduleModel({
    this.gridOnHours = 0.0,
    this.gridOffHours = 24.0,
    this.isOffGrid = true,
  });

  GridScheduleModel copyWith({
    double? gridOnHours,
    double? gridOffHours,
    bool? isOffGrid,
  }) {
    return GridScheduleModel(
      gridOnHours: gridOnHours ?? this.gridOnHours,
      gridOffHours: gridOffHours ?? this.gridOffHours,
      isOffGrid: isOffGrid ?? this.isOffGrid,
    );
  }
}
