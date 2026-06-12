import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/load_model.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import 'dashboard_screen.dart';

class LoadInputScreen extends ConsumerStatefulWidget {
  const LoadInputScreen({super.key});

  @override
  ConsumerState<LoadInputScreen> createState() => _LoadInputScreenState();
}

class _LoadInputScreenState extends ConsumerState<LoadInputScreen> {
  final _detailedFormKey = GlobalKey<FormState>();
  final _quickFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _powerValueController = TextEditingController();
  final _dailyHoursController = TextEditingController();
  final _quickPowerController = TextEditingController();
  final _quickHoursController = TextEditingController();

  PowerUnit _selectedUnit = PowerUnit.ampere;
  bool _isInverter = false;

  void _addDetailedLoad() {
    if (_detailedFormKey.currentState!.validate()) {
      final newLoad = LoadModel(
        id: const Uuid().v4(),
        name: _nameController.text,
        powerValue: double.parse(_powerValueController.text),
        unit: _selectedUnit,
        dailyUsageHours: double.parse(_dailyHoursController.text),
        isInverterDevice: _isInverter,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);
      _clearDetailedForm();
    }
  }

  void _addQuickLoad() {
    if (_quickFormKey.currentState!.validate()) {
      final newLoad = LoadModel(
        id: const Uuid().v4(),
        name: AppStrings.quickLoadTitle,
        powerValue: double.parse(_quickPowerController.text),
        unit: PowerUnit.ampere,
        dailyUsageHours: double.parse(_quickHoursController.text),
        isInverterDevice: false,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);
      _clearQuickForm();
    }
  }

  void _clearDetailedForm() {
    _nameController.clear();
    _powerValueController.clear();
    _dailyHoursController.clear();
    setState(() {
      _selectedUnit = PowerUnit.ampere;
      _isInverter = false;
    });
  }

  void _clearQuickForm() {
    _quickPowerController.clear();
    _quickHoursController.clear();
  }

