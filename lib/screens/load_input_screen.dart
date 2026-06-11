import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import '../models/load_model.dart';
import 'dashboard_screen.dart';

class LoadInputScreen extends ConsumerStatefulWidget {
  const LoadInputScreen({super.key});

  @override
  ConsumerState<LoadInputScreen> createState() => _LoadInputScreenState();
}

class _LoadInputScreenState extends ConsumerState<LoadInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _powerValueController = TextEditingController();
  final _dailyHoursController = TextEditingController();

  PowerUnit _selectedUnit = PowerUnit.watt;
  bool _isInverter = false;

  @override
  void dispose() {
    _nameController.dispose();
    _powerValueController.dispose();
    _dailyHoursController.dispose();
    super.dispose();
  }

  void _addLoad() {
    if (_formKey.currentState!.validate()) {
      final newLoad = LoadModel(
        name: _nameController.text,
        unit: _selectedUnit,
        powerValue: double.tryParse(_powerValueController.text) ?? 0.0,
        dailyUsageHours: double.tryParse(_dailyHoursController.text) ?? 0.0,
        isInverterDevice: _isInverter,
      );

      ref.read(loadListProvider.notifier).addLoad(newLoad);

      // Reset form
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

  @override
  Widget build(BuildContext context) {
    final loads = ref.watch(loadListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Electrical Loads'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Device Name'),
                        validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _powerValueController,
                              decoration: const InputDecoration(labelText: 'Power/Capacity'),
                              keyboardType: TextInputType.number,
                              validator: (value) => value!.isEmpty ? 'Enter value' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<PowerUnit>(
                              initialValue: _selectedUnit,
                              items: PowerUnit.values.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.name.toUpperCase()),
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
                        decoration: const InputDecoration(labelText: 'Daily Usage (Hours)'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Enter hours' : null,
                      ),
                      SwitchListTile(
                        title: const Text('Is Inverter AC?'),
                        value: _isInverter,
                        onChanged: _selectedUnit == PowerUnit.ton
                          ? (value) => setState(() => _isInverter = value)
                          : null, // Only enable for Air Conditioners (Ton) conceptually
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addLoad,
                        child: const Text('Add Load'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: loads.isEmpty
                ? const Center(child: Text('No loads added yet.'))
                : ListView.builder(
                    itemCount: loads.length,
                    itemBuilder: (context, index) {
                      final load = loads[index];
                      return ListTile(
                        title: Text(load.name),
                        subtitle: Text('${load.powerValue} ${load.unit.name} - ${load.dailyUsageHours} hrs/day'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            ref.read(loadListProvider.notifier).removeLoad(load.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
