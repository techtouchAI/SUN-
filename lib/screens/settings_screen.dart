import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../logic/providers.dart';
import '../logic/app_strings.dart';
import '../models/system_mode.dart';
import '../repositories/solar_calculation_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
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
                  ref.read(themeModeProvider.notifier).state = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
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
                label: AppStrings.wiringCostLabel,
                provider: wiringCostProvider,
              ),

              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'سعر الصرف (IQD)',
                provider: iqdExchangeRateProvider,
                suffix: ' IQD',
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'جهد الشبكة (V)',
                provider: gridVoltageProvider,
                suffix: ' V',
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'المتغيرات الهندسية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'جهد النظام (V)',
                provider: systemVoltageProvider,
                suffix: ' V',
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'ساعات الذروة (PSH)',
                provider: peakSunHoursProvider,
                suffix: ' ساعات',
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'نسبة الفقد (%)',
                provider: energyLossPercentageProvider,
                suffix: ' %',
              ),
              const SizedBox(height: 16),
              _buildPriceInput(
                context: context,
                ref: ref,
                label: 'أيام التغطية/الغيوم',
                provider: daysOfAutonomyProvider,
                suffix: ' أيام',
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'إعدادات متقدمة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (ref.watch(systemModeProvider) != SystemMode.ups) ...[
                _buildPriceInput(
                  context: context,
                  ref: ref,
                  label: 'قدرة اللوح المخصصة (Watt)',
                  provider: panelCapacityProvider,
                  suffix: ' W',
                  onChangedCallback: (parsedValue) {
                    final interpolatedIsc =
                        SolarCalculationRepository.getInterpolatedIsc(
                          parsedValue,
                        );
                    Future.microtask(() {
                      ref.read(panelIscProvider.notifier).state = double.parse(
                        interpolatedIsc.toStringAsFixed(2),
                      );
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPriceInput(
                  context: context,
                  ref: ref,
                  label: 'تيار القصر للوح (Isc)',
                  provider: panelIscProvider,
                  suffix: ' A',
                  keyString: ref.watch(panelIscProvider).toString(),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'مكان تركيب الإينفيرتر',
                  border: OutlineInputBorder(),
                ),
                initialValue: ref.watch(inverterLocationProvider),
                items: const [
                  DropdownMenuItem(
                    value: 'indoor',
                    child: Text('داخلي (Indoor)'),
                  ),
                  DropdownMenuItem(
                    value: 'outdoor',
                    child: Text('خارجي (Outdoor)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(inverterLocationProvider.notifier).state = value;
                  }
                },
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'تفاصيل الحماية الكهربائية (اختيارية)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 16),
                child: Text(
                  'أدخل بيانات الموقع الفعلية فقط. لا تُستخدم أي قيم عالمية أو افتراضات.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              if (ref.watch(systemModeProvider) != SystemMode.ups) ...[
                const Text(
                  'توصيل الألواح',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildOptionalIntInput(
                  ref: ref,
                  label: 'عدد الألواح على التوالي لكل مسار',
                  provider: pvModulesPerStringProvider,
                ),
                const SizedBox(height: 16),
                _buildOptionalIntInput(
                  ref: ref,
                  label: 'عدد المسارات على التوازي',
                  provider: pvParallelStringsProvider,
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'كابل DC',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildOptionalDoubleInput(
                ref: ref,
                label: 'طول مسار كابل DC باتجاه واحد',
                suffix: ' m',
                provider: dcCableLengthMetersProvider,
                allowZero: false,
              ),
              const SizedBox(height: 16),
              _buildOptionalDropdown(
                ref: ref,
                label: 'مادة الموصل',
                provider: dcCableMaterialProvider,
                items: const [
                  DropdownMenuItem(value: 'copper', child: Text('نحاس')),
                  DropdownMenuItem(value: 'aluminum', child: Text('ألمنيوم')),
                ],
              ),
              const SizedBox(height: 16),
              _buildOptionalDropdown(
                ref: ref,
                label: 'تصنيف عزل الكابل',
                provider: dcCableInsulationProvider,
                items: const [
                  DropdownMenuItem(value: '70C', child: Text('70°C')),
                  DropdownMenuItem(value: '90C', child: Text('90°C')),
                ],
              ),
              const SizedBox(height: 16),
              _buildOptionalDropdown(
                ref: ref,
                label: 'طريقة تمديد كابل DC',
                provider: dcCableInstallationMethodProvider,
                items: const [
                  DropdownMenuItem(
                    value: 'conduit',
                    child: Text('داخل مواسير'),
                  ),
                  DropdownMenuItem(
                    value: 'open_air',
                    child: Text('مكشوف بالهواء'),
                  ),
                  DropdownMenuItem(
                    value: 'tray',
                    child: Text('على حاملة كابلات'),
                  ),
                  DropdownMenuItem(value: 'buried', child: Text('مدفون')),
                ],
              ),
              const SizedBox(height: 16),
              _buildOptionalDoubleInput(
                ref: ref,
                label: 'درجة الحرارة المحيطة',
                suffix: ' °C',
                provider: dcCableAmbientTemperatureProvider,
                allowZero: true,
              ),
              const SizedBox(height: 16),
              _buildOptionalIntInput(
                ref: ref,
                label: 'عدد الموصلات الحاملة للتيار',
                provider: dcCableLoadedConductorsProvider,
              ),
              const Divider(),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('تصميم وبرمجة كنان الصائغ'),
                trailing: const Icon(Icons.telegram),
                onTap: () async {
                  try {
                    final url = Uri.parse('https://t.me/techtouch7');
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch Telegram: $e');
                  }
                },
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
    String suffix = '\$',
    void Function(double)? onChangedCallback,
    String? keyString,
  }) {
    return TextFormField(
      key: keyString != null ? Key(keyString) : null,
      initialValue: keyString ?? ref.read(provider).toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: suffix,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final parsedValue = double.tryParse(value);
        if (parsedValue != null && parsedValue >= 0) {
          ref.read(provider.notifier).state = parsedValue;
          if (onChangedCallback != null) {
            onChangedCallback(parsedValue);
          }
        }
      },
    );
  }

  Widget _buildOptionalDoubleInput({
    required WidgetRef ref,
    required String label,
    required StateProvider<double?> provider,
    required bool allowZero,
    String suffix = '',
  }) {
    final currentValue = ref.watch(provider);
    return TextFormField(
      key: ValueKey('$label-$currentValue'),
      initialValue: currentValue?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: suffix,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          ref.read(provider.notifier).state = null;
          return;
        }
        final parsedValue = double.tryParse(trimmed);
        if (parsedValue != null &&
            parsedValue.isFinite &&
            (allowZero ? parsedValue >= 0 : parsedValue > 0)) {
          ref.read(provider.notifier).state = parsedValue;
        }
      },
    );
  }

  Widget _buildOptionalIntInput({
    required WidgetRef ref,
    required String label,
    required StateProvider<int?> provider,
  }) {
    final currentValue = ref.watch(provider);
    return TextFormField(
      key: ValueKey('$label-$currentValue'),
      initialValue: currentValue?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          ref.read(provider.notifier).state = null;
          return;
        }
        final parsedValue = int.tryParse(trimmed);
        if (parsedValue != null && parsedValue > 0) {
          ref.read(provider.notifier).state = parsedValue;
        }
      },
    );
  }

  Widget _buildOptionalDropdown({
    required WidgetRef ref,
    required String label,
    required StateProvider<String?> provider,
    required List<DropdownMenuItem<String>> items,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      initialValue: ref.watch(provider),
      isExpanded: true,
      items: items,
      onChanged: (value) => ref.read(provider.notifier).state = value,
    );
  }
}
