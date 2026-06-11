import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import '../models/load_model.dart';
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

  // Detailed Input Controllers
  final _nameController = TextEditingController();
  final _powerValueController = TextEditingController();
  final _dailyHoursController = TextEditingController();
  PowerUnit _selectedUnit = PowerUnit.watt;
  bool _isInverter = false;

  // Quick Input Controllers
  final _quickPowerController = TextEditingController();
  final _quickHoursController = TextEditingController();

  // Edit Controllers
  final _editPowerController = TextEditingController();
  final _editHoursController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _powerValueController.dispose();
    _dailyHoursController.dispose();
    _quickPowerController.dispose();
    _quickHoursController.dispose();
    _editPowerController.dispose();
    _editHoursController.dispose();
    super.dispose();
  }

  void _addDetailedLoad() {
    if (_detailedFormKey.currentState!.validate()) {
      final newLoad = LoadModel(
        name: _nameController.text,
        unit: _selectedUnit,
        powerValue: double.tryParse(_powerValueController.text) ?? 0.0,
        dailyUsageHours: double.tryParse(_dailyHoursController.text) ?? 0.0,
        isInverterDevice: _isInverter,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);

      _nameController.clear();
      _powerValueController.clear();
      _dailyHoursController.clear();
      setState(() {
        _selectedUnit = PowerUnit.watt;
        _isInverter = false;
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _addQuickLoad() {
    if (_quickFormKey.currentState!.validate()) {
      final newLoad = LoadModel(
        name: AppStrings.quickLoadTitle,
        unit: PowerUnit.watt, // Quick load defaults to Watt
        powerValue: double.tryParse(_quickPowerController.text) ?? 0.0,
        dailyUsageHours: double.tryParse(_quickHoursController.text) ?? 0.0,
        isInverterDevice: false,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);

      _quickPowerController.clear();
      _quickHoursController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showEditDialog(LoadModel load) {
    _editPowerController.text = load.powerValue.toString();
    _editHoursController.text = load.dailyUsageHours.toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppStrings.editLoadTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _editPowerController,
                decoration: const InputDecoration(labelText: AppStrings.powerCapacity),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _editHoursController,
                decoration: const InputDecoration(labelText: AppStrings.dailyUsageHours),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedLoad = load.copyWith(
                  powerValue: double.tryParse(_editPowerController.text) ?? load.powerValue,
                  dailyUsageHours: double.tryParse(_editHoursController.text) ?? load.dailyUsageHours,
                );
                ref.read(loadListProvider.notifier).updateLoad(updatedLoad);
                Navigator.pop(context);
              },
              child: const Text(AppStrings.saveChanges),
            ),
          ],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.gridSettingsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              title: const Text(AppStrings.offGridMode),
              value: gridSchedule.isOffGrid,
              onChanged: (value) {
                ref.read(gridScheduleProvider.notifier).state = gridSchedule.copyWith(isOffGrid: value);
              },
            ),
            if (!gridSchedule.isOffGrid)
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
                                            return DropdownMenuItem(
                                              value: unit,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(unit.name.toUpperCase()),
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
                                    decoration: const InputDecoration(labelText: '${AppStrings.powerCapacity} (Watts)'),
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
    );
  }
}
