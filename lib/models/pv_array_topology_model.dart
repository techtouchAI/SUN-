class PvArrayTopologyModel {
  final int? modulesPerString;
  final int? parallelStrings;

  const PvArrayTopologyModel({this.modulesPerString, this.parallelStrings});

  bool get isComplete =>
      modulesPerString != null &&
      modulesPerString! > 0 &&
      parallelStrings != null &&
      parallelStrings! > 0;

  int? get totalModules =>
      isComplete ? modulesPerString! * parallelStrings! : null;

  PvArrayTopologyModel copyWith({
    int? modulesPerString,
    int? parallelStrings,
  }) => PvArrayTopologyModel(
    modulesPerString: modulesPerString ?? this.modulesPerString,
    parallelStrings: parallelStrings ?? this.parallelStrings,
  );

  Map<String, dynamic> toJson() => {
    'modulesPerString': modulesPerString,
    'parallelStrings': parallelStrings,
  };

  factory PvArrayTopologyModel.fromJson(Map<String, dynamic> json) =>
      PvArrayTopologyModel(
        modulesPerString: _positiveInt(json['modulesPerString']),
        parallelStrings: _positiveInt(json['parallelStrings']),
      );
}

int? _positiveInt(dynamic value) =>
    value is num &&
        value.isFinite &&
        value > 0 &&
        value == value.roundToDouble()
    ? value.toInt()
    : null;
