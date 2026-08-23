import 'package:uuid/uuid.dart';
import '../core/errors/app_exceptions.dart';

/// The physical unit entered by the user before conversion to watts.
enum PowerUnit { watt, ampere, ton }

class LoadOperatingPeriod {
  final double startHour;
  final double endHour;

  const LoadOperatingPeriod({required this.startHour, required this.endHour});

  double get durationHours => endHour - startHour;

  Map<String, dynamic> toJson() => {'startHour': startHour, 'endHour': endHour};

  factory LoadOperatingPeriod.fromJson(Map<String, dynamic> json) {
    final start = _readDouble(json['startHour'], 'startHour');
    final end = _readDouble(json['endHour'], 'endHour');
    return LoadOperatingPeriod(startHour: start, endHour: end);
  }
}

class LoadModel {
  final String id;
  final String name;
  final PowerUnit unit;
  final double powerValue;
  final int quantity;
  final double startingCurrentMultiplier;
  final double dailyUsageHours;
  final double daytimeHours;
  final double nighttimeHours;
  final List<LoadOperatingPeriod> operatingPeriods;
  final bool isInverterDevice;

  LoadModel({
    String? id,
    required this.name,
    required this.unit,
    required this.powerValue,
    this.quantity = 1,
    this.startingCurrentMultiplier = 1.0,
    required this.dailyUsageHours,
    double? daytimeHours,
    double? nighttimeHours,
    List<LoadOperatingPeriod>? operatingPeriods,
    this.isInverterDevice = false,
  }) : id = id ?? const Uuid().v4(),
       daytimeHours = daytimeHours ?? dailyUsageHours,
       nighttimeHours = nighttimeHours ?? 0.0,
       operatingPeriods = List.unmodifiable(operatingPeriods ?? const []);

  bool get hasExplicitTimeProfile =>
      operatingPeriods.isNotEmpty || daytimeHours > 0 || nighttimeHours > 0;

  double get calculatedDaytimeHours {
    if (operatingPeriods.isNotEmpty) {
      return operatingPeriods
          .where((period) => period.startHour >= 6 && period.startHour < 18)
          .fold(0.0, (sum, period) => sum + period.durationHours);
    }
    return daytimeHours;
  }

  double get calculatedNighttimeHours {
    if (operatingPeriods.isNotEmpty) {
      return operatingPeriods
          .where((period) => period.startHour < 6 || period.startHour >= 18)
          .fold(0.0, (sum, period) => sum + period.durationHours);
    }
    return nighttimeHours;
  }

  LoadModel copyWith({
    String? name,
    PowerUnit? unit,
    double? powerValue,
    int? quantity,
    double? startingCurrentMultiplier,
    double? dailyUsageHours,
    double? daytimeHours,
    double? nighttimeHours,
    List<LoadOperatingPeriod>? operatingPeriods,
    bool? isInverterDevice,
  }) {
    return LoadModel(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      powerValue: powerValue ?? this.powerValue,
      quantity: quantity ?? this.quantity,
      startingCurrentMultiplier:
          startingCurrentMultiplier ?? this.startingCurrentMultiplier,
      dailyUsageHours: dailyUsageHours ?? this.dailyUsageHours,
      daytimeHours: daytimeHours ?? this.daytimeHours,
      nighttimeHours: nighttimeHours ?? this.nighttimeHours,
      operatingPeriods: operatingPeriods ?? this.operatingPeriods,
      isInverterDevice: isInverterDevice ?? this.isInverterDevice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit.name,
      'powerValue': powerValue,
      'quantity': quantity,
      'startingCurrentMultiplier': startingCurrentMultiplier,
      'dailyUsageHours': dailyUsageHours,
      'daytimeHours': daytimeHours,
      'nighttimeHours': nighttimeHours,
      'operatingPeriods': operatingPeriods.map((p) => p.toJson()).toList(),
      'isInverterDevice': isInverterDevice,
    };
  }

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    final rawUnit = json['unit'];
    PowerUnit? unit;
    for (final candidate in PowerUnit.values) {
      if (candidate.name == rawUnit) {
        unit = candidate;
        break;
      }
    }
    if (unit == null) {
      throw InvalidLoadInput('وحدة الحمل المحفوظة غير معروفة.');
    }

    final rawPeriods = json['operatingPeriods'];
    final periods = rawPeriods is List
        ? rawPeriods.map((item) {
            if (item is! Map) {
              throw InvalidLoadInput('فترة تشغيل محفوظة غير صالحة.');
            }
            return LoadOperatingPeriod.fromJson(
              Map<String, dynamic>.from(item),
            );
          }).toList()
        : <LoadOperatingPeriod>[];

    final dailyHours = _readDouble(json['dailyUsageHours'], 'dailyUsageHours');
    return LoadModel(
      id: json['id'] is String ? json['id'] as String : null,
      name: json['name'] is String ? json['name'] as String : '',
      unit: unit,
      powerValue: _readDouble(json['powerValue'], 'powerValue'),
      quantity: _readInt(json['quantity'] ?? 1, 'quantity'),
      startingCurrentMultiplier: _readDouble(
        json['startingCurrentMultiplier'] ?? 1.0,
        'startingCurrentMultiplier',
      ),
      dailyUsageHours: dailyHours,
      daytimeHours: json.containsKey('daytimeHours')
          ? _readDouble(json['daytimeHours'], 'daytimeHours')
          : dailyHours,
      nighttimeHours: json.containsKey('nighttimeHours')
          ? _readDouble(json['nighttimeHours'], 'nighttimeHours')
          : 0.0,
      operatingPeriods: periods,
      isInverterDevice: json['isInverterDevice'] == true,
    );
  }
}

double _readDouble(dynamic value, String field) {
  if (value is num && value.isFinite) return value.toDouble();
  throw InvalidLoadInput(
    'القيمة المحفوظة للحقل $field غير صالحة.',
    field: field,
  );
}

int _readInt(dynamic value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw InvalidLoadInput(
    'القيمة المحفوظة للحقل $field غير صالحة.',
    field: field,
  );
}
