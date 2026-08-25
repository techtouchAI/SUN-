import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_calculator/models/dc_cable_installation_model.dart';
import 'package:solar_calculator/models/pv_array_topology_model.dart';
import 'package:solar_calculator/models/system_settings_model.dart';
import 'package:solar_calculator/repositories/settings_persistence_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists project PV topology and DC cable installation data', () async {
    final repository = SettingsPersistenceRepository();
    const settings = SystemSettingsModel(
      pvTopology: PvArrayTopologyModel(modulesPerString: 5, parallelStrings: 3),
      dcCableInstallation: DcCableInstallationModel(
        oneWayLengthMeters: 18,
        conductorMaterial: 'copper',
        insulationRating: '90C',
        installationMethod: 'conduit',
        ambientTemperatureCelsius: 40,
        loadedConductors: 2,
      ),
    );

    await repository.saveSettings(settings);
    final restored = await repository.loadSettings();

    expect(restored.pvTopology.modulesPerString, 5);
    expect(restored.pvTopology.parallelStrings, 3);
    expect(restored.dcCableInstallation.oneWayLengthMeters, 18);
    expect(restored.dcCableInstallation.conductorMaterial, 'copper');
    expect(restored.dcCableInstallation.insulationRating, '90C');
    expect(restored.dcCableInstallation.installationMethod, 'conduit');
    expect(restored.dcCableInstallation.ambientTemperatureCelsius, 40);
    expect(restored.dcCableInstallation.loadedConductors, 2);
  });
}