  void _showEditDialog(LoadModel load) {
    final nameCtrl = TextEditingController(text: load.name);
    final powerCtrl = TextEditingController(text: load.powerValue.toString());
    final hoursCtrl = TextEditingController(text: load.dailyUsageHours.toString());
    PowerUnit editUnit = load.unit;
    bool editInverter = load.isInverterDevice;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(AppStrings.editLoad),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: AppStrings.deviceName),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: powerCtrl,
                            decoration: const InputDecoration(labelText: AppStrings.powerCapacity),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<PowerUnit>(
                            initialValue: editUnit,
                            isExpanded: true,
                            items: PowerUnit.values.map((unit) {
                              String localizedName = '';
                              switch (unit) {
                                case PowerUnit.ampere: localizedName = AppStrings.unitAmpere; break;
                                case PowerUnit.watt: localizedName = AppStrings.unitWatt; break;
                                case PowerUnit.ton: localizedName = AppStrings.unitTon; break;
                              }
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(localizedName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                editUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: hoursCtrl,
                      decoration: const InputDecoration(labelText: AppStrings.dailyUsageHours),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      title: const Text(AppStrings.isInverterAC),
                      value: editInverter,
                      onChanged: editUnit == PowerUnit.ton
                          ? (value) => setDialogState(() => editInverter = value)
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final updatedLoad = load.copyWith(
                      name: nameCtrl.text,
                      powerValue: double.parse(powerCtrl.text),
                      unit: editUnit,
                      dailyUsageHours: double.parse(hoursCtrl.text),
                      isInverterDevice: editInverter,
                    );
                    ref.read(loadListProvider.notifier).updateLoad(updatedLoad);
                    Navigator.pop(context);
                  },
                  child: const Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGridSettings() {
    final gridSchedule = ref.watch(gridScheduleProvider);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.gridAndBatterySettings,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: AppStrings.batteryType,
                border: OutlineInputBorder(),
              ),
              initialValue: gridSchedule.batteryType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Lead-Acid/Gel', child: Text(AppStrings.batteryGel)),
                DropdownMenuItem(value: 'Lithium', child: Text(AppStrings.batteryLithium)),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(batteryType: value);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.isOffGridSystem),
              value: gridSchedule.isOffGrid,
              onChanged: (value) {
                ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(
                  isOffGrid: value,
                  isUpsMode: value ? false : gridSchedule.isUpsMode,
                );
              },
            ),
            if (!gridSchedule.isOffGrid) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.upsMode),
                value: gridSchedule.isUpsMode,
                onChanged: (value) {
                  ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(isUpsMode: value);
                  if (value) {
                    ref.read(isDaytimeOnlyProvider.notifier).state = false;
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: gridSchedule.gridOnHours.toString(),
                      decoration: const InputDecoration(labelText: AppStrings.gridOnHours),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final val = double.tryParse(value);
                        if (val != null) {
                          ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(gridOnHours: val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: gridSchedule.gridOffHours.toString(),
                      decoration: const InputDecoration(labelText: AppStrings.gridOffHours),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final val = double.tryParse(value);
                        if (val != null) {
                          ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(gridOffHours: val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loads = ref.watch(loadListProvider);
    final isDaytimeOnly = ref.watch(isDaytimeOnlyProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.addElectricalLoads),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.tabDetailedInput),
              Tab(text: AppStrings.tabQuickInput),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  _buildGridSettings(),
                  Expanded(
                    flex: 4,
                    child: TabBarView(
                      children: [
                        // Tab 1: Detailed Input
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Form(
                                  key: _detailedFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(labelText: AppStrings.deviceName),
                                        validator: (value) => value!.isEmpty ? AppStrings.pleaseEnterName : null,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller: _powerValueController,
                                              decoration: const InputDecoration(labelText: AppStrings.powerCapacity),
                                              keyboardType: TextInputType.number,
                                              validator: (value) => value!.isEmpty ? AppStrings.enterValue : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 1,
                                            child: DropdownButtonFormField<PowerUnit>(
                                              initialValue: _selectedUnit,
                                              isExpanded: true,
                                              items: PowerUnit.values.map((unit) {
                                                String localizedName = '';
                                                switch (unit) {
                                                  case PowerUnit.ampere: localizedName = AppStrings.unitAmpere; break;
                                                  case PowerUnit.watt: localizedName = AppStrings.unitWatt; break;
                                                  case PowerUnit.ton: localizedName = AppStrings.unitTon; break;
                                                }
                                                return DropdownMenuItem(
                                                  value: unit,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(localizedName),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedUnit = value!;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextFormField(
                                        controller: _dailyHoursController,
                                        decoration: const InputDecoration(labelText: AppStrings.dailyUsageHours),
                                        keyboardType: TextInputType.number,
                                        validator: (value) => value!.isEmpty ? AppStrings.enterHours : null,
                                      ),
                                      SwitchListTile(
                                        title: const Text(AppStrings.isInverterAC),
                                        value: _isInverter,
                                        onChanged: _selectedUnit == PowerUnit.ton
                                          ? (value) => setState(() => _isInverter = value)
                                          : null,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _addDetailedLoad,
                                        child: const Text(AppStrings.addLoadButton),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tab 2: Quick Input
                        SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Form(
                                  key: _quickFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _quickPowerController,
                                        decoration: const InputDecoration(labelText: '${AppStrings.powerCapacity} (${AppStrings.unitAmpere})'),
                                        keyboardType: TextInputType.number,
                                        validator: (value) => value!.isEmpty ? AppStrings.enterValue : null,
                                      ),
                                      TextFormField(
                                        controller: _quickHoursController,
                                        decoration: const InputDecoration(labelText: AppStrings.dailyUsageHours),
                                        keyboardType: TextInputType.number,
                                        validator: (value) => value!.isEmpty ? AppStrings.enterHours : null,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _addQuickLoad,
                                        child: const Text(AppStrings.addLoadButton),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SwitchListTile(
                      title: const Text(AppStrings.daytimeOnlyMode),
                      value: isDaytimeOnly,
                      onChanged: (value) {
                        ref.read(isDaytimeOnlyProvider.notifier).state = value;
                      },
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    flex: 3,
                    child: loads.isEmpty
                      ? const Center(child: Text(AppStrings.noLoadsAddedYet))
                      : ListView.builder(
                          itemCount: loads.length,
                          itemBuilder: (context, index) {
                            final load = loads[index];
                            return ListTile(
                              title: Text(load.name),
                              subtitle: Text('${load.powerValue} ${load.unit.name.toUpperCase()} - ${load.dailyUsageHours} ${AppStrings.hrsDay}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(load),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      ref.read(loadListProvider.notifier).removeLoad(load.id);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
