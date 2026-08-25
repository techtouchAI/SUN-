class DcCableInstallationModel {
  final double? oneWayLengthMeters;
  final String? conductorMaterial;
  final String? insulationRating;
  final String? installationMethod;
  final double? ambientTemperatureCelsius;
  final int? loadedConductors;

  const DcCableInstallationModel({
    this.oneWayLengthMeters,
    this.conductorMaterial,
    this.insulationRating,
    this.installationMethod,
    this.ambientTemperatureCelsius,
    this.loadedConductors,
  });

  bool get isComplete =>
      oneWayLengthMeters != null &&
      oneWayLengthMeters! > 0 &&
      _hasText(conductorMaterial) &&
      _hasText(insulationRating) &&
      _hasText(installationMethod) &&
      ambientTemperatureCelsius != null &&
      ambientTemperatureCelsius!.isFinite &&
      loadedConductors != null &&
      loadedConductors! > 0;

  DcCableInstallationModel copyWith({
    double? oneWayLengthMeters,
    String? conductorMaterial,
    String? insulationRating,
    String? installationMethod,
    double? ambientTemperatureCelsius,
    int? loadedConductors,
  }) => DcCableInstallationModel(
    oneWayLengthMeters: oneWayLengthMeters ?? this.oneWayLengthMeters,
    conductorMaterial: conductorMaterial ?? this.conductorMaterial,
    insulationRating: insulationRating ?? this.insulationRating,
    installationMethod: installationMethod ?? this.installationMethod,
    ambientTemperatureCelsius:
        ambientTemperatureCelsius ?? this.ambientTemperatureCelsius,
    loadedConductors: loadedConductors ?? this.loadedConductors,
  );

  Map<String, dynamic> toJson() => {
    'oneWayLengthMeters': oneWayLengthMeters,
    'conductorMaterial': conductorMaterial,
    'insulationRating': insulationRating,
    'installationMethod': installationMethod,
    'ambientTemperatureCelsius': ambientTemperatureCelsius,
    'loadedConductors': loadedConductors,
  };

  factory DcCableInstallationModel.fromJson(Map<String, dynamic> json) =>
      DcCableInstallationModel(
        oneWayLengthMeters: _positiveDouble(json['oneWayLengthMeters']),
        conductorMaterial: _nonBlank(json['conductorMaterial']),
        insulationRating: _nonBlank(json['insulationRating']),
        installationMethod: _nonBlank(json['installationMethod']),
        ambientTemperatureCelsius: _finiteDouble(
          json['ambientTemperatureCelsius'],
        ),
        loadedConductors: _positiveInt(json['loadedConductors']),
      );
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

double? _positiveDouble(dynamic value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

double? _finiteDouble(dynamic value) =>
    value is num && value.isFinite ? value.toDouble() : null;

int? _positiveInt(dynamic value) =>
    value is num &&
        value.isFinite &&
        value > 0 &&
        value == value.roundToDouble()
    ? value.toInt()
    : null;

String? _nonBlank(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;
