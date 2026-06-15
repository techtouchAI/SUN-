import 'package:uuid/uuid.dart';

enum PowerUnit { watt, ampere, ton }

class LoadModel {
  final String id;
  final String name;
  final PowerUnit unit;
  final double powerValue; // in Watts, Amperes, or Tons based on the unit
  final double startingCurrentMultiplier;
  final double dailyUsageHours;
  final bool isInverterDevice;

  LoadModel({
    String? id,
    required this.name,
    required this.unit,
    required this.powerValue,
    this.startingCurrentMultiplier = 1.0,
    required this.dailyUsageHours,
    this.isInverterDevice = false,
  }) : id = id ?? const Uuid().v4();

  LoadModel copyWith({
    String? name,
    PowerUnit? unit,
    double? powerValue,
    double? startingCurrentMultiplier,
    double? dailyUsageHours,
    bool? isInverterDevice,
  }) {
    return LoadModel(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      powerValue: powerValue ?? this.powerValue,
      startingCurrentMultiplier:
          startingCurrentMultiplier ?? this.startingCurrentMultiplier,
      dailyUsageHours: dailyUsageHours ?? this.dailyUsageHours,
      isInverterDevice: isInverterDevice ?? this.isInverterDevice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit.name,
      'powerValue': powerValue,
      'startingCurrentMultiplier': startingCurrentMultiplier,
      'dailyUsageHours': dailyUsageHours,
      'isInverterDevice': isInverterDevice,
    };
  }

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    return LoadModel(
      id: json['id'],
      name: json['name'],
      unit: PowerUnit.values.firstWhere((e) => e.name == json['unit']),
      powerValue: json['powerValue'].toDouble(),
      startingCurrentMultiplier: json['startingCurrentMultiplier'].toDouble(),
      dailyUsageHours: json['dailyUsageHours'].toDouble(),
      isInverterDevice: json['isInverterDevice'],
    );
  }
}
