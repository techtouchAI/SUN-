import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../core/validation/input_validator.dart';
import '../models/calculation_state.dart';
import '../models/final_calculation_dto.dart';
import '../models/load_list_state.dart';
import '../models/load_model.dart';
import '../models/system_settings_model.dart';
import '../repositories/load_persistence_repository.dart';
import '../repositories/settings_persistence_repository.dart';
import '../repositories/solar_calculation_repository.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final systemSettingsErrorProvider = StateProvider<String?>((ref) => null);

final solarCalculationRepositoryProvider = Provider<SolarCalculationRepository>(
  (ref) {
    return SolarCalculationRepository();
  },
);

final loadPersistenceRepositoryProvider = Provider<LoadPersistenceRepository>((
  ref,
) {
  return LoadPersistenceRepository();
});

final settingsPersistenceRepositoryProvider =
    Provider<SettingsPersistenceRepository>((ref) {
      return SettingsPersistenceRepository();
    });

class LoadListNotifier extends StateNotifier<LoadListState> {
  final LoadPersistenceRepository _repository;

  LoadListNotifier(this._repository) : super(const LoadListState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final loads = await _repository.loadLoads();
      InputValidator.validateLoads(loads);
      state = LoadListState(loads: List.unmodifiable(loads), isLoading: false);
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
  (ref) {
    return LoadListNotifier(ref.watch(loadPersistenceRepositoryProvider));
  },
);

class SystemSettingsNotifier extends StateNotifier<SystemSettingsModel> {
  final SettingsPersistenceRepository _repository;
  final ValueChanged<String?> _reportError;
  bool isLoading = true;

  SystemSettingsNotifier(this._repository, this._reportError)
    : super(const SystemSettingsModel()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final loaded = await _repository.loadSettings();
      if (!mounted) return;
      state = loaded;
      _reportError(null);
    } catch (error) {
      if (mounted) _reportError(error.toString());
    } finally {
      if (mounted) isLoading = false;
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
      breakerPrice: value.breakerPrice,
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
      return SystemSettingsNotifier(
        ref.watch(settingsPersistenceRepositoryProvider),
        (message) =>
            ref.read(systemSettingsErrorProvider.notifier).state = message,
      );
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
      breakerPrice: settings.breakerPrice,
      wiringCost: settings.wiringCost,
      systemVoltage: settings.systemVoltage,
      peakSunHours: settings.peakSunHours,
      energyLossPercentage: settings.energyLossPercentage,
      daysOfAutonomy: settings.daysOfAutonomy,
    );
    return CalculationReady(result);
  } on AppException catch (error) {
    return CalculationInvalidInput(error);
  } catch (error) {
    return CalculationFailed(error);
  }
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
