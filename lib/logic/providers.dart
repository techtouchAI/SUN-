import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../core/validation/input_validator.dart';
import '../models/calculation_state.dart';
import '../models/dc_cable_installation_model.dart';
import '../models/final_calculation_dto.dart';
import '../models/grid_schedule_model.dart';
import '../models/load_list_state.dart';
import '../models/load_model.dart';
import '../models/pv_array_topology_model.dart';
import '../models/system_mode.dart';
import '../models/system_settings_model.dart';
import '../models/system_result_model.dart';
import '../repositories/load_persistence_repository.dart';
import '../repositories/settings_persistence_repository.dart';
import '../repositories/solar_calculation_repository.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final systemErrorProvider = StateProvider<String?>((ref) => null);
final systemSettingsErrorProvider = StateProvider<String?>((ref) => null);

final solarCalculationRepositoryProvider = Provider<SolarCalculationRepository>(
  (ref) => SolarCalculationRepository(),
);

final loadPersistenceRepositoryProvider = Provider<LoadPersistenceRepository>(
  (ref) => LoadPersistenceRepository(),
);

final settingsPersistenceRepositoryProvider =
    Provider<SettingsPersistenceRepository>(
      (ref) => SettingsPersistenceRepository(),
    );

final panelCapacityProvider = StateProvider<double>((ref) => 540.0);
final panelIscProvider = StateProvider<double>((ref) {
  final capacity = ref.watch(panelCapacityProvider);
  return SolarCalculationRepository.getInterpolatedIsc(capacity);
});
final inverterLocationProvider = StateProvider<String>((ref) => 'indoor');
final systemModeProvider = StateProvider<SystemMode>(
  (ref) => SystemMode.hybrid,
);
final solarWattPriceProvider = StateProvider<double>((ref) => 0.16);
final batteryAmperePriceProvider = StateProvider<double>((ref) => 0.85);
final wiringCostProvider = StateProvider<double>((ref) => 0.0);
final systemVoltageProvider = StateProvider<double>((ref) => 48.0);
final peakSunHoursProvider = StateProvider<double>((ref) => 4.5);
final energyLossPercentageProvider = StateProvider<double>((ref) => 30.0);
final daysOfAutonomyProvider = StateProvider<double>((ref) => 1.0);
final gridScheduleProvider = StateProvider<GridScheduleModel>(
  (ref) => const GridScheduleModel(),
);
final gridVoltageProvider = StateProvider<double>((ref) => 220.0);
final iqdExchangeRateProvider = StateProvider<double>((ref) => 1500.0);
final pvModulesPerStringProvider = StateProvider<int?>((ref) => null);
final pvParallelStringsProvider = StateProvider<int?>((ref) => null);
final dcCableLengthMetersProvider = StateProvider<double?>((ref) => null);
final dcCableMaterialProvider = StateProvider<String?>((ref) => null);
final dcCableInsulationProvider = StateProvider<String?>((ref) => null);
final dcCableInstallationMethodProvider = StateProvider<String?>((ref) => null);
final dcCableAmbientTemperatureProvider = StateProvider<double?>((ref) => null);
final dcCableLoadedConductorsProvider = StateProvider<int?>((ref) => null);

class LoadListNotifier extends StateNotifier<LoadListState> {
  final LoadPersistenceRepository _repository;

