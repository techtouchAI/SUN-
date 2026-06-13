import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load_model.dart';
import '../models/system_result_model.dart';
import '../models/grid_schedule_model.dart';
import '../repositories/solar_calculation_repository.dart';
import '../repositories/load_persistence_repository.dart';

// Provide the repository
final solarCalculationRepositoryProvider = Provider<SolarCalculationRepository>((ref) {
  return SolarCalculationRepository();
});

// StateNotifier to manage the list of loads
class LoadListNotifier extends StateNotifier<List<LoadModel>> {
  final LoadPersistenceRepository persistenceRepository;
  LoadListNotifier(this.persistenceRepository) : super([]) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final savedLoads = await persistenceRepository.loadLoads();
    if (savedLoads.isNotEmpty) {
      state = savedLoads;
    }
  }

  void _saveData() {
    persistenceRepository.saveLoads(state);
  }

  void addLoad(LoadModel load) {
    state = [...state, load];
    _saveData();
  }

  void updateLoad(LoadModel updatedLoad) {
    state = [
      for (final load in state)
        if (load.id == updatedLoad.id) updatedLoad else load,
    ];
    _saveData();
  }

  void removeLoad(String id) {
    state = state.where((load) => load.id != id).toList();
    _saveData();
  }
}

// Provider for the load list state
final loadListProvider = StateNotifierProvider<LoadListNotifier, List<LoadModel>>((ref) {
  final persistenceRepo = LoadPersistenceRepository();
  return LoadListNotifier(persistenceRepo);
});

// Provider for dynamic panel capacity
final panelCapacityProvider = StateProvider<double>((ref) => 540.0);

// Provider for dynamic panel Isc
final panelIscProvider = StateProvider<double>((ref) => 0.0);

// Provider for daytime only mode
final isDaytimeOnlyProvider = StateProvider<bool>((ref) => false);

// Provider for grid schedule
final gridScheduleProvider = StateProvider<GridScheduleModel>((ref) => const GridScheduleModel());

// Derived provider for the calculation results
final systemResultProvider = Provider<SystemResultModel>((ref) {
  final loads = ref.watch(loadListProvider);
  final panelCapacity = ref.watch(panelCapacityProvider);
  final panelIsc = ref.watch(panelIscProvider);
  final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);
  final gridSchedule = ref.watch(gridScheduleProvider);
  final repository = ref.watch(solarCalculationRepositoryProvider);

  return repository.calculateSystem(loads, panelCapacity: panelCapacity, panelIsc: panelIsc, isDaytimeOnly: isDaytimeOnly, gridSchedule: gridSchedule);
});
