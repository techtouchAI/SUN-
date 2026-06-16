import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load_model.dart';
import '../models/system_result_model.dart';
import '../models/grid_schedule_model.dart';
import '../models/system_mode.dart';
import '../repositories/solar_calculation_repository.dart';
import '../repositories/load_persistence_repository.dart';

// Provide the repository
final solarCalculationRepositoryProvider = Provider<SolarCalculationRepository>((ref) {
  return SolarCalculationRepository();
});

final loadPersistenceRepositoryProvider = Provider<LoadPersistenceRepository>((ref) {
  return LoadPersistenceRepository();
});

// StateNotifier to manage the list of loads
class LoadListNotifier extends StateNotifier<List<LoadModel>> {
  final LoadPersistenceRepository _repository;

  LoadListNotifier(this._repository) : super([]) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final loads = await _repository.loadLoads();
    state = loads;
  }

  void addLoad(LoadModel load) {
    state = [...state, load];
    _repository.saveLoads(state);
  }

  void updateLoad(LoadModel updatedLoad) {
    state = [
      for (final load in state)
        if (load.id == updatedLoad.id) updatedLoad else load,
    ];
    _repository.saveLoads(state);
  }

  void removeLoad(String id) {
    state = state.where((load) => load.id != id).toList();
    _repository.saveLoads(state);
  }
}

// Provider for the load list state
final loadListProvider = StateNotifierProvider<LoadListNotifier, List<LoadModel>>((ref) {
  final repository = ref.watch(loadPersistenceRepositoryProvider);
  return LoadListNotifier(repository);
});

// Provider for dynamic panel capacity
final panelCapacityProvider = StateProvider<double>((ref) => 540.0);

// Provider for dynamic panel Isc
final panelIscProvider = StateProvider<double>((ref) {
  final initialCapacity = ref.read(panelCapacityProvider);
  return double.parse(SolarCalculationRepository.getInterpolatedIsc(initialCapacity).toStringAsFixed(2));
});

// Provider for inverter location
final inverterLocationProvider = StateProvider<String>((ref) => 'indoor');

// Provider for system mode
final systemModeProvider = StateProvider<SystemMode>((ref) => SystemMode.hybrid);

// ThemeMode Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Providers for pricing settings
final solarWattPriceProvider = StateProvider<double>((ref) => 0.16);
final batteryAmperePriceProvider = StateProvider<double>((ref) => 0.85);
final breakerPriceProvider = StateProvider<double>((ref) => 0.0);
final wiringCostProvider = StateProvider<double>((ref) => 0.0);

// Providers for engineering parameters
final systemVoltageProvider = StateProvider<double>((ref) => 48.0);
final peakSunHoursProvider = StateProvider<double>((ref) => 4.5);
final energyLossPercentageProvider = StateProvider<double>((ref) => 30.0);
final daysOfAutonomyProvider = StateProvider<double>((ref) => 1.0);

// Provider for grid schedule
final gridScheduleProvider = StateProvider<GridScheduleModel>((ref) => const GridScheduleModel());


// Providers for Grid Voltage and IQD
final gridVoltageProvider = StateProvider<double>((ref) => 220.0);
final iqdExchangeRateProvider = StateProvider<double>((ref) => 1500.0);

// System Error Provider
final systemErrorProvider = StateProvider<String?>((ref) => null);

// Derived provider for the calculation results
final systemResultProvider = Provider<SystemResultModel>((ref) {
  final loads = ref.watch(loadListProvider);
  final panelCapacity = ref.watch(panelCapacityProvider);
  final panelIsc = ref.watch(panelIscProvider);
  final systemMode = ref.watch(systemModeProvider);
  final gridSchedule = ref.watch(gridScheduleProvider);

  final solarWattPrice = ref.watch(solarWattPriceProvider);
  final batteryAmperePrice = ref.watch(batteryAmperePriceProvider);
  final breakerPrice = ref.watch(breakerPriceProvider);
  final wiringCost = ref.watch(wiringCostProvider);

  final systemVoltage = ref.watch(systemVoltageProvider);
  final peakSunHours = ref.watch(peakSunHoursProvider);
  final energyLossPercentage = ref.watch(energyLossPercentageProvider);
  final daysOfAutonomy = ref.watch(daysOfAutonomyProvider);

  final gridVoltage = ref.watch(gridVoltageProvider);
  final inverterLocation = ref.watch(inverterLocationProvider);
  final repository = ref.watch(solarCalculationRepositoryProvider);

  try {
    final result = repository.calculateSystem(
      loads,
      gridVoltage: gridVoltage,
      inverterLocation: inverterLocation,
      panelCapacity: panelCapacity,
      panelIsc: panelIsc,
      systemMode: systemMode,
      gridSchedule: gridSchedule,
      solarWattPrice: solarWattPrice,
      batteryAmperePrice: batteryAmperePrice,
      breakerPrice: breakerPrice,
      wiringCost: wiringCost,
      systemVoltage: systemVoltage,
      peakSunHours: peakSunHours,
      energyLossPercentage: energyLossPercentage,
      daysOfAutonomy: daysOfAutonomy,
    );

    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = null);
    return result;
  } catch (e) {
    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = e.toString());
    return SystemResultModel.empty();
  }
});