  LoadListNotifier(this._repository) : super(const LoadListState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final loads = await _repository.loadLoads();
      InputValidator.validateLoads(loads);
      state = LoadListState(
        loads: List<LoadModel>.unmodifiable(loads),
        isLoading: false,
      );
    } catch (error) {
      state = LoadListState(
        loads: const [],
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  void addLoad(LoadModel load) {
    if (state.isLoading) {
      throw const PersistenceFailure('انتظر اكتمال تحميل الأحمال قبل الإضافة.');
    }
    InputValidator.validateLoads([load]);
    final next = List<LoadModel>.unmodifiable([...state.loads, load]);
    state = state.copyWith(loads: next, clearError: true);
    _persist(next);
  }

  void updateLoad(LoadModel updatedLoad) {
    if (state.isLoading) {
      throw const PersistenceFailure('انتظر اكتمال تحميل الأحمال قبل التعديل.');
    }
    InputValidator.validateLoads([updatedLoad]);
    final next = List<LoadModel>.unmodifiable([
      for (final load in state.loads)
        if (load.id == updatedLoad.id) updatedLoad else load,
    ]);
    state = state.copyWith(loads: next, clearError: true);
    _persist(next);
  }

  void removeLoad(String id) {
    if (state.isLoading) {
      throw const PersistenceFailure('انتظر اكتمال تحميل الأحمال قبل الحذف.');
    }
    final next = List<LoadModel>.unmodifiable(
      state.loads.where((load) => load.id != id),
    );
    state = state.copyWith(loads: next, clearError: true);
    _persist(next);
  }

  Future<void> _persist(List<LoadModel> loads) async {
    try {
      await _repository.saveLoads(loads);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }
}

final loadListProvider = StateNotifierProvider<LoadListNotifier, LoadListState>(
  (ref) => LoadListNotifier(ref.watch(loadPersistenceRepositoryProvider)),
);

class SystemSettingsNotifier extends StateNotifier<SystemSettingsModel> {
  final SettingsPersistenceRepository _repository;
  final SystemSettingsModel Function() _readLegacySettings;
  final void Function(SystemSettingsModel) _applyLegacySettings;
  final ValueChanged<String?> _reportError;
  bool isLoading = true;
  bool _syncingLegacySettings = false;

  SystemSettingsNotifier({
    required SettingsPersistenceRepository repository,
    required SystemSettingsModel Function() readLegacySettings,
    required void Function(SystemSettingsModel) applyLegacySettings,
    required ValueChanged<String?> reportError,
  }) : _repository = repository,
       _readLegacySettings = readLegacySettings,
       _applyLegacySettings = applyLegacySettings,
       _reportError = reportError,
       super(const SystemSettingsModel()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final loaded = await _repository.loadSettings();
      if (!mounted) return;
      _syncingLegacySettings = true;
      state = loaded;
      _applyLegacySettings(loaded);
      _syncingLegacySettings = false;
      _reportError(null);
    } catch (error) {
      if (mounted) _reportError(error.toString());
    } finally {
      if (mounted) isLoading = false;
    }
  }

  void updateFromLegacySettings() {
    if (_syncingLegacySettings) return;
    try {
      update(_readLegacySettings());
    } catch (error) {
      _reportError(error.toString());
      _syncingLegacySettings = true;
      _applyLegacySettings(state);
      _syncingLegacySettings = false;
    }
  }

  void update(SystemSettingsModel value) {
    InputValidator.validateSystemParameters(
      panelCapacity: value.panelCapacity,
      panelIsc: value.panelIsc,
      peakSunHours: value.peakSunHours,
      systemVoltage: value.systemVoltage,
      gridVoltage: value.gridVoltage,
      energyLossPercentage: value.energyLossPercentage,
      daysOfAutonomy: value.daysOfAutonomy,
      solarWattPrice: value.solarWattPrice,
      batteryAmperePrice: value.batteryAmperePrice,
      wiringCost: value.wiringCost,
    );
    InputValidator.validateGridSchedule(
      gridStartHour: value.gridSchedule.gridStartHour,
      gridOnHours: value.gridSchedule.gridOnHours,
      gridOffHours: value.gridSchedule.gridOffHours,
      gridChargeDependencyPercent:
          value.gridSchedule.gridChargeDependencyPercent,
    );
    state = value;
    _reportError(null);
    _persist(value);
  }

  Future<void> _persist(SystemSettingsModel value) async {
    try {
      await _repository.saveSettings(value);
    } catch (error) {
      if (mounted) _reportError(error.toString());
    }
  }
}

final systemSettingsProvider =
    StateNotifierProvider<SystemSettingsNotifier, SystemSettingsModel>((ref) {
      SystemSettingsModel readLegacySettings() => SystemSettingsModel(
        panelCapacity: ref.read(panelCapacityProvider),
        panelIsc: ref.read(panelIscProvider),
        inverterLocation: ref.read(inverterLocationProvider),
        systemMode: ref.read(systemModeProvider),
        solarWattPrice: ref.read(solarWattPriceProvider),
        batteryAmperePrice: ref.read(batteryAmperePriceProvider),
        wiringCost: ref.read(wiringCostProvider),
        systemVoltage: ref.read(systemVoltageProvider),
        gridVoltage: ref.read(gridVoltageProvider),
        peakSunHours: ref.read(peakSunHoursProvider),
        energyLossPercentage: ref.read(energyLossPercentageProvider),
        daysOfAutonomy: ref.read(daysOfAutonomyProvider),
        iqdExchangeRate: ref.read(iqdExchangeRateProvider),
        gridSchedule: ref.read(gridScheduleProvider),
        pvTopology: PvArrayTopologyModel(
          modulesPerString: ref.read(pvModulesPerStringProvider),
          parallelStrings: ref.read(pvParallelStringsProvider),
        ),
        dcCableInstallation: DcCableInstallationModel(
          oneWayLengthMeters: ref.read(dcCableLengthMetersProvider),
          conductorMaterial: ref.read(dcCableMaterialProvider),
          insulationRating: ref.read(dcCableInsulationProvider),
          installationMethod: ref.read(dcCableInstallationMethodProvider),
          ambientTemperatureCelsius: ref.read(
            dcCableAmbientTemperatureProvider,
          ),
          loadedConductors: ref.read(dcCableLoadedConductorsProvider),
        ),
      );

      void applyLegacySettings(SystemSettingsModel value) {
        ref.read(panelCapacityProvider.notifier).state = value.panelCapacity;
        ref.read(panelIscProvider.notifier).state = value.panelIsc;
        ref.read(inverterLocationProvider.notifier).state =
            value.inverterLocation;
        ref.read(systemModeProvider.notifier).state = value.systemMode;
        ref.read(solarWattPriceProvider.notifier).state = value.solarWattPrice;
        ref.read(batteryAmperePriceProvider.notifier).state =
            value.batteryAmperePrice;
        ref.read(wiringCostProvider.notifier).state = value.wiringCost;
        ref.read(systemVoltageProvider.notifier).state = value.systemVoltage;
        ref.read(gridVoltageProvider.notifier).state = value.gridVoltage;
        ref.read(peakSunHoursProvider.notifier).state = value.peakSunHours;
        ref.read(energyLossPercentageProvider.notifier).state =
            value.energyLossPercentage;
        ref.read(daysOfAutonomyProvider.notifier).state = value.daysOfAutonomy;
        ref.read(iqdExchangeRateProvider.notifier).state =
            value.iqdExchangeRate;
        ref.read(gridScheduleProvider.notifier).state = value.gridSchedule;
        ref.read(pvModulesPerStringProvider.notifier).state =
            value.pvTopology.modulesPerString;
        ref.read(pvParallelStringsProvider.notifier).state =
            value.pvTopology.parallelStrings;
        ref.read(dcCableLengthMetersProvider.notifier).state =
            value.dcCableInstallation.oneWayLengthMeters;
        ref.read(dcCableMaterialProvider.notifier).state =
            value.dcCableInstallation.conductorMaterial;
        ref.read(dcCableInsulationProvider.notifier).state =
            value.dcCableInstallation.insulationRating;
        ref.read(dcCableInstallationMethodProvider.notifier).state =
            value.dcCableInstallation.installationMethod;
        ref.read(dcCableAmbientTemperatureProvider.notifier).state =
            value.dcCableInstallation.ambientTemperatureCelsius;
        ref.read(dcCableLoadedConductorsProvider.notifier).state =
            value.dcCableInstallation.loadedConductors;
      }

      final notifier = SystemSettingsNotifier(
        repository: ref.watch(settingsPersistenceRepositoryProvider),
        readLegacySettings: readLegacySettings,
        applyLegacySettings: applyLegacySettings,
        reportError: (message) =>
            ref.read(systemSettingsErrorProvider.notifier).state = message,
      );

      ref.listen<double>(panelCapacityProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(panelIscProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<String>(inverterLocationProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<SystemMode>(systemModeProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(solarWattPriceProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(batteryAmperePriceProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(wiringCostProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(systemVoltageProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(gridVoltageProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(peakSunHoursProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(energyLossPercentageProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(daysOfAutonomyProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double>(iqdExchangeRateProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<GridScheduleModel>(gridScheduleProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<int?>(pvModulesPerStringProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<int?>(pvParallelStringsProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double?>(dcCableLengthMetersProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<String?>(dcCableMaterialProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<String?>(dcCableInsulationProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<String?>(dcCableInstallationMethodProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<double?>(dcCableAmbientTemperatureProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      ref.listen<int?>(dcCableLoadedConductorsProvider, (_, _) {
        notifier.updateFromLegacySettings();
      });
      return notifier;
    });

final calculationStateProvider = Provider<CalculationState>((ref) {
  final loadState = ref.watch(loadListProvider);
  if (loadState.isLoading) return const CalculationNoLoads();
  if (loadState.errorMessage != null && loadState.loads.isEmpty) {
    return CalculationFailed(loadState.errorMessage!);
  }
  if (loadState.loads.isEmpty) return const CalculationNoLoads();

  final settings = ref.watch(systemSettingsProvider);
  final repository = ref.watch(solarCalculationRepositoryProvider);
  try {
    final result = repository.calculateSystem(
      loadState.loads,
      gridVoltage: settings.gridVoltage,
      inverterLocation: settings.inverterLocation,
      panelCapacity: settings.panelCapacity,
      panelIsc: settings.panelIsc,
      systemMode: settings.systemMode,
      gridSchedule: settings.gridSchedule,
      solarWattPrice: settings.solarWattPrice,
      batteryAmperePrice: settings.batteryAmperePrice,
      wiringCost: settings.wiringCost,
      systemVoltage: settings.systemVoltage,
      peakSunHours: settings.peakSunHours,
      energyLossPercentage: settings.energyLossPercentage,
      daysOfAutonomy: settings.daysOfAutonomy,
      pvModulesPerString: settings.pvTopology.modulesPerString,
      pvParallelStrings: settings.pvTopology.parallelStrings,
      dcCableOneWayLengthMeters:
          settings.dcCableInstallation.oneWayLengthMeters,
      dcCableMaterial: settings.dcCableInstallation.conductorMaterial,
      dcCableInsulation: settings.dcCableInstallation.insulationRating,
      dcCableInstallationMethod:
          settings.dcCableInstallation.installationMethod,
      dcCableAmbientTemperatureCelsius:
          settings.dcCableInstallation.ambientTemperatureCelsius,
      dcCableLoadedConductors: settings.dcCableInstallation.loadedConductors,
    );
    return CalculationReady(result);
  } on AppException catch (error) {
    return CalculationInvalidInput(error);
  } catch (error) {
    return CalculationFailed(error);
  }
});

final systemResultProvider = Provider<SystemResultModel?>((ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  void reportError(String? message) {
    Future.microtask(() {
      if (!disposed) {
        ref.read(systemErrorProvider.notifier).state = message;
      }
    });
  }

  final state = ref.watch(calculationStateProvider);
  if (state is CalculationReady) {
    reportError(null);
    return state.result;
  }
  if (state is CalculationInvalidInput) {
    reportError(state.error.message);
    return null;
  }
  if (state is CalculationFailed) {
    final message = state.error.toString();
    reportError(message);
    return null;
  }
  reportError(null);
  return null;
});

final finalCalculationDtoProvider = Provider<FinalCalculationDto?>((ref) {
  final state = ref.watch(calculationStateProvider);
  if (state is! CalculationReady) return null;
  final loads = ref.watch(loadListProvider).loads;
  final settings = ref.watch(systemSettingsProvider);
  return FinalCalculationDto(
    projectName: settings.projectName,
    generatedAt: DateTime.now(),
    appVersion: '1.0.18+568',
    calculationVersion: '2.0.0',
    loads: List.unmodifiable(loads),
    settings: settings,
    result: state.result,
  );
});
