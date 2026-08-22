import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exceptions.dart';
import '../core/validation/input_parser.dart';
import '../logic/app_strings.dart';
import '../logic/providers.dart';
import '../models/grid_schedule_model.dart';
import '../models/load_model.dart';
import '../models/system_mode.dart';
import '../models/system_settings_model.dart';
import '../services/update_service.dart';
import '../widgets/edit_load_dialog.dart';
import 'dashboard_screen.dart';
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
  final _powerController = TextEditingController();
  final _dayController = TextEditingController();
  final _nightController = TextEditingController(text: '0');
  final _quantityController = TextEditingController(text: '1');
  final _multiplierController = TextEditingController(text: '1');
  final _quickPowerController = TextEditingController();
  final _quickHoursController = TextEditingController();
  PowerUnit _selectedUnit = PowerUnit.watt;
  bool _isInverter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService().checkForUpdatesAndShowDialog(context);
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _powerController,
      _dayController,
      _nightController,
      _quantityController,
      _multiplierController,
      _quickPowerController,
      _quickHoursController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
    );
  }

  double? _tryNumber(TextEditingController controller) =>
      InputParser.doubleOrNull(controller.text);

  void _addDetailedLoad() {
    if (!(_detailedFormKey.currentState?.validate() ?? false)) return;
    final day = _tryNumber(_dayController);
    final night = _tryNumber(_nightController);
    final power = _tryNumber(_powerController);
    final multiplier = _tryNumber(_multiplierController);
    final quantity = InputParser.intOrNull(_quantityController.text);
    if (day == null ||
        night == null ||
        power == null ||
        multiplier == null ||
        quantity == null) {
      _showError(const InvalidLoadInput('تعذر قراءة قيم الحمل بعد التحقق.'));
      return;
    }
    try {
      final load = LoadModel(
        name: _nameController.text.trim(),
        powerValue: power,
        unit: _selectedUnit,
        quantity: quantity,
        startingCurrentMultiplier: multiplier,
        dailyUsageHours: day + night,
        daytimeHours: day,
        nighttimeHours: night,
        isInverterDevice: _isInverter,
      );
      ref.read(loadListProvider.notifier).addLoad(load);
      _clearDetailedForm();
    } catch (error) {
      _showError(error);
    }
  }

  void _addQuickLoad() {
    if (!(_quickFormKey.currentState?.validate() ?? false)) return;
    final hours = _tryNumber(_quickHoursController);
    final power = _tryNumber(_quickPowerController);
    if (hours == null || power == null) {
      _showError(const InvalidLoadInput('تعذر قراءة الحمل السريع بعد التحقق.'));
      return;
    }
    try {
      ref
          .read(loadListProvider.notifier)
          .addLoad(
            LoadModel(
              name: AppStrings.quickLoadTitle,
              powerValue: power,
              unit: PowerUnit.ampere,
              dailyUsageHours: hours,
              daytimeHours: hours,
              nighttimeHours: 0,
            ),
          );
      _quickPowerController.clear();
      _quickHoursController.clear();
    } catch (error) {
      _showError(error);
    }
  }

  void _clearDetailedForm() {
    _nameController.clear();
    _powerController.clear();
    _dayController.clear();
    _nightController.text = '0';
    _quantityController.text = '1';
    _multiplierController.text = '1';
    setState(() {
      _selectedUnit = PowerUnit.watt;
      _isInverter = false;
    });
  }

  Future<void> _editLoad(LoadModel load) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EditLoadDialog(
        load: load,
        onSave: (updated) {
          try {
            ref.read(loadListProvider.notifier).updateLoad(updated);
            return true;
          } catch (error) {
            _showError(error);
            return false;
          }
        },
      ),
    );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'أدخل $label.' : null;

  String? _positive(
    String? value,
    String label, {
    double max = double.infinity,
  }) {
    final parsed = value == null ? null : InputParser.doubleOrNull(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > max) {
      return '$label يجب أن تكون أكبر من صفر${max.isFinite ? ' وألا تتجاوز $max' : ''}.';
    }
    return null;
  }

  String? _hours(String? value, String label) {
    final parsed = value == null ? null : InputParser.doubleOrNull(value);
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 24) {
      return '$label يجب أن تكون بين 0 و24.';
    }
    return null;
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String? Function(String?) validator, {
    bool integer = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    validator: validator,
  );

  Widget _buildGridSettings(SystemSettingsModel settings) {
    final schedule = settings.gridSchedule;
    void updateSchedule(GridScheduleModel next) {
      try {
        ref
            .read(systemSettingsProvider.notifier)
            .update(settings.copyWith(gridSchedule: next));
      } catch (error) {
        _showError(error);
      }
    }

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.gridAndBatterySettings,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            DropdownButtonFormField<SystemMode>(
              initialValue: settings.systemMode,
              decoration: const InputDecoration(labelText: 'نوع النظام'),
              items: const [
                DropdownMenuItem(
                  value: SystemMode.hybrid,
                  child: Text('هايبرد — Hybrid'),
                ),
                DropdownMenuItem(
                  value: SystemMode.offGrid,
                  child: Text('مستقل — Off-grid'),
                ),
                DropdownMenuItem(
                  value: SystemMode.ups,
                  child: Text('UPS — شبكة وبطارية'),
                ),
                DropdownMenuItem(
                  value: SystemMode.directOnGrid,
                  child: Text('تشغيل نهاري — Direct on-grid'),
                ),
              ],
              onChanged: (mode) {
                if (mode == null) return;
                try {
                  ref
                      .read(systemSettingsProvider.notifier)
                      .update(settings.copyWith(systemMode: mode));
                } catch (error) {
                  _showError(error);
                }
              },
            ),
            if (settings.systemMode != SystemMode.directOnGrid &&
                settings.systemMode != SystemMode.ups)
              DropdownButtonFormField<String>(
                initialValue: schedule.batteryType,
                decoration: const InputDecoration(
                  labelText: AppStrings.batteryType,
                ),
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
                    updateSchedule(schedule.copyWith(batteryType: value));
                  }
                },
              ),
            if (settings.systemMode == SystemMode.hybrid ||
                settings.systemMode == SystemMode.ups) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${AppStrings.gridOnHours}: ${schedule.gridOnHours.toStringAsFixed(1)} ساعة',
                ),
                subtitle: Text(
                  '${AppStrings.gridOffHours}: ${schedule.gridOffHours.toStringAsFixed(1)} ساعة — '
                  'تبدأ الشبكة عند ${schedule.gridStartHour.toStringAsFixed(1)}:00',
                ),
                trailing: OutlinedButton(
                  onPressed: () => _editGridSchedule(settings, updateSchedule),
                  child: const Text('تعديل الجدول'),
                ),
              ),
              Slider(
                value: settings.systemMode == SystemMode.ups
                    ? 100
                    : schedule.gridChargeDependencyPercent,
                min: 0,
                max: 100,
                divisions: 20,
                label:
                    '${settings.systemMode == SystemMode.ups ? 100 : schedule.gridChargeDependencyPercent.toStringAsFixed(0)}%',
                onChanged: settings.systemMode == SystemMode.ups
                    ? null
                    : (value) => updateSchedule(
                        schedule.copyWith(gridChargeDependencyPercent: value),
                      ),
              ),
              Text(
                'اعتماد شحن البطارية على الشبكة: ${settings.systemMode == SystemMode.ups ? '100' : schedule.gridChargeDependencyPercent.toStringAsFixed(0)}%',
              ),
            ],
            const Text(
              'يتم تفسير الفترات النهارية 06:00–18:00، ولا يوزع التطبيق الحمل تلقائياً بين النهار والليل.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGridSchedule(
    SystemSettingsModel settings,
    ValueChanged<GridScheduleModel> updateSchedule,
  ) async {
    final schedule = settings.gridSchedule;
    final startController = TextEditingController(
      text: schedule.gridStartHour.toString(),
    );
    final onController = TextEditingController(
      text: schedule.gridOnHours.toString(),
    );
    final offController = TextEditingController(
      text: schedule.gridOffHours.toString(),
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('جدول توفر الشبكة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ساعة بدء توفر الشبكة (0–أقل من 24)',
                ),
              ),
              TextField(
                controller: onController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.gridOnHours,
                ),
              ),
              TextField(
                controller: offController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.gridOffHours,
                ),
              ),
              const SizedBox(height: 8),
              const Text('يجب أن يساوي مجموع الساعات 24.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final start = InputParser.doubleOrNull(startController.text);
                final on = InputParser.doubleOrNull(onController.text);
                final off = InputParser.doubleOrNull(offController.text);
                if (start == null ||
                    on == null ||
                    off == null ||
                    !start.isFinite ||
                    !on.isFinite ||
                    !off.isFinite ||
                    start < 0 ||
                    start >= 24 ||
                    start + on > 24.0001 ||
                    (on + off - 24).abs() > 0.0001) {
                  _showError(
                    const InvalidEngineeringInput(
                      'جدول الشبكة يتطلب بداية بين 0 و24، ونافذة لا تتجاوز نهاية اليوم، ومجموع ساعات يساوي 24.',
                    ),
                  );
                  return;
                }
                updateSchedule(
                  schedule.copyWith(
                    gridStartHour: start,
                    gridOnHours: on,
                    gridOffHours: off,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      );
    } finally {
      startController.dispose();
      onController.dispose();
      offController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadState = ref.watch(loadListProvider);
    final settings = ref.watch(systemSettingsProvider);
    if (loadState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.addElectricalLoads),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.tabDetailedInput),
              Tab(text: AppStrings.tabQuickInput),
            ],
          ),
        ),
        body: ListView(
          key: const ValueKey('load-input-page-list'),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildGridSettings(settings),
            SizedBox(
              height: 430,
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _detailedFormKey,
                      child: ListView(
                        key: const ValueKey('detailed-load-list'),
                        children: [
                          _numberField(
                            _nameController,
                            AppStrings.deviceName,
                            (value) => _required(value, 'اسم الجهاز'),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _powerController,
                            AppStrings.powerCapacity,
                            (value) => _positive(value, 'القدرة'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PowerUnit>(
                            initialValue: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'الوحدة',
                              border: OutlineInputBorder(),
                            ),
                            items: PowerUnit.values
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => _selectedUnit = value ?? _selectedUnit,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _quantityController,
                            'الكمية',
                            (value) => _positive(value, 'الكمية', max: 100000),
                            integer: true,
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _dayController,
                            'ساعات النهار (06:00–18:00)',
                            (value) => _hours(value, 'ساعات النهار'),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _nightController,
                            'ساعات الليل',
                            (value) => _hours(value, 'ساعات الليل'),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _multiplierController,
                            'معامل تيار البدء (1–10)',
                            (value) => _positive(value, 'المعامل', max: 10),
                          ),
                          SwitchListTile(
                            title: const Text(AppStrings.isInverterAC),
                            value: _isInverter,
                            onChanged: _selectedUnit == PowerUnit.ton
                                ? (value) => setState(() => _isInverter = value)
                                : null,
                          ),
                          ElevatedButton.icon(
                            key: const ValueKey('add-detailed-load'),
                            onPressed: _addDetailedLoad,
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.addLoadButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _quickFormKey,
                      child: ListView(
                        children: [
                          _numberField(
                            _quickPowerController,
                            'التيار الكلي (A)',
                            (value) => _positive(value, 'التيار'),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _quickHoursController,
                            'ساعات النهار (06:00–18:00)',
                            (value) => _hours(value, 'الساعات'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'الإدخال السريع يسجل الحمل كحمل نهاري؛ استخدم الإدخال المفصل للحمل الليلي.',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            key: const ValueKey('add-quick-load'),
                            onPressed: _addQuickLoad,
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.addLoadButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (loadState.errorMessage != null)
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text(loadState.errorMessage!),
              ),
            if (loadState.loads.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text(AppStrings.noLoadsAddedYet)),
              )
            else
              ...loadState.loads.map(
                (load) => ListTile(
                  key: ValueKey('load-${load.id}'),
                  title: Text(load.name),
                  subtitle: Text(
                    '${load.quantity} × ${load.powerValue} ${load.unit.name} — نهار ${load.daytimeHours} ساعة، ليل ${load.nighttimeHours} ساعة',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        key: ValueKey('edit-load-${load.id}'),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editLoad(load),
                      ),
                      IconButton(
                        key: ValueKey('delete-load-${load.id}'),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          try {
                            ref
                                .read(loadListProvider.notifier)
                                .removeLoad(load.id);
                          } catch (error) {
                            _showError(error);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                key: const ValueKey('open-results'),
                onPressed: loadState.loads.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      ),
                icon: const Icon(Icons.check_circle),
                label: const Text('عرض النتائج'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
