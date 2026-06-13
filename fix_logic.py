with open('lib/logic/providers.dart', 'r') as f:
    content = f.read()

content = content.replace('''// Providers for engineering parameters
final systemVoltageProvider = StateProvider<double>((ref) => 48.0);
final peakSunHoursProvider = StateProvider<double>((ref) => 4.5);
final energyLossPercentageProvider = StateProvider<double>((ref) => 18.0);
final daysOfAutonomyProvider = StateProvider<double>((ref) => 1.0);''', '''// Providers for engineering parameters
final systemVoltageProvider = StateProvider<double>((ref) => 48.0);
final peakSunHoursProvider = StateProvider<double>((ref) => 4.5);
final energyLossPercentageProvider = StateProvider<double>((ref) => 18.0);
final daysOfAutonomyProvider = StateProvider<double>((ref) => 1.0);

// Providers for Grid Voltage and IQD
final gridVoltageProvider = StateProvider<double>((ref) => 220.0);
final iqdExchangeRateProvider = StateProvider<double>((ref) => 1500.0);

// System Error Provider
final systemErrorProvider = StateProvider<String?>((ref) => null);''')

content = content.replace('''  final repository = ref.watch(solarCalculationRepositoryProvider);

  return repository.calculateSystem(''', '''  final gridVoltage = ref.watch(gridVoltageProvider);
  final repository = ref.watch(solarCalculationRepositoryProvider);

  try {
    final result = repository.calculateSystem(
      loads,
      gridVoltage: gridVoltage,
      panelCapacity: panelCapacity,
      panelIsc: panelIsc,
      isDaytimeOnly: isDaytimeOnly,
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

    // Clear any previous errors using Future.microtask to avoid modifying providers during build
    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = null);

    return result;
  } catch (e) {
    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = e.toString());
    return SystemResultModel.empty();
  }
}''')

# We need to drop the original calculateSystem call block from providers.dart which we just partially replaced.
# Actually, the original is:
#  return repository.calculateSystem(
#    loads,
#    panelCapacity: panelCapacity, ... etc

# Let's do it cleanly by re-writing providers.dart
