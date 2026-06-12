import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load_model.dart';
import '../models/system_result_model.dart';
import '../models/grid_schedule_model.dart';
import '../repositories/solar_calculation_repository.dart';

// Provide the repository
final solarCalculationRepositoryProvider = Provider<SolarCalculationRepository>((ref) {
  return SolarCalculationRepository();
});

// StateNotifier to manage the list of loads
class LoadListNotifier extends StateNotifier<List<LoadModel>> {
  LoadListNotifier() : super([]);

  void addLoad(LoadModel load) {
    state = [...state, load];
  }

  void updateLoad(LoadModel updatedLoad) {
    state = [
      for (final load in state)
        if (load.id == updatedLoad.id) updatedLoad else load,
    ];
  }

  void removeLoad(String id) {
    state = state.where((load) => load.id != id).toList();
  }
}

// Provider for the load list state
final loadListProvider = StateNotifierProvider<LoadListNotifier, List<LoadModel>>((ref) {
  return LoadListNotifier();
});

// Provider for dynamic panel capacity
final panelCapacityProvider = StateProvider<double>((ref) => 540.0);

// Provider for daytime only mode
final isDaytimeOnlyProvider = StateProvider<bool>((ref) => false);

// Provider for grid schedule
final gridScheduleProvider = StateProvider<GridScheduleModel>((ref) => const GridScheduleModel());

// Derived provider for the calculation results
final systemResultProvider = Provider<SystemResultModel>((ref) {
  final loads = ref.watch(loadListProvider);
  final panelCapacity = ref.watch(panelCapacityProvider);
  final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);
  final gridSchedule = ref.watch(gridScheduleProvider);
  final repository = ref.watch(solarCalculationRepositoryProvider);

  return repository.calculateSystem(loads, panelCapacity: panelCapacity, isDaytimeOnly: isDaytimeOnly, gridSchedule: gridSchedule);
});
