import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/load_model.dart';
import '../core/validation/load_form_validation.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import '../models/system_mode.dart';
import 'dashboard_screen.dart';
import '../services/update_service.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Schedule the update check after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkForUpdatesAndShowDialog(context);
    });
  }

  void _addDetailedLoad() {
    if (_detailedFormKey.currentState!.validate()) {
      final powerValue = LoadFormValidation.positiveValue(
        _powerValueController.text,
      );
      final dailyHours = LoadFormValidation.hoursValue(
        _dailyHoursController.text,
      );
      if (powerValue == null || dailyHours == null) return;
      final newLoad = LoadModel(
        id: const Uuid().v4(),
        name: _nameController.text,
        powerValue: powerValue,
        unit: _selectedUnit,
        dailyUsageHours: dailyHours,
        isInverterDevice: _isInverter,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);
      _clearDetailedForm();
    }
  }

  void _addQuickLoad() {
    if (_quickFormKey.currentState!.validate()) {
      final powerValue = LoadFormValidation.positiveValue(
        _quickPowerController.text,
      );
      final dailyHours = LoadFormValidation.hoursValue(
        _quickHoursController.text,
      );
      if (powerValue == null || dailyHours == null) return;
      final newLoad = LoadModel(
        id: const Uuid().v4(),
        name: AppStrings.quickLoadTitle,
        powerValue: powerValue,
        unit: PowerUnit.ampere,
        dailyUsageHours: dailyHours,
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
    final editFormKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: load.name);
    final powerCtrl = TextEditingController(text: load.powerValue.toString());
    final hoursCtrl = TextEditingController(
      text: load.dailyUsageHours.toString(),
    );
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
                child: Form(
                  key: editFormKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: AppStrings.deviceName,
                        ),
                        validator: LoadFormValidation.deviceName,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: powerCtrl,
                              decoration: const InputDecoration(
                                labelText: AppStrings.powerCapacity,
                              ),
                              keyboardType: TextInputType.number,
                              validator: LoadFormValidation.powerValue,
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
                                  case PowerUnit.ampere:
                                    localizedName = AppStrings.unitAmpere;
                                    break;
                                  case PowerUnit.watt:
                                    localizedName = AppStrings.unitWatt;
                                    break;
                                  case PowerUnit.ton:
                                    localizedName = AppStrings.unitTon;
                                    break;
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
                        decoration: const InputDecoration(
                          labelText: AppStrings.dailyUsageHours,
                        ),
                        keyboardType: TextInputType.number,
                        validator: LoadFormValidation.dailyHours,
                      ),
                      SwitchListTile(
                        title: const Text(AppStrings.isInverterAC),
                        value: editInverter,
                        onChanged: editUnit == PowerUnit.ton
                            ? (value) =>
                                  setDialogState(() => editInverter = value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(editFormKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    final powerValue = LoadFormValidation.positiveValue(
                      powerCtrl.text,
                    );
                    final dailyHours = LoadFormValidation.hoursValue(
                      hoursCtrl.text,
                    );
                    if (powerValue == null || dailyHours == null) return;
                    final updatedLoad = load.copyWith(
                      name: nameCtrl.text,
                      powerValue: powerValue,
                      unit: editUnit,
                      dailyUsageHours: dailyHours,
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
    final systemMode = ref.watch(systemModeProvider);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                AppStrings.gridAndBatterySettings,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (systemMode != SystemMode.directOnGrid)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: AppStrings.batteryType,
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                initialValue: gridSchedule.batteryType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'Lead-Acid/Gel',
                    child: Text(AppStrings.batteryGel),
                  ),
                  DropdownMenuItem(
                    value: 'Lithium',
                    child: Text(AppStrings.batteryLithium),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(gridScheduleProvider.notifier).state = gridSchedule
                        .copyWith(batteryType: value);
                  }
                },
              ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              title: const Text(AppStrings.isOffGridSystem),
              value: systemMode == SystemMode.offGrid,
              onChanged:
                  systemMode == SystemMode.directOnGrid ||
                      systemMode == SystemMode.ups
                  ? null
                  : (value) {
                      ref.read(systemModeProvider.notifier).state = value
                          ? SystemMode.offGrid
                          : SystemMode.hybrid;
                    },
            ),
            if (systemMode != SystemMode.offGrid) ...[
              SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                title: const Text(AppStrings.upsMode),
                value: systemMode == SystemMode.ups,
                onChanged: systemMode == SystemMode.directOnGrid
                    ? null
                    : (value) {
                        ref.read(systemModeProvider.notifier).state = value
                            ? SystemMode.ups
                            : SystemMode.hybrid;
                      },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: gridSchedule.gridOnHours.toString(),
                      decoration: const InputDecoration(
                        labelText: AppStrings.gridOnHours,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final val = double.tryParse(value);
                        if (val != null) {
                          ref.read(gridScheduleProvider.notifier).state =
                              gridSchedule.copyWith(gridOnHours: val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: gridSchedule.gridOffHours.toString(),
                      decoration: const InputDecoration(
                        labelText: AppStrings.gridOffHours,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final val = double.tryParse(value);
                        if (val != null) {
                          ref.read(gridScheduleProvider.notifier).state =
                              gridSchedule.copyWith(gridOffHours: val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (gridSchedule.gridOnHours > 0 &&
                  systemMode != SystemMode.directOnGrid) ...[
                Text(
                  systemMode == SystemMode.ups
                      ? 'نسبة الاعتماد على الوطنية لشحن البطاريات: 100%'
                      : 'نسبة الاعتماد على الوطنية لشحن البطاريات: ${gridSchedule.gridChargeDependencyPercent.toStringAsFixed(0)}%',
                ),
                Slider(
                  value: systemMode == SystemMode.ups
                      ? 100.0
                      : gridSchedule.gridChargeDependencyPercent,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: systemMode == SystemMode.ups
                      ? '100'
                      : gridSchedule.gridChargeDependencyPercent
                            .toStringAsFixed(0),
                  onChanged: systemMode == SystemMode.ups
                      ? null
                      : (value) {
                          ref
                              .read(gridScheduleProvider.notifier)
                              .state = gridSchedule.copyWith(
                            gridChargeDependencyPercent: value,
                          );
                        },
                ),
                if (systemMode == SystemMode.ups)
                  const Text(
                    "🔒 تم تثبيت الشحن من الوطنية بنسبة 100% نظراً لعدم توفر ألواح شمسية كبديل.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loads = ref.watch(loadListProvider);
    final systemMode = ref.watch(systemModeProvider);

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
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildGridSettings()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 350,
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
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: AppStrings.deviceName,
                                      ),
                                      validator: LoadFormValidation.deviceName,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _powerValueController,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  AppStrings.powerCapacity,
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator:
                                                LoadFormValidation.powerValue,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 1,
                                          child:
                                              DropdownButtonFormField<
                                                PowerUnit
                                              >(
                                                initialValue: _selectedUnit,
                                                isExpanded: true,
                                                items: PowerUnit.values.map((
                                                  unit,
                                                ) {
                                                  String localizedName = '';
                                                  switch (unit) {
                                                    case PowerUnit.ampere:
                                                      localizedName =
                                                          AppStrings.unitAmpere;
                                                      break;
                                                    case PowerUnit.watt:
                                                      localizedName =
                                                          AppStrings.unitWatt;
                                                      break;
                                                    case PowerUnit.ton:
                                                      localizedName =
                                                          AppStrings.unitTon;
                                                      break;
                                                  }
                                                  return DropdownMenuItem(
                                                    value: unit,
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        localizedName,
                                                      ),
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
                                      decoration: const InputDecoration(
                                        labelText: AppStrings.dailyUsageHours,
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: LoadFormValidation.dailyHours,
                                    ),
                                    SwitchListTile(
                                      title: const Text(
                                        AppStrings.isInverterAC,
                                      ),
                                      value: _isInverter,
                                      onChanged: _selectedUnit == PowerUnit.ton
                                          ? (value) => setState(
                                              () => _isInverter = value,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _addDetailedLoad,
                                      child: const Text(
                                        AppStrings.addLoadButton,
                                      ),
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
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _quickPowerController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            '${AppStrings.powerCapacity} (${AppStrings.unitAmpere})',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: LoadFormValidation.powerValue,
                                    ),
                                    TextFormField(
                                      controller: _quickHoursController,
                                      decoration: const InputDecoration(
                                        labelText: AppStrings.dailyUsageHours,
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: LoadFormValidation.dailyHours,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _addQuickLoad,
                                      child: const Text(
                                        AppStrings.addLoadButton,
                                      ),
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
              ),
              SliverToBoxAdapter(
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    title: const Text(AppStrings.daytimeOnlyMode),
                    value: systemMode == SystemMode.directOnGrid,
                    onChanged:
                        systemMode == SystemMode.ups ||
                            systemMode == SystemMode.offGrid
                        ? null
                        : (value) {
                            ref.read(systemModeProvider.notifier).state = value
                                ? SystemMode.directOnGrid
                                : SystemMode.hybrid;
                          },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider()),
              if (loads.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text(AppStrings.noLoadsAddedYet)),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final load = loads[index];
                    return ListTile(
                      title: Text(load.name),
                      subtitle: Text(
                        '${load.powerValue} ${load.unit.name.toUpperCase()} - ${load.dailyUsageHours} ${AppStrings.hrsDay}',
                      ),
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
                              ref
                                  .read(loadListProvider.notifier)
                                  .removeLoad(load.id);
                            },
                          ),
                        ],
                      ),
                    );
                  }, childCount: loads.length),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('عرض النتائج'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
