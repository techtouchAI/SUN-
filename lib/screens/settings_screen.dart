import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text(AppStrings.darkModeToggle),
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).state =
                      value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                AppStrings.pricingSettingsTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: AppStrings.solarWattPriceLabel,
                provider: solarWattPriceProvider,
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: AppStrings.batteryAmperePriceLabel,
                provider: batteryAmperePriceProvider,
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: AppStrings.breakerPriceLabel,
                provider: breakerPriceProvider,
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: AppStrings.wiringCostLabel,
                provider: wiringCostProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInput({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required StateProvider<double> provider,
  }) {
    return TextFormField(
      initialValue: ref.read(provider).toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: '\$',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final parsedValue = double.tryParse(value);
        if (parsedValue != null && parsedValue >= 0) {
          ref.read(provider.notifier).state = parsedValue;
        }
      },
    );
  }
}
