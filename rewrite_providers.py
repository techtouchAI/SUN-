with open('lib/logic/providers.dart', 'r') as f:
    content = f.read()

# Let's clean up the bottom of providers.dart manually:
import re
new_content = re.sub(
r'''  final repository = ref\.watch\(solarCalculationRepositoryProvider\);

  return repository\.calculateSystem\(
    loads,
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
  \);
\}\);''',
'''  final gridVoltage = ref.watch(gridVoltageProvider);
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

    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = null);
    return result;
  } catch (e) {
    Future.microtask(() => ref.read(systemErrorProvider.notifier).state = e.toString());
    return SystemResultModel.empty();
  }
});''', content)

with open('lib/logic/providers.dart', 'w') as f:
    f.write(new_content)
