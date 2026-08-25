import 'dc_cable_installation_model.dart';
import 'grid_schedule_model.dart';
import 'pv_array_topology_model.dart';
import 'system_mode.dart';

class SystemSettingsModel {
  final double panelCapacity;
  final double panelIsc;
  final String inverterLocation;
  final SystemMode systemMode;
  final double solarWattPrice;
  final double batteryAmperePrice;
  final double wiringCost;
  final double systemVoltage;
  final double gridVoltage;
  final double peakSunHours;
  final double energyLossPercentage;
  final double daysOfAutonomy;
  final double iqdExchangeRate;
  final GridScheduleModel gridSchedule;
  final String projectName;
  final PvArrayTopologyModel pvTopology;
  final DcCableInstallationModel dcCableInstallation;

  const SystemSettingsModel({
    this.panelCapacity = 540,
    this.panelIsc = 13.8,
    this.inverterLocation = 'indoor',
    this.systemMode = SystemMode.hybrid,
    this.solarWattPrice = 0.16,
    this.batteryAmperePrice = 0.85,
    this.wiringCost = 0,
    this.systemVoltage = 48,
    this.gridVoltage = 220,
    this.peakSunHours = 4.5,
    this.energyLossPercentage = 30,
    this.daysOfAutonomy = 1,
    this.iqdExchangeRate = 1500,
    this.gridSchedule = const GridScheduleModel(),
    this.projectName = 'مشروع الطاقة الشمسية',
    this.pvTopology = const PvArrayTopologyModel(),
    this.dcCableInstallation = const DcCableInstallationModel(),
  });

  SystemSettingsModel copyWith({
    double? panelCapacity,
    double? panelIsc,
    String? inverterLocation,
    SystemMode? systemMode,
    double? solarWattPrice,
    double? batteryAmperePrice,
    double? wiringCost,
    double? systemVoltage,
    double? gridVoltage,
    double? peakSunHours,
    double? energyLossPercentage,
    double? daysOfAutonomy,
    double? iqdExchangeRate,
    GridScheduleModel? gridSchedule,
    String? projectName,
    PvArrayTopologyModel? pvTopology,
    DcCableInstallationModel? dcCableInstallation,
  }) {
    return SystemSettingsModel(
      panelCapacity: panelCapacity ?? this.panelCapacity,
      panelIsc: panelIsc ?? this.panelIsc,
      inverterLocation: inverterLocation ?? this.inverterLocation,
      systemMode: systemMode ?? this.systemMode,
      solarWattPrice: solarWattPrice ?? this.solarWattPrice,
      batteryAmperePrice: batteryAmperePrice ?? this.batteryAmperePrice,
      wiringCost: wiringCost ?? this.wiringCost,
      systemVoltage: systemVoltage ?? this.systemVoltage,
      gridVoltage: gridVoltage ?? this.gridVoltage,
      peakSunHours: peakSunHours ?? this.peakSunHours,
      energyLossPercentage: energyLossPercentage ?? this.energyLossPercentage,
      daysOfAutonomy: daysOfAutonomy ?? this.daysOfAutonomy,
      iqdExchangeRate: iqdExchangeRate ?? this.iqdExchangeRate,
      gridSchedule: gridSchedule ?? this.gridSchedule,
      projectName: projectName ?? this.projectName,
      pvTopology: pvTopology ?? this.pvTopology,
      dcCableInstallation: dcCableInstallation ?? this.dcCableInstallation,
    );
  }

  Map<String, dynamic> toJson() => {
    'panelCapacity': panelCapacity,
    'panelIsc': panelIsc,
    'inverterLocation': inverterLocation,
    'systemMode': systemMode.name,
    'solarWattPrice': solarWattPrice,
    'batteryAmperePrice': batteryAmperePrice,
    'wiringCost': wiringCost,
    'systemVoltage': systemVoltage,
    'gridVoltage': gridVoltage,
    'peakSunHours': peakSunHours,
    'energyLossPercentage': energyLossPercentage,
    'daysOfAutonomy': daysOfAutonomy,
    'iqdExchangeRate': iqdExchangeRate,
    'gridSchedule': gridSchedule.toJson(),
    'projectName': projectName,
    'pvTopology': pvTopology.toJson(),
    'dcCableInstallation': dcCableInstallation.toJson(),
  };

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    final rawMode = json['systemMode'];
    final mode = SystemMode.values.firstWhere(
      (candidate) => candidate.name == rawMode,
      orElse: () => SystemMode.hybrid,
    );
    final rawGrid = json['gridSchedule'];
    final rawPvTopology = json['pvTopology'];
    final rawDcCableInstallation = json['dcCableInstallation'];
    return SystemSettingsModel(
      panelCapacity: _double(json['panelCapacity'], 540),
      panelIsc: _double(json['panelIsc'], 13.8),
      inverterLocation: _string(json['inverterLocation'], 'indoor'),
      systemMode: mode,
      solarWattPrice: _double(json['solarWattPrice'], 0.16),
      batteryAmperePrice: _double(json['batteryAmperePrice'], 0.85),
      wiringCost: _double(json['wiringCost'], 0),
      systemVoltage: _double(json['systemVoltage'], 48),
      gridVoltage: _double(json['gridVoltage'], 220),
      peakSunHours: _double(json['peakSunHours'], 4.5),
      energyLossPercentage: _double(json['energyLossPercentage'], 30),
      daysOfAutonomy: _double(json['daysOfAutonomy'], 1),
      iqdExchangeRate: _double(json['iqdExchangeRate'], 1500),
      gridSchedule: rawGrid is Map
          ? GridScheduleModel.fromJson(Map<String, dynamic>.from(rawGrid))
          : const GridScheduleModel(),
      projectName: _string(json['projectName'], 'مشروع الطاقة الشمسية'),
      pvTopology: rawPvTopology is Map
          ? PvArrayTopologyModel.fromJson(
              Map<String, dynamic>.from(rawPvTopology),
            )
          : const PvArrayTopologyModel(),
      dcCableInstallation: rawDcCableInstallation is Map
          ? DcCableInstallationModel.fromJson(
              Map<String, dynamic>.from(rawDcCableInstallation),
            )
          : const DcCableInstallationModel(),
    );
  }
}

double _double(dynamic value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;

String _string(dynamic value, String fallback) =>
    value is String && value.trim().isNotEmpty ? value : fallback;
