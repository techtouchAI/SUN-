import 'package:flutter/material.dart';

import '../core/validation/input_parser.dart';
import '../logic/app_strings.dart';
import '../models/load_model.dart';

class EditLoadDialog extends StatefulWidget {
  final LoadModel load;
  final bool Function(LoadModel updatedLoad) onSave;

  const EditLoadDialog({required this.load, required this.onSave, super.key});

  @override
  State<EditLoadDialog> createState() => _EditLoadDialogState();
}

class _EditLoadDialogState extends State<EditLoadDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _powerController;
  late final TextEditingController _dayController;
  late final TextEditingController _nightController;
  late final TextEditingController _quantityController;
  late final TextEditingController _multiplierController;
  final _formKey = GlobalKey<FormState>();
  late PowerUnit _unit;
  late bool _isInverter;

  @override
  void initState() {
    super.initState();
    final load = widget.load;
    _nameController = TextEditingController(text: load.name);
    _powerController = TextEditingController(text: load.powerValue.toString());
    _dayController = TextEditingController(text: load.daytimeHours.toString());
    _nightController = TextEditingController(
      text: load.nighttimeHours.toString(),
    );
    _quantityController = TextEditingController(text: load.quantity.toString());
    _multiplierController = TextEditingController(
      text: load.startingCurrentMultiplier.toString(),
    );
    _unit = load.unit;
    _isInverter = load.isInverterDevice;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _powerController.dispose();
    _dayController.dispose();
    _nightController.dispose();
    _quantityController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  String? _requiredValue(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'أدخل $label.';
    return null;
  }

  String? _positiveValue(String? value, String label, {double max = 100000}) {
    final parsed = InputParser.doubleOrNull(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return '$label يجب أن يكون رقماً أكبر من صفر.';
    }
    if (parsed > max) return '$label خارج المجال المسموح.';
    return null;
  }

  String? _hoursValue(String? value, String label) {
    final parsed = InputParser.doubleOrNull(value);
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 24) {
      return '$label يجب أن يكون بين 0 و24.';
    }
    return null;
  }

  String? _quantityValue(String? value) {
    final parsed = InputParser.intOrNull(value);
    if (parsed == null || parsed < 1 || parsed > 100000) {
      return 'الكمية يجب أن تكون عدداً صحيحاً بين 1 و100000.';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final parsedPower = InputParser.doubleOrNull(_powerController.text);
    final parsedQuantity = InputParser.intOrNull(_quantityController.text);
    final parsedDay = InputParser.doubleOrNull(_dayController.text);
    final parsedNight = InputParser.doubleOrNull(_nightController.text);
    final parsedMultiplier = InputParser.doubleOrNull(
      _multiplierController.text,
    );
    if (parsedPower == null ||
        parsedQuantity == null ||
        parsedDay == null ||
        parsedNight == null ||
        parsedMultiplier == null) {
      return;
    }

    final updated = widget.load.copyWith(
      name: _nameController.text.trim(),
      powerValue: parsedPower,
      unit: _unit,
      quantity: parsedQuantity,
      daytimeHours: parsedDay,
      nighttimeHours: parsedNight,
      dailyUsageHours: parsedDay + parsedNight,
      startingCurrentMultiplier: parsedMultiplier,
      isInverterDevice: _isInverter,
    );
    if (!widget.onSave(updated)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(AppStrings.editLoad),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.deviceName,
              ),
              validator: (value) => _requiredValue(value, 'اسم الجهاز'),
            ),
            TextFormField(
              controller: _powerController,
              decoration: const InputDecoration(
                labelText: AppStrings.powerCapacity,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _positiveValue(value, 'القدرة'),
            ),
            DropdownButtonFormField<PowerUnit>(
              initialValue: _unit,
              items: PowerUnit.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _unit = value);
              },
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
              validator: _quantityValue,
            ),
            TextFormField(
              controller: _dayController,
              decoration: const InputDecoration(labelText: 'ساعات النهار'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _hoursValue(value, 'ساعات النهار'),
            ),
            TextFormField(
              controller: _nightController,
              decoration: const InputDecoration(labelText: 'ساعات الليل'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _hoursValue(value, 'ساعات الليل'),
            ),
            TextFormField(
              controller: _multiplierController,
              decoration: const InputDecoration(labelText: 'معامل تيار البدء'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _positiveValue(value, 'المعامل', max: 10),
            ),
            SwitchListTile(
              title: const Text(AppStrings.isInverterAC),
              value: _isInverter,
              onChanged: _unit == PowerUnit.ton
                  ? (value) => setState(() => _isInverter = value)
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(AppStrings.cancel),
      ),
      ElevatedButton(
        key: ValueKey('save-edit-load-${widget.load.id}'),
        onPressed: _submit,
        child: const Text(AppStrings.save),
      ),
    ],
  );
}
